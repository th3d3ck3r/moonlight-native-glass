#import <AppKit/AppKit.h>
#include <SDL.h>
#include <mutex>
#include "nativetitlebar.h"
#include "nativeoverlay.h"

static NSString* const captureID = @"NativeCapture";
static NSString* const hostID = @"NativeHost";
static NSString* const statisticsID = @"NativeStatistics";
static NSString* const batteryID = @"NativeControllerBattery";
static NSString* const connectionID = @"NativeConnection";
struct TitleState { bool captured=false; bool statistics=false; NativeConnectionState connection=NativeConnectionState::Connecting; };
static TitleState state;
static std::mutex stateMutex;
static unsigned epoch=0;
static bool pending=false;

static NSString* connectionDescription(NativeConnectionState value) {
    switch (value) {
        case NativeConnectionState::Idle: return @"No stream connection";
        case NativeConnectionState::Connecting: return @"Connecting to host";
        case NativeConnectionState::Connected: return @"Connected · No connection warning reported";
        case NativeConnectionState::Poor: return @"Connected · Engine reports a poor connection";
        case NativeConnectionState::Disconnected: return @"Connection lost or failed";
    }
    return @"Connection status unavailable";
}
static NSString* powerDescription(SDL_JoystickPowerLevel level) {
    switch (level) {
        case SDL_JOYSTICK_POWER_EMPTY: return @"Very low battery";
        case SDL_JOYSTICK_POWER_LOW: return @"Low battery";
        case SDL_JOYSTICK_POWER_MEDIUM: return @"Medium battery";
        case SDL_JOYSTICK_POWER_FULL: return @"High battery";
        case SDL_JOYSTICK_POWER_WIRED: return @"Wired power · Charge level unavailable";
        default: return @"Battery information unavailable";
    }
}

@interface MLStreamTitlebar : NSObject <NSToolbarDelegate, NSPopoverDelegate>
@property(nonatomic, assign) NSWindow* window;
@property(nonatomic, retain) NSToolbar* toolbar;
@property(nonatomic, retain) NSToolbar* previousToolbar;
@property(nonatomic, assign) NSWindowTitleVisibility previousTitleVisibility;
@property(nonatomic, assign) NSWindowToolbarStyle previousToolbarStyle;
@property(nonatomic, retain) NSMutableDictionary* buttons;
@property(nonatomic, retain) NSPopover* details;
@property(nonatomic, copy) NSString* detailsID;
@property(nonatomic, copy) NSString* batteryDetails;
@property(nonatomic, assign) NSUInteger controllerCount;
@property(nonatomic, assign) BOOL batteryLow;
@property(nonatomic, assign) SDL_JoystickPowerLevel batteryLevel;
- (void)refresh;
- (void)updateDetails;
- (void)closeDetails;
- (void)perform:(NSString*)identifier anchor:(NSView*)anchor;
- (void)readControllers;
- (void)invalidate;
@end
static MLStreamTitlebar* titlebar;

