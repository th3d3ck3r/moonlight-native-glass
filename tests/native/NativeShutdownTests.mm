#import <AppKit/AppKit.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include <cstdio>
#include <cstdlib>
#include "nativeapplication.h"
#include "nativeoverlay.h"

void configureNativeStreamWindow(const char* token);
void stopNativeStreamWindow();
static void check(bool okay, const char* message) {
    if (!okay) { fprintf(stderr,"FAIL: %s\n",message); exit(1); }
}
static NSWindow* cocoa(SDL_Window* window) {
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    check(SDL_GetWindowWMInfo(window,&info),"Fixture requires a real SDL Cocoa window");
    return info.info.cocoa.window;
}
static void drain(bool sdl = true) {
    NSDate* until=[NSDate dateWithTimeIntervalSinceNow:.15];
    while (until.timeIntervalSinceNow>0) {
        if (sdl) SDL_PumpEvents();
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    }
}
int main() { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; [NSApp finishLaunching];
    SDL_SetMainReady(); check(SDL_Init(SDL_INIT_VIDEO)==0,"SDL video init");
    SDL_Window* window=SDL_CreateWindow("Native shutdown callback fixture",100,100,640,360,SDL_WINDOW_SHOWN);
    check(window!=nullptr,"SDL window creation");
    [NSApp activateIgnoringOtherApps:YES]; [cocoa(window) makeKeyAndOrderFront:nil]; drain();
    check(SDL_GetKeyboardFocus()==window,"Fixture must have SDL keyboard focus");
    // Deliver the real observation, then stop before its deferred attachment
    // runs. A stopped owner must never reinstall an overlay or window delegate.
    configureNativeStreamWindow("shutdown-before-attachment");
    [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidBecomeKeyNotification object:cocoa(window)];
    stopNativeStreamWindow(); drain();
    check(!nativeOverlayConfigured(),"Deferred focus callback reattached native controls after stream teardown");
    check(cocoa(window).toolbar==nil,"Shutdown must leave no orphan native toolbar");
    SDL_DestroyWindow(window); SDL_QuitSubSystem(SDL_INIT_VIDEO); drain(false);
    stopNativeStreamWindow(); SDL_Quit();
    puts("PASS: deferred native focus attachment cannot outlive shutdown");
    return 0;
} }
