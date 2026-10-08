#import <AppKit/AppKit.h>
#import <SDL.h>
#import <SDL_syswm.h>
#include <cstdio>
#include <cstdlib>
#include <string>
#include "nativeapplication.h"
#include "nativeoverlay.h"

// Test-only observation of the confinement property already used internally
// by SDL 2.30.5's Cocoa backend; it is absent from AppKit's public headers.
// Production code continues to use SDL's public capture/grab APIs exclusively.
@interface NSWindow (SDLConfinementProbe)
@property(nonatomic, readonly) NSRect mouseConfinementRect;
@end

void configureNativeBackgroundApplication();
void configureNativeStreamWindow(const char* token);
void stopNativeStreamWindow();
static NSString* const restoreName = @"com.moonlight-stream.NativeGlass.restoreStreamWindow";
static void check(bool value, const char* message) {
    if (!value) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
static void pump(double seconds = 0.3) {
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
    do {
        SDL_PumpEvents();
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        SDL_Event restore;
        if (nativeRestoreStreamWindowEventType())
            while (SDL_PeepEvents(&restore,1,SDL_GETEVENT,nativeRestoreStreamWindowEventType(),nativeRestoreStreamWindowEventType())==1)
                nativeRestoreStreamWindow(restore.user.windowID);
    } while ([deadline timeIntervalSinceNow] > 0);
}
static NSWindow* cocoa(SDL_Window* window) {
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    check(SDL_GetWindowWMInfo(window, &info), "SDL Cocoa window info unavailable");
    return info.info.cocoa.window;
}
static bool fixtureFullscreenTransition(SDL_Window* window, Uint32 flags) {
    const Uint32 previous=SDL_GetWindowFlags(window)&SDL_WINDOW_FULLSCREEN_DESKTOP;
    if (SDL_SetWindowFullscreen(window,flags)!=0) return false;
    // Session's existing macOS exclusive-mode workaround is part of the
    // transition callback contract. This standalone fixture has no Session.
    if (!flags && previous==SDL_WINDOW_FULLSCREEN) {
        SDL_SetWindowSize(window,640,360);
        SDL_SetWindowPosition(window,100,100);
    }
    return true;
}
static void checkRelativeMotion(SDL_Window* window) {
    SDL_FlushEvent(SDL_MOUSEMOTION);
    // Route actual native motion through SDL's Cocoa event handler. The first
    // event after enabling relative mode is intentionally discarded by SDL.
    for (int i=0; i<2; ++i) {
        CGEventRef current=CGEventCreate(nullptr);
        CGEventRef motion=CGEventCreateMouseEvent(nullptr,kCGEventMouseMoved,
            CGEventGetLocation(current),kCGMouseButtonLeft);
        CGEventSetIntegerValueField(motion,kCGMouseEventDeltaX,13);
        CGEventSetIntegerValueField(motion,kCGMouseEventDeltaY,-7);
        [NSApp postEvent:[NSEvent eventWithCGEvent:motion] atStart:NO];
        CFRelease(motion); CFRelease(current);
        pump();
    }
    SDL_Event event; bool routed=false;
    while (SDL_PollEvent(&event)) {
        if (event.type==SDL_MOUSEMOTION && event.motion.windowID==SDL_GetWindowID(window)
            && event.motion.xrel==13 && event.motion.yrel==-7) routed=true;
    }
    check(routed,"Relative motion must reach the original SDL stream after native controls");
}
int main(int argc, char** argv) {
    @autoreleasepool {
        if (argc == 3 && std::string(argv[1]) == "--restore") {
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:restoreName
                object:[NSString stringWithUTF8String:argv[2]] userInfo:nil deliverImmediately:YES];
            return 0;
        }
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];
        configureNativeBackgroundApplication();
        check(NSApp.activationPolicy==NSApplicationActivationPolicyAccessory,"Engine must stay out of Dock before SDL init");
        SDL_SetMainReady();
        check(SDL_Init(SDL_INIT_VIDEO) == 0, "SDL initialization failed");
        check(NSApp.activationPolicy==NSApplicationActivationPolicyAccessory,"SDL must not promote engine back into Dock");
        const char* token = "91A001FA-8C16-4321-AC12-508590128641";
        configureNativeStreamWindow(token);
        nativeSetStreamFullscreenTransition(fixtureFullscreenTransition);
        // No stream window exists: a restore request must create nothing.
        NSUInteger before = NSApp.windows.count;
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:restoreName
            object:[NSString stringWithUTF8String:token] userInfo:nil deliverImmediately:YES];
        pump();
        check(NSApp.windows.count == before, "Restore created a window without an existing stream");
        SDL_Window* window = SDL_CreateWindow("Stream lifecycle fixture", 100, 100, 640, 360, SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
        check(window != nullptr, "SDL window creation failed");
        NSWindow* nativeWindow = cocoa(window);
        [NSApp activateIgnoringOtherApps:YES];
        [nativeWindow makeKeyAndOrderFront:nil];
        pump();
        check([NSStringFromClass([nativeWindow.delegate class]) isEqualToString:@"MLStreamWindowDelegate"], "Adapter did not attach to the opened SDL window");
        const Uint32 windowID = SDL_GetWindowID(window);
        for (int attempt = 0; attempt < 3; ++attempt) {
            SDL_FlushEvents(SDL_FIRSTEVENT, SDL_LASTEVENT);
            [nativeWindow performClose:nil];
            pump();
            check(!nativeWindow.visible && (SDL_GetWindowFlags(window) & SDL_WINDOW_HIDDEN), "Close did not hide the SDL window");
            check(SDL_GetWindowFromID(windowID) == window, "Close destroyed the stream window");
            SDL_Event event;
            while (SDL_PollEvent(&event)) {
                check(event.type != SDL_QUIT && !(event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE), "Close queued session termination");
            }
            // A different instance's request must not restore this window.
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:restoreName object:@"wrong-token" userInfo:nil deliverImmediately:YES];
            pump();
            check(!nativeWindow.visible, "Unrelated restore request affected the window");
            // Exercise the same cross-process, main-run-loop route used by SwiftUI,
            // with no Qt event loop running (matching Session's SDL loop).
            NSTask* sender = [[NSTask alloc] init];
            sender.executableURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[0]]];
            sender.arguments = @[@"--restore", [NSString stringWithUTF8String:token]];
            check([sender launchAndReturnError:nullptr], "Restore sender failed");
            [sender waitUntilExit]; [sender release];
            pump(1.0);
            check(NSApp.activationPolicy==NSApplicationActivationPolicyAccessory,"Stream restoration must not create another Dock icon");
            check(nativeWindow.visible && SDL_GetKeyboardFocus() == window, "Cross-process restore did not show and focus the original SDL window");
        }
        SDL_FlushEvents(SDL_FIRSTEVENT,SDL_LASTEVENT);
        NSEvent* keyDown=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:nativeWindow.windowNumber context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
        NSEvent* keyUp=[NSEvent keyEventWithType:NSEventTypeKeyUp location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:nativeWindow.windowNumber context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
        [NSApp postEvent:keyDown atStart:NO]; [NSApp postEvent:keyUp atStart:NO]; pump();
        bool pressed=false,released=false; SDL_Event input;
        while (SDL_PollEvent(&input)) {
            if (input.type==SDL_KEYDOWN && input.key.keysym.sym==SDLK_a) pressed=true;
            if (input.type==SDL_KEYUP && input.key.keysym.sym==SDLK_a) released=true;
        }
        check(pressed && released,"Accessory stream must still receive SDL keyboard input");
        check(SDL_SetWindowFullscreen(window,SDL_WINDOW_FULLSCREEN_DESKTOP)==0,"Accessory fullscreen entry"); pump(1.0);
        check(NSApp.activationPolicy==NSApplicationActivationPolicyAccessory,"Fullscreen must not promote engine to Dock");
        check(cocoa(window).toolbar==nil,"Borderless fullscreen must not show native title-bar controls");
        check(SDL_SetWindowFullscreen(window,0)==0,"Accessory fullscreen exit"); pump(1.0);
        nativeWindow=cocoa(window);
        // Keep the title toolbar and customizable overlays in an accessory app.
        check(nativeWindow.toolbar!=nil,"Single-Dock engine lost title-bar controls");
        NSButton* hostButton=nil;
        for (NSToolbarItem* item in nativeWindow.toolbar.items)
            if ([item.itemIdentifier isEqual:@"NativeHost"]) hostButton=(NSButton*)item.view;
        check(hostButton!=nil,"Missing computer-name Control Center entry");
        check([NSStringFromClass(hostButton.class) isEqualToString:@"MLStreamToolbarButton"],"Title-bar controls must return tracked mouse-up to SDL");
        // Unlike performClick:, these events exercise AppKit's button tracking
        // loop and SDL's title-bar focus-click bookkeeping.
        NSPoint click=[hostButton convertPoint:NSMakePoint(NSMidX(hostButton.bounds),NSMidY(hostButton.bounds)) toView:nil];
        for (NSEventType type : {NSEventTypeLeftMouseDown,NSEventTypeLeftMouseUp}) {
            NSEvent* event=[NSEvent mouseEventWithType:type location:click modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:nativeWindow.windowNumber context:nil eventNumber:1 clickCount:1 pressure:0];
            [NSApp postEvent:event atStart:NO];
        }
        pump();
        bool opened=false; SDL_Event nativeAction;
        while (SDL_PollEvent(&nativeAction))
            if (nativeAction.type==nativeOverlayEventType() && nativeAction.user.code==102) opened=true;
        check(opened,"Real title-bar click must queue Control Center");
        for (Uint32 mode : {Uint32(0), Uint32(SDL_WINDOW_FULLSCREEN_DESKTOP), Uint32(SDL_WINDOW_FULLSCREEN)}) {
            std::printf("MODE: 0x%x\n",mode); std::fflush(stdout);
            // Session selects a supported display mode before entering exclusive
            // fullscreen. Keep the fixture's floating 640x360 size from being
            // mistaken for a physical monitor mode by sdl2-compat.
            if (mode==SDL_WINDOW_FULLSCREEN) {
                SDL_DisplayMode desktop;
                check(SDL_GetDesktopDisplayMode(SDL_GetWindowDisplayIndex(window),&desktop)==0,"Exclusive fixture desktop mode unavailable");
                check(SDL_SetWindowDisplayMode(window,&desktop)==0,"Exclusive fixture display mode selection failed");
            }
            check(SDL_SetWindowFullscreen(window,mode)==0,"Fullscreen title-bar transition"); pump(1.0);
            check((cocoa(window).toolbar==nil)==(mode!=0),"Title bar must appear only in windowed mode");
            nativeOverlayRestoreStreamFocus(window);
            check(SDL_SetRelativeMouseMode(SDL_TRUE)==0,"Fresh relative capture must work before controls");
            pump();
            const NSRect freshRelativeRect=cocoa(window).mouseConfinementRect;
            checkRelativeMotion(window);
            SDL_SetRelativeMouseMode(SDL_FALSE); SDL_ShowCursor(SDL_DISABLE);
            SDL_SetWindowMouseGrab(window,SDL_FALSE);
            nativeOverlayBeginControlsInput(window); nativeOverlaySetControlsVisible(true); pump();
            check(SDL_ShowCursor(SDL_QUERY)==SDL_ENABLE && SDL_GetWindowMouseGrab(window),"Controls pointer must be visible and confined in every window mode");
            check(!NSIsEmptyRect(cocoa(window).mouseConfinementRect),"Cocoa must actually confine the controls pointer, not only report SDL grab enabled");
            check(SDL_GetKeyboardFocus()==window,"Controls must preserve SDL keyboard focus");
            nativeOverlaySetControlsVisible(false); nativeOverlayEndControlsInput();
            check(!SDL_GetWindowMouseGrab(window) && SDL_ShowCursor(SDL_QUERY)==SDL_DISABLE,"Controls dismissal must restore the prior pointer state");
            // Reproduce a native panel/menu leaving SDL's mouse focus outside
            // the parent stream. Use the production focus restoration helper,
            // not just SDL's relative-mode boolean (which can mask this bug).
            NSWindow* other=[[NSWindow alloc] initWithContentRect:NSMakeRect(5,5,80,80) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
            [other makeKeyAndOrderFront:nil]; pump();
            SDL_WarpMouseGlobal(0,0); pump();
            std::printf("BEFORE DONE: mode=0x%x flags=0x%x visible=%d mini=%d key=%d SDLkey=%u\n",mode,SDL_GetWindowFlags(window),cocoa(window).visible,cocoa(window).miniaturized,cocoa(window).keyWindow,SDL_GetKeyboardFocus() ? SDL_GetWindowID(SDL_GetKeyboardFocus()) : 0); std::fflush(stdout);
            nativeOverlayRestoreStreamFocus(window);
            if (mode==SDL_WINDOW_FULLSCREEN) pump();
            std::printf("AFTER DONE: mode=0x%x flags=0x%x visible=%d mini=%d key=%d SDLkey=%u\n",mode,SDL_GetWindowFlags(window),cocoa(window).visible,cocoa(window).miniaturized,cocoa(window).keyWindow,SDL_GetKeyboardFocus() ? SDL_GetWindowID(SDL_GetKeyboardFocus()) : 0); std::fflush(stdout);
            check(SDL_GetKeyboardFocus()==window,"Done must restore keyboard focus to the stream");
            // Exclusive modesetting can leave mouse focus unset while capture
            // is off. SDL establishes it on relative-mode activation. The two
            // normal macOS modes must restore mouse focus before capture too.
            if (mode!=SDL_WINDOW_FULLSCREEN)
                check(SDL_GetMouseFocus()==window,"Done must restore mouse focus before normal-mode capture");
            check(SDL_SetRelativeMouseMode(SDL_TRUE)==0,"Relative capture must still work after controls");
            pump();
            check(SDL_GetRelativeMouseMode() && SDL_GetMouseFocus()==window,"Capture must survive the native event queue after Done");
            // SDL's Cocoa backend disassociates the system cursor in relative mode;
            // without an explicit grab its Cocoa confinement rect is empty.
            // Compare against fresh capture and verify real event routing,
            // while keeping the nonempty-rect assertion for visible controls.
            check(NSEqualRects(cocoa(window).mouseConfinementRect,freshRelativeRect),"Done must restore the same Cocoa pointer state as fresh relative capture");
            checkRelativeMotion(window);
            SDL_SetRelativeMouseMode(SDL_FALSE); SDL_ShowCursor(SDL_ENABLE);
            [other orderOut:nil]; [other release];
            SDL_FlushEvents(SDL_FIRSTEVENT,SDL_LASTEVENT);
            check(nativeHideStreamWindow(window),"Close shortcut could not hide the existing stream window"); pump(1.0);
            check(!cocoa(window).visible && SDL_GetWindowFromID(windowID)==window,"Close shortcut must hide rather than destroy the stream window");
            SDL_Event closeEvent;
            while (SDL_PollEvent(&closeEvent)) {
                check(closeEvent.type!=SDL_QUIT && !(closeEvent.type==SDL_WINDOWEVENT && closeEvent.window.event==SDL_WINDOWEVENT_CLOSE),"Close shortcut queued disconnect");
            }
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:restoreName object:[NSString stringWithUTF8String:token] userInfo:nil deliverImmediately:YES]; pump(1.0);
            check(cocoa(window).visible && SDL_GetKeyboardFocus()==window,"Moon restore after close shortcut failed");
        }
        check(SDL_SetWindowFullscreen(window,0)==0,"Return to windowed stream"); pump(1.0);
        // Resizing must still reach SDL's original window delegate.
        [nativeWindow setContentSize:NSMakeSize(720, 400)];
        pump();
        int width, height; SDL_GetWindowSize(window, &width, &height);
        check(width == 720 && height == 400, "Delegate forwarding broke SDL resizing");
        SDL_DestroyWindow(window);
        pump();
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:restoreName
            object:[NSString stringWithUTF8String:token] userInfo:nil deliverImmediately:YES];
        pump();
        nativeSetStreamFullscreenTransition(nullptr);
        stopNativeStreamWindow();
        SDL_Quit();
        std::puts("PASS: real SDL close/hide, repeat restore/focus, cross-process routing, no-window fallback, delegate forwarding and cleanup (no host/video test)");
    }
    return 0;
}