@implementation MLStreamTitlebar
- (instancetype)init {
    if ((self=[super init])) {
        self.buttons=[NSMutableDictionary dictionary];
        self.batteryDetails=@"No controller connected";
        for (NSString* name in @[NSWindowDidResizeNotification, NSWindowDidMiniaturizeNotification, NSWindowWillEnterFullScreenNotification, NSWindowWillExitFullScreenNotification, NSWindowDidChangeOcclusionStateNotification])
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:name object:nil];
    }
    return self;
}
- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return @[captureID,hostID,NSToolbarFlexibleSpaceItemIdentifier,statisticsID,batteryID,connectionID];
}
- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return @[captureID,NSToolbarFlexibleSpaceItemIdentifier,hostID,NSToolbarFlexibleSpaceItemIdentifier,statisticsID,connectionID];
}
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)identifier willBeInsertedIntoToolbar:(BOOL)inserted {
    NSToolbarItem* item=[[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    NSDictionary* labels=@{captureID:@"Release / Capture Input",hostID:@"Control Center",statisticsID:@"Show / Hide Statistics",batteryID:@"Controller Battery",connectionID:@"Connection Status"};
    NSButton* button=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"circle" accessibilityDescription:labels[identifier]] target:self action:@selector(clicked:)];
    button.bordered=NO; button.bezelStyle=NSBezelStyleTexturedRounded;
    button.frame=NSMakeRect(0,0,[identifier isEqual:hostID] ? 180 : ([identifier isEqual:batteryID] ? 42 : 28),26);
    if ([identifier isEqual:hostID]) {
        button.title=self.window.title.length ? self.window.title : @"Computer";
        button.image=[NSImage imageWithSystemSymbolName:@"chevron.down" accessibilityDescription:nil];
        button.imagePosition=NSImageRight; button.font=[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        button.cell.lineBreakMode=NSLineBreakByTruncatingTail;
    }
    button.toolTip=labels[identifier]; [button setAccessibilityLabel:labels[identifier]];
    self.buttons[identifier]=button; item.view=button; item.label=labels[identifier]; item.paletteLabel=item.label;
    button.translatesAutoresizingMaskIntoConstraints=NO;
    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:26],
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:[identifier isEqual:hostID] ? 70 : button.frame.size.width],
        [button.widthAnchor constraintLessThanOrEqualToConstant:[identifier isEqual:hostID] ? 230 : button.frame.size.width]
    ]];
    item.visibilityPriority=[identifier isEqual:batteryID] ? NSToolbarItemVisibilityPriorityLow : NSToolbarItemVisibilityPriorityHigh;
    // Native overflow must invoke the same action, including custom view items.
    NSMenuItem* menu=[[[NSMenuItem alloc] initWithTitle:item.label action:@selector(overflowClicked:) keyEquivalent:@""] autorelease];
    menu.target=self; menu.representedObject=identifier; item.menuFormRepresentation=menu;
    return item;
}
- (void)windowChanged:(NSNotification*)notification {
    if (notification.object==self.window) [self closeDetails];
}
- (void)overflowClicked:(NSMenuItem*)sender { [self perform:sender.representedObject anchor:nil]; }
- (void)clicked:(NSButton*)sender {
    for (NSString* identifier in self.buttons) if (self.buttons[identifier]==sender) { [self perform:identifier anchor:sender]; break; }
}
- (void)perform:(NSString*)identifier anchor:(NSView*)anchor {
    if ([identifier isEqual:captureID]) { nativeOverlayPerformAction(1); return; }
    if ([identifier isEqual:statisticsID]) { nativeOverlayPerformAction(3); return; }
    if ([identifier isEqual:hostID]) { [self closeDetails]; nativeOverlayPerformAction(102); return; }
    if (self.details.shown && [self.detailsID isEqual:identifier]) { [self closeDetails]; return; }
    [self closeDetails]; self.detailsID=identifier;
    self.details=[[[NSPopover alloc] init] autorelease]; self.details.delegate=self;
    self.details.behavior=NSPopoverBehaviorTransient; self.details.animates=NO;
    NSViewController* content=[[[NSViewController alloc] init] autorelease];
    NSView* view=[[[NSView alloc] initWithFrame:NSMakeRect(0,0,280,120)] autorelease];
    NSTextField* label=[NSTextField wrappingLabelWithString:@""]; label.frame=NSMakeRect(16,16,248,88);
    label.font=[NSFont systemFontOfSize:13]; label.selectable=NO; [view addSubview:label]; content.view=view;
    self.details.contentViewController=content; [self updateDetails];
    // A collapsed toolbar item opens from the stream's top edge instead.
    NSView* source=anchor.window ? anchor : self.window.contentView;
    NSRect rect=anchor.window ? anchor.bounds : NSMakeRect(NSMidX(source.bounds),NSMaxY(source.bounds)-1,1,1);
    [self.details showRelativeToRect:rect ofView:source preferredEdge:NSRectEdgeMinY];
}
- (void)updateDetails {
    if (!self.details) return;
    NSTextField* label=self.details.contentViewController.view.subviews.firstObject;
    TitleState copy; { std::lock_guard<std::mutex> lock(stateMutex); copy=state; }
    NSString* text=[self.detailsID isEqual:batteryID] ? self.batteryDetails : [NSString stringWithFormat:@"%@\n\nThis light reports connection state, not latency or frame pacing. Open Statistics for stream measurements.",connectionDescription(copy.connection)];
    label.stringValue=text;
    CGFloat height=ceil([text boundingRectWithSize:NSMakeSize(248,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:label.font}].size.height)+32;
    label.frame=NSMakeRect(16,16,248,height-32); self.details.contentSize=NSMakeSize(280,height);
}
- (void)refresh {
    if (!self.window) return;
    TitleState copy; { std::lock_guard<std::mutex> lock(stateMutex); copy=state; }
    NSButton* capture=self.buttons[captureID];
    capture.image=[NSImage imageWithSystemSymbolName:copy.captured ? @"cursorarrow.motionlines" : @"cursorarrow" accessibilityDescription:nil];
    capture.contentTintColor=copy.captured ? NSColor.controlAccentColor : NSColor.labelColor;
    capture.toolTip=copy.captured ? @"Input captured by host · Click to release" : @"Input released to Mac · Click to capture";
    [capture setAccessibilityLabel:capture.toolTip]; [capture setAccessibilityValue:copy.captured ? @"Captured" : @"Released"];
    NSButton* stats=self.buttons[statisticsID]; stats.image=[NSImage imageWithSystemSymbolName:@"chart.bar" accessibilityDescription:nil];
    stats.contentTintColor=copy.statistics ? NSColor.controlAccentColor : NSColor.labelColor;
    stats.toolTip=copy.statistics ? @"Hide Statistics" : @"Show Statistics"; [stats setAccessibilityLabel:stats.toolTip]; [stats setAccessibilityValue:copy.statistics ? @"Shown" : @"Hidden"];
    NSButton* connection=self.buttons[connectionID];
    NSString* symbol=@"circle.fill"; NSColor* tint=NSColor.secondaryLabelColor;
    switch (copy.connection) {
        case NativeConnectionState::Connecting: symbol=@"clock.fill"; tint=NSColor.systemOrangeColor; break;
        case NativeConnectionState::Connected: symbol=@"checkmark.circle.fill"; tint=NSColor.systemGreenColor; break;
        case NativeConnectionState::Poor: symbol=@"exclamationmark.circle.fill"; tint=NSColor.systemOrangeColor; break;
        case NativeConnectionState::Disconnected: symbol=@"xmark.circle.fill"; tint=NSColor.systemRedColor; break;
        case NativeConnectionState::Idle: break;
    }
    connection.image=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]; connection.contentTintColor=tint;
    connection.toolTip=connectionDescription(copy.connection); [connection setAccessibilityLabel:connection.toolTip];
    NSButton* battery=self.buttons[batteryID];
    NSString* batterySymbol=@"battery.0percent";
    if (self.batteryLevel==SDL_JOYSTICK_POWER_MEDIUM) batterySymbol=@"battery.50percent";
    else if (self.batteryLevel==SDL_JOYSTICK_POWER_FULL) batterySymbol=@"battery.100percent";
    else if (self.batteryLevel==SDL_JOYSTICK_POWER_WIRED) batterySymbol=@"bolt.fill";
    else if (self.batteryLevel==SDL_JOYSTICK_POWER_UNKNOWN) batterySymbol=@"questionmark";
    // The glyph is categorical; details never claim an exact percentage.
    NSImage* controllerImage=[NSImage imageWithSystemSymbolName:@"gamecontroller.fill" accessibilityDescription:nil];
    NSImage* levelImage=[NSImage imageWithSystemSymbolName:batterySymbol accessibilityDescription:nil];
    NSImage* combined=[NSImage imageWithSize:NSMakeSize(38,18) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [controllerImage drawInRect:NSMakeRect(0,1,20,16)]; [levelImage drawInRect:NSMakeRect(23,4,15,10)]; return YES;
    }]; [combined setTemplate:YES]; battery.image=combined;
    battery.contentTintColor=self.batteryLow ? NSColor.systemOrangeColor : NSColor.labelColor;
    battery.toolTip=self.batteryDetails; [battery setAccessibilityLabel:[@"Controller Battery · " stringByAppendingString:self.batteryDetails]];
    [self updateDetails];
}
- (void)readControllers {
    // Read cached SDL power data only from already-open controllers. Never open
    // devices, change input handlers, start discovery, or poll on a frame timer.
    NSMutableArray* lines=[NSMutableArray array]; BOOL low=NO; SDL_JoystickPowerLevel lowest=SDL_JOYSTICK_POWER_UNKNOWN;
    if (SDL_WasInit(SDL_INIT_JOYSTICK)) for (int i=0;i<SDL_NumJoysticks();i++) {
        if (!SDL_IsGameController(i)) continue;
        SDL_Joystick* joystick=SDL_JoystickFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
        if (!joystick || !SDL_JoystickGetAttached(joystick)) continue;
        SDL_JoystickPowerLevel level=SDL_JoystickCurrentPowerLevel(joystick);
        low |= level==SDL_JOYSTICK_POWER_EMPTY || level==SDL_JOYSTICK_POWER_LOW;
        if (lowest==SDL_JOYSTICK_POWER_UNKNOWN || (level!=SDL_JOYSTICK_POWER_UNKNOWN && level<lowest)) lowest=level;
        const char* name=SDL_JoystickName(joystick);
        [lines addObject:[NSString stringWithFormat:@"%@\n%@", name ? [NSString stringWithUTF8String:name] : @"Controller",powerDescription(level)]];
    }
    self.controllerCount=lines.count; self.batteryLow=low; self.batteryLevel=lowest;
    self.batteryDetails=lines.count ? [lines componentsJoinedByString:@"\n\n"] : @"No controller connected";
    BOOL present=NO; for (NSToolbarItem* item in self.toolbar.items) if ([item.itemIdentifier isEqual:batteryID]) present=YES;
    if (lines.count && !present) [self.toolbar insertItemWithItemIdentifier:batteryID atIndex:self.toolbar.items.count-1];
    if (!lines.count && present) {
        for (NSUInteger i=0;i<self.toolbar.items.count;i++) if ([self.toolbar.items[i].itemIdentifier isEqual:batteryID]) { [self.toolbar removeItemAtIndex:i]; break; }
        if ([self.detailsID isEqual:batteryID]) [self closeDetails];
        [self.buttons removeObjectForKey:batteryID];
    }
    [self refresh];
}
- (void)closeDetails {
    // Remove the delegate before closing/replacing a popover. A delayed close
    // notification must not clear a newer popover's state or target a dead owner.
    self.details.delegate=nil; [self.details close]; self.details=nil; self.detailsID=nil;
}
- (void)popoverDidClose:(NSNotification*)notification {
    if (notification.object==self.details) self.detailsID=nil;
}
- (void)invalidate {
    [[NSNotificationCenter defaultCenter] removeObserver:self]; [self closeDetails]; self.details.delegate=nil;
    if (self.window.toolbar==self.toolbar) {
        self.window.toolbar=self.previousToolbar; self.window.titleVisibility=self.previousTitleVisibility;
        self.window.toolbarStyle=self.previousToolbarStyle;
    }
    self.toolbar.delegate=nil; self.window=nil;
}
- (void)dealloc {
    [self invalidate]; [_toolbar release]; [_previousToolbar release]; [_buttons release]; [_details release]; [_detailsID release]; [_batteryDetails release]; [super dealloc];
}
@end

