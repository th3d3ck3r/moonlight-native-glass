// Compiled with nativetitlebar.mm. Touch Bar actions use the existing SDL queue;
// no decoder, frame-pacing, mouse tracking or recorder ownership lives here.
#include "nativestreamstats.h"
#import <objc/message.h>

static NSColor* touchAccent() {
    return crimsonEnabled() ? [NSColor colorWithSRGBRed:.95 green:.19 blue:.32 alpha:1] : NSColor.controlAccentColor;
}
static NSColor* touchSurface() {
    return crimsonEnabled() ? [NSColor colorWithSRGBRed:.12 green:.035 blue:.055 alpha:1] : [NSColor colorWithWhite:.13 alpha:1];
}
static NSImage* touchSymbol(NSString* name) {
    NSImage* image=[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    return [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightMedium]];
}
// The physical Touch Bar substitutes its own NSButtonCell metrics. Draw the
// compact content ourselves inside a native button so its font/padding agree
// with our width budget on both a real bar and preview fixtures.
@interface MLTouchButton : NSButton
@end
@implementation MLTouchButton
- (BOOL)isFlipped { return YES; }
- (NSSize)intrinsicContentSize { return NSMakeSize(74,30); }
- (void)drawRect:(NSRect)dirty {
    NSColor* background=self.bezelColor ?: touchSurface();
    [(self.cell.highlighted ? [background blendedColorWithFraction:.2 ofColor:NSColor.whiteColor] : background) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:6 yRadius:6] fill];
    NSFont* font=[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    CGFloat textWidth=[self.title sizeWithAttributes:@{NSFontAttributeName:font}].width;
    CGFloat icon=self.image ? 15 : 0,gap=icon && self.title.length ? 5 : 0;
    CGFloat total=MIN(self.bounds.size.width-12,textWidth+icon+gap);
    CGFloat x=(self.bounds.size.width-total)/2;
    if (self.image) {
        NSColor* tint=self.contentTintColor ?: touchAccent();
        NSImage* image=[self.image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithHierarchicalColor:tint]];
        [image drawInRect:NSMakeRect(x,(self.bounds.size.height-15)/2,15,15) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:self.enabled ? 1 : .4 respectFlipped:YES hints:nil];
        x+=icon+gap;
    }
    NSMutableParagraphStyle* paragraph=[[[NSMutableParagraphStyle alloc] init] autorelease];
    paragraph.lineBreakMode=NSLineBreakByTruncatingTail;
    [self.title drawInRect:NSMakeRect(x,(self.bounds.size.height-14)/2,total-icon-gap,14)
        withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:[NSColor.whiteColor colorWithAlphaComponent:self.enabled ? 1 : .4],NSParagraphStyleAttributeName:paragraph}];
}
@end

