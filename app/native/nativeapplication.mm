#import <AppKit/AppKit.h>
#import <SDL.h>

// Native helpers stay out of the Dock, while their SDL windows can still
// activate and receive input. Ordinary Qt launches never call this.
void configureNativeBackgroundApplication()
{
    SDL_SetHint(SDL_HINT_MAC_BACKGROUND_APP, "1");
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

#import <SDL.h>
#import <SDL_syswm.h>
#include <cstdio>
#include <string>
#include <thread>
#include <atomic>
#include <poll.h>
#include <unistd.h>
#include <cerrno>
#include <exception>
#include <dlfcn.h>
#include <functional>
#include "nativeoverlay.h"
#include "nativetitlebar.h"
#include "nativeapplication.h"

// This reader never calls AppKit window APIs. It only validates framed commands
// and queues SDL events; the live Session owns every action on its main thread.
static bool connectionWaiting = false;
void nativeSetConnectionWaiting(bool waiting) { connectionWaiting = waiting; }
bool nativeConnectionWaiting() { return connectionWaiting; }

static std::thread menuReader;
static std::atomic<bool> menuReaderStopping(true);
static bool supportedMenuAction(int action) {
    return action == 100 || action == 200 || action == 201 || action == 202 ||
           action == 203 || action == 207 || action == 208 || action == 209 ||
           action == 210 || action == 212 || action == 213 || action == 214 || action == 215 || action == 216;
}
void nativeAcknowledgeMenuAction(int action, Uint32 requestID) {
    if (!requestID) return;
    std::fprintf(stdout,"{\"event\":\"menuActionAcknowledged\",\"action\":%d,\"requestID\":%u}\n",action,requestID);
    std::fflush(stdout);
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,"Native menu action %d accepted (request %u)",action,requestID);
}
void nativeStopStreamMenuCommands() {
    menuReaderStopping = true;
    if (menuReader.joinable()) menuReader.join();
}

static NSString* const MLRestoreStreamWindow = @"com.moonlight-stream.NativeGlass.restoreStreamWindow";
static Uint32 restoreEventType;
static std::string lastMenuState;
Uint32 nativeRestoreStreamWindowEventType() { return restoreEventType; }

static NSWindow* nativeSDLWindow(SDL_Window* window)
{
    if (!window) return nil;
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    return SDL_GetWindowWMInfo(window, &info) && info.subsystem == SDL_SYSWM_COCOA ? info.info.cocoa.window : nil;
}

