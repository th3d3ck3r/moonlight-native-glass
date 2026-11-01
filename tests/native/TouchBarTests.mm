#import <AppKit/AppKit.h>
#import <objc/runtime.h>
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
// Keep AppKit presentation mocked in this process: navigation must reuse one
// existing popover, never try to present a nested one on CI's system bar.
static NSUInteger popoverShows=0;
static NSPopoverTouchBarItem* lastShownPopover=nil;
static void fakeShowPopover(id receiver,SEL selector,id sender) { ++popoverShows; lastShownPopover=receiver; }
static void navigate(NSTouchBar* bar,NSString* name) { [button(bar,name) performClick:nil]; pump(); }
static void checkPage(NSTouchBar* bar,NSArray* identifiers,const char* message) {
    check([bar.defaultItemIdentifiers isEqualToArray:identifiers],message);
}
static NSString* cardValue(NSView* dashboard,NSString* label) {
    for (NSArray* entry in [dashboard valueForKey:@"cards"]) if ([entry[0] isEqual:label]) return entry[1];
    return nil;
}
static void checkMetricFrames(NSView* dashboard) {
    NSArray* cards=[dashboard valueForKey:@"cards"];
    NSArray* frames=[dashboard performSelector:@selector(cardFrames)];
    check(frames.count==cards.count,"Every metric must retain a drawable cell after a Control Strip resize");
    CGFloat previous=-1;
    for (NSValue* value in frames) {
        NSRect cell=value.rectValue;
        check(NSContainsRect(dashboard.bounds,cell) && cell.size.width>=50 && cell.size.height==30,
              "Metric cells must remain readable and completely inside their actual allocation");
        check(NSMinX(cell)>=previous,"Control Strip compression must not overlap neighboring measurements");
        previous=NSMaxX(cell);
    }
}
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
    BOOL expandedPage=[bar.defaultItemIdentifiers containsObject:@"touch.detail"] || [bar.defaultItemIdentifiers containsObject:@"touch.mute"] || [bar.defaultItemIdentifiers containsObject:@"touch.stats"] || [bar.defaultItemIdentifiers containsObject:@"touch.back"];
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
// The native layout adapter is exercised independently of the Metal renderer.
// Register its production runtime boundary only after the legacy/fallback tests;
// this process must not load or present a real private Touch Bar window on CI.
static char surfaceActiveKey,surfaceStateKey;
static void fakeSurfaceActive(id receiver,SEL selector,BOOL active) { objc_setAssociatedObject(receiver,&surfaceActiveKey,@(active),OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static void fakeSurfaceState(id receiver,SEL selector,NSInteger state) { objc_setAssociatedObject(receiver,&surfaceStateKey,@(state),OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static NSButton* surfaceButton(NSTouchBar* bar,NSString* name) {
    NSTouchBarItem* item=[bar itemForIdentifier:name];
    return [item isKindOfClass:NSPopoverTouchBarItem.class] ? (NSButton*)[(NSPopoverTouchBarItem*)item collapsedRepresentation] : (NSButton*)[(NSCustomTouchBarItem*)item view];
}
static void checkSurfacePage(NSView* surface,NSArray* identifiers,const char* message) { check([[surface valueForKey:@"identifiers"] isEqualToArray:identifiers],message); }
static void captureSurface(NSView* surface,NSString* path,CGFloat width) {
    NSView* root=[[[NSView alloc] initWithFrame:NSMakeRect(0,0,width,30)] autorelease];
    [root addSubview:surface]; surface.translatesAutoresizingMaskIntoConstraints=NO;
    NSArray* allocation=@[[surface.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [surface.topAnchor constraintEqualToAnchor:root.topAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:root.bottomAnchor]];
    [NSLayoutConstraint activateConstraints:allocation]; [root layoutSubtreeIfNeeded];
    surface.needsLayout=YES; [surface layoutSubtreeIfNeeded];
    NSView* artwork=[surface valueForKey:@"artwork"]; NSScrollView* scroll=[surface valueForKey:@"scroll"];
    fprintf(stderr,"SURFACE %s root=%s frame=%s bounds=%s visible=%s art=%s scroll=%s\n",path.lastPathComponent.UTF8String,
        NSStringFromRect(root.bounds).UTF8String,NSStringFromRect(surface.frame).UTF8String,NSStringFromRect(surface.bounds).UTF8String,
        NSStringFromRect(surface.visibleRect).UTF8String,NSStringFromRect(artwork.frame).UTF8String,NSStringFromRect(scroll.frame).UTF8String);
    check(NSEqualRects(artwork.frame,root.bounds) && NSContainsRect(root.bounds,scroll.frame),"Artwork must fill and the native scroll viewport must fit the actual allocation");
    for (NSView* control in [surface valueForKey:@"controls"]) {
        check(control.bounds.size.width>=30 && control.bounds.size.height==30,"Animated surface preserves comfortable controls");
        if ([control isKindOfClass:NSClassFromString(@"MLTouchStatsButton")] || [control isKindOfClass:NSClassFromString(@"MLTouchInfoPanel")])
            checkMetricFrames([control valueForKey:@"dashboard"]);
    }
    NSBitmapImageRep* image=[root bitmapImageRepForCachingDisplayInRect:root.bounds]; [root cacheDisplayInRect:root.bounds toBitmapImageRep:image];
    check([[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES],"Export actual native animated surface control composition");
    [NSLayoutConstraint deactivateConstraints:allocation]; [surface removeFromSuperview];
}
// Negotiate space through real Auto Layout instead of assigning a width to the
// surface. A second arranged view represents the space owned by the Control
// Strip; hiding/showing/resizing it must transfer the available app area.
static void exerciseFlexibleSurface(NSView* surface) {
    check(surface.intrinsicContentSize.width==NSViewNoIntrinsicMetric && surface.intrinsicContentSize.height==30,
          "The single native Touch Bar item must advertise a flexible width, not a centered content-sized width");
    for (NSLayoutConstraint* constraint in surface.constraints)
        check(!(constraint.firstAttribute==NSLayoutAttributeWidth && constraint.relation==NSLayoutRelationEqual && !constraint.secondItem),
              "A full-bar item must not impose a fixed physical width beside the Control Strip");
    NSStackView* host=[[[NSStackView alloc] initWithFrame:NSMakeRect(0,0,1085,30)] autorelease];
    host.orientation=NSUserInterfaceLayoutOrientationHorizontal; host.spacing=0;
    host.alignment=NSLayoutAttributeCenterY; host.distribution=NSStackViewDistributionFill; host.detachesHiddenViews=YES;
    [host.widthAnchor constraintEqualToConstant:1085].active=YES;
    [host.heightAnchor constraintEqualToConstant:30].active=YES;
    NSView* systemStrip=[[[NSView alloc] initWithFrame:NSMakeRect(0,0,260,30)] autorelease];
    systemStrip.translatesAutoresizingMaskIntoConstraints=NO;
    NSLayoutConstraint* stripWidth=[systemStrip.widthAnchor constraintEqualToConstant:260]; stripWidth.active=YES;
    [systemStrip.heightAnchor constraintEqualToConstant:30].active=YES;
    [systemStrip setContentHuggingPriority:1000 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [systemStrip setContentCompressionResistancePriority:1000 forOrientation:NSLayoutConstraintOrientationHorizontal];
    surface.translatesAutoresizingMaskIntoConstraints=NO;
    [host addArrangedSubview:surface]; [host addArrangedSubview:systemStrip];
    struct Allocation { CGFloat strip; BOOL hidden; } allocations[]={{260,NO},{260,YES},{400,NO},{285,NO},{465,NO},{685,NO},{260,YES}};
    for (const auto& allocation:allocations) {
        stripWidth.constant=allocation.strip; systemStrip.hidden=allocation.hidden;
        host.needsLayout=YES; [host layoutSubtreeIfNeeded]; surface.needsLayout=YES; [surface layoutSubtreeIfNeeded];
        CGFloat available=1085-(allocation.hidden ? 0 : allocation.strip);
        fprintf(stderr,"NEGOTIATED SURFACE strip=%.0f hidden=%d expected=%.0f actual=%s\n",allocation.strip,allocation.hidden,available,NSStringFromRect(surface.frame).UTF8String);
        check(fabs(surface.frame.size.width-available)<.5 && surface.frame.size.height==30,
              "The native item must fill all available space as the Control Strip changes, including full width");
        NSView* artwork=[surface valueForKey:@"artwork"];
        check(fabs(artwork.frame.size.width-available)<.5,"The animation must follow the negotiated app area rather than the controls' natural width");
        for (NSView* control in [surface valueForKey:@"controls"])
            if ([control isKindOfClass:NSClassFromString(@"MLTouchStatsButton")]) checkMetricFrames([control valueForKey:@"dashboard"]);
    }
    [host removeArrangedSubview:surface]; [surface removeFromSuperview];
}
int main(int argc,char** argv) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp finishLaunching]; NSApp.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    Method showPopover=class_getInstanceMethod(NSPopoverTouchBarItem.class,@selector(showPopover:));
    check(showPopover!=nullptr,"Resolve native popover presentation for the test spy");
    IMP originalShowPopover=method_setImplementation(showPopover,(IMP)fakeShowPopover);
    SDL_SetMainReady(); check(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_GAMECONTROLLER)==0,"SDL init");
    SDL_Window* stream=SDL_CreateWindow("Touch Bar fixture",80,100,960,540,SDL_WINDOW_SHOWN|SDL_WINDOW_RESIZABLE);
    check(stream!=nullptr,"Stream fixture"); SDL_SysWMinfo info; SDL_VERSION(&info.version); check(SDL_GetWindowWMInfo(stream,&info),"Cocoa window");
    NSWindow* window=info.info.cocoa.window;
    NSUserDefaults* preferences=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    id oldLayout=[[preferences objectForKey:@"touchBarLiveStats"] retain];
    id oldVolume=[[preferences objectForKey:@"playbackVolume"] retain];
    [preferences setBool:YES forKey:@"touchBarLiveStats"]; [preferences synchronize];
    NSTouchBar* original=[[[NSTouchBar alloc] init] autorelease]; window.touchBar=original;
    nativeOverlayAttach(window,"touchbar-fixture"); pump(); NSTouchBar* bar=[window.touchBar retain];
    check(bar && bar!=original && bar.defaultItemIdentifiers.count==3,"Live stats, capture and controls must occupy the main Touch Bar");
    NSTouchBar* dashboard=expanded(bar,@"touch.info"); NSTouchBar* more=expanded(bar,@"touch.more");
    NSPopoverTouchBarItem* controlsPopover=(NSPopoverTouchBarItem*)[bar itemForIdentifier:@"touch.more"];
    NSArray* controlsItems=@[@"touch.audio",@"touch.record",@"touch.replay",@"touch.stats",@"touch.window",@"touch.disconnect"];
    NSArray* audioItems=@[@"touch.back",@"touch.mute",@"touch.volume",@"touch.volumeLabel"];
    NSArray* windowItems=@[@"touch.back",@"touch.hardware",@"touch.fullscreen",@"touch.controls",@"touch.hide"];
    check([[more itemForIdentifier:@"touch.audio"] isKindOfClass:NSCustomTouchBarItem.class] &&
          [[more itemForIdentifier:@"touch.window"] isKindOfClass:NSCustomTouchBarItem.class],
          "Audio and Window inside Controls must be navigation buttons, not nested popovers");
    checkPage(more,controlsItems,"Controls starts on its root page");
    navigate(more,@"touch.audio");
    NSTouchBar* audio=more; NSTouchBar* windowControls=more;
    check(controlsPopover.popoverTouchBar==more && window.touchBar==bar && popoverShows==0,
          "Opening Audio must keep the existing Controls popover and owning root bar");
    checkPage(audio,audioItems,"Volume must remain on an explicit Audio page with Back");
    NSTextField* volumeText=(NSTextField*)((NSCustomTouchBarItem*)[audio itemForIdentifier:@"touch.volumeLabel"]).view;
    check([volumeText isKindOfClass:NSTextField.class] && [volumeText.textColor isEqual:NSColor.whiteColor],"Volume percentage must remain a readable, static readout");
    check(dashboard && audio && more,"Status, audio and secondary controls must remain available");
    navigate(audio,@"touch.back"); checkPage(more,controlsItems,"Audio Back returns to Controls without replacing its bar");
    navigate(more,@"touch.window"); checkPage(windowControls,windowItems,"Window actions use the same explicit navigation panel");
    check(controlsPopover.popoverTouchBar==more && popoverShows==0,"Navigation must never invoke a nested showPopover call");
    navigate(windowControls,@"touch.back"); checkPage(more,controlsItems,"Window Back returns to Controls");
    for (NSString* name in @[@"touch.info",@"touch.more"]) check(((NSPopoverTouchBarItem*)[bar itemForIdentifier:name]).showsCloseButton,"Expanded pages need a clear Back control");
    nativeTitlebarSetCapture(true); nativeTitlebarSetConnection(NativeConnectionState::Connected);
    nativeTitlebarSetRecording(false,false,false,false,false,false,0,"Recording disabled"); pump();
    check(!button(more,@"touch.record").enabled && !button(more,@"touch.replay").enabled,"Disabled recording must not trigger recorder actions");
    [button(more,@"touch.replay") performClick:nil]; check(!action(219),"Disabled replay must not enqueue an action");
    SDL_bool relative=SDL_GetRelativeMouseMode();
    [button(bar,@"touch.capture") performClick:nil]; check(action(202),"Release uses the explicit UI command independent of its keyboard shortcut");
    navigate(more,@"touch.window");
    [button(windowControls,@"touch.fullscreen") performClick:nil]; check(action(221),"Fullscreen queues the explicit native UI route");
    navigate(windowControls,@"touch.back");
    [button(more,@"touch.stats") performClick:nil]; check(action(203),"Statistics off-to-on uses the explicit UI command");
    navigate(more,@"touch.audio");
    [button(audio,@"touch.mute") performClick:nil]; check(action(207),"Mute action routing");
    navigate(audio,@"touch.back");
    nativeTitlebarSetCapture(false); pump();
    [button(bar,@"touch.capture") performClick:nil]; check(action(201),"Capture-on uses the explicit UI command");
    nativeTitlebarSetCapture(true); nativeTitlebarSetStatistics(true); pump();
    [button(more,@"touch.stats") performClick:nil]; check(action(208),"Statistics on-to-off uses the explicit UI command");
    nativeTitlebarSetStatistics(false); pump();
    navigate(more,@"touch.window");
    [button(windowControls,@"touch.controls") performClick:nil]; check(action(100),"Stream controls use the recognized explicit UI route");
    [button(windowControls,@"touch.hide") performClick:nil]; check(action(200),"Hide uses the explicit stream-window action");
    navigate(windowControls,@"touch.back");
    [button(more,@"touch.disconnect") performClick:nil]; check(action(12),"Disconnect uses the existing stream action");
    navigate(more,@"touch.audio");
    NSSliderTouchBarItem* slider=(NSSliderTouchBarItem*)[audio itemForIdentifier:@"touch.volume"];
    check(slider.slider.continuous && slider.slider.trackFillColor!=nil,
          "Volume keeps the continuous Crimson Glass slider");
    for (NSNumber* value in @[@.37,@.62,@.16]) {
        slider.slider.doubleValue=value.doubleValue; [(id)slider.target performSelector:slider.action withObject:slider]; pump();
        NSString* expected=[NSString stringWithFormat:@"%.0f%%",value.doubleValue*100];
        check([volumeText.stringValue isEqual:expected],"Continuous volume changes update the real playback readout");
        nativeTitlebarSetCapture(false); nativeTitlebarSetStatistics(false);
        nativeTitlebarSetRecording(true,true,true,true,false,false,65,"Recording while adjusting volume");
        nativeOverlayPresentStatistics("Incoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms\nBitrate: 25 Mbps"); pump();
        id owner=bar.delegate; [owner performSelector:@selector(touchTick:) withObject:nil]; pump();
        checkPage(audio,audioItems,"Timer and stream state refreshes must not return Audio to the home page");
        check(controlsPopover.popoverTouchBar==audio && [audio itemForIdentifier:@"touch.volume"]==slider && window.touchBar==bar,
              "Volume adjustment must keep the same slider, panel and responder ownership");
        check([volumeText.stringValue isEqual:expected],"A refresh must not reset the chosen volume");
        [button(audio,@"touch.mute") performClick:nil]; check(action(207),"Mute stays reachable while adjusting volume");
    }
    slider.slider.doubleValue=1; [(id)slider.target performSelector:slider.action withObject:slider]; pump();
    checkPage(audio,audioItems,"Completing slider adjustment must leave Audio open until Back or close");
    // Reopening Controls deliberately starts at its root; ordinary refreshes do
    // not. The spy verifies this uses its original popover, not a new presenter.
    [(NSButton*)controlsPopover.collapsedRepresentation performClick:nil]; pump();
    check(popoverShows==1 && lastShownPopover==controlsPopover && controlsPopover.popoverTouchBar==more,
          "Reopening Controls must present its original popover exactly once");
    checkPage(more,controlsItems,"Reopening Controls resets its page deliberately");
    navigate(more,@"touch.window");
    [button(windowControls,@"touch.hardware") performClick:nil]; pump();
    check([button(windowControls,@"touch.hardware").title isEqual:@"Hide Mac"],"Hardware monitor action opens the local monitor");
    [button(windowControls,@"touch.hardware") performClick:nil]; pump();
    check([button(windowControls,@"touch.hardware").title isEqual:@"Monitor"],"Hardware monitor action closes the local monitor");
    navigate(windowControls,@"touch.back");
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
    NSButton* mainStats=((NSPopoverTouchBarItem*)[bar itemForIdentifier:@"touch.info"]).collapsedRepresentation;
    NSView* inlineReadings=[mainStats valueForKey:@"dashboard"];
    nativeOverlayPresentStatistics("Incoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms (variance: 1 ms)\nBitrate: 25 Mbps"); pump();
    check([cardValue(inlineReadings,@"NETWORK RTT") isEqual:@"4 ms"],
          "The compact live bar must use a deliberate short RTT value rather than a truncated variance suffix");
    check([inlineReadings.accessibilityLabel containsString:@"4 ms (variance: 1 ms)"] &&
          [cardValue(readings,@"NETWORK RTT") isEqual:@"4 ms (variance: 1 ms)"],
          "The full latency and variance must remain available in accessibility and detailed measurements");
    for (NSView* view in @[readings,inlineReadings]) {
        [view setValue:@(NSProcessInfo.processInfo.systemUptime-5) forKey:@"streamUpdated"];
        [view performSelector:@selector(refreshCards)];
        check([view.accessibilityLabel containsString:@"Stale"] && ![view.accessibilityLabel containsString:@"60.00 FPS"],
              "An expired snapshot must replace its measurements with Stale, not leave old values visible");
        [view setValue:@"" forKey:@"streamText"]; [view performSelector:@selector(refreshCards)];
        check([view.accessibilityLabel containsString:@"Waiting for data"] && ![view.accessibilityLabel containsString:@"Stale"],
              "No snapshot must say Waiting for data rather than claim a stale sample");
    }
    nativeOverlayPresent(0,false,nullptr); pump();
    // Fresh snapshots may omit a field (old build bitrate flag, unsupported
    // host latency). Missing and expired data are distinct states.
    nativeOverlayPresentStatistics("Video stream: 2560x1440 60.00 FPS (Codec: HEVC 10-bit HDR)\nIncoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms"); pump();
    check([cardValue(readings,@"BITRATE") isEqual:@"Not reported"] && [cardValue(inlineReadings,@"BITRATE") isEqual:@"Not reported"],
          "A fresh snapshot lacking bitrate must say Not reported in both dashboards, never stale");
    [readings setValue:@1 forKey:@"page"]; [readings performSelector:@selector(refreshCards)];
    check([cardValue(readings,@"CODEC") isEqual:@"HEVC 10-bit HDR"],
          "Video codec must parse the actual formatter's embedded Codec field without a standalone codec row");
    check([cardValue(readings,@"HOST LATENCY") isEqual:@"Not reported"],
          "Hosts without latency telemetry must not be mistaken for a stale stream");
    [readings setValue:@0 forKey:@"page"]; [readings performSelector:@selector(refreshCards)];
    const char* actualSnapshot="Video stream: 2560x1440 60.00 FPS (Codec: HEVC 10-bit HDR)\nBitrate: 25.1 Mbps, Peak (5s): 26.4\nIncoming frame rate from network: 60.00 FPS\nDecoding frame rate: 60.00 FPS\nRendering frame rate: 59.98 FPS\nAverage network latency: 4 ms";
    nativeOverlayPresentStatistics(actualSnapshot); pump();
    check([readings.accessibilityLabel containsString:@"60.00 FPS"] && [button(more,@"touch.stats").title isEqual:@"Stats off"],"Touch Bar telemetry must update while the on-screen Statistics window remains off");
    check([mainStats.accessibilityLabel containsString:@"60.00 FPS"] && [cardValue(inlineReadings,@"BITRATE") isEqual:@"25.1 Mbps"] && [cardValue(readings,@"BITRATE") containsString:@"25.1 Mbps"],
          "Live and detailed bitrate must use the actual formatter while the on-screen overlay is off");
    const char* changedSnapshot="Video stream: 1920x1080 59.94 FPS (Codec: H.264)\nBitrate: 18.7 Mbps, Peak (5s): 20.2\nIncoming frame rate from network: 59.94 FPS\nAverage network latency: 6 ms";
    nativeOverlayPresentStatistics(changedSnapshot); pump();
    check([cardValue(inlineReadings,@"BITRATE") isEqual:@"18.7 Mbps"] && [cardValue(readings,@"BITRATE") containsString:@"18.7 Mbps"] &&
          [mainStats.accessibilityLabel containsString:@"59.94 FPS"] && ![mainStats.accessibilityLabel containsString:@"25.1 Mbps"],
          "A new snapshot must replace bitrate and frame rate in both dashboards, not revive cached values");
    [readings setValue:@1 forKey:@"page"]; [readings performSelector:@selector(refreshCards)];
    check([cardValue(readings,@"CODEC") isEqual:@"H.264"] && ![readings.accessibilityLabel containsString:@"HEVC 10-bit HDR"],
          "Changing streams must replace the displayed codec as soon as fresh statistics arrive");
    nativeOverlayPresentStatistics("Video stream: 2560x1440 60.00 FPS\nVideo codec: HEVC Main10\nBitrate: 25 Mbps\nIncoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms"); pump();
    check([cardValue(readings,@"CODEC") isEqual:@"HEVC Main10"],"Standalone Video codec rows remain compatible");
    [readings setValue:@0 forKey:@"page"]; [readings performSelector:@selector(refreshCards)];
    nativeTitlebarSetConnection(NativeConnectionState::Poor); pump();
    check([mainStats.accessibilityLabel containsString:@"poor connection"],"Live stats must preserve the original connection warning");
    NSArray* liveCards=[[mainStats valueForKey:@"dashboard"] valueForKey:@"cards"];
    check([liveCards[0][0] containsString:@"Poor link"],"Connection warnings remain visible on the main live bar");
    nativeTitlebarSetConnection(NativeConnectionState::Connected); pump();
    NSString* directory=argc>1 ? [NSString stringWithUTF8String:argv[1]] : @"build/touchbar-previews";
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    const char* fixture="Video stream: 2560x1440 60 FPS\nVideo codec: HEVC Main10\nHost processing latency: 1.1/2.0/1.5 ms\nIncoming frame rate from network: 60.00 FPS\nAverage network latency: 4 ms\nBitrate: 25 Mbps\nAverage decoding time: 1.2 ms\nAverage frame queue delay: 0.4 ms\nAverage rendering time: 0.8 ms\nFrames dropped by network: 0.00%\nFrames dropped due to jitter: 0.01%\nRendering frame rate: 59.98 FPS"; nativeOverlayPresentStatistics(fixture); pump();
    for (int i=0;i<3;++i) { [readings performSelector:@selector(sample)]; pump(); }
    nativeOverlayPresentStatistics(fixture); pump();
    capture(bar,[directory stringByAppendingPathComponent:@"touchbar-main.png"]);
    capture(bar,[directory stringByAppendingPathComponent:@"touchbar-main-wide.png"],1085);
    navigate(more,@"touch.audio");
    capture(audio,[directory stringByAppendingPathComponent:@"touchbar-audio.png"]);
    navigate(audio,@"touch.back");
    capture(more,[directory stringByAppendingPathComponent:@"touchbar-more.png"]);
    navigate(more,@"touch.window");
    capture(windowControls,[directory stringByAppendingPathComponent:@"touchbar-window.png"]);
    navigate(windowControls,@"touch.back");
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
    navigate(more,@"touch.audio");
    capture(audio,[directory stringByAppendingPathComponent:@"touchbar-audio-wide.png"],1085);
    navigate(audio,@"touch.back");
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
    NSTouchBar* legacyAudio=expanded(window.touchBar,@"touch.audio");
    check(legacyAudio && [legacyAudio.defaultItemIdentifiers containsObject:@"touch.volume"],
          "Original layout retains its direct, single-level Audio popover");
    capture(legacyAudio,[directory stringByAppendingPathComponent:@"touchbar-audio-controls-layout.png"]);
    nativeOverlayDetach();
    Class bridge=objc_allocateClassPair(NSView.class,"MLTouchBarAnimationBridge",0);
    check(bridge!=Nil,"Create isolated animation bridge boundary");
    class_addMethod(bridge,NSSelectorFromString(@"setPresentationActive:"),(IMP)fakeSurfaceActive,"v@:B");
    class_addMethod(bridge,NSSelectorFromString(@"showConnectionState:"),(IMP)fakeSurfaceState,"v@:q");
    objc_registerClassPair(bridge);
    [preferences setBool:YES forKey:@"touchBarLiveStats"]; [preferences synchronize];
    nativeOverlayAttach(window,"animated-touchbar"); pump();
    NSTouchBar* animated=[window.touchBar retain];
    check([animated.defaultItemIdentifiers isEqualToArray:@[@"touch.surface"]],"Loaded renderer uses one native surface rather than competing Touch Bar items");
    NSView* surface=[((NSCustomTouchBarItem*)[animated itemForIdentifier:@"touch.surface"]).view retain];
    NSArray* homeItems=@[@"touch.capture",@"touch.info",@"touch.more"];
    NSArray* surfaceControls=@[@"touch.home",@"touch.audio",@"touch.record",@"touch.replay",@"touch.stats",@"touch.window",@"touch.disconnect"];
    checkSurfacePage(surface,homeItems,"Animated surface starts with persistent live metrics and essential controls");
    nativeOverlayPresentStatistics(fixture); nativeTitlebarSetConnection(NativeConnectionState::Connected); pump();
    exerciseFlexibleSurface(surface);
    for (NSNumber* width in @[@620,@800])
        captureSurface(surface,[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"touchbar-surface-strip-%.0f.png",width.doubleValue]],width.doubleValue);
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-main.png"],685);
    NSView* moon=[surface valueForKey:@"moonTarget"];
    check(moon.frame.size.width==96 && fabs(NSMidX(moon.frame)-342.5)<.1,"Main layout keeps a centered clear moon target between metrics");
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-main-wide.png"],1085);
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-main-narrow.png"],400);
    NSScrollView* surfaceScroll=[surface valueForKey:@"scroll"]; NSView* surfaceDocument=[surface valueForKey:@"document"];
    NSButton* narrowCapture=surfaceButton(animated,@"touch.capture"),*narrowControls=surfaceButton(animated,@"touch.more");
    check(narrowCapture.superview==surface && narrowControls.superview==surface &&
          fabs(narrowCapture.frame.origin.x)<.1 && fabs(NSMaxX(narrowControls.frame)-400)<.1,
          "Narrow main bar must keep Capture and Controls pinned and fully visible");
    check(NSMinX(surfaceScroll.frame)>=NSMaxX(narrowCapture.frame) && NSMaxX(surfaceScroll.frame)<=NSMinX(narrowControls.frame),
          "Live measurements scroll between the essential controls without covering them");
    check([[[surfaceButton(animated,@"touch.info") valueForKey:@"dashboard"] valueForKey:@"moonCenter"] doubleValue]<0,
          "Narrow measurements must clear the previous wide dashboard offset");
    check(surfaceDocument.frame.size.width>=350 && surfaceScroll.contentView.bounds.origin.x==0,
          "Narrow main starts with incoming FPS; RTT and bitrate remain reachable by scrolling");
    NSPoint gapInSurface=NSZeroPoint;
    [surfaceScroll.contentView scrollToPoint:NSMakePoint(10,0)];
    surface.needsLayout=YES; [surface layoutSubtreeIfNeeded];
    check(fabs(surfaceScroll.contentView.bounds.origin.x-10)<.1,"Ordinary relayout must preserve the user's scroll position");
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-main-reset.png"],685);
    check(fabs(surfaceScroll.contentView.bounds.origin.x)<.1,"Resizing to the compact physical width recenters the initial layout");
    [surfaceButton(animated,@"touch.more") performClick:nil]; pump();
    checkSurfacePage(surface,surfaceControls,"Controls changes the existing surface without presenting a popover");
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-controls-narrow.png"],400);
    gapInSurface=[surface convertPoint:NSMakePoint(surfaceDocument.frame.size.width/2,15) fromView:surfaceDocument];
    check(fabs(gapInSurface.x-200)<.1,"Opening a narrow Controls page centers its gap on the visible moon");
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-controls.png"],685);
    gapInSurface=[surface convertPoint:NSMakePoint(surfaceDocument.frame.size.width/2,15) fromView:surfaceDocument];
    check(fabs(gapInSurface.x-342.5)<.1,"Compact Controls keeps its moon gap centered after resizing");
    check(window.touchBar==animated && popoverShows==1,"Animated navigation preserves ownership and never calls showPopover");
    [surfaceButton(animated,@"touch.audio") performClick:nil]; pump();
    checkSurfacePage(surface,audioItems,"Animated Audio page has the continuous volume slider and explicit Back");
    NSSliderTouchBarItem* animatedSlider=(NSSliderTouchBarItem*)[animated itemForIdentifier:@"touch.volume"];
    check(animatedSlider.slider.continuous,"Animated layout retains continuous native volume adjustment");
    for (NSNumber* value in @[@.24,@.68,@.31]) {
        animatedSlider.slider.doubleValue=value.doubleValue; [(id)animatedSlider.target performSelector:animatedSlider.action withObject:animatedSlider];
        nativeOverlayPresentStatistics(fixture); nativeTitlebarSetRecording(true,true,true,true,false,false,37,"Recording");
        [animated.delegate performSelector:@selector(touchTick:) withObject:nil]; pump();
        checkSurfacePage(surface,audioItems,"Telemetry and recording updates must not dismiss the animated volume page");
        check([animated itemForIdentifier:@"touch.volume"]==animatedSlider,"Animated Audio refresh retains the actual slider instance");
    }
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-audio.png"],685);
    [surfaceButton(animated,@"touch.back") performClick:nil]; [surfaceButton(animated,@"touch.window") performClick:nil]; pump();
    checkSurfacePage(surface,windowItems,"Animated Window page retains every window action");
    [surfaceButton(animated,@"touch.fullscreen") performClick:nil]; check(action(221),"Animated fullscreen preserves the native SDL action route");
    [surfaceButton(animated,@"touch.back") performClick:nil]; [surfaceButton(animated,@"touch.home") performClick:nil];
    [surfaceButton(animated,@"touch.info") performClick:nil]; pump();
    checkSurfacePage(surface,@[@"touch.home",@"touch.detail"],"Detailed statistics share the same animated surface");
    NSView* surfacePanel=((NSCustomTouchBarItem*)[animated itemForIdentifier:@"touch.detail"]).view;
    NSView* surfaceReadings=[surfacePanel valueForKey:@"dashboard"];
    NSButton* surfaceNext=[surfacePanel valueForKey:@"next"];
    for (int page=0;page<6;++page) {
        check([[surfaceReadings valueForKey:@"page"] intValue]==page,"All six animated statistics pages remain reachable");
        [surfaceNext performClick:nil];
    }
    captureSurface(surface,[directory stringByAppendingPathComponent:@"touchbar-surface-details.png"],685);
    NSUserDefaults* frontend=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass"] autorelease];
    id oldFullWidth=[[frontend objectForKey:@"touchBarFullWidth"] retain];
    [animated.delegate performSelector:@selector(touchRestoreControlStrip:) withObject:nil];
    check(![frontend boolForKey:@"touchBarFullWidth"],"Moon restore changes only the per-app full-width setting");
    if (oldFullWidth) [frontend setObject:oldFullWidth forKey:@"touchBarFullWidth"]; else [frontend removeObjectForKey:@"touchBarFullWidth"];
    [oldFullWidth release]; [frontend synchronize];
    nativeOverlayDetach();
    check(window.touchBar==original && [surface valueForKey:@"owner"]==nil,"Animated detach restores responder ownership and clears retained surface targets");
    check(![objc_getAssociatedObject([surface valueForKey:@"artwork"],&surfaceActiveKey) boolValue],"Animated renderer is stopped on detach");
    [surface release]; [animated release];
    if (oldLayout) [preferences setObject:oldLayout forKey:@"touchBarLiveStats"]; else [preferences removeObjectForKey:@"touchBarLiveStats"];
    if (oldVolume) [preferences setObject:oldVolume forKey:@"playbackVolume"]; else [preferences removeObjectForKey:@"playbackVolume"];
    [oldVolume release];
    [preferences synchronize]; [oldLayout release];
    method_setImplementation(showPopover,originalShowPopover);
    SDL_DestroyWindow(stream); SDL_Quit(); fprintf(stderr,"PASS: Touch Bar actions, Audio navigation/continuous volume stability, state, stale data, fit, previews and lifetime\n");
    return 0;
} }
