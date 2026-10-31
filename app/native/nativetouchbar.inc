// Compiled with nativetitlebar.mm. Touch Bar actions use the existing SDL queue;
// no decoder, frame-pacing, mouse tracking or recorder ownership lives here.
#include "nativestreamstats.h"

static NSColor* touchAccent() {
    return crimsonEnabled() ? [NSColor colorWithSRGBRed:.95 green:.19 blue:.32 alpha:1] : NSColor.controlAccentColor;
}
static NSImage* touchSymbol(NSString* name) {
    NSImage* image=[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    return [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightMedium]];
}
static NSButton* touchButton(NSString* title,NSString* symbol,id target,SEL action,CGFloat width) {
    NSButton* button=[NSButton buttonWithTitle:title target:target action:action];
    button.image=touchSymbol(symbol); button.imagePosition=NSImageLeft;
    button.font=[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
    button.bezelColor=[NSColor colorWithSRGBRed:.12 green:.035 blue:.055 alpha:1];
    button.contentTintColor=touchAccent(); button.lineBreakMode=NSLineBreakByTruncatingTail;
    [button.widthAnchor constraintEqualToConstant:width].active=YES;
    return button;
}

@interface MLTouchDashboard : NSView {
    MLHardwareReading previous;
    double previousTime;
    BOOL havePrevious,busy;
    std::array<std::vector<double>,3> samples;
}
@property(nonatomic,assign) BOOL active;
@property(nonatomic,assign) NSInteger page;
@property(nonatomic,copy) NSArray* cards;
@property(nonatomic,copy) NSString* streamText;
@property(nonatomic,copy) NSString* devicesText;
@property(nonatomic,assign) double streamUpdated;
@property(nonatomic,assign) double cpu;
@property(nonatomic,assign) double ram;
@property(nonatomic,assign) double gpu;
@property(nonatomic,assign) double rx;
@property(nonatomic,assign) double tx;
- (void)sample;
- (void)refreshCards;
@end
@implementation MLTouchDashboard
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.active=YES; self.cpu=self.ram=self.gpu=self.rx=self.tx=-1;
        self.identifier=@"TouchDashboard"; self.streamText=@""; self.devicesText=@"No controller connected";
        [self.widthAnchor constraintEqualToConstant:370].active=YES;
        [self.heightAnchor constraintEqualToConstant:30].active=YES;
        [self refreshCards];
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (NSString*)metric:(NSString*)prefix fallback:(NSString*)fallback {
    // Never present a sample as current once the source stops updating.
    if (NSProcessInfo.processInfo.systemUptime-self.streamUpdated>4) return fallback;
    for (const auto& row:NativeStreamStats::parse(self.streamText.UTF8String ?: ""))
        if ([ [NSString stringWithUTF8String:row.label.c_str()] hasPrefix:prefix])
            return [NSString stringWithUTF8String:row.value.c_str()];
    return fallback;
}
- (void)refreshCards {
    NSString* missing=self.streamText.length ? @"Unavailable / stale" : @"Enable Statistics";
    switch (self.page) {
        case 0: self.cards=@[@[@"INCOMING FPS",[self metric:@"Incoming frame rate" fallback:missing]],
                            @[@"NETWORK RTT",[self metric:@"Average network latency" fallback:missing]],
                            @[@"BITRATE",[self metric:@"Bitrate" fallback:missing]]]; break;
        case 1: self.cards=@[@[@"DECODE",[self metric:@"Average decoding time" fallback:missing]],
                            @[@"NETWORK DROPS",[self metric:@"Frames dropped by" fallback:missing]],
                            @[@"RENDER FPS",[self metric:@"Rendering frame rate" fallback:missing]]]; break;
        case 2: self.cards=@[@[@"LOCAL CPU",self.cpu<0 ? @"Sampling…" : [NSString stringWithFormat:@"%.0f%%",self.cpu]],
                            @[@"LOCAL RAM",self.ram<0 ? @"Unavailable" : [NSString stringWithFormat:@"%.1f / %.0f GB",self.ram/100.*NSProcessInfo.processInfo.physicalMemory/1073741824.,NSProcessInfo.processInfo.physicalMemory/1073741824.]],
                            @[@"LOCAL GPU",self.gpu<0 ? @"Unavailable" : [NSString stringWithFormat:@"%.0f%%",self.gpu]]]; break;
        default: {
            NSArray* thermal=@[@"Normal",@"Warm",@"High",@"Critical"];
            self.cards=@[@[@"LOCAL NETWORK",self.rx<0 ? @"Sampling…" : [NSString stringWithFormat:@"↓%.1f ↑%.1f MB/s",self.rx,self.tx]],
                         @[@"THERMAL",thermal[MIN(3,MAX(0,(NSInteger)NSProcessInfo.processInfo.thermalState))]],
                         @[@"CONTROLLERS",self.devicesText ?: @"None"]]; break;
        }
    }
    NSMutableArray* spoken=[NSMutableArray array];
    for (NSArray* card in self.cards) [spoken addObject:[card componentsJoinedByString:@": "]];
    [self setAccessibilityLabel:[spoken componentsJoinedByString:@"; "]];
    self.needsDisplay=YES;
}
- (void)sample {
    if (!self.active || busy) return;
    busy=YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        MLHardwareReading current=readLocalHardware();
        double now=NSProcessInfo.processInfo.systemUptime;
        dispatch_async(dispatch_get_main_queue(), ^{
            busy=NO; if (!self.active) return;
            double elapsed=now-previousTime;
            self.cpu=self.rx=self.tx=-1;
            if (havePrevious && elapsed>0) {
                if (current.cpuValid && previous.cpuValid && current.cpuTotal>previous.cpuTotal && current.cpuBusy>=previous.cpuBusy)
                    self.cpu=MIN(100.,100.*double(current.cpuBusy-previous.cpuBusy)/double(current.cpuTotal-previous.cpuTotal));
                if (current.networkValid && previous.networkValid && current.received>=previous.received && current.sent>=previous.sent) {
                    self.rx=(current.received-previous.received)/elapsed/1000000.; self.tx=(current.sent-previous.sent)/elapsed/1000000.;
                }
            }
            previous=current; previousTime=now; havePrevious=YES;
            self.ram=current.memory<0 ? -1 : current.memory/double(NSProcessInfo.processInfo.physicalMemory)*100.; self.gpu=current.gpu;
            double values[]={self.cpu,self.ram,self.gpu};
            for (int i=0;i<3;++i) { samples[i].push_back(values[i]); if (samples[i].size()>60) samples[i].erase(samples[i].begin()); }
            [self refreshCards];
        });
    });
}
- (void)drawRect:(NSRect)dirty {
    [NSColor.blackColor setFill]; NSRectFill(self.bounds);
    CGFloat width=self.bounds.size.width/3;
    for (NSUInteger i=0;i<self.cards.count;++i) {
        NSRect cell=NSMakeRect(i*width,0,width-4,30);
        [[NSColor colorWithSRGBRed:.09 green:.025 blue:.04 alpha:1] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:cell xRadius:5 yRadius:5] fill];
        if (self.page==2) {
            NSBezierPath* graph=[NSBezierPath bezierPath]; BOOL started=NO;
            for (size_t n=0;n<samples[i].size();++n) {
                double value=samples[i][n]; if (value<0) { started=NO; continue; }
                NSPoint point=NSMakePoint(NSMaxX(cell)-3-double(samples[i].size()-1-n)/59.*(cell.size.width-6),29-MIN(100.,value)/100.*12);
                if (started) [graph lineToPoint:point]; else [graph moveToPoint:point]; started=YES;
            }
            [[touchAccent() colorWithAlphaComponent:.45] setStroke]; graph.lineWidth=1; [graph stroke];
        }
        NSMutableParagraphStyle* paragraph=[[[NSMutableParagraphStyle alloc] init] autorelease]; paragraph.lineBreakMode=NSLineBreakByTruncatingTail;
        [self.cards[i][0] drawInRect:NSInsetRect(NSMakeRect(cell.origin.x,1,cell.size.width,10),5,0) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:8 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:touchAccent(),NSParagraphStyleAttributeName:paragraph}];
        [self.cards[i][1] drawInRect:NSInsetRect(NSMakeRect(cell.origin.x,12,cell.size.width,17),5,0) withAttributes:@{NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.whiteColor,NSParagraphStyleAttributeName:paragraph}];
    }
}
- (void)dealloc { self.active=NO; [_cards release]; [_streamText release]; [_devicesText release]; [super dealloc]; }
@end