static NSButton* touchButton(NSString* title,NSString* symbol,id target,SEL action,CGFloat width) {
    NSButton* button=[MLTouchButton buttonWithTitle:title target:target action:action];
    button.image=touchSymbol(symbol); button.imagePosition=NSImageLeft;
    button.font=[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
    [button.heightAnchor constraintEqualToConstant:30].active=YES;
    button.bezelColor=touchSurface();
    button.contentTintColor=touchAccent(); button.lineBreakMode=NSLineBreakByTruncatingTail;
    NSLayoutConstraint* constraint=[button.widthAnchor constraintEqualToConstant:width];
    constraint.identifier=@"MoonlightLG.TouchWidth"; constraint.active=YES;
    return button;
}

@interface MLTouchDashboard : NSView {
    MLHardwareReading previous;
    double previousTime;
    BOOL havePrevious,busy;
    std::array<std::vector<double>,3> samples;
}
@property(nonatomic,assign) BOOL active;
@property(nonatomic,assign) BOOL inlineMode;
@property(nonatomic,assign) NSInteger page;
@property(nonatomic,assign) NSInteger connectionState;
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
- (void)copyHardwareFrom:(MLTouchDashboard*)source;
@end
@implementation MLTouchDashboard
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.active=YES; self.cpu=self.ram=self.gpu=self.rx=self.tx=-1;
        self.identifier=@"TouchDashboard"; self.streamText=@""; self.devicesText=@"No controller connected";
        NSLayoutConstraint* constraint=[self.widthAnchor constraintGreaterThanOrEqualToConstant:350];
        constraint.identifier=@"MoonlightLG.TouchWidth"; constraint.active=YES;
        [self setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self.heightAnchor constraintEqualToConstant:30].active=YES;
        [self refreshCards];
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (NSView*)hitTest:(NSPoint)point { return self.inlineMode ? nil : [super hitTest:point]; }
- (void)setFrameSize:(NSSize)size { [super setFrameSize:size]; if (self.inlineMode) [self refreshCards]; }
- (NSSize)intrinsicContentSize { return NSMakeSize(350,30); }
- (NSString*)metric:(NSString*)prefix fallback:(NSString*)fallback {
    // Never present a sample as current once the source stops updating.
    if (NSProcessInfo.processInfo.systemUptime-self.streamUpdated>4) return fallback;
    for (const auto& row:NativeStreamStats::parse(self.streamText.UTF8String ?: ""))
        if ([ [NSString stringWithUTF8String:row.label.c_str()] hasPrefix:prefix])
            return [NSString stringWithUTF8String:row.value.c_str()];
    return fallback;
}
- (void)refreshCards {
    NSString* missing=self.streamText.length ? @"Unavailable / stale" : @"Waiting for data";
    if (self.inlineMode) {
        NSString* bitrate=[self metric:@"Bitrate" fallback:missing];
        bitrate=[[bitrate componentsSeparatedByString:@","] firstObject];
        NSMutableArray* cards=[NSMutableArray arrayWithArray:@[
            @[(self.connectionState==2 ? @"FPS" : [NSString stringWithFormat:@"FPS · %@",@[@"Idle",@"Connecting",@"Connected",@"Poor link",@"Disconnected"][MIN(4,MAX(0,self.connectionState))]]),[self metric:@"Incoming frame rate" fallback:missing]],
            @[@"NETWORK RTT",[self metric:@"Average network latency" fallback:missing]],
            @[@"BITRATE",bitrate]]];
        if (self.bounds.size.width>=840) {
            [cards addObject:@[@"DECODE",[self metric:@"Average decoding time" fallback:missing]]];
            [cards addObject:@[@"DROPS",[self metric:@"Frames dropped by" fallback:missing]]];
        }
        if (self.bounds.size.width>=620) {
            [cards addObject:@[@"MAC CPU",self.cpu<0 ? @"Sampling…" : [NSString stringWithFormat:@"%.0f%%",self.cpu]]];
            [cards addObject:@[@"MAC RAM",self.ram<0 ? @"Unavailable" : [NSString stringWithFormat:@"%.1f GB",self.ram/100.*NSProcessInfo.processInfo.physicalMemory/1073741824.]]];
            [cards addObject:@[@"MAC GPU",self.gpu<0 ? @"Unavailable" : [NSString stringWithFormat:@"%.0f%%",self.gpu]]];
        }
        self.cards=cards;
    } else switch (self.page) {
        case 0: self.cards=@[@[@"INCOMING FPS",[self metric:@"Incoming frame rate" fallback:missing]],
                            @[@"NETWORK RTT",[self metric:@"Average network latency" fallback:missing]],
                            @[@"BITRATE",[self metric:@"Bitrate" fallback:missing]]]; break;
        case 1: self.cards=@[@[@"VIDEO",[self metric:@"Video stream" fallback:missing]],
                            @[@"CODEC",[self metric:@"Video codec" fallback:missing]],
                            @[@"HOST LATENCY",[self metric:@"Host processing latency" fallback:missing]]]; break;
        case 2: self.cards=@[@[@"DECODE",[self metric:@"Average decoding time" fallback:missing]],
                            @[@"FRAME QUEUE",[self metric:@"Average frame queue delay" fallback:missing]],
                            @[@"RENDER TIME",[self metric:@"Average rendering time" fallback:missing]]]; break;
        case 3: self.cards=@[@[@"NETWORK DROPS",[self metric:@"Frames dropped by" fallback:missing]],
                            @[@"JITTER DROPS",[self metric:@"Frames dropped due" fallback:missing]],
                            @[@"RENDER FPS",[self metric:@"Rendering frame rate" fallback:missing]]]; break;
        case 4: self.cards=@[@[@"LOCAL CPU",self.cpu<0 ? @"Sampling…" : [NSString stringWithFormat:@"%.0f%%",self.cpu]],
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
- (void)copyHardwareFrom:(MLTouchDashboard*)source {
    self.cpu=source.cpu; self.ram=source.ram; self.gpu=source.gpu; self.rx=source.rx; self.tx=source.tx;
    samples=source->samples;
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
    CGFloat width=self.bounds.size.width/MAX((NSUInteger)1,self.cards.count);
    for (NSUInteger i=0;i<self.cards.count;++i) {
        NSRect cell=NSMakeRect(i*width,0,width-4,30);
        [touchSurface() setFill];
        [[NSBezierPath bezierPathWithRoundedRect:cell xRadius:5 yRadius:5] fill];
        NSInteger channel=self.inlineMode ? (NSInteger)i-(NSInteger)self.cards.count+3 : (NSInteger)i;
        if ((!self.inlineMode && self.page==4) || (self.inlineMode && self.cards.count>=6 && channel>=0 && channel<3)) {
            NSBezierPath* graph=[NSBezierPath bezierPath]; BOOL started=NO;
            for (size_t n=0;n<samples[channel].size();++n) {
                double value=samples[channel][n]; if (value<0) { started=NO; continue; }
                NSPoint point=NSMakePoint(NSMaxX(cell)-3-double(samples[channel].size()-1-n)/59.*(cell.size.width-6),29-MIN(100.,value)/100.*12);
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

@interface MLTouchStatsButton : NSButton
@property(nonatomic,retain) MLTouchDashboard* dashboard;
@end
@implementation MLTouchStatsButton
- (NSSize)intrinsicContentSize { return NSMakeSize(350,30); }
- (void)setFrameSize:(NSSize)size { [super setFrameSize:size]; self.dashboard.frame=self.bounds; }
- (void)dealloc { [_dashboard release]; [super dealloc]; }
@end

// One item owns the pager and measurements. AppKit cannot drop the dashboard
// independently when a segmented control's Touch Bar metrics grow on hardware.
@interface MLTouchInfoPanel : NSView
@property(nonatomic,retain) MLTouchDashboard* dashboard;
@property(nonatomic,retain) NSButton* previous;
@property(nonatomic,retain) NSButton* next;
@property(nonatomic,retain) NSTextField* pageLabel;
@end
@implementation MLTouchInfoPanel
- (NSSize)intrinsicContentSize { return NSMakeSize(430,30); }
- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    self.previous.frame=NSMakeRect(0,0,30,30);
    self.pageLabel.frame=NSMakeRect(34,7,50,17);
    self.next.frame=NSMakeRect(88,0,30,30);
    self.dashboard.frame=NSMakeRect(126,0,MAX(1,size.width-126),30);
}
- (void)dealloc { [_dashboard release]; [_previous release]; [_next release]; [_pageLabel release]; [super dealloc]; }
@end

// NSTouchBar owns the actual controls. The same views are rendered by the
// regression fixture for layout QA on runners without physical Touch Bar hardware.
// Same optional system-modal AppKit selectors as the frontend. This changes
// presentation only for the active owner and never writes system preferences.
static BOOL touchPresentFullWidth(NSTouchBar* bar) {
    SEL show=NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:");
    SEL hide=NSSelectorFromString(@"dismissSystemModalTouchBar:");
    if (![NSTouchBar respondsToSelector:show] || ![NSTouchBar respondsToSelector:hide]) return NO;
    ((void(*)(id,SEL,NSTouchBar*,long long,id))objc_msgSend)(NSTouchBar.class,show,bar,1,nil);
    return YES;
}
static void touchDismissFullWidth(NSTouchBar* bar) {
    SEL hide=NSSelectorFromString(@"dismissSystemModalTouchBar:");
    if ([NSTouchBar respondsToSelector:hide]) ((void(*)(id,SEL,NSTouchBar*))objc_msgSend)(NSTouchBar.class,hide,bar);
}
static BOOL touchWantsFullWidth(MLStreamTitlebar* owner) {
    NSUserDefaults* preferences=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass"] autorelease];
    [preferences synchronize];
    return !owner.touchInvalidating && [preferences boolForKey:@"touchBarFullWidth"] && owner.streamTouchBar && owner.window.touchBar==owner.streamTouchBar && owner.window.visible && owner.window.keyWindow && NSApp.active;
}
@implementation MLStreamTitlebar (TouchBar)
- (void)updateTouchPresentation {
    if (self.touchPresentationUpdating) return;
    BOOL wanted=touchWantsFullWidth(self);
    if (wanted==self.touchFullWidthPresented) return;
    self.touchPresentationUpdating=YES;
    if (wanted) {
        self.touchFullWidthPresented=YES;
        if (!touchPresentFullWidth(self.streamTouchBar)) self.touchFullWidthPresented=NO;
    } else { self.touchFullWidthPresented=NO; touchDismissFullWidth(self.streamTouchBar); }
    self.touchPresentationUpdating=NO;
    // React once to a real focus/preference change emitted during presentation.
    // An unsupported selector must not cause recursive retries.
    if (wanted!=touchWantsFullWidth(self)) [self updateTouchPresentation];
}
- (void)touchPresentationChanged:(NSNotification*)notification { [self updateTouchPresentation]; }

- (NSTouchBar*)touchBarWithItems:(NSArray*)identifiers {
    NSTouchBar* bar=[[[NSTouchBar alloc] init] autorelease]; bar.delegate=self;
    bar.defaultItemIdentifiers=identifiers;
    return bar;
}
- (void)installTouchBar {
    self.touchButtons=[NSMutableDictionary dictionary]; self.touchPopovers=[NSMutableArray array];
    self.touchDashboard=[[[MLTouchDashboard alloc] initWithFrame:NSMakeRect(0,0,350,30)] autorelease];
    NSUserDefaults* preferences=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    self.touchLiveStats=[preferences objectForKey:@"touchBarLiveStats"] ? [preferences boolForKey:@"touchBarLiveStats"] : YES;
    self.touchInlineDashboard=[[[MLTouchDashboard alloc] initWithFrame:NSMakeRect(0,0,350,30)] autorelease];
    self.touchInlineDashboard.inlineMode=YES;
    self.previousTouchBar=self.window.touchBar;
    self.streamTouchBar=[self touchBarWithItems:self.touchLiveStats ? @[@"touch.capture",@"touch.info",@"touch.more"] : @[@"touch.info",@"touch.capture",@"touch.audio",@"touch.record",@"touch.replay",@"touch.more"]];
    self.window.touchBar=self.streamTouchBar;
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(touchPresentationChanged:) name:@"com.moonlight-stream.NativeGlass.touchBarPresentationChanged" object:nil];
    [self updateTouchPresentation];
    self.touchTimer=[NSTimer timerWithTimeInterval:1 target:self selector:@selector(touchTick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.touchTimer forMode:NSRunLoopCommonModes];
    [self refreshTouchBar];
}
- (void)touchTick:(NSTimer*)timer {
    [self updateTouchPresentation];
    if (!self.window || !self.window.visible || !NSApp.active || !self.window.keyWindow) return;
    // Local sampling only; the streaming engine still owns the stats cadence.
    [self.touchDashboard sample]; [self refreshTouchBar];
}
- (NSTouchBarItem*)touchBar:(NSTouchBar*)bar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    if ([identifier isEqual:@"touch.info"] || [identifier isEqual:@"touch.audio"] || [identifier isEqual:@"touch.more"] || [identifier isEqual:@"touch.window"]) {
        NSPopoverTouchBarItem* item=[[[NSPopoverTouchBarItem alloc] initWithIdentifier:identifier] autorelease];
        BOOL info=[identifier isEqual:@"touch.info"],audio=[identifier isEqual:@"touch.audio"];
        BOOL window=[identifier isEqual:@"touch.window"];
        item.visibilityPriority=info ? 1000 : 500;
        item.collapsedRepresentationLabel=info ? @"Live Status" : audio ? @"Audio" : window ? @"Window" : self.touchLiveStats ? @"Controls" : @"More";
        item.collapsedRepresentationImage=touchSymbol(info ? @"moon.fill" : audio ? @"speaker.wave.2.fill" : @"ellipsis.circle");
        NSButton* button;
        if (info && self.touchLiveStats) {
            MLTouchStatsButton* stats=[[[MLTouchStatsButton alloc] initWithFrame:NSMakeRect(0,0,350,30)] autorelease];
            stats.title=@""; stats.bordered=NO; stats.target=item; stats.action=@selector(showPopover:);
            stats.dashboard=self.touchInlineDashboard; [stats addSubview:self.touchInlineDashboard];
            NSLayoutConstraint* constraint=[stats.widthAnchor constraintGreaterThanOrEqualToConstant:350];
            constraint.identifier=@"MoonlightLG.TouchWidth"; constraint.active=YES;
            [stats.heightAnchor constraintEqualToConstant:30].active=YES;
            [stats setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
            button=stats;
        } else button=touchButton(item.collapsedRepresentationLabel,info ? @"moon.fill" : audio ? @"speaker.wave.2.fill" : window ? @"display" : @"slider.horizontal.3",item,@selector(showPopover:),info ? 116 : (!audio && self.touchLiveStats && !window) ? 98 : window ? 80 : 66);
        button.identifier=identifier; item.collapsedRepresentation=button;
        self.touchButtons[identifier]=button; [self.touchPopovers addObject:item]; item.showsCloseButton=YES;
        item.popoverTouchBar=[self touchBarWithItems:info ? @[@"touch.detail"] : audio ? @[@"touch.mute",@"touch.volume",@"touch.volumeLabel"] : window ? @[@"touch.hardware",@"touch.fullscreen",@"touch.controls",@"touch.hide"] : self.touchLiveStats ? @[@"touch.audio",@"touch.record",@"touch.replay",@"touch.stats",@"touch.window",@"touch.disconnect"] : @[@"touch.stats",@"touch.hardware",@"touch.fullscreen",@"touch.controls",@"touch.hide",@"touch.disconnect"]];
        [self refreshTouchBar]; return item;
    }
    if ([identifier isEqual:@"touch.volume"]) {
        NSSliderTouchBarItem* item=[[[NSSliderTouchBarItem alloc] initWithIdentifier:identifier] autorelease];
        item.slider.minValue=0; item.slider.maxValue=1; item.slider.continuous=YES;
        item.slider.doubleValue=nativePlaybackVolume(); item.slider.trackFillColor=touchAccent(); item.target=self; item.action=@selector(touchVolume:);
        NSLayoutConstraint* constraint=[item.slider.widthAnchor constraintGreaterThanOrEqualToConstant:220];
        constraint.identifier=@"MoonlightLG.TouchWidth"; constraint.active=YES;
        [item.slider setAccessibilityLabel:@"Local playback volume; recording audio unchanged"];
        self.touchVolume=item; return item;
    }
    NSCustomTouchBarItem* item=[[[NSCustomTouchBarItem alloc] initWithIdentifier:identifier] autorelease];
    if ([identifier isEqual:@"touch.volumeLabel"]) {
        NSTextField* label=[NSTextField labelWithString:@"100%"];
        label.font=[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightSemibold];
        label.textColor=NSColor.whiteColor; label.alignment=NSTextAlignmentCenter;
        NSLayoutConstraint* constraint=[label.widthAnchor constraintEqualToConstant:74];
        constraint.identifier=@"MoonlightLG.TouchWidth"; constraint.active=YES;
        [label setAccessibilityLabel:@"Playback volume percentage"];
        self.touchVolumeText=label; item.view=label;
    }
    else if ([identifier isEqual:@"touch.detail"]) {
        MLTouchInfoPanel* panel=[[[MLTouchInfoPanel alloc] initWithFrame:NSMakeRect(0,0,430,30)] autorelease];
        panel.identifier=identifier; panel.dashboard=self.touchDashboard;
        // This dashboard is manually laid out inside a single Touch Bar item.
        // Its standalone minimum-width constraint must not compete with its parent.
        for (NSLayoutConstraint* constraint in self.touchDashboard.constraints)
            if ([constraint.identifier isEqual:@"MoonlightLG.TouchWidth"]) constraint.active=NO;
        panel.previous=touchButton(@"",@"chevron.left",self,@selector(touchPage:),30);
        panel.next=touchButton(@"",@"chevron.right",self,@selector(touchPage:),30);
        panel.previous.identifier=@"touch.page.previous"; panel.next.identifier=@"touch.page.next";
        panel.previous.toolTip=@"Previous statistics page"; panel.next.toolTip=@"Next statistics page";
        self.touchButtons[panel.previous.identifier]=panel.previous; self.touchButtons[panel.next.identifier]=panel.next;
        panel.pageLabel=[NSTextField labelWithString:@"Live"];
        panel.pageLabel.font=[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
        panel.pageLabel.textColor=NSColor.whiteColor; panel.pageLabel.alignment=NSTextAlignmentCenter;
        self.touchPageLabel=panel.pageLabel;
        for (NSView* child in @[panel.previous,panel.pageLabel,panel.next,panel.dashboard]) [panel addSubview:child];
        NSLayoutConstraint* width=[panel.widthAnchor constraintGreaterThanOrEqualToConstant:430];
        width.identifier=@"MoonlightLG.TouchWidth"; width.active=YES;
        [panel.heightAnchor constraintEqualToConstant:30].active=YES;
        [panel setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        item.visibilityPriority=1000; item.view=panel; [panel setFrameSize:NSMakeSize(430,30)];
    } else {
        NSDictionary* titles=@{@"touch.capture":@"Capture",@"touch.record":@"Record",@"touch.replay":@"Replay",@"touch.stats":@"Stats",@"touch.hardware":@"Monitor",@"touch.fullscreen":@"Full Screen",@"touch.controls":@"Controls",@"touch.hide":@"Hide",@"touch.disconnect":@"Disconnect",@"touch.mute":@"Mute",@"touch.volumeLabel":@"100%"};
        NSDictionary* symbols=@{@"touch.capture":@"cursorarrow",@"touch.record":@"record.circle",@"touch.replay":@"arrow.counterclockwise",@"touch.stats":@"chart.xyaxis.line",@"touch.hardware":@"cpu",@"touch.fullscreen":@"arrow.up.left.and.arrow.down.right",@"touch.controls":@"slider.horizontal.3",@"touch.hide":@"eye.slash",@"touch.disconnect":@"power",@"touch.mute":@"speaker.slash.fill",@"touch.volumeLabel":@"speaker.wave.2"};
        CGFloat width=[identifier isEqual:@"touch.capture"] || [identifier isEqual:@"touch.hardware"] ? 84 : [identifier isEqual:@"touch.stats"] ? 90 : [identifier isEqual:@"touch.controls"] ? 94 : [identifier isEqual:@"touch.record"] ? 98 : [identifier isEqual:@"touch.disconnect"] ? 100 : [identifier isEqual:@"touch.fullscreen"] ? 100 : 74;
        NSButton* button=touchButton(titles[identifier] ?: identifier,symbols[identifier] ?: @"circle",self,@selector(touchAction:),width);
        button.identifier=identifier; self.touchButtons[identifier]=button; item.view=button;
    }
    [self refreshTouchBar]; return item;
}
- (void)touchPage:(NSButton*)sender {
    if (!self.window || self.window.touchBar!=self.streamTouchBar) return;
    self.touchDashboard.page=(self.touchDashboard.page+([sender.identifier isEqual:@"touch.page.previous"] ? 5 : 1))%6;
    [self refreshTouchBar];
}
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
    for (NSButton* button in self.touchButtons.allValues) { button.bezelColor=touchSurface(); button.contentTintColor=touchAccent(); }
    self.touchDashboard.streamText=[NSString stringWithUTF8String:copy.streamText.c_str()] ?: @"";
    self.touchDashboard.streamUpdated=copy.streamUpdated;
    self.touchDashboard.devicesText=self.controllerCount ? [NSString stringWithFormat:@"%lu · %@",(unsigned long)self.controllerCount,powerDescription(self.batteryLevel)] : @"None connected";
    [self.touchDashboard refreshCards];
    self.touchInlineDashboard.connectionState=(NSInteger)copy.connection;
    self.touchInlineDashboard.streamText=self.touchDashboard.streamText;
    self.touchInlineDashboard.streamUpdated=copy.streamUpdated;
    self.touchInlineDashboard.devicesText=self.touchDashboard.devicesText;
    [self.touchInlineDashboard copyHardwareFrom:self.touchDashboard]; [self.touchInlineDashboard refreshCards];
    NSButton* info=self.touchButtons[@"touch.info"];
    NSString* fps=[self.touchDashboard metric:@"Incoming frame rate" fallback:@""];
    if (!self.touchLiveStats) {
        info.title=copy.connection==NativeConnectionState::Connected ? (fps.length ? [NSString stringWithFormat:@"%.0f FPS",fps.doubleValue] : @"Connected") : @[@"Idle",@"Connecting",@"Connected",@"Poor link",@"Disconnected"][(NSInteger)copy.connection];
        info.image=touchSymbol(copy.connection==NativeConnectionState::Poor || copy.connection==NativeConnectionState::Disconnected ? @"exclamationmark.circle" : @"moon.fill");
    }
    info.toolTip=[NSString stringWithFormat:@"%@ · Stream measurements, decoding, local hardware and controllers",connectionDescription(copy.connection)];
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
    if (self.touchLiveStats) {
        NSButton* controls=self.touchButtons[@"touch.more"];
        controls.title=copy.recording ? [NSString stringWithFormat:@"REC %llu:%02llu",(unsigned long long)(copy.seconds/60),(unsigned long long)(copy.seconds%60)] : copy.saving ? @"Saving" : copy.recorderFailed ? @"Rec error" : @"Controls";
        controls.image=touchSymbol(copy.recording ? @"record.circle.fill" : @"slider.horizontal.3");
        controls.bezelColor=copy.recording ? [touchAccent() colorWithAlphaComponent:.7] : touchSurface();
        controls.contentTintColor=copy.recording ? NSColor.whiteColor : touchAccent();
    }
    self.touchButtons[@"touch.stats"].title=copy.statistics ? @"Stats on" : @"Stats off";
    self.touchButtons[@"touch.hardware"].title=self.hardware ? @"Hide Mac" : @"Monitor";
    self.touchButtons[@"touch.mute"].title=copy.muted ? @"Unmute" : @"Mute";
    self.touchVolumeText.stringValue=[NSString stringWithFormat:@"%.0f%%",nativePlaybackVolume()*100];
    NSArray* pageNames=@[@"Live",@"Video",@"Time",@"Drops",@"Mac",@"I/O"];
    self.touchPageLabel.stringValue=pageNames[MIN(5,MAX(0,self.touchDashboard.page))];
    [self.touchPageLabel setAccessibilityLabel:[NSString stringWithFormat:@"Statistics page %ld of 6: %@",(long)self.touchDashboard.page+1,self.touchPageLabel.stringValue]];
    if (self.touchVolume) { self.touchVolume.slider.doubleValue=nativePlaybackVolume(); self.touchVolume.slider.trackFillColor=touchAccent(); }
    for (NSString* key in self.touchButtons) {
        NSButton* button=self.touchButtons[key];
        [button setAccessibilityLabel:button.toolTip.length ? [NSString stringWithFormat:@"%@ · %@",button.title,button.toolTip] : button.title];
    }
    for (NSButton* button in self.touchButtons.allValues) button.needsDisplay=YES;
    if (self.touchLiveStats) [info setAccessibilityLabel:[NSString stringWithFormat:@"%@; %@; tap for more stream information",connectionDescription(copy.connection),self.touchInlineDashboard.accessibilityLabel]];
}
- (void)invalidateTouchBar {
    self.touchInvalidating=YES;
    if (self.touchFullWidthPresented) { self.touchFullWidthPresented=NO; touchDismissFullWidth(self.streamTouchBar); }
    [self.touchTimer invalidate]; self.touchTimer=nil; self.touchDashboard.active=NO; self.touchInlineDashboard.active=NO;
    for (NSPopoverTouchBarItem* item in self.touchPopovers) { [item dismissPopover:nil]; item.popoverTouchBar.delegate=nil; }
    for (NSButton* button in self.touchButtons.allValues) { button.target=nil; button.action=NULL; }
    self.touchVolume.target=nil; self.touchVolume.action=NULL;
    self.touchPageLabel=nil;
    if (self.window.touchBar==self.streamTouchBar) self.window.touchBar=self.previousTouchBar;
    self.streamTouchBar.delegate=nil; self.streamTouchBar=nil; self.previousTouchBar=nil;
    self.touchButtons=nil; self.touchPopovers=nil; self.touchDashboard=nil; self.touchInlineDashboard=nil; self.touchVolume=nil; self.touchVolumeText=nil;
}
@end