static Uint32 connectionWindowID;
static bool connectionVideoReference;
static void* connectionLibrary;
static void (*attachConnection)(void*,const char*,const char*,void(*)(int));
static void (*updateConnection)(const char*,int);
static void (*detachConnection)();
static std::function<void(int)> connectionCommand;
void nativeSetConnectionCommand(std::function<void(int)> command) { connectionCommand = std::move(command); }
static void connectionAction(int action) { if (connectionCommand) connectionCommand(action); }
SDL_Window* nativeConnectionWindow() { return connectionWindowID ? SDL_GetWindowFromID(connectionWindowID) : nullptr; }
void nativeUpdateConnectionWindow(const char* message, int phase) { if (updateConnection && connectionWindowID) updateConnection(message,phase); }
void nativeDetachConnectionWindowView() { if (detachConnection) detachConnection(); }
bool nativeCreateConnectionWindow(const char* host,const char* game,int x,int y,Uint32 flags) {
    if (!connectionLibrary) {
        const char* overridePath = getenv("MOONLIGHT_NATIVE_CONNECTION_LIBRARY");
        NSString* path = overridePath ? [NSString stringWithUTF8String:overridePath] :
            [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libMoonlightLGConnection.dylib"];
        connectionLibrary = dlopen(path.UTF8String,RTLD_NOW|RTLD_LOCAL);
        if (!connectionLibrary) { SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,"Connection view could not load: %s",dlerror()); return false; }
        attachConnection = reinterpret_cast<decltype(attachConnection)>(dlsym(connectionLibrary,"MLConnectionAttach"));
        updateConnection = reinterpret_cast<decltype(updateConnection)>(dlsym(connectionLibrary,"MLConnectionUpdate"));
        detachConnection = reinterpret_cast<decltype(detachConnection)>(dlsym(connectionLibrary,"MLConnectionDetach"));
        if (!attachConnection || !updateConnection || !detachConnection) return false;
    }
    if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0) return false;
    connectionVideoReference = true;
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE,8); SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,8); SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,8);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE,0); SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE,0);
    SDL_Window* window = SDL_CreateWindow(host,x-480,y-320,960,640,
        SDL_WINDOW_ALLOW_HIGHDPI|SDL_WINDOW_RESIZABLE|flags);
    if (!window && flags) window = SDL_CreateWindow(host,x-480,y-320,960,640,SDL_WINDOW_ALLOW_HIGHDPI|SDL_WINDOW_RESIZABLE);
    NSWindow* cocoa = nativeSDLWindow(window);
    if (!cocoa) { if (window) SDL_DestroyWindow(window); SDL_QuitSubSystem(SDL_INIT_VIDEO); connectionVideoReference=false; return false; }
    connectionWindowID = SDL_GetWindowID(window);
    attachConnection(cocoa,host,game,connectionAction);
    [NSApp activateIgnoringOtherApps:YES];
    [cocoa makeKeyAndOrderFront:nil];
    return true;
}
void nativeEndConnectionWindow() {
    nativeDetachConnectionWindowView();
    SDL_Window* window = nativeConnectionWindow();
    connectionWindowID = 0;
    if (window) SDL_DestroyWindow(window);
    if (connectionVideoReference) SDL_QuitSubSystem(SDL_INIT_VIDEO);
    connectionVideoReference = false;
    connectionCommand = {};
}

static void sendWindowEvent(const char* event)
{
    // Lifecycle only, on the main thread; no frame callbacks or polling.
    std::fprintf(stdout, "{\"event\":\"%s\"}\n", event);
    std::fflush(stdout);
}

static bool (*fullscreenTransition)(SDL_Window*, Uint32);
void nativeSetStreamFullscreenTransition(bool (*transition)(SDL_Window*, Uint32))
{
    fullscreenTransition = transition;
}
static bool transitionFullscreen(SDL_Window* window, Uint32 flags)
{
    // Standalone window tests have no Session/decoder. The running engine always
    // installs its Session callback before any native window action is handled.
    return fullscreenTransition ? fullscreenTransition(window, flags)
                                : SDL_SetWindowFullscreen(window, flags) == 0;
}

// Preserve SDL's delegate and forward every other responder/window callback.
// A normal window close is presentation-only; Session's disconnect shortcuts,
// errors and shutdown path still destroy the original SDL window normally.
@interface MLStreamWindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, retain) id original;
@property(nonatomic, assign) Uint32 windowID;
@property(nonatomic, assign) Uint32 hiddenFullscreenFlags;
@property(nonatomic, assign) BOOL changingVisibility;
@end

static void cancelDisconnectConfirmation(bool restoreInput);

static bool hideStreamWindow(SDL_Window* window)
{
    NSWindow* nativeWindow = nativeSDLWindow(window);
    if (!nativeWindow || ![nativeWindow.delegate isKindOfClass:[MLStreamWindowDelegate class]]) return false;
    MLStreamWindowDelegate* delegate = nativeWindow.delegate;
    if (delegate.changingVisibility) return false;
    if (SDL_GetWindowFlags(window) & SDL_WINDOW_HIDDEN) return true;
    cancelDisconnectConfirmation(true);
    const Uint32 fullscreen = SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN_DESKTOP;
    delegate.changingVisibility = YES;
    if (fullscreen) nativeTitlebarSetWindowTransition(true);
    // SDL3 (through sdl2-compat) hides a fullscreen Cocoa window without leaving
    // its Space. Exit explicitly first or the user is stranded on a black Space.
    // Use Session's stock transition so its existing renderer safety applies.
    if (fullscreen && !transitionFullscreen(window, 0)) {
        delegate.changingVisibility = NO;
        nativeTitlebarSetWindowTransition(false);
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Native fullscreen hide transition failed: %s", SDL_GetError());
        return false;
    }
    delegate.hiddenFullscreenFlags = fullscreen;
    SDL_HideWindow(window);
    delegate.changingVisibility = NO;
    if (fullscreen) nativeTitlebarSetWindowTransition(false);
    sendWindowEvent("windowHidden");
    return true;
}