// NSTouchBar owns the actual controls. The same views are rendered by the
// regression fixture for layout QA on runners without physical Touch Bar hardware.
@interface MLStreamTitlebar (TouchBar) <NSTouchBarDelegate>
- (void)installTouchBar;
- (void)refreshTouchBar;
- (void)invalidateTouchBar;
@end
@implementation MLStreamTitlebar (TouchBar)
- (NSTouchBar*)touchBarWithItems:(NSArray*)identifiers {
    NSTouchBar* bar=[[[NSTouchBar alloc] init] autorelease]; bar.delegate=self;
    bar.defaultItemIdentifiers=identifiers;
    return bar;
}
- (void)installTouchBar {
    self.touchButtons=[NSMutableDictionary dictionary]; self.touchPopovers=[NSMutableArray array];
    self.touchDashboard=[[[MLTouchDashboard alloc] initWithFrame:NSMakeRect(0,0,370,30)] autorelease];
    self.previousTouchBar=self.window.touchBar;
    self.streamTouchBar=[self touchBarWithItems:@[@"touch.info",@"touch.capture",@"touch.audio",@"touch.record",@"touch.replay",@"touch.more"]];
    self.window.touchBar=self.streamTouchBar;
    self.touchTimer=[NSTimer timerWithTimeInterval:1 target:self selector:@selector(touchTick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.touchTimer forMode:NSRunLoopCommonModes];
    [self refreshTouchBar];
}
- (void)touchTick:(NSTimer*)timer {
    if (!self.window || !self.window.visible || !NSApp.active || !self.window.keyWindow) return;
    // Local sampling only; the streaming engine still owns the stats cadence.
    [self.touchDashboard sample]; [self refreshTouchBar];
}
- (NSTouchBarItem*)touchBar:(NSTouchBar*)bar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    if ([identifier isEqual:@"touch.info"] || [identifier isEqual:@"touch.audio"] || [identifier isEqual:@"touch.more"]) {
        NSPopoverTouchBarItem* item=[[[NSPopoverTouchBarItem alloc] initWithIdentifier:identifier] autorelease];
        BOOL info=[identifier isEqual:@"touch.info"],audio=[identifier isEqual:@"touch.audio"];
        item.collapsedRepresentationLabel=info ? @"Live Status" : audio ? @"Audio" : @"More";
        item.collapsedRepresentationImage=touchSymbol(info ? @"moon.fill" : audio ? @"speaker.wave.2.fill" : @"ellipsis.circle");
        NSButton* button=touchButton(item.collapsedRepresentationLabel,info ? @"moon.fill" : audio ? @"speaker.wave.2.fill" : @"ellipsis.circle",item,@selector(showPopover:),info ? 116 : 66);
        button.identifier=identifier; item.collapsedRepresentation=button;
        self.touchButtons[identifier]=button; [self.touchPopovers addObject:item]; item.showsCloseButton=YES;
        item.popoverTouchBar=[self touchBarWithItems:info ? @[@"touch.pages",@"touch.dashboard"] : audio ? @[@"touch.mute",@"touch.volume",@"touch.volumeLabel"] : @[@"touch.stats",@"touch.hardware",@"touch.fullscreen",@"touch.controls",@"touch.hide",@"touch.disconnect"]];
        [self refreshTouchBar]; return item;
    }
    if ([identifier isEqual:@"touch.volume"]) {
        NSSliderTouchBarItem* item=[[[NSSliderTouchBarItem alloc] initWithIdentifier:identifier] autorelease];
        item.slider.minValue=0; item.slider.maxValue=1; item.slider.continuous=YES;
        item.slider.doubleValue=nativePlaybackVolume(); item.target=self; item.action=@selector(touchVolume:);
        [item.slider.widthAnchor constraintEqualToConstant:280].active=YES;
        [item.slider setAccessibilityLabel:@"Local playback volume; recording audio unchanged"];
        self.touchVolume=item; return item;
    }
    NSCustomTouchBarItem* item=[[[NSCustomTouchBarItem alloc] initWithIdentifier:identifier] autorelease];
    if ([identifier isEqual:@"touch.dashboard"]) item.view=self.touchDashboard;
    else if ([identifier isEqual:@"touch.pages"]) {
        NSSegmentedControl* pages=[NSSegmentedControl segmentedControlWithLabels:@[@"Stream",@"Decode",@"Mac",@"Devices"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(touchPage:)];
        pages.selectedSegment=self.touchDashboard.page; pages.segmentStyle=NSSegmentStyleRounded;
        [pages.widthAnchor constraintEqualToConstant:214].active=YES; item.view=pages;
    } else {
        NSDictionary* titles=@{@"touch.capture":@"Capture",@"touch.record":@"Record",@"touch.replay":@"Replay",@"touch.stats":@"Stats",@"touch.hardware":@"Monitor",@"touch.fullscreen":@"Full Screen",@"touch.controls":@"Controls",@"touch.hide":@"Hide",@"touch.disconnect":@"Disconnect",@"touch.mute":@"Mute",@"touch.volumeLabel":@"100%"};
        NSDictionary* symbols=@{@"touch.capture":@"cursorarrow",@"touch.record":@"record.circle",@"touch.replay":@"arrow.counterclockwise",@"touch.stats":@"chart.xyaxis.line",@"touch.hardware":@"cpu",@"touch.fullscreen":@"arrow.up.left.and.arrow.down.right",@"touch.controls":@"slider.horizontal.3",@"touch.hide":@"eye.slash",@"touch.disconnect":@"power",@"touch.mute":@"speaker.slash.fill",@"touch.volumeLabel":@"speaker.wave.2"};
        CGFloat width=[identifier isEqual:@"touch.record"] ? 98 : [identifier isEqual:@"touch.disconnect"] ? 100 : [identifier isEqual:@"touch.fullscreen"] ? 100 : 74;
        NSButton* button=touchButton(titles[identifier] ?: identifier,symbols[identifier] ?: @"circle",self,@selector(touchAction:),width);
        button.identifier=identifier; self.touchButtons[identifier]=button; item.view=button;
    }
    [self refreshTouchBar]; return item;
}
- (void)touchPage:(NSSegmentedControl*)sender { self.touchDashboard.page=sender.selectedSegment; [self.touchDashboard refreshCards]; }
- (void)touchVolume:(NSSliderTouchBarItem*)sender {
    if (!self.window || self.window.touchBar!=self.streamTouchBar) return;
    nativePlaybackSetVolume(sender.slider.floatValue);
    NSUserDefaults* defaults=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    [defaults setFloat:nativePlaybackVolume() forKey:@"playbackVolume"];
    [self updateDetails]; [self refreshTouchBar];
}
- (void)touchAction:(NSButton*)sender {
    if (!self.window || self.window.touchBar!=self.streamTouchBar || !sender.enabled) return;
    NSString* name=sender.identifier;
    NSDictionary* actions=@{@"touch.capture":@1,@"touch.record":@217,@"touch.replay":@219,@"touch.stats":@3,@"touch.mute":@207,@"touch.fullscreen":@2,@"touch.controls":@11,@"touch.hide":@0,@"touch.disconnect":@12};
    if ([name isEqual:@"touch.hardware"]) [self perform:hardwareID anchor:nil];
    else if (actions[name]) nativeOverlayPerformAction([actions[name] intValue]);
    if ([name isEqual:@"touch.hide"] || [name isEqual:@"touch.disconnect"])
        for (NSPopoverTouchBarItem* popover in self.touchPopovers) [popover dismissPopover:nil];
}
- (void)refreshTouchBar {
    if (!self.streamTouchBar) return;
    TitleState copy; { std::lock_guard<std::mutex> lock(stateMutex); copy=state; }
    self.touchDashboard.streamText=[NSString stringWithUTF8String:copy.streamText.c_str()] ?: @"";
    self.touchDashboard.streamUpdated=copy.streamUpdated;
    self.touchDashboard.devicesText=self.controllerCount ? [NSString stringWithFormat:@"%lu · %@",(unsigned long)self.controllerCount,powerDescription(self.batteryLevel)] : @"None connected";
    [self.touchDashboard refreshCards];
    NSButton* info=self.touchButtons[@"touch.info"];
    NSString* fps=[self.touchDashboard metric:@"Incoming frame rate" fallback:@""];
    info.title=copy.connection==NativeConnectionState::Connected ? (fps.length ? [@"Live · " stringByAppendingString:fps] : @"Connected") : connectionDescription(copy.connection);
    info.image=touchSymbol(copy.connection==NativeConnectionState::Poor || copy.connection==NativeConnectionState::Disconnected ? @"exclamationmark.circle" : @"moon.fill");
    info.toolTip=@"Stream measurements, decoding, local hardware and controllers";
    NSButton* capture=self.touchButtons[@"touch.capture"]; capture.title=copy.captured ? @"Release" : @"Capture";
    capture.image=touchSymbol(copy.captured ? @"cursorarrow.motionlines" : @"cursorarrow");
    capture.bezelColor=copy.captured ? [touchAccent() colorWithAlphaComponent:.45] : [NSColor colorWithWhite:.13 alpha:1];
    capture.contentTintColor=copy.captured ? NSColor.whiteColor : touchAccent();
    NSButton* audio=self.touchButtons[@"touch.audio"];
    audio.title=copy.muted ? @"Muted" : [NSString stringWithFormat:@"%.0f%%",nativePlaybackVolume()*100];
    audio.image=touchSymbol(copy.muted ? @"speaker.slash.fill" : @"speaker.wave.2.fill");
    NSButton* record=self.touchButtons[@"touch.record"];
    record.title=copy.recording ? [NSString stringWithFormat:@"%llu:%02llu",(unsigned long long)(copy.seconds/60),(unsigned long long)(copy.seconds%60)] : copy.recorderFailed ? @"Rec error" : copy.recorder ? @"Record" : @"Rec off";
    record.image=touchSymbol(copy.recording ? @"stop.circle.fill" : copy.recorderFailed ? @"exclamationmark.circle" : @"record.circle");
    record.enabled=copy.recorder; record.toolTip=[NSString stringWithUTF8String:copy.recordingMessage.c_str()];
    record.bezelColor=copy.recording ? [touchAccent() colorWithAlphaComponent:.7] : [NSColor colorWithWhite:.13 alpha:1];
    record.contentTintColor=copy.recording ? NSColor.whiteColor : touchAccent();
    NSButton* replay=self.touchButtons[@"touch.replay"];
    replay.title=copy.saving ? @"Saving" : copy.replayReady ? @"Save" : copy.buffering ? @"Buffer" : @"Replay";
    replay.enabled=copy.recorder && copy.replayReady && !copy.saving;
    replay.image=touchSymbol(copy.saving ? @"hourglass" : @"arrow.counterclockwise");
    self.touchButtons[@"touch.stats"].title=copy.statistics ? @"Stats on" : @"Stats off";
    self.touchButtons[@"touch.hardware"].title=self.hardware ? @"Hide Mac" : @"Monitor";
    self.touchButtons[@"touch.mute"].title=copy.muted ? @"Unmute" : @"Mute";
    self.touchButtons[@"touch.volumeLabel"].title=[NSString stringWithFormat:@"%.0f%%",nativePlaybackVolume()*100];
    self.touchButtons[@"touch.volumeLabel"].enabled=NO;
    if (self.touchVolume) self.touchVolume.slider.doubleValue=nativePlaybackVolume();
    for (NSString* key in self.touchButtons) {
        NSButton* button=self.touchButtons[key];
        [button setAccessibilityLabel:button.toolTip.length ? [NSString stringWithFormat:@"%@ · %@",button.title,button.toolTip] : button.title];
    }
}
- (void)invalidateTouchBar {
    [self.touchTimer invalidate]; self.touchTimer=nil; self.touchDashboard.active=NO;
    for (NSPopoverTouchBarItem* item in self.touchPopovers) { [item dismissPopover:nil]; item.popoverTouchBar.delegate=nil; }
    for (NSButton* button in self.touchButtons.allValues) { button.target=nil; button.action=NULL; }
    self.touchVolume.target=nil; self.touchVolume.action=NULL;
    if (self.window.touchBar==self.streamTouchBar) self.window.touchBar=self.previousTouchBar;
    self.streamTouchBar.delegate=nil; self.streamTouchBar=nil; self.previousTouchBar=nil;
    self.touchButtons=nil; self.touchPopovers=nil; self.touchDashboard=nil; self.touchVolume=nil;
}
@end
