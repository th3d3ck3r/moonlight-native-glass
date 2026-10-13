// Compiled with the native title bar so all controls share its tracking repair.
#import <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <array>
#include <vector>
#include <cmath>

struct MLHardwareReading {
    uint64_t cpuBusy=0,cpuTotal=0,received=0,sent=0;
    double memory=-1,gpu=-1;
    bool cpuValid=false,networkValid=false;
};
static MLHardwareReading readLocalHardware() {
    MLHardwareReading r;
    host_cpu_load_info_data_t cpu{}; mach_msg_type_number_t count=HOST_CPU_LOAD_INFO_COUNT;
    mach_port_t host=mach_host_self();
    if (host_statistics(host,HOST_CPU_LOAD_INFO,(host_info_t)&cpu,&count)==KERN_SUCCESS) {
        r.cpuBusy=uint64_t(cpu.cpu_ticks[CPU_STATE_USER])+cpu.cpu_ticks[CPU_STATE_SYSTEM]+cpu.cpu_ticks[CPU_STATE_NICE];
        r.cpuTotal=r.cpuBusy+cpu.cpu_ticks[CPU_STATE_IDLE]; r.cpuValid=true;
    }
    vm_statistics64_data_t vm{}; count=HOST_VM_INFO64_COUNT;
    vm_size_t page=0;
    if (host_page_size(host,&page)==KERN_SUCCESS && host_statistics64(host,HOST_VM_INFO64,(host_info64_t)&vm,&count)==KERN_SUCCESS) {
        // Anonymous resident + wired + compressed pages, excluding purgeable cache.
        r.memory=(MAX(0.,double(vm.internal_page_count)-vm.purgeable_count)+vm.wire_count+vm.compressor_page_count)*page;
    }
    mach_port_deallocate(mach_task_self(),host);
    ifaddrs* interfaces=nullptr;
    if (getifaddrs(&interfaces)==0) {
        for (ifaddrs* i=interfaces;i;i=i->ifa_next) if (i->ifa_addr && i->ifa_addr->sa_family==AF_LINK &&
            i->ifa_data && (i->ifa_flags & IFF_UP) && !(i->ifa_flags & IFF_LOOPBACK)) {
            // Hardware Ethernet/Wi-Fi interfaces only, avoiding VPN/bridge double counts.
            if (strncmp(i->ifa_name,"en",2)!=0) continue;
            const if_data* data=(const if_data*)i->ifa_data;
            r.received+=data->ifi_ibytes; r.sent+=data->ifi_obytes; r.networkValid=true;
        }
        freeifaddrs(interfaces);
    }
    // Registry counters are optional and vary by GPU/OS. Only accept a driver
    // reported percentage, never substitute app render time for machine GPU load.
    io_iterator_t services=0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault,IOServiceMatching("IOAccelerator"),&services)==KERN_SUCCESS) {
        io_object_t service;
        while ((service=IOIteratorNext(services))) {
            CFTypeRef value=IORegistryEntryCreateCFProperty(service,CFSTR("PerformanceStatistics"),kCFAllocatorDefault,0);
            if (value && CFGetTypeID(value)==CFDictionaryGetTypeID()) {
                for (NSString* key in @[@"Device Utilization %",@"GPU Activity(%)"]) {
                    id metric=[(NSDictionary*)value objectForKey:key];
                    if ([metric isKindOfClass:NSNumber.class]) {
                        double percent=[metric doubleValue];
                        if (std::isfinite(percent) && percent>=0 && percent<=100) r.gpu=MAX(r.gpu,percent);
                    }
                }
            }
            if (value) CFRelease(value); IOObjectRelease(service);
        }
        IOObjectRelease(services);
    }
    return r;
}