@implementation MLStreamWindowDelegate
- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [self.original respondsToSelector:selector];
}
- (id)forwardingTargetForSelector:(SEL)selector { return self.original; }
- (BOOL)windowShouldClose:(NSWindow*)sender
{
    SDL_Window* window = SDL_GetWindowFromID(self.windowID);
    if (nativeSDLWindow(window) == sender && !(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN)) {
        hideStreamWindow(window);
        return NO;
    }
    return [self.original respondsToSelector:_cmd] ? [self.original windowShouldClose:sender] : YES;
}
- (void)windowWillClose:(NSNotification*)notification
{
    cancelDisconnectConfirmation(false);
    nativeOverlayDetach();
    self.windowID = 0;
    sendWindowEvent("windowClosed");
    if ([self.original respondsToSelector:_cmd]) [self.original windowWillClose:notification];
}
- (void)dealloc { [_original release]; [super dealloc]; }
@end

bool nativeHideStreamWindow(SDL_Window* window)
{
    NSWindow* nativeWindow = nativeSDLWindow(window);
    if (!nativeWindow || ![nativeWindow.delegate isKindOfClass:[MLStreamWindowDelegate class]]) return false;
    return hideStreamWindow(window);
}
bool nativeStreamWindowHasHiddenFullscreen(SDL_Window* window)
{
    NSWindow* nativeWindow = nativeSDLWindow(window);
    if (!nativeWindow || ![nativeWindow.delegate isKindOfClass:[MLStreamWindowDelegate class]]) return false;
    return ((MLStreamWindowDelegate*)nativeWindow.delegate).hiddenFullscreenFlags != 0
        && (SDL_GetWindowFlags(window) & SDL_WINDOW_HIDDEN);
}

@interface MLStreamWindowAccess : NSObject
@property(nonatomic, assign) BOOL stopped;
@property(nonatomic, retain) MLStreamWindowDelegate* windowDelegate;
@property(nonatomic, copy) NSString* token;
@property(nonatomic, retain) NSAlert* disconnectConfirmation;
- (void)windowBecameKey:(NSNotification*)notification;
- (void)restore:(NSNotification*)notification;
- (void)menuAction:(NSNotification*)notification;
- (void)restoreWindow;
- (void)invalidate;
@end

static MLStreamWindowAccess* streamWindowAccess;

bool nativeStreamDisconnectConfirmationVisible() { return streamWindowAccess.disconnectConfirmation != nil; }
static void cancelDisconnectConfirmation(bool restoreInput) {
    NSAlert* alert = [streamWindowAccess.disconnectConfirmation retain];
    if (!alert) return;
    streamWindowAccess.disconnectConfirmation = nil;
    if (alert.window.sheetParent) [NSApp endSheet:alert.window returnCode:NSModalResponseAbort];
    if (restoreInput) nativeOverlayPerformAction(214);
    [alert release];
}
bool nativeConfirmDisconnectAndExit(SDL_Window* window) {
    NSWindow* parent = nativeSDLWindow(window);
    if (!parent || !streamWindowAccess || streamWindowAccess.windowDelegate.windowID != SDL_GetWindowID(window) || !parent.visible) return false;
    if (streamWindowAccess.disconnectConfirmation) return true;
    MLStreamWindowAccess* owner = streamWindowAccess;
    const Uint32 windowID = SDL_GetWindowID(window);
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    alert.messageText = @"Disconnect and exit the host game?";
    alert.informativeText = @"This closes the game on the host computer. Unsaved progress may be lost.";
    [alert addButtonWithTitle:@"Cancel"]; [alert addButtonWithTitle:@"Disconnect and Exit"];
    alert.window.appearance = parent.effectiveAppearance;
    owner.disconnectConfirmation = alert;
    [NSApp activateIgnoringOtherApps:YES];
    [alert beginSheetModalForWindow:parent completionHandler:^(NSModalResponse response) {
        if (owner.disconnectConfirmation != alert) return;
        owner.disconnectConfirmation = nil;
        // A replaced/closed session must never receive this sheet's old reply.
        if (owner != streamWindowAccess || owner.windowDelegate.windowID != windowID || SDL_GetWindowFromID(windowID) != window) return;
        nativeOverlayPerformAction(response == NSAlertSecondButtonReturn ? 209 : 214);
    }];
    return true;
}