static void scheduleRefresh() {
    // Caller holds stateMutex. Every state transition is coalesced and stale
    // callbacks cannot touch a detached or subsequent stream window.
    if (pending) return; pending=true; unsigned expected=epoch;
    dispatch_async(dispatch_get_main_queue(), ^{
        { std::lock_guard<std::mutex> lock(stateMutex); if (expected!=epoch) return; pending=false; }
        [titlebar refresh];
    });
}
void nativeTitlebarSetCapture(bool captured) { std::lock_guard<std::mutex> lock(stateMutex); if (state.captured!=captured) { state.captured=captured; scheduleRefresh(); } }
void nativeTitlebarSetStatistics(bool visible) { std::lock_guard<std::mutex> lock(stateMutex); if (state.statistics!=visible) { state.statistics=visible; scheduleRefresh(); } }
void nativeTitlebarSetConnection(NativeConnectionState value) { std::lock_guard<std::mutex> lock(stateMutex); if (state.connection!=value) { state.connection=value; scheduleRefresh(); } }
void nativeTitlebarConnectionStarted() {
    std::lock_guard<std::mutex> lock(stateMutex);
    // A health/termination callback can race the asynchronous startup return.
    // Do not overwrite a more recent warning or failure with optimistic green.
    if (state.connection==NativeConnectionState::Connecting) { state.connection=NativeConnectionState::Connected; scheduleRefresh(); }
}
void nativeTitlebarControllersChanged() { [titlebar readControllers]; }
void nativeTitlebarAttach(void* window) {
    nativeTitlebarDetach();
    titlebar=[[MLStreamTitlebar alloc] init]; titlebar.window=(NSWindow*)window;
    titlebar.previousToolbar=titlebar.window.toolbar; titlebar.previousTitleVisibility=titlebar.window.titleVisibility; titlebar.previousToolbarStyle=titlebar.window.toolbarStyle;
    titlebar.toolbar=[[[NSToolbar alloc] initWithIdentifier:@"NativeStreamToolbar"] autorelease];
    titlebar.toolbar.delegate=titlebar; titlebar.toolbar.displayMode=NSToolbarDisplayModeIconOnly;
    titlebar.toolbar.allowsUserCustomization=NO; titlebar.toolbar.autosavesConfiguration=NO;
    if (@available(macOS 15.0, *)) titlebar.toolbar.centeredItemIdentifiers=[NSSet setWithObject:hostID];
    else titlebar.toolbar.centeredItemIdentifier=hostID;
    titlebar.window.titleVisibility=NSWindowTitleHidden; titlebar.window.toolbarStyle=NSWindowToolbarStyleUnifiedCompact;
    titlebar.window.toolbar=titlebar.toolbar; [titlebar readControllers];
}
void nativeTitlebarDetach() {
    { std::lock_guard<std::mutex> lock(stateMutex); epoch++; pending=false; }
    [titlebar invalidate]; [titlebar release]; titlebar=nil;
}
