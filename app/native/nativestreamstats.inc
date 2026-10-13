#include "nativestreamstats.h"
// Reuse the native title-button tracking boundary in this child overlay.
static CGFloat streamDetailHeight(const NativeStreamStats::Row& row,CGFloat width,CGFloat scale) {
    NSString* text=[NSString stringWithFormat:@"%@\n%@",[[NSString stringWithUTF8String:row.display.c_str()] uppercaseString],[NSString stringWithUTF8String:row.value.c_str()]];
    NSRect needed=[text boundingRectWithSize:NSMakeSize(MAX(1,width-8*scale),CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12.5*scale weight:NSFontWeightSemibold]}];
    return MAX(48*scale,ceil(needed.size.height)+8*scale);
}
@class MLStreamStatsView;
@interface MLStreamStatsDocument : NSView
@end
@implementation MLStreamStatsDocument
- (BOOL)isFlipped { return YES; }
@end
@interface MLStreamStatsGraph : NSView
@property(nonatomic,assign) MLStreamStatsView* owner;
@property(nonatomic,copy) NSString* key;
@property(nonatomic,assign) BOOL percentage;
@end
@interface MLStreamStatsView : NSView {
    NativeStreamStats::History history;
    std::vector<NativeStreamStats::Row> rows;
    uint64_t lastRevision;
    double latestTime;
}
@property(nonatomic,retain) NSUserDefaults* preferences;
@property(nonatomic,retain) NSScrollView* scroll;
@property(nonatomic,retain) NSView* document;
@property(nonatomic,retain) NSButton* graphsButton;
@property(nonatomic,assign) BOOL graphs;
@property(nonatomic,assign) BOOL captured;
@property(nonatomic,assign) CGFloat scale;
- (void)present:(NSString*)text revision:(uint64_t)revision;
- (void)reset;
- (void)refresh;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;
- (void)drawGraph:(NSString*)key inRect:(NSRect)rect percentage:(BOOL)percentage;
@end
@implementation MLStreamStatsGraph
- (BOOL)isFlipped { return YES; }
- (NSView*)hitTest:(NSPoint)point { return nil; }
- (void)drawRect:(NSRect)dirty { [self.owner drawGraph:self.key inRect:self.bounds percentage:self.percentage]; }
- (void)dealloc { [_key release]; [super dealloc]; }
@end
@implementation MLStreamStatsView
- (BOOL)isFlipped { return YES; }
- (NSView*)hitTest:(NSPoint)point { return self.captured ? nil : [super hitTest:point]; }
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.identifier=@"NativeStreamStatistics";
        self.preferences=[[[NSUserDefaults alloc] initWithSuiteName:suite] autorelease];
        self.scale=1;
        self.graphsButton=[MLStreamToolbarButton buttonWithTitle:@"Graphs" target:self action:@selector(toggleGraphs:)];
        self.graphsButton.identifier=@"StreamStatisticsGraphs"; self.graphsButton.bordered=NO;
        self.graphsButton.font=[NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        self.graphsButton.image=[NSImage imageWithSystemSymbolName:@"chart.xyaxis.line" accessibilityDescription:nil];
        self.graphsButton.imagePosition=NSImageLeft; [self addSubview:self.graphsButton];
        self.scroll=[[[NSScrollView alloc] initWithFrame:NSZeroRect] autorelease];
        self.scroll.drawsBackground=NO; self.scroll.hasVerticalScroller=YES; self.scroll.autohidesScrollers=YES;
        self.scroll.borderType=NSNoBorder; self.scroll.scrollerStyle=NSScrollerStyleOverlay;
        self.document=[[[MLStreamStatsDocument alloc] initWithFrame:NSZeroRect] autorelease];
        self.scroll.documentView=self.document; [self addSubview:self.scroll];
        [self refresh];
    }
    return self;
}
- (void)reset { history.clear(); rows.clear(); lastRevision=0; [self refresh]; }
- (void)present:(NSString*)text revision:(uint64_t)revision {
    if (revision==lastRevision) return;
    lastRevision=revision; latestTime=NSProcessInfo.processInfo.systemUptime;
    rows=NativeStreamStats::parse(text.UTF8String ?: ""); history.append(rows,latestTime);
    [self refresh];
}
- (NSUInteger)sampleCount {
    size_t count=0; for (auto& entry:history.samples) count=MAX(count,entry.second.size()); return count;
}
- (void)toggleGraphs:(id)sender {
    [self.preferences setBool:!self.graphs forKey:@"streamStatsGraphs"];
    [self.preferences synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:changed object:nil userInfo:nil deliverImmediately:YES];
    [self refresh];
}
- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    BOOL columns=width>=420*self.scale;
    CGFloat total=38*self.scale; NSUInteger column=0;
    for (const auto& row:rows) {
        if (!row.metric) {
            if (column) { total+=(self.graphs ? 65 : 43)*self.scale; column=0; }
            total+=streamDetailHeight(row,MAX(1,width-16*self.scale),self.scale);
        } else if (columns && !column) column=1;
        else { total+=(self.graphs ? 65 : 43)*self.scale; column=0; }
    }
    if (column) total+=(self.graphs ? 65 : 43)*self.scale;
    return total+8*self.scale;
}
- (void)refresh {
    self.graphs=[self.preferences objectForKey:@"streamStatsGraphs"] ? [self.preferences boolForKey:@"streamStatsGraphs"] : YES;
    self.graphsButton.state=self.graphs ? NSControlStateValueOn : NSControlStateValueOff;
    self.graphsButton.contentTintColor=self.graphs ? (crimsonEnabled() ? crimsonAccent() : NSColor.controlAccentColor) : NSColor.secondaryLabelColor;
    self.graphsButton.toolTip=self.graphs ? @"Hide stream statistics graphs" : @"Show stream statistics graphs";
    [self.graphsButton setAccessibilityLabel:self.graphsButton.toolTip];
    [self.graphsButton setAccessibilityValue:self.graphs ? @"On" : @"Off"];
    [self layoutRows]; self.needsDisplay=YES;
}
- (void)setFrameSize:(NSSize)size { [super setFrameSize:size]; if (self.scroll) [self layoutRows]; }
- (void)layoutRows {
    CGFloat width=self.bounds.size.width,height=self.bounds.size.height,s=self.scale;
    self.graphsButton.frame=NSMakeRect(MAX(0,width-94*s),6*s,82*s,24*s);
    self.scroll.frame=NSMakeRect(8*s,34*s,MAX(0,width-16*s),MAX(0,height-40*s));
    NSPoint offset=self.scroll.contentView.bounds.origin;
    for (NSView* view in [[self.document.subviews copy] autorelease]) {
        if ([view isKindOfClass:MLStreamStatsGraph.class]) ((MLStreamStatsGraph*)view).owner=nil;
        [view removeFromSuperview];
    }
    CGFloat contentWidth=self.scroll.contentSize.width;
    BOOL columns=width>=420*s;
    CGFloat gap=12*s,cellWidth=columns ? (contentWidth-gap)/2 : contentWidth;
    CGFloat rowHeight=(self.graphs ? 65 : 43)*s;
    // A flipped document starts at the top and preserves scroll offset on reflow.
    CGFloat total=MAX(self.scroll.contentSize.height,[self preferredHeightForWidth:width]-40*s);
    self.document.frame=NSMakeRect(0,0,contentWidth,total);
    CGFloat top=0; NSUInteger column=0;
    for (const auto& row:rows) {
        if (!row.metric && column) { top+=rowHeight; column=0; }
        CGFloat rh=row.metric ? rowHeight : streamDetailHeight(row,contentWidth,s);
        CGFloat x=row.metric && columns ? column*(cellWidth+gap) : 0;
        CGFloat w=row.metric ? cellWidth : contentWidth;
        NSString* heading=[[NSString stringWithUTF8String:row.display.c_str()] uppercaseString];
        NSString* value=[NSString stringWithUTF8String:row.value.c_str()];
        NSMutableAttributedString* text=[[[NSMutableAttributedString alloc] initWithString:[heading stringByAppendingString:@"\n"] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10.5*s weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}] autorelease];
        [text appendAttributedString:[[[NSAttributedString alloc] initWithString:value attributes:@{NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:12.5*s weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor}] autorelease]];
        NSTextField* label=[NSTextField wrappingLabelWithString:@""]; label.attributedStringValue=text;
        label.selectable=NO; label.frame=NSMakeRect(x+4*s,top+2*s,MAX(0,w-8*s),row.metric ? 36*s : rh-4*s);
        [label setAccessibilityLabel:[NSString stringWithFormat:@"%@: %@",[NSString stringWithUTF8String:row.label.c_str()],value]];
        [self.document addSubview:label];
        if (row.metric && self.graphs) {
            MLStreamStatsGraph* graph=[[[MLStreamStatsGraph alloc] initWithFrame:NSMakeRect(x+4*s,top+38*s,MAX(0,w-8*s),MAX(0,rh-46*s))] autorelease];
            graph.owner=self; graph.key=[NSString stringWithUTF8String:row.label.c_str()]; graph.percentage=row.percentage;
            [self.document addSubview:graph];
        }
        if (row.metric && columns && !column) column=1;
        else { column=0; top+=rh; }
    }
    offset.y=MAX(0,MIN(offset.y,MAX(0,total-self.scroll.contentSize.height)));
    [self.scroll.contentView scrollToPoint:offset]; [self.scroll reflectScrolledClipView:self.scroll.contentView];
}
- (void)drawRect:(NSRect)dirty {
    [[NSColor colorWithSRGBRed:.035 green:.025 blue:.03 alpha:NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency ? 1 : .48] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12] fill];
    [[(crimsonEnabled() ? crimsonAccent() : NSColor.controlAccentColor) colorWithAlphaComponent:.4] setStroke];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,.5,.5) xRadius:12 yRadius:12] stroke];
    [@"STREAM STATISTICS" drawAtPoint:NSMakePoint(12*self.scale,11*self.scale) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11*self.scale weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];
}
- (void)drawGraph:(NSString*)key inRect:(NSRect)rect percentage:(BOOL)percentage {
    [[NSColor colorWithWhite:1 alpha:.06] setStroke]; NSBezierPath* baseline=[NSBezierPath bezierPath];
    [baseline moveToPoint:NSMakePoint(0,NSMaxY(rect)-1)]; [baseline lineToPoint:NSMakePoint(NSMaxX(rect),NSMaxY(rect)-1)]; [baseline stroke];
    auto found=history.samples.find(key.UTF8String); if (found==history.samples.end()) return;
    double maximum=percentage ? 100 : 1;
    if (!percentage) for (const auto& point:found->second) if (std::isfinite(point.value)) maximum=MAX(maximum,point.value);
    NSBezierPath* path=[NSBezierPath bezierPath]; BOOL started=NO; double last=0;
    for (const auto& point:found->second) {
        if (!std::isfinite(point.value)) { started=NO; continue; }
        NSPoint position=NSMakePoint(MAX(0,MIN(1.,1-(latestTime-point.time)/60))*rect.size.width,NSMaxY(rect)-1-MIN(1.,point.value/maximum)*MAX(0,rect.size.height-2));
        if (started && point.time-last<=5) [path lineToPoint:position]; else [path moveToPoint:position];
        started=YES; last=point.time;
    }
    NSColor* accent=crimsonEnabled() ? crimsonAccent() : NSColor.controlAccentColor;
    [accent setStroke]; path.lineWidth=1.5; [path stroke];
    if (found->second.size()==1 && std::isfinite(found->second.back().value)) {
        // A first real sample is a point, not a fabricated history segment.
        double value=found->second.back().value;
        CGFloat x=MAX(1.5,rect.size.width-1.5),y=MAX(1.5,MIN(rect.size.height-1.5,NSMaxY(rect)-1-MIN(1.,value/maximum)*MAX(0,rect.size.height-2)));
        [accent setFill]; [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x-1.5,y-1.5,3,3)] fill];
    }
}
- (void)dealloc {
    self.graphsButton.target=nil;
    for (NSView* view in self.document.subviews) if ([view isKindOfClass:MLStreamStatsGraph.class]) ((MLStreamStatsGraph*)view).owner=nil;
    [_preferences release]; [_graphsButton release]; [_scroll release]; [_document release]; [super dealloc];
}
@end