bool nativeStreamMenuCommandsEnabled() { return streamWindowAccess != nil; }

bool nativeStartStreamMenuCommands(int fd) {
    // One reader per streaming helper; Qt's notifier is disabled before entry.
    nativeStopStreamMenuCommands();
    if (!streamWindowAccess.token) return true;
    if (fd < 0) return false;
    const std::string token = streamWindowAccess.token.UTF8String;
    menuReaderStopping = false;
    try { menuReader = std::thread([fd,token] {
        std::string buffer;
        while (!menuReaderStopping) {
            pollfd descriptor = {fd,POLLIN,0};
            const int ready = poll(&descriptor,1,100);
            if (ready < 0 && errno == EINTR) continue;
            if (ready < 0 || (ready && (descriptor.revents & (POLLERR|POLLNVAL)))) break;
            if (!ready) continue;
            char chunk[4096];
            const ssize_t count = read(fd,chunk,sizeof(chunk));
            if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
            if (count <= 0) {
                // A vanished frontend disconnects without killing the host game.
                if (!menuReaderStopping) nativeOverlayPerformAction(212);
                break;
            }
            buffer.append(chunk,size_t(count));
            if (buffer.size() > 65536) { SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,"Native menu command exceeds limit"); break; }
            size_t newline;
            while ((newline=buffer.find('\n')) != std::string::npos) {
                const std::string line=buffer.substr(0,newline); buffer.erase(0,newline+1);
                @autoreleasepool {
                    NSData* data=[NSData dataWithBytes:line.data() length:line.size()];
                    id request=[NSJSONSerialization JSONObjectWithData:data options:0 error:nullptr];
                    if (![request isKindOfClass:NSDictionary.class] || ![request[@"command"] isEqual:@"menuAction"] ||
                        ![request[@"token"] isEqual:[NSString stringWithUTF8String:token.c_str()]]) continue;
                    id actionValue=request[@"action"], identifier=request[@"requestID"];
                    if (![actionValue isKindOfClass:NSNumber.class] || ![identifier isKindOfClass:NSNumber.class] ||
                        CFGetTypeID((CFTypeRef)actionValue)==CFBooleanGetTypeID() || CFGetTypeID((CFTypeRef)identifier)==CFBooleanGetTypeID()) continue;
                    const double actionNumber=[actionValue doubleValue], idNumber=[identifier doubleValue];
                    if (actionNumber < 0 || actionNumber > 216 || actionNumber != int(actionNumber) ||
                        idNumber < 1 || idNumber > UINT32_MAX || idNumber != Uint32(idNumber)) continue;
                    const int action=int(actionNumber);
                    if (!supportedMenuAction(action)) continue;
                    if (!nativeOverlayPerformAction(action,Uint32(idNumber)))
                        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,"Could not queue native menu action %d",action);
                }
            }
        }
    }); } catch (const std::exception& error) {
        menuReaderStopping = true;
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,"Native menu reader could not start: %s",error.what());
        return false;
    }
    return true;
}

