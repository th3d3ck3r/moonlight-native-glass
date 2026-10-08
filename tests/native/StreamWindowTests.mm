#import <AppKit/AppKit.h>
#import <SDL.h>
#import <SDL_syswm.h>
#include <cstdio>
#include <cstdlib>
#include <string>
#include "nativeapplication.h"
#include "nativeoverlay.h"

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
    } while ([deadline timeIntervalSinceNow] > 0);
}
static NSWindow* cocoa(SDL_Window* window) {
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    check(SDL_GetWindowWMInfo(window, &info), "SDL Cocoa window info unavailable");
    return info.info.cocoa.window;
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
            check(SDL_SetWindowFullscreen(window,mode)==0,"Fullscreen title-bar transition"); pump(1.0);
            check((cocoa(window).toolbar==nil)==(mode!=0),"Title bar must appear only in windowed mode");
            SDL_SetRelativeMouseMode(SDL_FALSE); SDL_ShowCursor(SDL_DISABLE);
            SDL_SetWindowMouseGrab(window,SDL_FALSE);
            nativeOverlayBeginControlsInput(window); nativeOverlaySetControlsVisible(true); pump();
            check(SDL_ShowCursor(SDL_QUERY)==SDL_ENABLE && SDL_GetWindowMouseGrab(window),"Controls pointer must be visible and confined in every window mode");
            check(SDL_GetKeyboardFocus()==window,"Controls must preserve SDL keyboard focus");
            nativeOverlaySetControlsVisible(false); nativeOverlayEndControlsInput();
            check(!SDL_GetWindowMouseGrab(window) && SDL_ShowCursor(SDL_QUERY)==SDL_DISABLE,"Controls dismissal must restore the prior pointer state");
            // Reproduce a native panel/menu leaving SDL's mouse focus outside
            // the parent stream. Use the production focus restoration helper,
            // not just SDL's relative-mode boolean (which can mask this bug).
            NSWindow* other=[[NSWindow alloc] initWithContentRect:NSMakeRect(5,5,80,80) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
            [other makeKeyAndOrderFront:nil]; pump();
            SDL_WarpMouseGlobal(0,0); pump();
            nativeOverlayRestoreStreamFocus(window);
            check(SDL_GetKeyboardFocus()==window && SDL_GetMouseFocus()==window,"Done must restore both keyboard and mouse focus to the stream");
            check(SDL_SetRelativeMouseMode(SDL_TRUE)==0,"Relative capture must still work after controls");
            pump();
            check(SDL_GetRelativeMouseMode() && SDL_GetMouseFocus()==window,"Capture must survive the native event queue after Done");
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
        stopNativeStreamWindow();
        SDL_Quit();
        std::puts("PASS: real SDL close/hide, repeat restore/focus, cross-process routing, no-window fallback, delegate forwarding and cleanup (no host/video test)");
    }
    return 0;
}