// A separate decoration sits below graph drawing and never owns input.
@interface MLHardwareMaterial : NSView
@end
@implementation MLHardwareMaterial
- (NSView*)hitTest:(NSPoint)point { return nil; }
@end
@interface MLHardwareView : NSView {
    std::array<std::vector<double>,6> history;
    MLHardwareReading previous;
    double previousTime;
    bool havePrevious;
    BOOL busy;
}
@property(nonatomic,retain) NSTimer* sampler;
@property(nonatomic,retain) NSUserDefaults* preferences;
@property(nonatomic,retain) NSView* adjustments;
@property(nonatomic,retain) NSView* material;
@property(nonatomic,assign) BOOL captured;
@property(nonatomic,assign) BOOL active;
@property(nonatomic,assign) double interval;
@property(nonatomic,assign) double seconds;
@property(nonatomic,assign) NSUInteger metrics;
- (void)stop;
- (void)sample:(NSTimer*)timer;
- (void)fit;
@end
@implementation MLHardwareView
- (BOOL)isFlipped { return YES; }
- (NSView*)hitTest:(NSPoint)point { return self.captured ? nil : [super hitTest:point]; }
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.identifier=@"NativeHardwareOverlay";
        self.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        self.material=[[[MLHardwareMaterial alloc] initWithFrame:frame] autorelease];
        self.material.wantsLayer=YES; self.material.layer.cornerRadius=12; self.material.layer.masksToBounds=YES;
        NSView* effect;
        if (@available(macOS 26.0,*)) {
            NSGlassEffectView* glass=[[[NSGlassEffectView alloc] initWithFrame:self.bounds] autorelease];
            glass.cornerRadius=12; glass.contentView=[[[NSView alloc] initWithFrame:self.bounds] autorelease];
            effect=glass;
        } else {
            NSVisualEffectView* blur=[[[NSVisualEffectView alloc] initWithFrame:self.bounds] autorelease];
            blur.material=NSVisualEffectMaterialHUDWindow; blur.blendingMode=NSVisualEffectBlendingModeWithinWindow;
            blur.state=NSVisualEffectStateActive; effect=blur;
        }
        effect.autoresizingMask=NSViewWidthSizable | NSViewHeightSizable; [self.material addSubview:effect];
        self.preferences=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
        self.interval=[self.preferences doubleForKey:@"hardwareInterval"];
        if (self.interval!=.5 && self.interval!=1 && self.interval!=2) self.interval=1;
        self.seconds=[self.preferences doubleForKey:@"hardwareHistory"];
        if (self.seconds!=60 && self.seconds!=180 && self.seconds!=300) self.seconds=60;
        self.metrics=[self.preferences objectForKey:@"hardwareMetrics"] ? [self.preferences integerForKey:@"hardwareMetrics"] & 31 : 31;
        double opacity=[self.preferences doubleForKey:@"hardwareOpacity"];
        self.alphaValue=opacity>=.35 && opacity<=1 ? opacity : .92;
        self.wantsLayer=YES; self.layer.cornerRadius=12; self.layer.masksToBounds=YES;
        for (int index=0;index<2;++index) {
            NSButton* b=[MLStreamToolbarButton buttonWithImage:[NSImage imageWithSystemSymbolName:index ? @"xmark" : @"slider.horizontal.3" accessibilityDescription:index ? @"Close Hardware Monitor" : @"Adjust Hardware Monitor"] target:self action:index ? @selector(close:) : @selector(adjust:)];
            b.bordered=NO; b.identifier=index ? @"HardwareClose" : @"HardwareAdjust";
            b.toolTip=index ? @"Close Hardware Monitor" : @"Adjust position, size and graphs"; [self addSubview:b];
        }
        self.active=YES;
        self.sampler=[NSTimer timerWithTimeInterval:self.interval target:self selector:@selector(sample:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.sampler forMode:NSRunLoopCommonModes];
        [self sample:nil];
    }
    return self;
}
- (void)viewDidMoveToSuperview {
    [super viewDidMoveToSuperview]; [self.material removeFromSuperview];
    if (self.superview) { [self.superview addSubview:self.material positioned:NSWindowBelow relativeTo:self]; [self fit]; }
}
- (void)stop { self.active=NO; [self.sampler invalidate]; self.sampler=nil; }
- (void)close:(id)sender {
    // Route through the title owner so the toolbar state and capture repair agree.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MLHardwareClose" object:self];
}
- (void)adjust:(id)sender {
    self.adjustments.hidden=!self.adjustments.hidden;
    if (!self.adjustments) {
        self.adjustments=[[[NSView alloc] initWithFrame:NSZeroRect] autorelease];
        [self addSubview:self.adjustments];
        NSArray* names=@[@"CPU",@"RAM",@"GPU",@"Network",@"Thermal"];
        for (NSUInteger i=0;i<5;++i) {
            NSButton* b=[MLStreamToolbarButton checkboxWithTitle:names[i] target:self action:@selector(metric:)];
            b.tag=i; b.state=(self.metrics & (1<<i)) ? NSControlStateValueOn : NSControlStateValueOff;
            b.frame=NSMakeRect(10+(i%3)*92,8+(i/3)*26,90,24); [self.adjustments addSubview:b];
        }
        for (NSUInteger i=0;i<2;++i) {
            NSPopUpButton* b=[[[NSPopUpButton alloc] initWithFrame:NSMakeRect(10+i*132,64,126,26) pullsDown:NO] autorelease];
            [b addItemsWithTitles:i ? @[@"History: 1 min",@"History: 3 min",@"History: 5 min"] : @[@"Update: 0.5 sec",@"Update: 1 sec",@"Update: 2 sec"]];
            b.tag=i; b.target=self; b.action=@selector(option:);
            [b selectItemAtIndex:i ? (self.seconds==60 ? 0 : self.seconds==180 ? 1 : 2) : (self.interval==.5 ? 0 : self.interval==1 ? 1 : 2)];
            [self.adjustments addSubview:b];
        }
        NSSlider* opacity=[MLStreamVolumeSlider sliderWithValue:self.alphaValue minValue:.35 maxValue:1 target:self action:@selector(opacity:)];
        opacity.trackFillColor=crimsonEnabled() ? [NSColor colorWithSRGBRed:.95 green:.19 blue:.32 alpha:1] : nil;
        opacity.frame=NSMakeRect(74,100,184,24); [opacity setAccessibilityLabel:@"Hardware Monitor Opacity"];
        [self.adjustments addSubview:opacity];
        NSTextField* label=[NSTextField labelWithString:@"Opacity"]; label.frame=NSMakeRect(10,103,64,20); [self.adjustments addSubview:label];
        self.adjustments.hidden=NO;
    }
    [self fit]; self.needsDisplay=YES;
}
- (void)metric:(NSButton*)sender {
    if (sender.state==NSControlStateValueOn) self.metrics|=1<<sender.tag; else self.metrics &= ~(1<<sender.tag);
    [self.preferences setInteger:self.metrics forKey:@"hardwareMetrics"]; self.needsDisplay=YES;
}
- (void)option:(NSPopUpButton*)sender {
    if (sender.tag) {
        self.seconds=sender.indexOfSelectedItem==0 ? 60 : sender.indexOfSelectedItem==1 ? 180 : 300;
        [self.preferences setDouble:self.seconds forKey:@"hardwareHistory"];
    } else {
        self.interval=sender.indexOfSelectedItem==0 ? .5 : sender.indexOfSelectedItem==1 ? 1 : 2;
        [self.preferences setDouble:self.interval forKey:@"hardwareInterval"];
        // A cadence change starts a fresh evenly-spaced graph history.
        for (auto& values:history) values.clear(); havePrevious=false;
        [self.sampler invalidate];
        self.sampler=[NSTimer timerWithTimeInterval:self.interval target:self selector:@selector(sample:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.sampler forMode:NSRunLoopCommonModes];
    }
    requestTitlebarInputRepair(self.window); self.needsDisplay=YES;
}
- (void)opacity:(NSSlider*)sender {
    self.alphaValue=sender.doubleValue; [self.preferences setDouble:self.alphaValue forKey:@"hardwareOpacity"];
    requestTitlebarInputRepair(self.window);
}
- (void)setCaptured:(BOOL)value { _captured=value; if (value) self.adjustments.hidden=YES; self.needsDisplay=YES; }
- (void)sample:(NSTimer*)timer {
    if (!self.active || busy || (self.window && !self.window.visible)) return;
    busy=YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        MLHardwareReading current=readLocalHardware();
        double time=NSProcessInfo.processInfo.systemUptime;
        dispatch_async(dispatch_get_main_queue(), ^{
            busy=NO; if (!self.active) return;
            double cpu=-1,rx=-1,tx=-1,elapsed=time-previousTime;
            if (havePrevious && elapsed>0) {
                if (current.cpuValid && previous.cpuValid && current.cpuTotal>previous.cpuTotal && current.cpuBusy>=previous.cpuBusy)
                    cpu=MIN(100.,100.*double(current.cpuBusy-previous.cpuBusy)/double(current.cpuTotal-previous.cpuTotal));
                if (current.networkValid && previous.networkValid && current.received>=previous.received && current.sent>=previous.sent) {
                    rx=(current.received-previous.received)/elapsed/1000000.; tx=(current.sent-previous.sent)/elapsed/1000000.;
                }
            }
            previous=current; previousTime=time; havePrevious=true;
            double values[]={cpu,current.memory<0 ? -1 : current.memory/double(NSProcessInfo.processInfo.physicalMemory)*100.,current.gpu,rx,tx,double(NSProcessInfo.processInfo.thermalState)};
            for (size_t i=0;i<6;++i) { history[i].push_back(values[i]); size_t limit=size_t(self.seconds/self.interval)+1; if (history[i].size()>limit) history[i].erase(history[i].begin(),history[i].begin()+(history[i].size()-limit)); }
            self.needsDisplay=YES;
        });
    });
}
- (void)fit {
    if (!self.superview) return;
    NSRect bounds=self.superview.bounds; NSRect f=self.frame;
    f.size.width=MIN(MAX(280,f.size.width),bounds.size.width);
    f.size.height=MIN(MAX(self.adjustments && !self.adjustments.hidden ? 450 : 320,f.size.height),MAX(0,bounds.size.height-32));
    f.origin.x=MAX(0,MIN(f.origin.x,NSMaxX(bounds)-f.size.width));
    CGFloat minY=self.superview.flipped ? 32 : 0;
    CGFloat maxY=MAX(minY,NSMaxY(bounds)-f.size.height-(self.superview.flipped ? 0 : 32));
    f.origin.y=MAX(minY,MIN(f.origin.y,maxY));
    if (!NSEqualRects(self.frame,f)) self.frame=f;
    self.material.frame=f; self.material.alphaValue=self.alphaValue;
    NSView* effect=self.material.subviews.firstObject;
    if (@available(macOS 26.0,*)) if ([effect isKindOfClass:NSGlassEffectView.class]) ((NSGlassEffectView*)effect).tintColor=crimsonEnabled() ? [[NSColor colorWithSRGBRed:.95 green:.19 blue:.32 alpha:1] colorWithAlphaComponent:.25] : nil;
    NSUInteger i=0; for (NSView* view in self.subviews) if ([view isKindOfClass:NSButton.class]) view.frame=NSMakeRect(f.size.width-60+28*i++,5,24,24);
    self.adjustments.frame=NSMakeRect(4,34,f.size.width-8,132);
}
- (void)mouseDown:(NSEvent*)event {
    NSPoint start=[self convertPoint:event.locationInWindow fromView:nil];
    BOOL resize=start.x>self.bounds.size.width-24 && start.y>self.bounds.size.height-24;
    if (!resize && start.y>34) return;
    NSRect initial=self.frame; NSPoint startInParent=[self.superview convertPoint:event.locationInWindow fromView:nil];
    NSEvent* next;
    while ((next=[self.window nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp])) {
        if (next.type==NSEventTypeLeftMouseUp) { [NSApp postEvent:next atStart:YES]; break; }
        NSPoint delta=[self.superview convertPoint:next.locationInWindow fromView:nil]; delta.x-=startInParent.x; delta.y-=startInParent.y;
        NSRect frame=initial;
        if (resize) {
            frame.size.width+=delta.x;
            if (self.superview.flipped) frame.size.height+=delta.y;
            else { frame.size.height-=delta.y; frame.origin.y+=delta.y; }
        }
        else { frame.origin.x+=delta.x; frame.origin.y+=delta.y; }
        self.frame=frame; [self fit];
    }
    NSRect bounds=self.superview.bounds;
    [self.preferences setDouble:self.frame.origin.x/MAX(1,bounds.size.width-self.frame.size.width) forKey:@"hardwareX"];
    double savedY=self.superview.flipped ? 1-(self.frame.origin.y-32)/MAX(1,bounds.size.height-self.frame.size.height-32) : self.frame.origin.y/MAX(1,bounds.size.height-self.frame.size.height-32);
    [self.preferences setDouble:savedY forKey:@"hardwareY"];
    [self.preferences setDouble:self.frame.size.width forKey:@"hardwareWidth"];
    [self.preferences setDouble:self.frame.size.height forKey:@"hardwareHeight"];
    requestTitlebarInputRepair(self.window);
}
- (void)drawRect:(NSRect)dirty {
    [super drawRect:dirty];
    BOOL crimson=crimsonEnabled();
    NSColor* accent=crimson ? [NSColor colorWithSRGBRed:.95 green:.19 blue:.32 alpha:1] : NSColor.controlAccentColor;
    [[NSColor colorWithSRGBRed:.035 green:.025 blue:.03 alpha:NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency ? 1 : .48] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12] fill];
    [[accent colorWithAlphaComponent:.4] setStroke]; [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,.5,.5) xRadius:12 yRadius:12] stroke];
    NSDictionary* small=@{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.secondaryLabelColor};
    NSDictionary* bold=@{NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.whiteColor};
    [@"LOCAL HARDWARE" drawAtPoint:NSMakePoint(12,11) withAttributes:small];
    CGFloat top=self.adjustments && !self.adjustments.hidden ? 174 : 40;
    NSUInteger rows=0; for (NSUInteger i=0;i<5;++i) if (self.metrics & (1<<i)) ++rows;
    CGFloat rowHeight=(self.bounds.size.height-top-20)/MAX(1,rows);
    NSArray* labels=@[@"CPU",@"RAM",@"GPU",@"NETWORK · WI-FI / ETHERNET",@"TEMPERATURE / THERMAL"];
    for (NSUInteger i=0;i<5;++i) if (self.metrics & (1<<i)) {
        size_t channel=i==4 ? 5 : i; double value=history[channel].empty() ? -1 : history[channel].back();
        NSString* text=value<0 ? @"Unavailable" : [NSString stringWithFormat:@"%.1f%%",value];
        if (i==1 && value>=0) text=[NSString stringWithFormat:@"%.1f / %.1f GB",value/100.*NSProcessInfo.processInfo.physicalMemory/1073741824.,NSProcessInfo.processInfo.physicalMemory/1073741824.];
        if (i==3 && value>=0) text=[NSString stringWithFormat:@"↓ %.2f  ↑ %.2f MB/s",value,history[4].back()];
        if (i==4) { NSArray* thermal=@[@"Normal",@"Warm",@"High",@"Critical"]; text=value<0 ? @"Thermal status unavailable" : [@"°C unavailable · " stringByAppendingString:thermal[MIN(3,MAX(0,int(value)))]]; }
        [labels[i] drawAtPoint:NSMakePoint(12,top) withAttributes:small];
        [text drawAtPoint:NSMakePoint(12,top+16) withAttributes:bold];
        if (i!=4 && rowHeight>42) {
            NSRect graph=NSMakeRect(12,top+37,self.bounds.size.width-24,MAX(4,rowHeight-44));
            [[NSColor colorWithWhite:1 alpha:.06] setStroke]; NSBezierPath* baseline=[NSBezierPath bezierPath]; [baseline moveToPoint:NSMakePoint(graph.origin.x,NSMaxY(graph))]; [baseline lineToPoint:NSMakePoint(NSMaxX(graph),NSMaxY(graph))]; [baseline stroke];
            double scale=100;
            if (i==3) { scale=.1; for (size_t c=3;c<=4;++c) for (double sample:history[c]) scale=MAX(scale,sample); }
            for (size_t c=channel;c<=channel+(i==3 ? 1 : 0);++c) {
                NSBezierPath* path=[NSBezierPath bezierPath]; BOOL started=NO;
                size_t capacity=size_t(self.seconds/self.interval)+1;
                for (size_t n=0;n<history[c].size();++n) {
                    double sample=history[c][n]; if (sample<0) { started=NO; continue; }
                    NSPoint point=NSMakePoint(NSMaxX(graph)-double(history[c].size()-1-n)/MAX(size_t(1),capacity-1)*graph.size.width,NSMaxY(graph)-MIN(1.,sample/scale)*graph.size.height);
                    if (started) [path lineToPoint:point]; else [path moveToPoint:point]; started=YES;
                }
                [(c==4 ? NSColor.systemCyanColor : accent) setStroke]; path.lineWidth=1.5; [path stroke];
            }
        }
        top+=rowHeight;
    }
    [@"↘" drawAtPoint:NSMakePoint(self.bounds.size.width-20,self.bounds.size.height-20) withAttributes:small];
    if (!rows) [@"Choose metrics in Adjust" drawAtPoint:NSMakePoint(12,top+12) withAttributes:bold];
}
- (void)dealloc { [self stop]; [_preferences release]; [_adjustments release]; [_material release]; [super dealloc]; }
@end