@implementation MLStreamWindowAccess
- (void)windowBecameKey:(NSNotification*)notification
{
    if (self.stopped || self != streamWindowAccess || nativeConnectionWaiting()) return;
    NSWindow* candidate = notification.object;
    // SDL updates its focus during this notification. Resolve after its handler,
    // never intercept a hidden decoder-test window or the Qt selection window.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.stopped || self != streamWindowAccess || nativeConnectionWaiting()) return;
        SDL_Window* window = SDL_GetKeyboardFocus();
        if (!window || nativeSDLWindow(window) != candidate || !(SDL_GetWindowFlags(window) & SDL_WINDOW_SHOWN)) return;
        nativeAttachStreamWindow(window);
    });
}
- (void)restore:(NSNotification*)notification
{
    if (self.stopped || self != streamWindowAccess || ![notification.object isEqualToString:self.token]) return;
    if (!self.windowDelegate.windowID || !restoreEventType || restoreEventType == Uint32(-1)) return;
    // Never run SDL's blocking fullscreen animation inside an AppKit/distributed
    // notification callback. Its completion must be able to drain the main loop.
    SDL_Event event = {};
    event.type = restoreEventType;
    event.user.windowID = self.windowDelegate.windowID;
    SDL_PushEvent(&event);
}
- (void)menuAction:(NSNotification*)notification
{
    if (self.stopped || self != streamWindowAccess || ![notification.object isEqualToString:self.token] || !self.windowDelegate.windowID) return;
    NSString* prefix = @"com.moonlight-stream.NativeGlass.menuAction.";
    if (![notification.name hasPrefix:prefix]) return;
    NSString* suffix = [notification.name substringFromIndex:prefix.length];
    int action = suffix.intValue;
    if (![suffix isEqualToString:[NSString stringWithFormat:@"%d", action]]) return;
    if (action == 100 || action == 200 || action == 201 || action == 202 || action == 203 || action == 207 || action == 208 || action == 209 || action == 210 || action == 212) nativeOverlayPerformAction(action);
}
- (void)restoreWindow
{
    if (self.stopped || self != streamWindowAccess) return;
    SDL_Window* window = SDL_GetWindowFromID(self.windowDelegate.windowID);
    NSWindow* nativeWindow = nativeSDLWindow(window);
    if (!nativeWindow || self.windowDelegate.changingVisibility) return;
    self.windowDelegate.changingVisibility = YES;
    const bool restoringFullscreen = self.windowDelegate.hiddenFullscreenFlags != 0;
    if (restoringFullscreen) nativeTitlebarSetWindowTransition(true);
    [NSApp activateIgnoringOtherApps:YES];
    SDL_ShowWindow(window);
    if (SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED) SDL_RestoreWindow(window);
    if (self.windowDelegate.hiddenFullscreenFlags) {
        if (transitionFullscreen(window, self.windowDelegate.hiddenFullscreenFlags))
            self.windowDelegate.hiddenFullscreenFlags = 0;
        else SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Native fullscreen restore transition failed: %s", SDL_GetError());
    }
    SDL_RaiseWindow(window);
    [nativeWindow makeKeyAndOrderFront:nil];
    self.windowDelegate.changingVisibility = NO;
    if (restoringFullscreen) nativeTitlebarSetWindowTransition(false);
}
- (void)invalidate
{
    if (self.stopped) return;
    self.stopped = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    if (self.windowDelegate.windowID) {
        SDL_Window* window = SDL_GetWindowFromID(self.windowDelegate.windowID);
        NSWindow* nativeWindow = nativeSDLWindow(window);
        if (nativeWindow.delegate == self.windowDelegate) nativeWindow.delegate = self.windowDelegate.original;
        if (nativeWindow) sendWindowEvent("windowClosed");
    }
    self.windowDelegate = nil;
}
- (void)dealloc
{
    [self invalidate];
    [_windowDelegate release]; [_token release]; [_disconnectConfirmation release]; [super dealloc];
}
@end

