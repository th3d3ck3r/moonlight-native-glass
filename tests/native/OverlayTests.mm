#import <AppKit/AppKit.h>
#import <SDL.h>
#include "nativeoverlay.h"
#include <cstdio>
#include <cstdlib>
static void check(bool okay,const char* message) { if (!okay) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static void pump() { NSDate* end=[NSDate dateWithTimeIntervalSinceNow:.2]; while (end.timeIntervalSinceNow>0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; }
static void capture(NSString* path) { pump(); NSTask* task=[[[NSTask alloc] init] autorelease]; task.launchPath=@"/usr/sbin/screencapture"; task.arguments=@[@"-x",path]; [task launch]; [task waitUntilExit]; check(task.terminationStatus==0,"Composited capture failed"); }
int main(int argc,char** argv) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; [NSApp finishLaunching];
    SDL_SetMainReady(); check(SDL_Init(SDL_INIT_VIDEO)==0,"SDL initialization");
    NSUserDefaults* defaults=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    NSDictionary* previous=[[defaults persistentDomainForName:@"com.moonlight-stream.NativeGlass.Overlay"] retain];
    [defaults removePersistentDomainForName:@"com.moonlight-stream.NativeGlass.Overlay"]; [defaults setBool:YES forKey:@"controlsEnabled"]; [defaults synchronize];
    NSWindow* window=[[[NSWindow alloc] initWithContentRect:NSMakeRect(60,120,960,540) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO] autorelease];
    window.title=@"Native overlay preview — sample statistics, no live stream"; window.releasedWhenClosed=NO;
    window.backgroundColor=[NSColor colorWithSRGBRed:.06 green:.10 blue:.16 alpha:1];
    [window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    pump(); [window makeKeyAndOrderFront:nil]; pump();
    check(NSApp.keyWindow==window,"Fixture must own keyboard focus before overlay attachment");
    nativeOverlayAttach(window,"overlay-test"); check(nativeOverlayEventType()!=SDL_USEREVENT,"Must not consume upstream SDL user events");
    const char* sample="Video stream: 1920x1080 60 FPS\nVideo codec: H.264\nIncoming frame rate: 59.98 FPS\nRendering frame rate: 59.98 FPS\nFrames dropped by network: 0.00%\nAverage network latency: 2 ms\nAverage decoding time: 1.2 ms\nAverage frame queue delay: 0.4 ms\nAverage rendering time: 0.8 ms";
    check(nativeOverlayPresent(0,true,sample),"Native statistics ownership"); check(nativeOverlayPresent(1,true,"Design preview · Sample values"),"Status ownership"); pump();
    fprintf(stderr,"Overlay children=%lu visible=%d configured=%d\n",(unsigned long)window.childWindows.count,window.visible,nativeOverlayConfigured());
    check(window.childWindows.count==2,"Passive surfaces only; controls hidden by default");
    for (NSWindow* panel in window.childWindows) {
        check(panel.ignoresMouseEvents,"Statistics/status must pass through input");
        check(!panel.canBecomeKeyWindow && !panel.canBecomeMainWindow,"Passive panels must reject keyboard/main focus");
    }
    check(NSApp.keyWindow==window,"Passive overlay must not steal focus");
    SDL_KeyboardEvent key={}; key.state=SDL_PRESSED; key.keysym.sym=SDLK_o; key.keysym.mod=KMOD_LCTRL|KMOD_LALT|KMOD_LSHIFT;
    check(nativeOverlayShortcut(&key)==11,"Default controls shortcut");
    for (int i=0;i<12;i++) { key.keysym.sym="qzxsmcdvleko"[i]; check(nativeOverlayShortcut(&key)==i,"Every existing shortcut is retained"); }
    key.keysym.mod=KMOD_LCTRL; check(nativeOverlayShortcut(&key)==-1,"Normal host keys must not be consumed");
    [defaults setObject:@{@"11":@{@"key":@"p",@"modifiers":@3}} forKey:@"shortcuts"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    key.keysym.sym=SDLK_p; key.keysym.mod=KMOD_LCTRL|KMOD_LALT; check(nativeOverlayShortcut(&key)==11,"Customized controls shortcut");
    key.keysym.sym=SDLK_o; key.keysym.mod|=KMOD_LSHIFT; check(nativeOverlayShortcut(&key)==-1,"Old custom binding must be removed");
    [defaults removeObjectForKey:@"shortcuts"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    NSString* out=argc>1 ? [NSString stringWithUTF8String:argv[1]] : @"/tmp";
    [NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]]; pump(); capture([out stringByAppendingPathComponent:@"overlay-dark.png"]);
    nativeOverlaySetControlsVisible(true); pump(); check(window.childWindows.count==3,"Separate controls surface"); capture([out stringByAppendingPathComponent:@"overlay-controls-dark.png"]);
    [defaults setDouble:1.5 forKey:@"scale"]; [defaults setObject:@"bottomRight" forKey:@"position"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES];
    [window setContentSize:NSMakeSize(640,360)]; pump();
    NSRect bounds=[window convertRectToScreen:window.contentView.bounds];
    for (NSWindow* panel in window.childWindows) check(NSContainsRect(bounds,panel.frame),"Scaled panel must fit resized stream");
    NSArray* panels=window.childWindows;
    for (NSUInteger i=0;i<panels.count;i++) for (NSUInteger j=i+1;j<panels.count;j++) check(!NSIntersectsRect([panels[i] frame],[panels[j] frame]),"Overlay panels must not overlap");
    capture([out stringByAppendingPathComponent:@"overlay-compact-large.png"]);
    [NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]]; capture([out stringByAppendingPathComponent:@"overlay-light.png"]);
    nativeOverlayDetach(); check(!nativeOverlayPresent(0,true,sample),"Detached adapter must allow legacy fallback"); check(window.childWindows.count==0,"No orphan overlay panels");
    nativeOverlayAttach(window,"next-session"); check(nativeOverlayConfigured(),"Repeated session attachment"); nativeOverlayDetach();
    if (previous) [defaults setPersistentDomain:previous forName:@"com.moonlight-stream.NativeGlass.Overlay"]; else [defaults removePersistentDomainForName:@"com.moonlight-stream.NativeGlass.Overlay"]; [previous release]; [defaults synchronize];
    [window close]; SDL_Quit(); puts("Native overlay state, all shortcuts, layout, focus, teardown and preview checks passed"); return 0;
} }
