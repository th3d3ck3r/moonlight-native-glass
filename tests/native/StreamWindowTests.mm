#import <AppKit/AppKit.h>
#import <SDL.h>
#import <SDL_syswm.h>
#include <cstdio>
#include <cstdlib>
#include <string>

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
        SDL_SetMainReady();
        check(SDL_Init(SDL_INIT_VIDEO) == 0, "SDL initialization failed");
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
            check(nativeWindow.visible && SDL_GetKeyboardFocus() == window, "Cross-process restore did not show and focus the original SDL window");
        }
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