void nativeAttachStreamWindow(SDL_Window* window) {
    if (!streamWindowAccess || streamWindowAccess.stopped || nativeConnectionWaiting()) return;
    NSWindow* candidate = nativeSDLWindow(window);
    if (!candidate) return;
        if (streamWindowAccess.windowDelegate.windowID == SDL_GetWindowID(window)) return;
        MLStreamWindowDelegate* delegate = [[MLStreamWindowDelegate alloc] init];
        delegate.original = candidate.delegate;
        delegate.windowID = SDL_GetWindowID(window);
        streamWindowAccess.windowDelegate = delegate;
        candidate.delegate = delegate;
        [delegate release];
        nativeOverlayAttach(candidate, streamWindowAccess.token.UTF8String);
        // Overlay attachment reserves SDL_USEREVENT for stock Session events.
        if (!restoreEventType) restoreEventType = SDL_RegisterEvents(1);
        sendWindowEvent("windowOpened");
}
void nativeRestoreStreamWindow(Uint32 windowID)
{
    if (windowID && streamWindowAccess.windowDelegate.windowID == windowID)
        [streamWindowAccess restoreWindow];
}
void nativePublishMenuState(SDL_Window* window, bool captured, bool statistics, bool muted)
{
    NSWindow* cocoa = nativeSDLWindow(window);
    if (!cocoa || !streamWindowAccess || streamWindowAccess.windowDelegate.windowID != SDL_GetWindowID(window)) return;
    Uint32 flags = SDL_GetWindowFlags(window);
    Uint32 fullscreen = flags & SDL_WINDOW_FULLSCREEN_DESKTOP;
    if (flags & SDL_WINDOW_HIDDEN) fullscreen = streamWindowAccess.windowDelegate.hiddenFullscreenFlags;
    const int mode = !fullscreen ? 0 : SDL_GetHintBoolean(SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES, SDL_FALSE) ? 2 : 1;
    char message[512];
    std::snprintf(message, sizeof(message), "{\"event\":\"menuState\",\"windowNumber\":%ld,\"visible\":%s,\"captured\":%s,\"statistics\":%s,\"controls\":%s,\"muted\":%s,\"mode\":%d}\n",
        (long)cocoa.windowNumber, (flags & (SDL_WINDOW_HIDDEN | SDL_WINDOW_MINIMIZED)) ? "false" : "true",
        captured ? "true" : "false", statistics ? "true" : "false", nativeOverlayControlsVisible() ? "true" : "false", muted ? "true" : "false", mode);
    if (lastMenuState == message) return;
    lastMenuState = message;
    std::fputs(message, stdout);
    std::fflush(stdout);
}
void configureNativeStreamWindow(const char* token)
{
    configureNativeBackgroundApplication();
    connectionWaiting = false;
    lastMenuState.clear();
    nativeTitlebarSetCapture(false);
    nativeTitlebarSetStatistics(false);
    nativeTitlebarSetConnection(NativeConnectionState::Connecting);
    streamWindowAccess = [[MLStreamWindowAccess alloc] init];
    streamWindowAccess.token = [NSString stringWithUTF8String:token];
    for (int action : {100, 200, 201, 202, 203, 207, 208, 209, 210, 212})
        [[NSDistributedNotificationCenter defaultCenter] addObserver:streamWindowAccess selector:@selector(menuAction:)
            name:[NSString stringWithFormat:@"com.moonlight-stream.NativeGlass.menuAction.%d", action]
            object:streamWindowAccess.token suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [[NSNotificationCenter defaultCenter] addObserver:streamWindowAccess selector:@selector(windowBecameKey:)
                                                name:NSWindowDidBecomeKeyNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:streamWindowAccess selector:@selector(restore:)
                        name:MLRestoreStreamWindow object:streamWindowAccess.token suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}
void stopNativeStreamWindow()
{
    connectionWaiting = false;
    // Invalidate synchronously: queued focus blocks may retain the old owner.
    [streamWindowAccess invalidate];
    cancelDisconnectConfirmation(false);
    nativeStopStreamMenuCommands();
    if (restoreEventType && restoreEventType != Uint32(-1)) SDL_FlushEvent(restoreEventType);
    nativeOverlayDetach();
    [streamWindowAccess release]; streamWindowAccess = nil;
}
