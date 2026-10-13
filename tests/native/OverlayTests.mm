#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <SDL.h>
#import <SDL_syswm.h>
#include "nativeoverlay.h"
#include "nativetitlebar.h"
#include "nativeplaybackvolume.h"
#include <cstdio>
#include <cstdlib>
#include <cmath>
static void check(bool okay,const char* message) { if (!okay) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static void pump(double seconds=.2) { NSDate* end=[NSDate dateWithTimeIntervalSinceNow:seconds]; while (end.timeIntervalSinceNow>0) { SDL_PumpEvents(); [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; } }
#include "TitlebarFixture.h"
static bool hasLabel(NSView* view, NSString* text) {
    if ([view isKindOfClass:NSTextField.class] && [((NSTextField*)view).stringValue containsString:text]) return true;
    for (NSView* child in view.subviews) if (hasLabel(child,text)) return true;
    return false;
}
static NSView* tintView(NSView* view) {
    if ([view.identifier isEqual:@"native-crimson-overlay-tint"]) return view;
    for (NSView* child in view.subviews) if (NSView* found=tintView(child)) return found;
    return nil;
}
static void checkCrimson(NSWindow* panel, bool enabled) {
    NSView* tint=tintView(panel.contentView);
    check(tint!=nil && tint.hidden==!enabled,"Every overlay must follow Crimson Glass, including existing passive panels");
    check(tint.layer.cornerRadius==12 && tint.layer.borderWidth==1,"Crimson overlay edges must be rounded and outlined");
    check(panel.backgroundColor.alphaComponent==0 && panel.contentView.layer.masksToBounds && panel.contentView.layer.cornerRadius==12,"Opaque accessibility fallback must stay inside rounded panel edges, without square corners");
    check([tint hitTest:NSMakePoint(10,10)]==nil,"Tint must never intercept mouse input");
    if (enabled) {
        NSColor* color=[[NSColor colorWithCGColor:tint.layer.backgroundColor] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        const bool reduce=[NSWorkspace sharedWorkspace].accessibilityDisplayShouldReduceTransparency;
        check(color.redComponent>color.greenComponent+(reduce ? 0.015 : 0.1),"Overlay fill must carry the crimson palette in translucent and opaque accessibility modes");
        check(!reduce || color.alphaComponent==1,"Reduce Transparency must use an opaque overlay fill");
    }
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
    CGFloat stockChrome=window.frame.size.height-window.contentLayoutRect.size.height;
    BOOL originalTransparency=window.titlebarAppearsTransparent;
    NSColor* originalBackground=window.backgroundColor;
    NSTitlebarSeparatorStyle originalSeparator=window.titlebarSeparatorStyle;
    NSWindowStyleMask originalStyle=window.styleMask;
    NSRect originalFrame=window.frame;
    nativeOverlayAttach(window,"overlay-test"); check(nativeOverlayEventType()!=SDL_USEREVENT,"Must not consume upstream SDL user events");
    pump();
    check(titlebarRoot(window)!=nil && window.toolbar==nil && window.titleVisibility==NSWindowTitleHidden,"Slim native title row installed without a tall toolbar");
    CGFloat slimChrome=window.frame.size.height-window.contentLayoutRect.size.height;
    fprintf(stderr,"Titlebar chrome: original=%.1f slim=%.1f points\n",stockChrome,slimChrome);
    fprintf(stderr,"OVERLAY FRAME: before=%s after=%s style=0x%lx content=%s\n",NSStringFromRect(originalFrame).UTF8String,NSStringFromRect(window.frame).UTF8String,(unsigned long)window.styleMask,NSStringFromRect(window.contentView.frame).UTF8String);
    check(slimChrome<=32 && slimChrome<=stockChrome+1,"Slim controls must stay in the original title row and preserve drawable geometry");
    check((window.styleMask & NSWindowStyleMaskFullSizeContentView) && NSEqualRects(originalFrame,window.frame),"Video must extend under the title overlay without moving the window");
    NSView* backdrop=titlebarBackground(window);
    check(window.titlebarSeparatorStyle==NSTitlebarSeparatorStyleNone && backdrop && backdrop.frame.size.width==window.frame.size.width && backdrop.frame.size.height>=24 && backdrop.frame.size.height<=32,"Rounded surface must span the full bar, including traffic lights");
    check([backdrop hitTest:NSMakePoint(10,10)]==nil,"Decorative rounded background must pass all mouse input through");
    check(titlebarButton(window,@"NativeHost") && titlebarButton(window,@"NativeCapture") && titlebarButton(window,@"NativeStatistics") && titlebarButton(window,@"NativeConnection"),"Required title-bar controls");
    check(!titlebarButton(window,@"NativeControllerBattery"),"Controller indicator hidden when none connected");
    NSButton* host=titlebarButton(window,@"NativeHost");
    check([host.title isEqual:window.title] && host.imagePosition==NSImageRight,"Computer name and chevron retained");
    [host performClick:nil]; check(takeAction(102),"Computer name queues controls action, not statistics");
    NSButton* captureButton=titlebarButton(window,@"NativeCapture");
    [captureButton performClick:nil]; check(takeAction(1),"Title capture uses original SDL action");
    NSButton* statisticsButton=titlebarButton(window,@"NativeStatistics");
    NSButton* muteButton=titlebarButton(window,@"NativeMute");
    check(muteButton && [NSStringFromClass(muteButton.class) isEqualToString:@"MLStreamToolbarButton"],"Mute must share the title-button mouse tracking boundary");
    [muteButton performClick:nil]; pump();
    check(!takeAction(207),"Speaker must open volume controls without toggling mute");
    NSPopover* volume=[muteButton.target valueForKey:@"details"];
    check(volume.shown,"Playback volume popover must open");
    NSSlider* slider=(NSSlider*)titlebarFindView(volume.contentViewController.view,@"PlaybackVolumeSlider");
    NSButton* popupMute=(NSButton*)titlebarFindView(volume.contentViewController.view,@"PlaybackMute");
    check(slider && [NSStringFromClass(slider.class) isEqualToString:@"MLStreamVolumeSlider"] && popupMute && [NSStringFromClass(popupMute.class) isEqualToString:@"MLStreamToolbarButton"],"Volume slider and mute share tracking repair");
    slider.doubleValue=.45; [slider.target performSelector:slider.action withObject:slider];
    check(std::fabs(nativePlaybackVolume()-.45f)<.0001f,"Slider must update playback gain");
    [popupMute performClick:nil]; check(takeAction(207),"Popover mute queues existing playback action");
    nativeTitlebarSetMuted(true); pump();
    check([popupMute.toolTip containsString:@"Unmute Playback"] && [muteButton.toolTip containsString:@"Recording audio is unchanged"],"Muted volume controls synchronize with menu state");
    check(std::fabs(nativePlaybackVolume()-.45f)<.0001f,"Mute must retain prior slider level");
    nativeTitlebarSetMuted(false); pump();
    check([popupMute.toolTip containsString:@"Mute Playback"],"Unmuted popover state must refresh");
    [muteButton.target performSelector:@selector(closeDetails)]; pump();
    NSButton* hardwareButton=titlebarButton(window,@"NativeHardware");
    check(hardwareButton && [NSStringFromClass(hardwareButton.class) isEqualToString:@"MLStreamToolbarButton"],"Hardware toggle uses shared tracking");
    [hardwareButton performClick:nil]; pump(1.2);
    NSView* monitor=titlebarFindView(window.contentView,@"NativeHardwareOverlay");
    check(monitor && !monitor.hiddenOrHasHiddenAncestor,"Hardware monitor attaches inside the existing stream content");
    check(!NSEqualRects(monitor.frame,NSZeroRect) && NSContainsRect(window.contentView.bounds,monitor.frame),"Hardware monitor stays inside stream bounds");
    check([monitor valueForKey:@"sampler"]!=nil,"Visible monitor must sample");
    nativeTitlebarSetCapture(true); pump();
    check([monitor hitTest:NSMakePoint(NSMinX(monitor.frame)+12,NSMinY(monitor.frame)+12)]==nil,"Captured hardware overlay passes gameplay clicks through");
    nativeTitlebarSetCapture(false); pump();
    check([monitor hitTest:NSMakePoint(NSMinX(monitor.frame)+12,NSMinY(monitor.frame)+12)]!=nil,"Released hardware overlay permits local adjustment");
    NSButton* adjust=(NSButton*)titlebarFindView(monitor,@"HardwareAdjust");
    [adjust performClick:nil]; pump();
    NSView* adjustments=[monitor valueForKey:@"adjustments"];
    check(adjustments && !adjustments.hidden,"Monitor adjustment controls open locally");
    [adjust performClick:nil]; pump();
    [monitor retain]; [hardwareButton performClick:nil]; pump();
    check(!monitor.superview && [monitor valueForKey:@"sampler"]==nil,"Closed hardware monitor removes view and stops sampling");
    [monitor release];
    check(NSMinX(statisticsButton.frame)<NSMinX(hardwareButton.frame) && NSMinX(hardwareButton.frame)<NSMinX(muteButton.frame),"Monitoring controls precede playback in title order");
    check(statisticsButton.image!=nil,"Native line-graph symbol must be available");
    [statisticsButton performClick:nil]; check(takeAction(3),"Title statistics uses original SDL action");
    nativeTitlebarSetRecording(true,true,true,true,false,false,65,"Recording"); pump();
    NSButton* recordButton=titlebarButton(window,@"NativeRecord"); NSButton* replayButton=titlebarButton(window,@"NativeReplay");
    check(recordButton.enabled && [recordButton.toolTip containsString:@"1:05"],"Recording button and elapsed tooltip");
    check(replayButton.enabled,"Ready replay action");
    nativeTitlebarSetRecording(true,false,true,false,true,false,0,"Saving"); pump();
    check(!replayButton.enabled && [replayButton.toolTip containsString:@"Saving"],"Replay save prevents duplicate exports");
    nativeTitlebarSetRecording(false,false,false,false,false,false,0,"Disabled"); pump();
    check(!recordButton.enabled && !replayButton.enabled,"Disabled recorder controls");
    NSRect videoBounds=window.contentView.bounds, videoFrame=window.contentView.frame;
    int drawableWidth,drawableHeight; SDL_GL_GetDrawableSize(stream,&drawableWidth,&drawableHeight);
    nativeTitlebarSetCapture(true); pump(); check([captureButton.toolTip containsString:@"captured by host"],"Capture state refresh");
    check(titlebarRoot(window).hiddenOrHasHiddenAncestor && backdrop.hidden && !window.movable && [window standardWindowButton:NSWindowCloseButton].hiddenOrHasHiddenAncestor,"Captured stream must have no visible or draggable title chrome");
    NSPoint top=NSMakePoint(NSMidX(window.contentView.bounds),NSMaxY(window.contentView.bounds)-10);
    NSView* hit=[window.contentView.superview hitTest:[window.contentView convertPoint:top toView:window.contentView.superview]];
    check(hit && (hit==window.contentView || [hit isDescendantOf:window.contentView]),"Hidden title buttons must not intercept the video region");
    for (int i=0;i<4;++i) { nativeTitlebarSetCapture(false); pump(); nativeTitlebarSetCapture(true); pump(); }
    nativeTitlebarSetCapture(false); pump(); check([captureButton.toolTip containsString:@"released to Mac"],"Capture release refresh");
    check(!titlebarRoot(window).hiddenOrHasHiddenAncestor && !backdrop.hidden && backdrop.alphaValue==1 && window.movable,"Intentional release must restore all title controls and dragging");
    int afterWidth,afterHeight; SDL_GL_GetDrawableSize(stream,&afterWidth,&afterHeight);
    check(NSEqualRects(videoBounds,window.contentView.bounds) && NSEqualRects(videoFrame,window.contentView.frame) && NSEqualRects(originalFrame,window.frame) && drawableWidth==afterWidth && drawableHeight==afterHeight,"Capture changes must not resize or shift the video/drawable/window");
    // Releasing during the fade must defeat its stale completion callback.
    nativeTitlebarSetCapture(true); pump(.02); nativeTitlebarSetCapture(false); pump();
    check(!backdrop.hidden && backdrop.alphaValue==1,"A previous hide must not hide freshly released controls");
    NSButton* connectionButton=titlebarButton(window,@"NativeConnection");
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
    check(titlebarButton(window,@"NativeControllerBattery")!=nil,"Controller indicator appears after connection");
    NSButton* batteryButton=titlebarButton(window,@"NativeControllerBattery");
    check([batteryButton.toolTip containsString:@"unavailable"],"Unknown charge is not fabricated");
    [connectionButton performClick:nil]; pump();
    bool foundDetails=false; for (NSWindow* candidate in NSApp.windows) if (candidate.visible && hasLabel(candidate.contentView,@"not latency or frame pacing")) foundDetails=true;
    check(foundDetails,"Connection popover contains accurate state explanation");
    [connectionButton performClick:nil]; [batteryButton performClick:nil]; pump();
    bool foundBattery=false; for (NSWindow* candidate in NSApp.windows) if (candidate.visible && hasLabel(candidate.contentView,@"Battery information unavailable")) foundBattery=true;
    check(foundBattery,"Rapid details replacement must keep the current popover state");
    [batteryButton performClick:nil]; pump();
    NSString* titlebarOut=argc>1 ? [NSString stringWithUTF8String:argv[1]] : @"/tmp/native-overlay-previews";
    [[NSFileManager defaultManager] createDirectoryAtPath:titlebarOut withIntermediateDirectories:YES attributes:nil error:nil];
    capture([titlebarOut stringByAppendingPathComponent:@"titlebar-slim-dark.png"]);
    nativeTitlebarSetCapture(true); pump(); capture([titlebarOut stringByAppendingPathComponent:@"titlebar-captured-hidden.png"]);
    nativeTitlebarSetCapture(false); pump(); capture([titlebarOut stringByAppendingPathComponent:@"titlebar-released-overlay.png"]);
    [hardwareButton performClick:nil]; pump(2.2);
    capture([titlebarOut stringByAppendingPathComponent:@"hardware-monitor.png"]);
    [muteButton performClick:nil]; pump(); capture([titlebarOut stringByAppendingPathComponent:@"playback-volume.png"]);
    [muteButton.target performSelector:@selector(closeDetails)]; [hardwareButton performClick:nil]; pump();
    [window setContentSize:NSMakeSize(300,360)]; pump();
    NSButton* overflow=titlebarButton(window,@"NativeOverflow");
    check(overflow && !overflow.hidden && statisticsButton.hidden,"Narrow title row must expose overflow rather than overlapping controls");
    check(NSMaxX(host.frame)<=NSMinX(overflow.frame)+1,"Computer entry must not overlap narrow-window overflow");
    capture([titlebarOut stringByAppendingPathComponent:@"titlebar-slim-narrow.png"]);
    [window setContentSize:NSMakeSize(960,540)]; pump();
    check(overflow.hidden && !statisticsButton.hidden,"Widening must restore direct title controls");
    const char* sample="Video stream: 1920x1080 60 FPS\nVideo codec: H.264\nIncoming frame rate: 59.98 FPS\nRendering frame rate: 59.98 FPS\nFrames dropped by network: 0.00%\nAverage network latency: 2 ms\nAverage decoding time: 1.2 ms\nAverage frame queue delay: 0.4 ms\nAverage rendering time: 0.8 ms";
    check(nativeOverlayPresent(0,true,sample),"Native statistics ownership"); check(nativeOverlayPresent(1,true,"Design preview · Sample values"),"Status ownership"); pump();
    fprintf(stderr,"Overlay children=%lu visible=%d configured=%d\n",(unsigned long)window.childWindows.count,window.visible,nativeOverlayConfigured());
    check(window.childWindows.count==2,"Passive surfaces only; controls hidden by default");
    for (NSWindow* panel in window.childWindows) {
        check(panel.ignoresMouseEvents,"Statistics/status must pass through input");
        check(!panel.canBecomeKeyWindow && !panel.canBecomeMainWindow,"Passive panels must reject keyboard/main focus");
    }
    check(NSApp.keyWindow==window,"Passive overlay must not steal focus");
    NSArray* passive=[window.childWindows copy];
    for (NSWindow* panel in passive) checkCrimson(panel,true);
    [defaults setBool:NO forKey:@"crimsonGlass"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    for (NSWindow* panel in passive) { check([window.childWindows containsObject:panel],"Appearance switching must retain passive panel identities"); checkCrimson(panel,false); }
    [defaults setBool:YES forKey:@"crimsonGlass"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    for (NSWindow* panel in passive) checkCrimson(panel,true);
    [passive release];
    SDL_KeyboardEvent key={}; key.state=SDL_PRESSED; key.keysym.sym=SDLK_o; key.keysym.mod=KMOD_LCTRL|KMOD_LALT|KMOD_LSHIFT;
    [defaults setBool:NO forKey:@"controlsEnabled"]; [defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    check(nativeOverlayShortcut(&key)==11,"Default controls shortcut");
    nativeTitlebarSetCapture(true); pump();
    check(titlebarRoot(window).hiddenOrHasHiddenAncestor,"Shortcut checks must run with chrome hidden");
    for (int i=0;i<13;i++) { key.keysym.sym="qzxsmcdvlekob"[i]; check(nativeOverlayShortcut(&key)==i,"Every existing shortcut and plain Disconnect must resolve"); }
    nativeTitlebarSetCapture(false); pump();
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
    for (NSWindow* panel in window.childWindows) checkCrimson(panel,true);
    capture([out stringByAppendingPathComponent:@"overlay-controls-dark.png"]);
    [batteryButton performClick:nil]; pump(); capture([out stringByAppendingPathComponent:@"titlebar-controller-details.png"]);
    [batteryButton performClick:nil]; pump();
    SDL_GameControllerClose(virtualController); SDL_JoystickDetachVirtual(device); nativeTitlebarControllersChanged(); pump();
    check(!titlebarButton(window,@"NativeControllerBattery"),"Controller indicator removed after disconnect");
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
    nativeOverlayDetach(); check((window.styleMask & NSWindowStyleMaskFullSizeContentView)==(originalStyle & NSWindowStyleMaskFullSizeContentView),"Detach restores original full-size content style"); check(window.toolbar==nil && !titlebarRoot(window) && window.titleVisibility==NSWindowTitleVisible && window.titlebarAppearsTransparent==originalTransparency && !titlebarBackground(window) && [window.backgroundColor isEqual:originalBackground] && window.titlebarSeparatorStyle==originalSeparator,"Original title bar restored on detach"); check(!nativeOverlayPresent(0,true,sample),"Detached adapter must allow legacy fallback"); check(window.childWindows.count==0,"No orphan overlay panels");
    nativeOverlayAttach(window,"next-session"); check(nativeOverlayConfigured(),"Repeated session attachment"); nativeOverlayDetach();
    if (previous) [defaults setPersistentDomain:previous forName:@"com.moonlight-stream.NativeGlass.Overlay"]; else [defaults removePersistentDomainForName:@"com.moonlight-stream.NativeGlass.Overlay"]; [previous release]; [defaults synchronize];
    SDL_DestroyWindow(stream); SDL_Quit(); puts("Native overlay state, all shortcuts, layout, focus, teardown and preview checks passed"); return 0;
} }
