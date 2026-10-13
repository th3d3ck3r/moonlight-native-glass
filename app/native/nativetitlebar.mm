#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include <mutex>
#include <string>
#include "nativetitlebar.h"
#include "nativeoverlay.h"

static BOOL crimsonEnabled() {
    NSUserDefaults* defaults = [[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    return [defaults objectForKey:@"crimsonGlass"] ? [defaults boolForKey:@"crimsonGlass"] : YES;
}

static NSString* const captureID = @"NativeCapture";
static NSString* const hostID = @"NativeHost";
static NSString* const statisticsID = @"NativeStatistics";
static NSString* const batteryID = @"NativeControllerBattery";
static NSString* const recordID = @"NativeRecord";
static NSString* const replayID = @"NativeReplay";
static NSString* const connectionID = @"NativeConnection";
struct TitleState { bool recorder=false,recording=false,buffering=false,replayReady=false,saving=false,recorderFailed=false; uint64_t seconds=0; std::string recordingMessage="Recording disabled"; bool captured=false; bool statistics=false; NativeConnectionState connection=NativeConnectionState::Connecting; };
static TitleState state;
static std::mutex stateMutex;
static unsigned epoch=0;
static bool pending=false;

static void requestTitlebarInputRepair(NSWindow* window);

// SDL's Cocoa backend observes title-bar mouse-down before AppKit starts a
// button's tracking loop. AppKit consumes the matching mouse-up inside that
// loop, so return a title-bar release to SDL's normal event pump afterwards.
// Otherwise SDL keeps its focus-click-pending flag and disables confinement.
@interface MLStreamToolbarButton : NSButton
@end
@implementation MLStreamToolbarButton
- (void)mouseDown:(NSEvent*)event {
    [super mouseDown:event];
    if (([NSEvent pressedMouseButtons] & 1) == 0) {
        NSEvent* release=[NSEvent mouseEventWithType:NSEventTypeLeftMouseUp
            location:event.locationInWindow modifierFlags:event.modifierFlags
            timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:event.windowNumber
            context:nil eventNumber:event.eventNumber clickCount:event.clickCount pressure:0];
        [NSApp postEvent:release atStart:YES];
    }
    requestTitlebarInputRepair(self.window);
}
@end

// Decorative chrome must not intercept native buttons, drag events or SDL input.
@interface MLTitlebarBackground : NSView
@end
@implementation MLTitlebarBackground
- (NSView*)hitTest:(NSPoint)point { return nil; }
@end

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
@property(nonatomic, retain) id eventMonitor;
@property(nonatomic, retain) NSTimer* inputRepairTimer;
@property(nonatomic, retain) NSMenu* trackingMenu;
@property(nonatomic, retain) NSToolbar* toolbar;
@property(nonatomic, retain) NSToolbar* previousToolbar;
@property(nonatomic, assign) NSWindowTitleVisibility previousTitleVisibility;
@property(nonatomic, assign) NSWindowToolbarStyle previousToolbarStyle;
@property(nonatomic, assign) BOOL previousTransparency;
@property(nonatomic, assign) NSTitlebarSeparatorStyle previousSeparator;
@property(nonatomic, retain) NSColor* previousBackgroundColor;
@property(nonatomic, retain) NSView* background;
@property(nonatomic, retain) NSTitlebarAccessoryViewController* accessory;
@property(nonatomic, retain) NSView* row;
@property(nonatomic, retain) NSButton* overflow;
@property(nonatomic, assign) BOOL presentationInstalled;
@property(nonatomic, assign) BOOL previousFullSizeContent;
@property(nonatomic, assign) BOOL previousMovable;
@property(nonatomic, assign) CGFloat titleHeight;
@property(nonatomic, retain) NSView* nativeChrome;
@property(nonatomic, assign) BOOL chromeVisible;
@property(nonatomic, assign) NSUInteger visibilityRevision;
@property(nonatomic, assign) BOOL windowTransition;
@property(nonatomic, assign) BOOL fullscreenTransition;
@property(nonatomic, retain) NSMutableDictionary* buttons;
@property(nonatomic, retain) NSPopover* details;
@property(nonatomic, copy) NSString* detailsID;
@property(nonatomic, copy) NSString* batteryDetails;
@property(nonatomic, assign) NSUInteger controllerCount;
@property(nonatomic, assign) BOOL batteryLow;
@property(nonatomic, assign) SDL_JoystickPowerLevel batteryLevel;
- (void)requestInputRepair;
- (void)repairInput:(NSTimer*)timer;
- (void)refresh;
- (void)updateDetails;
- (void)closeDetails;
- (void)perform:(NSString*)identifier anchor:(NSView*)anchor;
- (void)readControllers;
- (void)updateWindowToolbar;
- (void)invalidate;
- (void)layoutControls;
- (void)updateVisibility;
@end
static MLStreamTitlebar* titlebar;

static void requestTitlebarInputRepair(NSWindow* window) {
    if (window && titlebar.window==window) [titlebar requestInputRepair];
}

@implementation MLStreamTitlebar
- (void)requestInputRepair {
    if (!self.window || self.inputRepairTimer) return;
    // A native button/menu can consume mouse-up in a nested tracking loop.
    // Wait until tracking finishes, then let SDL process that release before
    // asking the production input handler to re-establish prior capture.
    self.inputRepairTimer=[NSTimer scheduledTimerWithTimeInterval:0.02 target:self
        selector:@selector(repairInput:) userInfo:nil repeats:NO];
}
- (void)repairInput:(NSTimer*)timer {
    self.inputRepairTimer=nil;
    if (!self.window || !self.window.visible || self.window.miniaturized ||
        self.windowTransition || self.fullscreenTransition ||
        !NSApp.active || !self.window.keyWindow) return;
    if ([NSEvent pressedMouseButtons] & 1) { [self requestInputRepair]; return; }
    // Popovers own local interaction until dismissal. Their close callbacks
    // request repair; never recapture the host behind an open native popup.
    if (self.details.shown || self.trackingMenu) return;
    SDL_Window* window=SDL_GetKeyboardFocus();
    if (!window) return;
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    if (!SDL_GetWindowWMInfo(window,&info) || info.info.cocoa.window!=self.window) return;
    nativeOverlayPerformAction(220,SDL_GetWindowID(window));
}
- (instancetype)init {
    if ((self=[super init])) {
        self.buttons=[NSMutableDictionary dictionary];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:) name:@"com.moonlight-stream.NativeGlass.overlaySettingsChanged" object:nil];
        self.batteryDetails=@"No controller connected";
        for (NSString* name in @[NSWindowDidMoveNotification, NSWindowDidEndLiveResizeNotification, NSWindowDidResizeNotification, NSWindowDidMiniaturizeNotification, NSWindowWillEnterFullScreenNotification, NSWindowWillExitFullScreenNotification, NSWindowDidEnterFullScreenNotification, NSWindowDidExitFullScreenNotification, NSWindowDidChangeOcclusionStateNotification, @"NSWindowDidFailToEnterFullScreenNotification", @"NSWindowDidFailToExitFullScreenNotification"])
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:name object:nil];
        for (NSString* name in @[NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification])
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(focusChanged:) name:name object:nil];
        for (NSString* name in @[NSApplicationDidBecomeActiveNotification, NSApplicationDidResignActiveNotification])
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(focusChanged:) name:name object:NSApp];
    }
    return self;
}
- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return @[captureID,hostID,NSToolbarFlexibleSpaceItemIdentifier,statisticsID,recordID,replayID,batteryID,connectionID];
}
- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return @[captureID,NSToolbarFlexibleSpaceItemIdentifier,hostID,NSToolbarFlexibleSpaceItemIdentifier,statisticsID,recordID,replayID,connectionID];
}
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)identifier willBeInsertedIntoToolbar:(BOOL)inserted {
    NSToolbarItem* item=[[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    NSDictionary* labels=@{captureID:@"Release / Capture Input",hostID:@"Control Center",statisticsID:@"Show / Hide Statistics",batteryID:@"Controller Battery",connectionID:@"Connection Status",recordID:@"Record / Stop",replayID:@"Save Instant Replay"};
    NSButton* button=[MLStreamToolbarButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"circle" accessibilityDescription:labels[identifier]] target:self action:@selector(clicked:)];
    button.bordered=NO; button.bezelStyle=NSBezelStyleTexturedRounded;
    button.frame=NSMakeRect(0,0,[identifier isEqual:hostID] ? 180 : ([identifier isEqual:batteryID] ? 38 : 24),22);
    button.identifier=identifier;
    button.image=[button.image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightRegular]];
    if ([identifier isEqual:hostID]) {
        button.title=self.window.title.length ? self.window.title : @"Computer";
        button.image=[NSImage imageWithSystemSymbolName:@"chevron.down" accessibilityDescription:nil];
        button.imagePosition=NSImageRight; button.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
        button.cell.lineBreakMode=NSLineBreakByTruncatingTail;
    }
    button.toolTip=labels[identifier]; [button setAccessibilityLabel:labels[identifier]];
    self.buttons[identifier]=button; item.view=button; item.label=labels[identifier]; item.paletteLabel=item.label;
    item.visibilityPriority=[identifier isEqual:batteryID] ? NSToolbarItemVisibilityPriorityLow : NSToolbarItemVisibilityPriorityHigh;
    // Native overflow must invoke the same action, including custom view items.
    NSMenuItem* menu=[[[NSMenuItem alloc] initWithTitle:item.label action:@selector(overflowClicked:) keyEquivalent:@""] autorelease];
    menu.target=self; menu.representedObject=identifier; item.menuFormRepresentation=menu;
    return item;
}
- (void)windowChanged:(NSNotification*)notification {
    if (notification.object!=self.window) return;
    [self closeDetails];
    if ([notification.name isEqual:NSWindowDidMoveNotification] || [notification.name isEqual:NSWindowDidEndLiveResizeNotification]) [self requestInputRepair];
    if ([notification.name isEqual:NSWindowWillEnterFullScreenNotification] || [notification.name isEqual:NSWindowWillExitFullScreenNotification])
        self.fullscreenTransition=YES;
    else if ([notification.name isEqual:NSWindowDidEnterFullScreenNotification] || [notification.name isEqual:NSWindowDidExitFullScreenNotification]
        || [notification.name isEqual:@"NSWindowDidFailToEnterFullScreenNotification"] || [notification.name isEqual:@"NSWindowDidFailToExitFullScreenNotification"])
        self.fullscreenTransition=NO;
    // Detach while the native title still exists; a borderless window rejects
    // all titlebarAccessoryViewControllers operations, including reads.
    if (self.fullscreenTransition) [self removeAccessory];
    // Defer until SDL/AppKit finish changing the window style. Borderless
    // desktop fullscreen has no titled mask; native fullscreen has FullScreen.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;
        [self updateWindowToolbar];
    });
}
- (void)themeChanged:(NSNotification*)notification { [self updateWindowToolbar]; [self refresh]; }
- (void)focusChanged:(NSNotification*)notification {
    if (notification.object==self.window || notification.object==NSApp) [self updateVisibility];
}
- (void)removeAccessory {
    ++self.visibilityRevision;
    self.nativeChrome.hidden=NO; self.nativeChrome.alphaValue=1; self.nativeChrome=nil;
    self.chromeVisible=YES;
    self.accessory.view.hidden=NO;
    [self.background.layer removeAllAnimations];
    self.background.hidden=NO; self.background.alphaValue=1;
    for (NSNumber* type in @[@(NSWindowCloseButton),@(NSWindowMiniaturizeButton),@(NSWindowZoomButton)])
        [self.window standardWindowButton:(NSWindowButton)type.integerValue].hidden=NO;
    if (self.presentationInstalled && self.window) self.window.movable=self.previousMovable;
    [self.background removeFromSuperview];
    if (self.window && self.presentationInstalled) self.window.backgroundColor=self.previousBackgroundColor;
    if (self.window && self.accessory && (self.window.styleMask & NSWindowStyleMaskTitled)) {
        if (self.presentationInstalled) self.window.titlebarSeparatorStyle=self.previousSeparator;
        NSUInteger index=[self.window.titlebarAccessoryViewControllers indexOfObjectIdenticalTo:self.accessory];
        if (index!=NSNotFound) [self.window removeTitlebarAccessoryViewControllerAtIndex:index];
    }
    [self.accessory.view removeFromSuperview];
}
- (void)updateWindowToolbar {
    if (!self.window) return;
    self.window.appearance=crimsonEnabled() ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua] : nil;
    ((NSButton*)self.buttons[hostID]).contentTintColor=crimsonEnabled() ? [NSColor colorWithSRGBRed:.95 green:.19 blue:.32 alpha:1] : nil;
    NSWindowStyleMask style=self.window.styleMask;
    BOOL fullscreen=self.windowTransition || self.fullscreenTransition || (style & NSWindowStyleMaskFullScreen) || !(style & NSWindowStyleMaskTitled);
    if (fullscreen) {
        [self removeAccessory];
        if (!self.windowTransition && !self.fullscreenTransition && self.window.visible) {
            // Fullscreen has no native title row. Reuse only the stream command
            // row as an overlay when input is released; never add window chrome
            // or mutate fullscreen/Metal drawable geometry.
            self.presentationInstalled=YES;
            NSView* frame=self.window.contentView.superview;
            self.background.frame=NSMakeRect(0,NSMaxY(frame.bounds)-28,frame.bounds.size.width,28);
            self.background.subviews.firstObject.frame=self.background.bounds;
            [frame addSubview:self.background positioned:NSWindowAbove relativeTo:self.window.contentView];
            self.accessory.view.frame=NSMakeRect(6,NSMaxY(frame.bounds)-26,MAX(40,frame.bounds.size.width-12),24);
            [frame addSubview:self.accessory.view positioned:NSWindowAbove relativeTo:self.background];
            [self layoutControls]; [self updateVisibility];
        }
        return;
    }
    // A right-aligned accessory shares the ordinary thin title row. Full-size
    // content is permanent while installed; capture toggles never change layout.
    if (self.window.visible) {
        self.presentationInstalled=YES;
        NSRect originalFrame=self.window.frame;
        BOOL extendContent=!(style & NSWindowStyleMaskFullSizeContentView);
        if (self.titleHeight<=0)
            self.titleHeight=MIN(32,MAX(24,self.window.frame.size.height-self.window.contentLayoutRect.size.height));
        // Install full-size content once, never in response to capture changes.
        // Video fills the title area; showing chrome only overlays that picture.
        // Keep SDL's original content view and native window/frame identity.
        if (extendContent)
            self.window.styleMask=style | NSWindowStyleMaskFullSizeContentView;
        self.window.titleVisibility=NSWindowTitleHidden;
        self.window.titlebarAppearsTransparent=YES;
        self.window.titlebarSeparatorStyle=NSTitlebarSeparatorStyleNone;
        // Draw one rounded surface across the full title area, underneath all
        // native controls. The same SDL content view and window frame stay intact.
        self.window.backgroundColor=NSColor.blackColor;
        NSView* frame=self.window.contentView.superview;
        CGFloat height=self.titleHeight;
        if (frame && height>0 && height<=40) {
            self.background.frame=NSMakeRect(0,NSMaxY(frame.bounds)-height,frame.bounds.size.width,height);
            self.background.subviews.firstObject.frame=self.background.bounds;
            if (self.background.superview!=frame)
                [frame addSubview:self.background positioned:NSWindowAbove relativeTo:self.window.contentView];
        }
        NSUInteger accessoryIndex=[self.window.titlebarAccessoryViewControllers indexOfObjectIdenticalTo:self.accessory];
        // SDL's borderless style change can retain the controller while AppKit
        // removes its native title parent. Reparenting the view for fullscreen
        // must not leave that stale registration on the return to windowed.
        if (accessoryIndex!=NSNotFound && self.accessory.view.superview==frame) {
            [self.window removeTitlebarAccessoryViewControllerAtIndex:accessoryIndex];
            accessoryIndex=NSNotFound;
        }
        if (accessoryIndex==NSNotFound) {
            [self.accessory.view removeFromSuperview];
            [self.window addTitlebarAccessoryViewController:self.accessory];
        }
        // AppKit may preserve the former content size when changing style or
        // installing an accessory. Preserve the outer frame instead, allowing
        // the video view to fill the existing title area without a window jump.
        if (extendContent && !NSEqualRects(originalFrame,self.window.frame))
            [self.window setFrame:originalFrame display:NO];
        self.accessory.view.frame=NSMakeRect(0,0,MAX(40,self.window.frame.size.width-88),self.accessory.view.frame.size.height);
        [self layoutControls];
        // Find the title-only ancestor using the public view hierarchy. Never
        // hide the frame/content view or depend on private AppKit class names.
        NSView* close=[self.window standardWindowButton:NSWindowCloseButton];
        for (NSView* view=close.superview; view && view!=frame; view=view.superview) {
            if ([self.accessory.view isDescendantOf:view] &&
                ![self.window.contentView isDescendantOf:view]) {
                self.nativeChrome=view; break;
            }
        }
        [self updateVisibility];
    }
}
- (void)updateVisibility {
    if (!self.window || !self.presentationInstalled || self.windowTransition || self.fullscreenTransition) return;
    TitleState copy; { std::lock_guard<std::mutex> lock(stateMutex); copy=state; }
    BOOL show=!copy.captured || !NSApp.active || !self.window.keyWindow || self.details.shown || self.trackingMenu || self.window.attachedSheet;
    BOOL fullscreen=(self.window.styleMask & NSWindowStyleMaskFullScreen) || !(self.window.styleMask & NSWindowStyleMaskTitled);
    // Hidden native chrome must not retain a title-bar drag target. SDL keeps
    // receiving motion/keys in the same view, with all command routes intact.
    self.window.movable=show && !fullscreen ? self.previousMovable : NO;
    self.accessory.view.hidden=!show;
    self.nativeChrome.hidden=!show;
    for (NSNumber* type in @[@(NSWindowCloseButton),@(NSWindowMiniaturizeButton),@(NSWindowZoomButton)])
        [self.window standardWindowButton:(NSWindowButton)type.integerValue].hidden=!show || fullscreen;
    if (show==self.chromeVisible) return;
    self.chromeVisible=show;
    NSUInteger revision=++self.visibilityRevision;
    if (show) {
        [self.background.layer removeAllAnimations];
        self.background.hidden=NO; self.background.alphaValue=1;
    } else {
        // The decorative surface fades; interactive controls disappear at
        // once, so there are no invisible buttons during the animation.
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
            context.duration=NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? 0 : .16;
            self.background.animator.alphaValue=0;
        } completionHandler:^{
            if (self.window && self.visibilityRevision==revision && !self.chromeVisible) self.background.hidden=YES;
        }];
    }
}
- (void)layoutControls {
    CGFloat width=self.accessory.view.bounds.size.width;
    CGFloat height=self.accessory.view.bounds.size.height;
    NSView* glass=self.accessory.view.subviews.firstObject;
    glass.frame=NSMakeRect(0,1,MAX(0,width-4),MAX(0,height-2));
    self.row.frame=glass.bounds;
    CGFloat w=self.row.bounds.size.width, h=self.row.bounds.size.height;
    BOOL compact=w<360;
    CGFloat right=MAX(0,w-3);
    NSButton* connection=self.buttons[connectionID];
    connection.frame=NSMakeRect(MAX(0,right-24),0,24,h); right-=28;
    self.overflow.hidden=!compact;
    self.overflow.frame=NSMakeRect(MAX(0,right-24),0,24,h);
    if (compact) right-=28;
    BOOL battery=NO; for (NSToolbarItem* item in self.toolbar.items) if ([item.itemIdentifier isEqual:batteryID]) battery=YES;
    for (NSString* identifier in @[batteryID,replayID,recordID,statisticsID]) {
        NSButton* button=self.buttons[identifier];
        BOOL show=!compact && (![identifier isEqual:batteryID] || battery);
        button.hidden=!show;
        if (show) { CGFloat size=[identifier isEqual:batteryID] ? 38 : 24; button.frame=NSMakeRect(right-size,0,size,h); right-=size+4; }
    }
    NSButton* capture=self.buttons[captureID]; capture.hidden=compact;
    capture.frame=NSMakeRect(3,0,24,h);
    CGFloat left=compact ? 3 : 31;
    NSButton* host=self.buttons[hostID];
    CGFloat hostWidth=MIN(230,MAX(0,right-left));
    CGFloat middle=width-self.window.frame.size.width/2;
    CGFloat x=MAX(left,MIN(middle-hostWidth/2,right-hostWidth));
    host.frame=NSMakeRect(x,0,hostWidth,h);
    for (NSButton* button in self.buttons.allValues) if (button.superview!=self.row) [self.row addSubview:button];
    if (self.overflow.superview!=self.row) [self.row addSubview:self.overflow];
}
- (void)showOverflow:(NSButton*)sender {
    NSMenu* menu=[[[NSMenu alloc] initWithTitle:@"Stream Controls"] autorelease]; menu.autoenablesItems=NO;
    for (NSToolbarItem* item in self.toolbar.items) {
        if (!item.menuFormRepresentation) continue;
        NSMenuItem* command=[[item.menuFormRepresentation copy] autorelease];
        command.image=((NSButton*)item.view).image; command.enabled=((NSButton*)item.view).enabled;
        [menu addItem:command];
    }
    self.trackingMenu=menu;
    [self updateVisibility];
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,NSMinY(sender.bounds)) inView:sender];
    self.trackingMenu=nil;
    [self updateVisibility];
    [self requestInputRepair];
}
- (void)overflowClicked:(NSMenuItem*)sender { [self perform:sender.representedObject anchor:nil]; }
- (void)clicked:(NSButton*)sender {
    for (NSString* identifier in self.buttons) if (self.buttons[identifier]==sender) { [self perform:identifier anchor:sender]; break; }
}
- (void)perform:(NSString*)identifier anchor:(NSView*)anchor {
    if ([identifier isEqual:recordID]) { nativeOverlayPerformAction(217); return; }
    if ([identifier isEqual:replayID]) { nativeOverlayPerformAction(219); return; }
    if ([identifier isEqual:captureID]) { nativeOverlayPerformAction(1); return; }
    if ([identifier isEqual:statisticsID]) { nativeOverlayPerformAction(3); return; }
    if ([identifier isEqual:hostID]) { [self closeDetails]; nativeOverlayPerformAction(102); return; }
    if (self.details.shown && [self.detailsID isEqual:identifier]) { [self closeDetails]; return; }
    [self closeDetails]; self.detailsID=identifier;
    self.details=[[[NSPopover alloc] init] autorelease]; self.details.delegate=self;
    self.details.appearance=crimsonEnabled() ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua] : nil;
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
    [self updateVisibility];
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
    capture.contentTintColor=copy.captured ? (crimsonEnabled() ? [NSColor colorWithSRGBRed:0.95 green:0.19 blue:0.32 alpha:1] : NSColor.controlAccentColor) : NSColor.labelColor;
    capture.toolTip=copy.captured ? @"Input captured by host · Click to release" : @"Input released to Mac · Click to capture";
    [capture setAccessibilityLabel:capture.toolTip]; [capture setAccessibilityValue:copy.captured ? @"Captured" : @"Released"];
    NSButton* stats=self.buttons[statisticsID]; stats.image=[NSImage imageWithSystemSymbolName:@"chart.xyaxis.line" accessibilityDescription:nil];
    stats.contentTintColor=copy.statistics ? (crimsonEnabled() ? [NSColor colorWithSRGBRed:0.95 green:0.19 blue:0.32 alpha:1] : NSColor.controlAccentColor) : NSColor.labelColor;
    stats.toolTip=copy.statistics ? @"Hide Statistics" : @"Show Statistics"; [stats setAccessibilityLabel:stats.toolTip]; [stats setAccessibilityValue:copy.statistics ? @"Shown" : @"Hidden"];
    NSButton* record=self.buttons[recordID];
    record.image=[NSImage imageWithSystemSymbolName:copy.recording ? @"stop.circle.fill" : (copy.recorderFailed ? @"exclamationmark.circle" : @"record.circle") accessibilityDescription:nil];
    record.enabled=copy.recorder;
    record.contentTintColor=copy.recording || copy.recorderFailed ? NSColor.systemRedColor : NSColor.labelColor;
    NSString* recordingMessage=[NSString stringWithUTF8String:copy.recordingMessage.c_str()];
    record.toolTip=copy.recording ? [NSString stringWithFormat:@"Stop Recording · %llu:%02llu · %@",(unsigned long long)(copy.seconds/60),(unsigned long long)(copy.seconds%60),recordingMessage] : [@"Record · " stringByAppendingString:recordingMessage];
    [record setAccessibilityLabel:record.toolTip];
    NSButton* replay=self.buttons[replayID];
    replay.image=[NSImage imageWithSystemSymbolName:copy.saving ? @"hourglass" : @"arrow.counterclockwise.circle" accessibilityDescription:nil];
    replay.enabled=copy.recorder && copy.replayReady && !copy.saving;
    replay.contentTintColor=copy.buffering ? NSColor.systemBlueColor : NSColor.secondaryLabelColor;
    replay.toolTip=copy.saving ? @"Saving Replay" : (copy.replayReady ? @"Save Instant Replay" : (copy.buffering ? @"Replay buffering · Waiting for a usable keyframe" : @"Enable Instant Replay in Recording settings"));
    [replay setAccessibilityLabel:replay.toolTip];
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
    for (NSButton* button in self.buttons.allValues) if (button!=self.buttons[batteryID]) button.image=[button.image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightRegular]];
    [self updateDetails];
    [self updateVisibility];
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
        [self.buttons[batteryID] removeFromSuperview];
        [self.buttons removeObjectForKey:batteryID];
    }
    [self layoutControls]; [self refresh];
}
- (void)closeDetails {
    // Remove the delegate before closing/replacing a popover. A delayed close
    // notification must not clear a newer popover's state or target a dead owner.
    BOOL wasShown=self.details.shown;
    self.details.delegate=nil; [self.details close]; self.details=nil; self.detailsID=nil;
    if (wasShown) [self requestInputRepair];
    [self updateVisibility];
}
- (void)popoverDidClose:(NSNotification*)notification {
    if (notification.object==self.details) { self.detailsID=nil; [self requestInputRepair]; [self updateVisibility]; }
}
- (void)invalidate {
    [self.trackingMenu cancelTracking]; self.trackingMenu=nil;
    if (self.eventMonitor) { [NSEvent removeMonitor:self.eventMonitor]; self.eventMonitor=nil; }
    [self.inputRepairTimer invalidate]; self.inputRepairTimer=nil;
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self]; [self closeDetails]; self.details.delegate=nil;
    [self.inputRepairTimer invalidate]; self.inputRepairTimer=nil;
    [self removeAccessory];
    if (self.presentationInstalled && self.window) {
        self.window.titleVisibility=self.previousTitleVisibility;
        self.window.titlebarAppearsTransparent=self.previousTransparency;
        if (!self.previousFullSizeContent && (self.window.styleMask & NSWindowStyleMaskTitled))
            self.window.styleMask=self.window.styleMask & ~NSWindowStyleMaskFullSizeContentView;
        for (NSNumber* type in @[@(NSWindowCloseButton),@(NSWindowMiniaturizeButton),@(NSWindowZoomButton)])
            [self.window standardWindowButton:(NSWindowButton)type.integerValue].hidden=NO;
    }
    self.toolbar.delegate=nil; self.window=nil;
}
- (void)dealloc {
    [self invalidate]; [_nativeChrome release]; [_background release]; [_previousBackgroundColor release]; [_accessory release]; [_row release]; [_overflow release]; [_toolbar release]; [_previousToolbar release]; [_buttons release]; [_details release]; [_detailsID release]; [_batteryDetails release]; [super dealloc];
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
void nativeTitlebarSetRecording(bool available,bool recording,bool buffering,bool ready,bool saving,bool failed,uint64_t seconds,const char* message) {
    std::lock_guard<std::mutex> lock(stateMutex);
    state.recorder=available;state.recording=recording;state.buffering=buffering;state.replayReady=ready;state.saving=saving;state.recorderFailed=failed;state.seconds=seconds;state.recordingMessage=message ? message : "";
    scheduleRefresh();
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
    titlebar.previousFullSizeContent=(titlebar.window.styleMask & NSWindowStyleMaskFullSizeContentView)!=0;
    titlebar.previousMovable=titlebar.window.movable;
    titlebar.chromeVisible=YES;
    MLStreamTitlebar* owner=titlebar;
    owner.eventMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp handler:^NSEvent*(NSEvent* event) {
        if (event.window==owner.window && owner.window) {
            NSRect content=owner.window.contentView.frame;
            NSPoint barPoint=[owner.background convertPoint:event.locationInWindow fromView:nil];
            if (!NSPointInRect(event.locationInWindow,content) ||
                (owner.chromeVisible && owner.background.superview && NSPointInRect(barPoint,owner.background.bounds)))
                [owner requestInputRepair];
        }
        return event;
    }];
    titlebar.previousToolbar=titlebar.window.toolbar; titlebar.previousTitleVisibility=titlebar.window.titleVisibility; titlebar.previousToolbarStyle=titlebar.window.toolbarStyle; titlebar.previousTransparency=titlebar.window.titlebarAppearsTransparent; titlebar.previousBackgroundColor=titlebar.window.backgroundColor;
    titlebar.previousSeparator=(titlebar.window.styleMask & NSWindowStyleMaskTitled) ? titlebar.window.titlebarSeparatorStyle : NSTitlebarSeparatorStyleAutomatic;
    titlebar.toolbar=[[[NSToolbar alloc] initWithIdentifier:@"NativeStreamToolbar"] autorelease];
    titlebar.toolbar.delegate=titlebar; titlebar.toolbar.displayMode=NSToolbarDisplayModeIconOnly;
    titlebar.toolbar.allowsUserCustomization=NO; titlebar.toolbar.autosavesConfiguration=NO;
    // Keep command metadata for narrow-window overflow, without installing a
    // taller NSToolbar on the stream window.
    for (NSString* identifier in @[captureID,hostID,statisticsID,recordID,replayID,connectionID])
        [titlebar.toolbar insertItemWithItemIdentifier:identifier atIndex:titlebar.toolbar.items.count];
    titlebar.accessory=[[[NSTitlebarAccessoryViewController alloc] init] autorelease];
    titlebar.accessory.layoutAttribute=NSLayoutAttributeRight;
    NSView* root=[[[NSView alloc] initWithFrame:NSMakeRect(0,0,MAX(40,titlebar.window.frame.size.width-88),24)] autorelease];
    root.identifier=@"NativeStreamTitlebar";
    titlebar.accessory.view=root;
    titlebar.row=[[[NSView alloc] initWithFrame:root.bounds] autorelease];
    // The control accessory itself is transparent; one surface spans the
    // entire bar so its lower-left corner includes the traffic-light region.
    NSView* controls=[[[NSView alloc] initWithFrame:root.bounds] autorelease];
    controls.identifier=@"NativeStreamTitlebarControls"; [controls addSubview:titlebar.row]; [root addSubview:controls];
    titlebar.background=[[[MLTitlebarBackground alloc] initWithFrame:NSZeroRect] autorelease];
    titlebar.background.identifier=@"NativeStreamTitlebarBackground";
    NSView* glass;
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView* effect=[[[NSGlassEffectView alloc] initWithFrame:NSZeroRect] autorelease];
        effect.cornerRadius=12;
        effect.contentView=[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]; glass=effect;
    } else {
        NSVisualEffectView* effect=[[[NSVisualEffectView alloc] initWithFrame:NSZeroRect] autorelease];
        effect.material=NSVisualEffectMaterialTitlebar; effect.blendingMode=NSVisualEffectBlendingModeBehindWindow;
        effect.state=NSVisualEffectStateFollowsWindowActiveState; effect.wantsLayer=YES;
        effect.layer.cornerRadius=12; effect.layer.masksToBounds=YES; glass=effect;
    }
    glass.identifier=@"NativeStreamTitlebarGlass"; [titlebar.background addSubview:glass];
    titlebar.overflow=[MLStreamToolbarButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"ellipsis" accessibilityDescription:@"More Stream Controls"] target:titlebar action:@selector(showOverflow:)];
    titlebar.overflow.bordered=NO; titlebar.overflow.identifier=@"NativeOverflow";
    titlebar.overflow.toolTip=@"More Stream Controls"; [titlebar.overflow setAccessibilityLabel:titlebar.overflow.toolTip];
    [titlebar updateWindowToolbar]; [titlebar readControllers];
}
void nativeTitlebarDetach() {
    { std::lock_guard<std::mutex> lock(stateMutex); epoch++; pending=false; }
    [titlebar invalidate]; [titlebar release]; titlebar=nil;
}
void nativeTitlebarSetWindowTransition(bool transitioning) {
    titlebar.windowTransition=transitioning;
    [titlebar updateWindowToolbar];
}
