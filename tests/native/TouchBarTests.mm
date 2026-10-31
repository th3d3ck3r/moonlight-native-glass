#import <AppKit/AppKit.h>
#import <SDL.h>
#import <SDL_syswm.h>
#include "nativeoverlay.h"
#include "nativetitlebar.h"
#include <cstdio>
#include <cstdlib>

static void check(bool okay,const char* message) { if (!okay) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static void pump() { NSDate* until=[NSDate dateWithTimeIntervalSinceNow:.08]; while (until.timeIntervalSinceNow>0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.005]]; }
static NSButton* button(NSTouchBar* bar,NSString* name) { return (NSButton*)((NSCustomTouchBarItem*)[bar itemForIdentifier:name]).view; }
static bool action(int expected) { SDL_Event event; bool found=false; while (SDL_PollEvent(&event)) if (event.type==nativeOverlayEventType() && event.user.code==expected) found=true; return found; }
static NSTouchBar* expanded(NSTouchBar* bar,NSString* name) { return ((NSPopoverTouchBarItem*)[bar itemForIdentifier:name]).popoverTouchBar; }
static void capture(NSTouchBar* bar,NSString* path,CGFloat available=685) {
    NSView* root=[[[NSView alloc] initWithFrame:NSMakeRect(0,0,available,54)] autorelease];
    root.wantsLayer=YES; root.layer.backgroundColor=NSColor.blackColor.CGColor;
    NSStackView* stack=[[[NSStackView alloc] initWithFrame:NSMakeRect(8,12,669,30)] autorelease];
    stack.orientation=NSUserInterfaceLayoutOrientationHorizontal; stack.spacing=6;
    stack.alignment=NSLayoutAttributeCenterY; stack.distribution=NSStackViewDistributionFill;
    [root addSubview:stack];
    CGFloat requested=0; BOOL flexible=NO;
    for (NSString* identifier in bar.defaultItemIdentifiers) {
        NSTouchBarItem* item=[bar itemForIdentifier:identifier]; NSView* view=nil;
        if ([item isKindOfClass:NSPopoverTouchBarItem.class]) view=((NSPopoverTouchBarItem*)item).collapsedRepresentation;
        else if ([item isKindOfClass:NSSliderTouchBarItem.class]) view=((NSSliderTouchBarItem*)item).slider;
        else if ([item isKindOfClass:NSCustomTouchBarItem.class]) view=((NSCustomTouchBarItem*)item).view;
        check(view!=nil,"Every declared Touch Bar item must resolve on a Mac without hardware");
        if ([view isKindOfClass:NSClassFromString(@"MLTouchButton")]) {
            NSButton* control=(NSButton*)view;
            CGFloat text=[control.title sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold]}].width;
            CGFloat assigned=0;
            for (NSLayoutConstraint* constraint in control.constraints) if ([constraint.identifier isEqual:@"MoonlightLG.TouchWidth"]) assigned=constraint.constant;
            check(text+(control.image ? 20 : 0)+12<=assigned,[[NSString stringWithFormat:@"%@ requires %.1f points, assigned %.1f",control.title,text+(control.image ? 20 : 0)+12,assigned] UTF8String]);
        }
        view.translatesAutoresizingMaskIntoConstraints=NO;
        [stack addArrangedSubview:view];
        if ([identifier isEqual:@"touch.detail"] || [identifier isEqual:@"touch.volume"] || ([identifier isEqual:@"touch.info"] && [view isKindOfClass:NSClassFromString(@"MLTouchStatsButton")])) flexible=YES;
        for (NSLayoutConstraint* constraint in view.constraints) if ([constraint.identifier isEqual:@"MoonlightLG.TouchWidth"] && constraint.firstAttribute==NSLayoutAttributeWidth && constraint.secondItem==nil && (constraint.relation==NSLayoutRelationEqual || constraint.relation==NSLayoutRelationGreaterThanOrEqual)) requested+=constraint.constant;
    }
    requested+=MAX(0,(NSInteger)stack.arrangedSubviews.count-1)*6;
    BOOL expandedPage=[bar.defaultItemIdentifiers containsObject:@"touch.detail"] || [bar.defaultItemIdentifiers containsObject:@"touch.mute"] || [bar.defaultItemIdentifiers containsObject:@"touch.stats"];
    CGFloat budget=available-16-(expandedPage ? 64 : 0);
    check(requested<=budget,"Reserve the system Control Strip and native popover Back control; never rely on the full physical bar");
    check(bar.escapeKeyReplacementItemIdentifier==nil,"Preserve the system Escape behavior");
    stack.frame=NSMakeRect(8,12,flexible ? budget : requested,30);
    [root layoutSubtreeIfNeeded];
    BOOL framesFit=YES;
    for (NSView* view in stack.arrangedSubviews) {
        fprintf(stderr,"Touch item %s (%s): %s budget %.1f\n",view.identifier.UTF8String ?: "unnamed",NSStringFromClass(view.class).UTF8String,NSStringFromRect(view.frame).UTF8String,budget);
        // AppKit constraints place alignment rectangles. NSTextField includes
        // two pixels of optical padding outside that rectangle in its frame.
        NSRect alignment=[view alignmentRectForFrame:view.frame];
        fprintf(stderr,"  alignment: %s\n",NSStringFromRect(alignment).UTF8String);
        if (!(alignment.size.width>20 && NSMaxX(alignment)<=budget+1)) framesFit=NO;
    }
    NSBitmapImageRep* image=[root bitmapImageRepForCachingDisplayInRect:root.bounds]; [root cacheDisplayInRect:root.bounds toBitmapImageRep:image];
    check([[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES],"Touch Bar item preview export");
    check(framesFit,"Touch Bar item clipped or collapsed");
    for (NSView* view in [[stack.arrangedSubviews copy] autorelease]) { [stack removeArrangedSubview:view]; [view removeFromSuperview]; }
}
int main(int argc,char** argv) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp finishLaunching]; NSApp.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    SDL_SetMainReady(); check(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_GAMECONTROLLER)==0,"SDL init");
    SDL_Window* stream=SDL_CreateWindow("Touch Bar fixture",80,100,960,540,SDL_WINDOW_SHOWN|SDL_WINDOW_RESIZABLE);
    check(stream!=nullptr,"Stream fixture"); SDL_SysWMinfo info; SDL_VERSION(&info.version); check(SDL_GetWindowWMInfo(stream,&info),"Cocoa window");
    NSWindow* window=info.info.cocoa.window;
    NSUserDefaults* preferences=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    id oldLayout=[[preferences objectForKey:@"touchBarLiveStats"] retain];
    [preferences setBool:YES forKey:@"touchBarLiveStats"]; [preferences synchronize];
    NSTouchBar* original=[[[NSTouchBar alloc] init] autorelease]; window.touchBar=original;
    nativeOverlayAttach(window,"touchbar-fixture"); pump(); NSTouchBar* bar=[window.touchBar retain];
    check(bar && bar!=original && bar.defaultItemIdentifiers.count==3,"Live stats, capture and controls must occupy the main Touch Bar");
    NSTouchBar* dashboard=expanded(bar,@"touch.info"); NSTouchBar* more=expanded(bar,@"touch.more"); NSTouchBar* audio=expanded(more,@"touch.audio"); NSTouchBar* windowControls=expanded(more,@"touch.window");
    NSTextField* volumeText=(NSTextField*)((NSCustomTouchBarItem*)[audio itemForIdentifier:@"touch.volumeLabel"]).view;
    check([volumeText isKindOfClass:NSTextField.class] && [volumeText.textColor isEqual:NSColor.whiteColor],"Volume percentage must remain a readable, static readout");
    check(dashboard && audio && more,"Status, audio and secondary controls must expand with native close buttons");
    for (NSString* name in @[@"touch.info",@"touch.more"]) check(((NSPopoverTouchBarItem*)[bar itemForIdentifier:name]).showsCloseButton,"Expanded pages need a clear Back control");
    nativeTitlebarSetCapture(true); nativeTitlebarSetConnection(NativeConnectionState::Connected);
    nativeTitlebarSetRecording(false,false,false,false,false,false,0,"Recording disabled"); pump();
    check(!button(more,@"touch.record").enabled && !button(more,@"touch.replay").enabled,"Disabled recording must not trigger recorder actions");
    [button(more,@"touch.replay") performClick:nil]; check(!action(219),"Disabled replay must not enqueue an action");
    SDL_bool relative=SDL_GetRelativeMouseMode();
    [button(bar,@"touch.capture") performClick:nil]; check(action(1),"Capture uses the same SDL action as the title bar");
    [button(windowControls,@"touch.fullscreen") performClick:nil]; check(action(2),"Fullscreen queues the existing stream handler");
    [button(more,@"touch.stats") performClick:nil]; check(action(3),"Statistics action routing");
    [button(audio,@"touch.mute") performClick:nil]; check(action(207),"Mute action routing");
    check(SDL_GetRelativeMouseMode()==relative,"Touch Bar actions must not directly mutate mouse confinement");
    nativeTitlebarSetRecording(true,true,true,true,false,false,125,"Original Stream Quality"); pump();
    check([button(more,@"touch.record").title isEqual:@"2:05"] && button(more,@"touch.replay").enabled,"Recording time and replay readiness must synchronize");
    [button(more,@"touch.record") performClick:nil]; check(action(217),"Record routes through the plugin action");
    [button(more,@"touch.replay") performClick:nil]; check(action(219),"Replay uses the existing save action");
    nativeTitlebarSetRecording(true,true,true,true,true,false,126,"Saving"); pump();
    check(!button(more,@"touch.replay").enabled && [button(more,@"touch.replay").title isEqual:@"Saving"],"Prevent duplicate replay saves");
    nativeOverlayPresent(0,true,"Incoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms\nBitrate: 25 Mbps\nAverage decoding time: 1.2 ms\nFrames dropped by network: 0.0%\nRendering frame rate: 59.98 FPS"); pump();
    NSView* panel=((NSCustomTouchBarItem*)[dashboard itemForIdentifier:@"touch.detail"]).view;
    NSView* readings=[panel valueForKey:@"dashboard"];
    check([readings.accessibilityLabel containsString:@"60.00 FPS"] && [readings.accessibilityLabel containsString:@"4 ms"],"Stream values come from actual engine statistics");
    [readings setValue:@0 forKey:@"streamUpdated"]; [readings performSelector:@selector(refreshCards)];
    check([readings.accessibilityLabel containsString:@"stale"],"Stale measurements must not appear live");
    nativeOverlayPresent(0,false,nullptr); pump();
    nativeOverlayPresentStatistics("Incoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms\nBitrate: 25 Mbps"); pump();
    check([readings.accessibilityLabel containsString:@"60.00 FPS"] && [button(more,@"touch.stats").title isEqual:@"Stats off"],"Touch Bar telemetry must update while the on-screen Statistics window remains off");
    NSButton* mainStats=((NSPopoverTouchBarItem*)[bar itemForIdentifier:@"touch.info"]).collapsedRepresentation;
    check([mainStats.accessibilityLabel containsString:@"60.00 FPS"],"Live measurements must be visible directly on the main bar");
    NSString* directory=argc>1 ? [NSString stringWithUTF8String:argv[1]] : @"build/touchbar-previews";
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    const char* fixture="Video stream: 2560x1440 60 FPS\nVideo codec: HEVC Main10\nHost processing latency: 1.1/2.0/1.5 ms\nIncoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms\nBitrate: 25 Mbps\nAverage decoding time: 1.2 ms\nAverage frame queue delay: 0.4 ms\nAverage rendering time: 0.8 ms\nFrames dropped by network: 0.00%\nFrames dropped due to jitter: 0.01%\nRendering frame rate: 59.98 FPS"; nativeOverlayPresentStatistics(fixture); pump();
    for (int i=0;i<3;++i) { [readings performSelector:@selector(sample)]; pump(); }
    nativeOverlayPresentStatistics(fixture); pump();
    capture(bar,[directory stringByAppendingPathComponent:@"touchbar-main.png"]);
    capture(bar,[directory stringByAppendingPathComponent:@"touchbar-main-wide.png"],1085);
    capture(audio,[directory stringByAppendingPathComponent:@"touchbar-audio.png"]);
    capture(more,[directory stringByAppendingPathComponent:@"touchbar-more.png"]);
    capture(windowControls,[directory stringByAppendingPathComponent:@"touchbar-window.png"]);
    NSButton* next=[panel valueForKey:@"next"],*previousPage=[panel valueForKey:@"previous"];
    for (int i=0;i<6;++i) {
        check([[readings valueForKey:@"page"] intValue]==i,"Every detailed statistics page must be reachable");
        capture(dashboard,[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"touchbar-info-%d.png",i]]);
        check(readings.frame.size.width>=300 && NSMaxX(readings.frame)<=panel.bounds.size.width,"Measurements must remain visible beside the compact pager");
        [next performClick:nil]; pump();
    }
    check([[readings valueForKey:@"page"] intValue]==0,"Next page wraps through all six pages");
    [previousPage performClick:nil]; check([[readings valueForKey:@"page"] intValue]==5,"Previous page wraps to I/O");
    capture(dashboard,[directory stringByAppendingPathComponent:@"touchbar-info-wide.png"],1085);
    capture(audio,[directory stringByAppendingPathComponent:@"touchbar-audio-wide.png"],1085);
    [next retain];
    NSButton* stale=[button(more,@"touch.record") retain];
    nativeOverlayDetach(); check(window.touchBar==original,"Restore the previous responder bar at handoff/detach");
    [stale performClick:nil]; check(!action(217),"A retained old button must not target a detached or later session");
    check(next.target==nil && next.action==NULL,"Expanded page controls must clear their targets before detach");
    [next release]; [stale release]; [bar release];
    for (int i=0;i<10;++i) { nativeOverlayAttach(window,"next-touchbar"); nativeOverlayDetach(); pump(); check(window.touchBar==original,"Repeated session cleanup restores ownership"); }
    nativeOverlayPresentStatistics("Incoming frame rate: 999 FPS");
    [preferences setBool:NO forKey:@"touchBarLiveStats"]; [preferences synchronize];
    nativeOverlayAttach(window,"legacy-touchbar"); pump();
    check(window.touchBar.defaultItemIdentifiers.count==6,"The original controls layout must remain available");
    NSButton* legacyInfo=((NSPopoverTouchBarItem*)[window.touchBar itemForIdentifier:@"touch.info"]).collapsedRepresentation;
    check(![legacyInfo.accessibilityLabel containsString:@"999"],"Detached telemetry cannot leak into a later session");
    capture(window.touchBar,[directory stringByAppendingPathComponent:@"touchbar-controls-layout.png"]);
    nativeOverlayDetach();
    if (oldLayout) [preferences setObject:oldLayout forKey:@"touchBarLiveStats"]; else [preferences removeObjectForKey:@"touchBarLiveStats"];
    [preferences synchronize]; [oldLayout release];
    SDL_DestroyWindow(stream); SDL_Quit(); fprintf(stderr,"PASS: Touch Bar actions, state, stale data, fit, previews and lifetime\n");
    return 0;
} }
