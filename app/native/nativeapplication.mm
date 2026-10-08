#import <AppKit/AppKit.h>

// Only the windowless adapter calls this. The stock Session/SDL process keeps
// its ordinary activation policy, menu bar and keyboard focus.
void configureNativeBackgroundApplication()
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

#import <SDL.h>
#import <SDL_syswm.h>
#include <cstdio>
#include "nativeoverlay.h"
#include "nativetitlebar.h"

static NSString* const MLRestoreStreamWindow = @"com.moonlight-stream.NativeGlass.restoreStreamWindow";

static NSWindow* nativeSDLWindow(SDL_Window* window)
{
    if (!window) return nil;
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    return SDL_GetWindowWMInfo(window, &info) && info.subsystem == SDL_SYSWM_COCOA ? info.info.cocoa.window : nil;
}

static void sendWindowEvent(const char* event)
{
    // Lifecycle only, on the main thread; no frame callbacks or polling.
    std::fprintf(stdout, "{\"event\":\"%s\"}\n", event);
    std::fflush(stdout);
}

// Preserve SDL's delegate and forward every other responder/window callback.
// A normal window close is presentation-only; Session's disconnect shortcuts,
// errors and shutdown path still destroy the original SDL window normally.
@interface MLStreamWindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, retain) id original;
@property(nonatomic, assign) Uint32 windowID;
@end

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
        SDL_HideWindow(window);
        sendWindowEvent("windowHidden");
        return NO;
    }
    return [self.original respondsToSelector:_cmd] ? [self.original windowShouldClose:sender] : YES;
}
- (void)windowWillClose:(NSNotification*)notification
{
    nativeOverlayDetach();
    self.windowID = 0;
    sendWindowEvent("windowClosed");
    if ([self.original respondsToSelector:_cmd]) [self.original windowWillClose:notification];
}
- (void)dealloc { [_original release]; [super dealloc]; }
@end

@interface MLStreamWindowAccess : NSObject
@property(nonatomic, retain) MLStreamWindowDelegate* windowDelegate;
@property(nonatomic, copy) NSString* token;
- (void)windowBecameKey:(NSNotification*)notification;
- (void)restore:(NSNotification*)notification;
@end

@implementation MLStreamWindowAccess
- (void)windowBecameKey:(NSNotification*)notification
{
    NSWindow* candidate = notification.object;
    // SDL updates its focus during this notification. Resolve after its handler,
    // never intercept a hidden decoder-test window or the Qt selection window.
    dispatch_async(dispatch_get_main_queue(), ^{
        SDL_Window* window = SDL_GetKeyboardFocus();
        if (!window || nativeSDLWindow(window) != candidate || !(SDL_GetWindowFlags(window) & SDL_WINDOW_SHOWN)) return;
        if (self.windowDelegate.windowID == SDL_GetWindowID(window)) return;
        MLStreamWindowDelegate* delegate = [[MLStreamWindowDelegate alloc] init];
        delegate.original = candidate.delegate;
        delegate.windowID = SDL_GetWindowID(window);
        self.windowDelegate = delegate;
        candidate.delegate = delegate;
        [delegate release];
        nativeOverlayAttach(candidate, self.token.UTF8String);
        sendWindowEvent("windowOpened");
    });
}
- (void)restore:(NSNotification*)notification
{
    if (![notification.object isEqualToString:self.token]) return;
    SDL_Window* window = SDL_GetWindowFromID(self.windowDelegate.windowID);
    NSWindow* nativeWindow = nativeSDLWindow(window);
    if (!nativeWindow) return;
    SDL_ShowWindow(window);
    if (SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED) SDL_RestoreWindow(window);
    [NSApp activateIgnoringOtherApps:YES];
    SDL_RaiseWindow(window);
    [nativeWindow makeKeyAndOrderFront:nil];
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    SDL_Window* window = SDL_GetWindowFromID(self.windowDelegate.windowID);
    NSWindow* nativeWindow = nativeSDLWindow(window);
    if (nativeWindow.delegate == self.windowDelegate) nativeWindow.delegate = self.windowDelegate.original;
    [_windowDelegate release]; [_token release]; [super dealloc];
}
@end

static MLStreamWindowAccess* streamWindowAccess;
void configureNativeStreamWindow(const char* token)
{
    nativeTitlebarSetCapture(false);
    nativeTitlebarSetStatistics(false);
    nativeTitlebarSetConnection(NativeConnectionState::Connecting);
    streamWindowAccess = [[MLStreamWindowAccess alloc] init];
    streamWindowAccess.token = [NSString stringWithUTF8String:token];
    [[NSNotificationCenter defaultCenter] addObserver:streamWindowAccess selector:@selector(windowBecameKey:)
                                                name:NSWindowDidBecomeKeyNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:streamWindowAccess selector:@selector(restore:)
                        name:MLRestoreStreamWindow object:streamWindowAccess.token suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}
void stopNativeStreamWindow()
{
    nativeOverlayDetach();
    [streamWindowAccess release]; streamWindowAccess = nil;
}
