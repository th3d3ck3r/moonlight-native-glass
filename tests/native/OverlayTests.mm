#import <AppKit/AppKit.h>
#import <SDL.h>
#import <SDL_syswm.h>
#include "nativeoverlay.h"
#include "nativetitlebar.h"
#include <cstdio>
#include <cstdlib>
static void check(bool okay,const char* message) { if (!okay) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static void pump() { NSDate* end=[NSDate dateWithTimeIntervalSinceNow:.2]; while (end.timeIntervalSinceNow>0) { SDL_PumpEvents(); [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; } }
static NSToolbarItem* toolbarItem(NSWindow* window, NSString* identifier) {
    for (NSToolbarItem* item in window.toolbar.items) if ([item.itemIdentifier isEqual:identifier]) return item;
    return nil;
}
static bool hasLabel(NSView* view, NSString* text) {
    if ([view isKindOfClass:NSTextField.class] && [((NSTextField*)view).stringValue containsString:text]) return true;
    for (NSView* child in view.subviews) if (hasLabel(child,text)) return true;
    return false;
}
static bool takeAction(int code) {
    SDL_Event event; bool found=false;
    while (SDL_PollEvent(&event)) if (event.type==nativeOverlayEventType() && event.user.code==code) found=true;
    return found;
}
static NSButton* buttonWithTag(NSView* view, NSInteger tag) {
    if ([view isKindOfClass:NSButton.class] && view.tag==tag) return (NSButton*)view;
    for (NSView* child in view.subviews) if (NSButton* button=buttonWithTag(child,tag)) return button;
    return nil;
}
static void capture(NSString* path) { pump(); NSTask* task=[[[NSTask alloc] init] autorelease]; task.launchPath=@"/usr/sbin/screencapture"; task.arguments=@[@"-x",path]; [task launch]; [task waitUntilExit]; check(task.terminationStatus==0,"Composited capture failed"); }
int main(int argc,char** argv) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; [NSApp finishLaunching];
    SDL_SetMainReady(); check(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_GAMECONTROLLER)==0,"SDL initialization");
    bool consumed = true;
    check(!nativeOverlayConsumeKeyRelease(consumed,SDL_PRESSED) && !consumed,"New press after missing key-up must start a fresh cycle");
    consumed = true;
    check(nativeOverlayConsumeKeyRelease(consumed,SDL_RELEASED) && !consumed,"Consumed shortcut release must not reach the host");
    check(!nativeOverlayConsumeKeyRelease(consumed,SDL_RELEASED),"Ordinary host key release must pass through");
    NSUserDefaults* defaults=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    NSDictionary* previous=[[defaults persistentDomainForName:@"com.moonlight-stream.NativeGlass.Overlay"] retain];
    [defaults removePersistentDomainForName:@"com.moonlight-stream.NativeGlass.Overlay"]; [defaults setBool:YES forKey:@"controlsEnabled"]; [defaults synchronize];
    SDL_Window* stream = SDL_CreateWindow("Native overlay preview — sample statistics, no live stream",60,120,960,540,SDL_WINDOW_SHOWN|SDL_WINDOW_RESIZABLE|SDL_WINDOW_ALLOW_HIGHDPI);
    check(stream != nullptr,"SDL stream window creation");
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    check(SDL_GetWindowWMInfo(stream,&info),"SDL Cocoa window info");
    NSWindow* window=info.info.cocoa.window;
    window.title=@"Native overlay preview — sample statistics, no live stream"; window.releasedWhenClosed=NO;
    window.backgroundColor=[NSColor colorWithSRGBRed:.06 green:.10 blue:.16 alpha:1];
    [window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    pump(); [window makeKeyAndOrderFront:nil]; pump();
    check(NSApp.keyWindow==window,"Fixture must own keyboard focus before overlay attachment");
    nativeOverlayAttach(window,"overlay-test"); check(nativeOverlayEventType()!=SDL_USEREVENT,"Must not consume upstream SDL user events");
    check(window.toolbar!=nil && window.titleVisibility==NSWindowTitleHidden,"Native compact title toolbar installed");
    check(toolbarItem(window,@"NativeHost") && toolbarItem(window,@"NativeCapture") && toolbarItem(window,@"NativeStatistics") && toolbarItem(window,@"NativeConnection"),"Required title-bar controls");
    check(!toolbarItem(window,@"NativeControllerBattery"),"Controller indicator hidden when none connected");
    NSButton* host=(NSButton*)toolbarItem(window,@"NativeHost").view;
    check([host.title isEqual:window.title] && host.imagePosition==NSImageRight,"Computer name and chevron retained");
    [host performClick:nil]; check(takeAction(102),"Computer name queues controls action, not statistics");
    NSButton* captureButton=(NSButton*)toolbarItem(window,@"NativeCapture").view;
    [captureButton performClick:nil]; check(takeAction(1),"Title capture uses original SDL action");
    NSButton* statisticsButton=(NSButton*)toolbarItem(window,@"NativeStatistics").view;
    [statisticsButton performClick:nil]; check(takeAction(3),"Title statistics uses original SDL action");
    nativeTitlebarSetCapture(true); pump(); check([captureButton.toolTip containsString:@"captured by host"],"Capture state refresh");
    nativeTitlebarSetCapture(false); pump(); check([captureButton.toolTip containsString:@"released to Mac"],"Capture release refresh");
    NSButton* connectionButton=(NSButton*)toolbarItem(window,@"NativeConnection").view;
    nativeTitlebarSetConnection(NativeConnectionState::Connecting); pump(); check([connectionButton.toolTip containsString:@"Connecting"],"Connecting state");
    nativeTitlebarSetConnection(NativeConnectionState::Connected); pump(); check([connectionButton.toolTip containsString:@"No connection warning"],"Connected state");
    nativeTitlebarSetConnection(NativeConnectionState::Poor); pump(); check([connectionButton.toolTip containsString:@"poor connection"],"Poor state");
    nativeTitlebarConnectionStarted(); pump(); check([connectionButton.toolTip containsString:@"poor connection"],"Startup completion must not clear an existing connection warning");
    nativeTitlebarSetConnection(NativeConnectionState::Disconnected); pump(); check([connectionButton.toolTip containsString:@"lost or failed"],"Disconnected state");
    nativeTitlebarConnectionStarted(); pump(); check([connectionButton.toolTip containsString:@"lost or failed"],"Startup completion must not clear a connection failure");
    nativeTitlebarSetConnection(NativeConnectionState::Idle); pump(); check([connectionButton.toolTip containsString:@"No stream connection"],"Idle state");
    nativeTitlebarSetConnection(NativeConnectionState::Connected); pump();
    // An actual virtual SDL controller exercises appearance/removal without
    // opening hardware from the title-bar implementation.
    int device=SDL_JoystickAttachVirtual(SDL_JOYSTICK_TYPE_GAMECONTROLLER,6,16,0);
    check(device>=0,"Virtual controller creation");
    SDL_GameController* virtualController=SDL_GameControllerOpen(device); check(virtualController!=nullptr,"Virtual controller open");
    nativeTitlebarControllersChanged(); pump();
    check(toolbarItem(window,@"NativeControllerBattery")!=nil,"Controller indicator appears after connection");
    NSButton* batteryButton=(NSButton*)toolbarItem(window,@"NativeControllerBattery").view;
    check([batteryButton.toolTip containsString:@"unavailable"],"Unknown charge is not fabricated");
    [connectionButton performClick:nil]; pump();
    bool foundDetails=false; for (NSWindow* candidate in NSApp.windows) if (candidate.visible && hasLabel(candidate.contentView,@"not latency or frame pacing")) foundDetails=true;
    check(foundDetails,"Connection popover contains accurate state explanation");
    [connectionButton performClick:nil]; [batteryButton performClick:nil]; pump();
    bool foundBattery=false; for (NSWindow* candidate in NSApp.windows) if (candidate.visible && hasLabel(candidate.contentView,@"Battery information unavailable")) foundBattery=true;
    check(foundBattery,"Rapid details replacement must keep the current popover state");
    [batteryButton performClick:nil]; pump();
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
    [defaults setBool:NO forKey:@"controlsEnabled"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    check(nativeOverlayShortcut(&key)==11,"Default controls shortcut");
    for (int i=0;i<13;i++) { key.keysym.sym="qzxsmcdvlekob"[i]; check(nativeOverlayShortcut(&key)==i,"Every existing shortcut and plain Disconnect must resolve"); }
    key.keysym.mod=KMOD_LCTRL; check(nativeOverlayShortcut(&key)==-1,"Normal host keys must not be consumed");
    [defaults setObject:@{@"11":@{@"key":@"p",@"modifiers":@3}, @"12":@{@"key":@"r",@"modifiers":@10}} forKey:@"shortcuts"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    key.keysym.sym=SDLK_p; key.keysym.mod=KMOD_LCTRL|KMOD_LALT; check(nativeOverlayShortcut(&key)==11,"Customized controls shortcut");
    key.keysym.sym=SDLK_o; key.keysym.mod|=KMOD_LSHIFT; check(nativeOverlayShortcut(&key)==-1,"Old custom binding must be removed");
    key.keysym.sym=SDLK_r; key.keysym.mod=KMOD_LGUI|KMOD_LALT; check(nativeOverlayShortcut(&key)==12,"Plain Disconnect shortcut must be customizable");
    [defaults removeObjectForKey:@"shortcuts"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    NSString* out=argc>1 ? [NSString stringWithUTF8String:argv[1]] : @"/tmp";
    [NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]]; pump(); capture([out stringByAppendingPathComponent:@"overlay-dark.png"]);
    nativeOverlaySetControlsVisible(true); pump(); check(window.childWindows.count==3,"Separate controls surface");
    NSWindow* controls=nil;
    for (NSWindow* panel in window.childWindows) if (!panel.ignoresMouseEvents) controls=panel;
    NSButton* disconnect=buttonWithTag(controls.contentView,12);
    check(disconnect!=nil && [disconnect.accessibilityLabel isEqual:@"Disconnect"],"Default controls must expose Disconnect");
    [disconnect performClick:nil]; check(takeAction(12),"Disconnect must use plain disconnect, not close/hide or quit host game");
    check(NSApp.keyWindow==window && !controls.canBecomeKeyWindow,"Control buttons must preserve stream keyboard focus and cursor confinement");
    SDL_ShowCursor(SDL_DISABLE);
    SDL_SetWindowMouseGrab(stream,SDL_FALSE);
    SDL_Rect restricted={20,20,400,300}; SDL_SetWindowMouseRect(stream,&restricted);
    nativeOverlayBeginControlsInput(stream);
    check(SDL_ShowCursor(SDL_QUERY)==SDL_ENABLE && SDL_GetWindowMouseGrab(stream),"Controls must show and confine the local pointer");
    check(SDL_GetWindowMouseRect(stream)==nullptr,"Controls must allow the entire stream window, not just the video region");
    nativeOverlayBeginControlsInput(stream);
    nativeOverlayEndControlsInput();
    const SDL_Rect* restored=SDL_GetWindowMouseRect(stream);
    check(SDL_ShowCursor(SDL_QUERY)==SDL_DISABLE && !SDL_GetWindowMouseGrab(stream),"Dismissal must restore pointer visibility and grab state");
    check(restored && restored->x==20 && restored->y==20 && restored->w==400 && restored->h==300,"Dismissal must restore the previous pointer region");
    SDL_SetWindowMouseRect(stream,nullptr); SDL_ShowCursor(SDL_ENABLE);
    for (NSWindow* panel in window.childWindows) check(panel.visible && (panel.occlusionState & NSWindowOcclusionStateVisible),"Showing controls must keep all overlays unobscured");
    capture([out stringByAppendingPathComponent:@"overlay-controls-dark.png"]);
    [batteryButton performClick:nil]; pump(); capture([out stringByAppendingPathComponent:@"titlebar-controller-details.png"]);
    [batteryButton performClick:nil]; pump();
    SDL_GameControllerClose(virtualController); SDL_JoystickDetachVirtual(device); nativeTitlebarControllersChanged(); pump();
    check(!toolbarItem(window,@"NativeControllerBattery"),"Controller indicator removed after disconnect");
    [defaults setDouble:1.5 forKey:@"scale"]; [defaults setObject:@"bottomRight" forKey:@"position"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES];
    [window setContentSize:NSMakeSize(640,360)]; pump();
    NSRect bounds=[window convertRectToScreen:window.contentView.bounds];
    for (NSWindow* panel in window.childWindows) check(NSContainsRect(bounds,panel.frame),"Scaled panel must fit resized stream");
    NSArray* panels=window.childWindows;
    for (NSUInteger i=0;i<panels.count;i++) for (NSUInteger j=i+1;j<panels.count;j++) check(!NSIntersectsRect([panels[i] frame],[panels[j] frame]),"Overlay panels must not overlap");
    capture([out stringByAppendingPathComponent:@"overlay-compact-large.png"]);
    [NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]]; capture([out stringByAppendingPathComponent:@"overlay-light.png"]);
    // All selected actions must still fit when a previously wide bar shrinks.
    [defaults setObject:@[@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10] forKey:@"buttons"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    [window setContentSize:NSMakeSize(320,300)]; pump();
    bounds=[window convertRectToScreen:window.contentView.bounds];
    for (NSWindow* panel in window.childWindows) check(NSContainsRect(bounds,panel.frame),"Every panel must fit after controls shrink with all actions selected");
    controls=nil; for (NSWindow* panel in window.childWindows) if (!panel.ignoresMouseEvents) controls=panel;
    check(buttonWithTag(controls.contentView,12)!=nil,"Disconnect must remain directly visible in compact controls");
    nativeOverlayDetach(); check(window.toolbar==nil && window.titleVisibility==NSWindowTitleVisible,"Original title bar restored on detach"); check(!nativeOverlayPresent(0,true,sample),"Detached adapter must allow legacy fallback"); check(window.childWindows.count==0,"No orphan overlay panels");
    nativeOverlayAttach(window,"next-session"); check(nativeOverlayConfigured(),"Repeated session attachment"); nativeOverlayDetach();
    if (previous) [defaults setPersistentDomain:previous forName:@"com.moonlight-stream.NativeGlass.Overlay"]; else [defaults removePersistentDomainForName:@"com.moonlight-stream.NativeGlass.Overlay"]; [previous release]; [defaults synchronize];
    SDL_DestroyWindow(stream); SDL_Quit(); puts("Native overlay state, all shortcuts, layout, focus, teardown and preview checks passed"); return 0;
} }
