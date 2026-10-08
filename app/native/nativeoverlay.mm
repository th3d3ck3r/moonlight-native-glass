#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include "nativeoverlay.h"
#include <atomic>
#include <mutex>
#include <array>
#include <cstring>

static NSString* const suite = @"com.moonlight-stream.NativeGlass.Overlay";
static NSString* const changed = @"com.moonlight-stream.NativeGlass.overlaySettingsChanged";
static NSString* const toggle = @"com.moonlight-stream.NativeGlass.toggleStreamControls";
static std::atomic<bool> configured(false);
static Uint32 actionEvent = (Uint32)-1;
struct Snapshot { bool enabled = false; char text[1024] = {}; };
static std::mutex snapshotMutex;
static Snapshot snapshots[2];
static bool updatePending = false;
static unsigned generation = 0;
struct Binding { SDL_Keycode key; SDL_Keymod modifiers; };
static std::mutex bindingMutex;
static std::array<Binding, 12> bindings;
static const char* defaultKeys = "qzxsmcdvleko";
static NSArray* titles() { return @[@"Disconnect", @"Release / Capture Input", @"Full Screen", @"Statistics", @"Mouse Mode", @"Cursor Visibility", @"Minimize", @"Paste Clipboard", @"Pointer Region Lock", @"Disconnect and Exit", @"Keyboard Capture", @"Show / Hide Controls"]; }
// Index 9 is the existing quit-and-exit action, not a host-game termination.
static void pushAction(int code) { if (actionEvent == (Uint32)-1) return; SDL_Event e = {}; e.type = actionEvent; e.user.code = code; SDL_PushEvent(&e); }

// Passive surfaces must never become keyboard or main windows. Controls may
// accept keyboard focus when explicitly clicked, without replacing the stream.
@interface MLOverlayPanel : NSPanel
@end
@implementation MLOverlayPanel
- (BOOL)canBecomeKeyWindow { return !self.ignoresMouseEvents; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface MLOverlayController : NSObject
@property(nonatomic, assign) NSWindow* parent;
@property(nonatomic, retain) NSPanel* stats;
@property(nonatomic, retain) NSPanel* status;
@property(nonatomic, retain) NSPanel* controls;
@property(nonatomic, retain) NSTextField* statsText;
@property(nonatomic, retain) NSTextField* statusText;
@property(nonatomic, retain) NSUserDefaults* defaults;
@property(nonatomic, copy) NSString* token;
@property(nonatomic, assign) BOOL showingControls;
@property(nonatomic, assign) BOOL layingOut;
- (void)refresh;
- (void)layoutPanels;
@end
static MLOverlayController* controller;

@implementation MLOverlayController
- (instancetype)init {
    if ((self = [super init])) {
        self.defaults = [[[NSUserDefaults alloc] initWithSuiteName:suite] autorelease];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:NSWindowDidResizeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:NSWindowDidMoveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:NSWindowDidChangeScreenNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:NSWindowDidChangeBackingPropertiesNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:NSWindowDidDeminiaturizeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:NSWindowDidMiniaturizeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowChanged:) name:NSWindowDidChangeOcclusionStateNotification object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(accessibilityChanged:) name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification object:nil];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:changed object:nil];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleControls:) name:toggle object:nil];
    }
    return self;
}
- (NSPanel*)panelWithText:(NSTextField**)field {
    NSPanel* panel = [[[MLOverlayPanel alloc] initWithContentRect:NSMakeRect(0,0,300,100) styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO] autorelease];
    panel.releasedWhenClosed = NO; panel.opaque = NO; panel.backgroundColor = NSColor.clearColor;
    panel.hasShadow = YES; panel.hidesOnDeactivate = NO; panel.ignoresMouseEvents = field != nullptr;
    panel.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorIgnoresCycle;
    panel.becomesKeyOnlyIfNeeded = YES;
    NSVisualEffectView* material = [[[NSVisualEffectView alloc] initWithFrame:panel.contentView.bounds] autorelease];
    material.material = NSVisualEffectMaterialHUDWindow; material.blendingMode = NSVisualEffectBlendingModeBehindWindow; material.state = NSVisualEffectStateActive;
    material.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable; material.wantsLayer = YES; material.layer.cornerRadius = 12; material.layer.masksToBounds = YES;
    panel.contentView = material;
    NSView* container = material;
    if (@available(macOS 26.0, *)) {
        if (!field && ![NSWorkspace sharedWorkspace].accessibilityDisplayShouldReduceTransparency) {
            NSGlassEffectView* glass = [[[NSGlassEffectView alloc] initWithFrame:material.frame] autorelease];
            glass.cornerRadius = 12;
            glass.contentView = [[[NSView alloc] initWithFrame:material.frame] autorelease];
            glass.contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            panel.contentView = glass; container = glass.contentView;
        }
    }
    if (field) {
        NSTextField* label = [NSTextField wrappingLabelWithString:@""];
        label.textColor = NSColor.labelColor; label.selectable = NO;
        [container addSubview:label]; *field = label;
    }
    return panel;
}
- (void)windowChanged:(NSNotification*)n { if (n.object == self.parent) [self layoutPanels]; }
- (void)settingsChanged:(NSNotification*)n { [self.defaults synchronize]; if (self.showingControls && ![self.defaults boolForKey:@"controlsEnabled"]) pushAction(101); [self refresh]; }
- (void)accessibilityChanged:(NSNotification*)n { [self refresh]; }
- (void)toggleControls:(NSNotification*)n { if ([n.object isEqual:self.token]) pushAction(100); }
- (void)action:(NSButton*)sender { pushAction((int)sender.tag); }
- (void)dismiss:(id)sender { pushAction(101); }
- (void)refresh {
    [self.defaults synchronize];
    NSDictionary* custom = [self.defaults dictionaryForKey:@"shortcuts"];
    { std::lock_guard<std::mutex> lock(bindingMutex);
      for (int i=0;i<12;i++) {
          id stored = custom[[NSString stringWithFormat:@"%d",i]];
          NSDictionary* b = [stored isKindOfClass:NSDictionary.class] ? stored : nil;
          NSString* key = [b[@"key"] isKindOfClass:NSString.class] ? b[@"key"] : nil;
          SDL_Keycode code = key.length == 1 ? (SDL_Keycode)[key.lowercaseString characterAtIndex:0] : defaultKeys[i];
          int mods = [b[@"modifiers"] isKindOfClass:NSNumber.class] ? [b[@"modifiers"] intValue] : 7;
          if (code < 'a' || code > 'z' || (mods != 3 && mods != 7 && mods != 10 && mods != 14)) { code=defaultKeys[i]; mods=7; }
          bindings[i] = {code, (SDL_Keymod)(((mods & 1) ? KMOD_CTRL : 0) | ((mods & 2) ? KMOD_ALT : 0) | ((mods & 4) ? KMOD_SHIFT : 0) | ((mods & 8) ? KMOD_GUI : 0))};
      }
    }
    if (!self.stats) { NSTextField* label = nil; self.stats = [self panelWithText:&label]; self.statsText = label; }
    if (!self.status) { NSTextField* label = nil; self.status = [self panelWithText:&label]; self.statusText = label; }
    if (self.controls) { [self.parent removeChildWindow:self.controls]; [self.controls orderOut:nil]; self.controls = nil; }
    if (self.showingControls) {
        self.controls = [self panelWithText:nullptr];
        self.controls.ignoresMouseEvents = NO;
        NSView* content = self.controls.contentView;
        if (@available(macOS 26.0, *)) { if ([content isKindOfClass:NSGlassEffectView.class]) content = ((NSGlassEffectView*)content).contentView; }
        NSArray* actions = [self.defaults arrayForKey:@"buttons"] ?: @[@2,@3,@1,@6,@7];
        CGFloat x = 10;
        NSArray* names = titles();
        NSArray* symbols = @[@"xmark.circle",@"cursorarrow",@"arrow.up.left.and.arrow.down.right",@"chart.bar",@"computermouse",@"eye",@"minus",@"doc.on.clipboard",@"rectangle.dashed",@"power",@"keyboard",@"slider.horizontal.3"];
        CGFloat available = MAX(160,self.parent.frame.size.width - 40);
        NSMenu* overflow = [[[NSMenu alloc] initWithTitle:@"More Stream Controls"] autorelease];
        for (NSNumber* action in actions) {
            if (![action isKindOfClass:NSNumber.class]) continue;
            NSInteger i = action.integerValue; if (i<0 || i>10) continue;
            if (x + 88 > available) { NSMenuItem* item = [[[NSMenuItem alloc] initWithTitle:names[i] action:@selector(action:) keyEquivalent:@""] autorelease]; item.target=self; item.tag=i; [overflow addItem:item]; continue; }
            NSButton* button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:names[i]] target:self action:@selector(action:)];
            button.bezelStyle=NSBezelStyleRounded; button.tag=i; button.toolTip=names[i]; [button setAccessibilityLabel:names[i]];
            button.frame=NSMakeRect(x,8,34,30); [content addSubview:button]; x+=40;
        }
        if (overflow.numberOfItems) { NSPopUpButton* more = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(x,8,40,30) pullsDown:YES] autorelease]; [more addItemWithTitle:@"…"]; for (NSMenuItem* item in overflow.itemArray) [more.menu addItem:[[item copy] autorelease]]; [more setAccessibilityLabel:@"More Stream Controls"]; [content addSubview:more]; x+=46; }
        NSButton* close = [NSButton buttonWithTitle:@"Done" target:self action:@selector(dismiss:)]; close.frame=NSMakeRect(x,8,58,30); [content addSubview:close];
        [self.controls setContentSize:NSMakeSize(x+68,46)];
    }
    [self layoutPanels];
}
- (void)setPanel:(NSPanel*)panel visible:(BOOL)visible {
    if (!panel) return;
    if (visible) {
        if (panel.parentWindow != self.parent) [self.parent addChildWindow:panel ordered:NSWindowAbove];
        [panel orderFront:nil];
    } else {
        if (panel.parentWindow) [panel.parentWindow removeChildWindow:panel];
        if (panel.visible) [panel orderOut:nil];
    }
}
- (void)layoutPanels {
    if (!self.parent || self.layingOut) return;
    self.layingOut=YES;
    @try {
    Snapshot copy[2]; { std::lock_guard<std::mutex> lock(snapshotMutex); copy[0]=snapshots[0]; copy[1]=snapshots[1]; }
    double savedScale = [self.defaults doubleForKey:@"scale"]; CGFloat scale = savedScale > 0 ? MAX(.8,MIN(1.5,savedScale)) : 1;
    NSRect bounds = [self.parent convertRectToScreen:[self.parent.contentView bounds]];
    CGFloat width = MAX(120,MIN(510*scale,bounds.size.width-24));
    CGFloat reservedBottom = self.controls ? 70 : 0;
    if (copy[1].enabled && copy[1].text[0]) {
        NSString* status = [NSString stringWithUTF8String:copy[1].text] ?: @"";
        NSRect size = [status boundingRectWithSize:NSMakeSize(width-24*scale,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13*scale weight:NSFontWeightMedium]}];
        reservedBottom = (self.controls ? 70 : 12) + ceil(size.size.height) + 24*scale + 12;
    }
    for (int i=0;i<2;i++) {
        CGFloat availableHeight = MAX(0,bounds.size.height-24-(i==0 ? reservedBottom : 0));
        NSPanel* panel = i==0 ? self.stats : self.status; NSTextField* label=i==0?self.statsText:self.statusText;
        label.stringValue=[NSString stringWithUTF8String:copy[i].text] ?: @"";
        label.font=i==0 ? [NSFont monospacedDigitSystemFontOfSize:12*scale weight:NSFontWeightRegular] : [NSFont systemFontOfSize:13*scale weight:NSFontWeightMedium];
        CGFloat padding=12*scale;
        NSRect needed=[label.stringValue boundingRectWithSize:NSMakeSize(width-2*padding,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:label.font}];
        for (int attempt=0; attempt<8 && needed.size.height+2*padding>availableHeight; attempt++) {
            CGFloat size=MAX(9,label.font.pointSize*.9);
            label.font=i==0 ? [NSFont monospacedDigitSystemFontOfSize:size weight:NSFontWeightRegular] : [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
            needed=[label.stringValue boundingRectWithSize:NSMakeSize(width-2*padding,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:label.font}];
        }
        CGFloat height=MIN(ceil(needed.size.height)+2*padding,availableHeight);
        NSRect labelFrame=NSMakeRect(padding,padding,width-2*padding,MAX(0,height-2*padding));
        if (!NSEqualRects(label.frame,labelFrame)) label.frame=labelFrame;
        NSString* position=[self.defaults stringForKey:@"position"] ?: @"topLeft";
        CGFloat x=[position containsString:@"Right"] ? NSMaxX(bounds)-width-12 : NSMinX(bounds)+12;
        CGFloat y=[position hasPrefix:@"bottom"] ? NSMinY(bounds)+12+reservedBottom : NSMaxY(bounds)-height-12;
        if (i==1) { x=NSMidX(bounds)-width/2; y=NSMinY(bounds)+(self.controls ? 70 : 12); }
        NSRect frame=NSMakeRect(x,y,width,height);
        if (!NSEqualRects(panel.frame,frame)) [panel setFrame:frame display:NO];
        BOOL visible=copy[i].enabled && copy[i].text[0] && self.parent.visible && !self.parent.miniaturized;
        [self setPanel:panel visible:visible];
        NSVisualEffectView* material=(NSVisualEffectView*)panel.contentView;
        material.material=NSVisualEffectMaterialHUDWindow;
        if ([NSWorkspace sharedWorkspace].accessibilityDisplayShouldReduceTransparency) { material.state=NSVisualEffectStateInactive; panel.backgroundColor=NSColor.windowBackgroundColor; }
        else { material.state=NSVisualEffectStateActive; panel.backgroundColor=NSColor.clearColor; }
    }
    if (self.controls) { NSRect frame=self.controls.frame; frame.origin=NSMakePoint(NSMidX(bounds)-frame.size.width/2,NSMinY(bounds)+12); [self.controls setFrame:frame display:NO]; [self setPanel:self.controls visible:self.parent.visible && !self.parent.miniaturized]; }
    } @finally { self.layingOut=NO; }
}
- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self]; [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    for (NSPanel* panel in @[self.stats ?: (id)NSNull.null,self.status ?: (id)NSNull.null,self.controls ?: (id)NSNull.null]) if ((id)panel != NSNull.null) { [self.parent removeChildWindow:panel]; [panel orderOut:nil]; }
    [_stats release]; [_status release]; [_controls release]; [_statsText release]; [_statusText release]; [_defaults release]; [_token release]; [super dealloc];
}
@end

bool nativeOverlayControlsEnabled() { return [controller.defaults boolForKey:@"controlsEnabled"]; }
bool nativeOverlayConfigured() { return configured.load(); }
Uint32 nativeOverlayEventType() { return actionEvent; }
int nativeOverlayShortcut(const SDL_KeyboardEvent* event) {
    if (!configured || event->repeat || event->state != SDL_PRESSED) return -1;
    int mods = event->keysym.mod;
    int normalized = ((mods & KMOD_CTRL)?KMOD_CTRL:0)|((mods & KMOD_ALT)?KMOD_ALT:0)|((mods & KMOD_SHIFT)?KMOD_SHIFT:0)|((mods & KMOD_GUI)?KMOD_GUI:0);
    std::lock_guard<std::mutex> lock(bindingMutex);
    for (int i=0;i<12;i++) if (bindings[i].key==event->keysym.sym && bindings[i].modifiers==normalized) return i;
    return -1;
}
bool nativeOverlayPresent(int type, bool enabled, const char* text) {
    if (!configured || type<0 || type>1) return false;
    std::lock_guard<std::mutex> lock(snapshotMutex); snapshots[type].enabled=enabled; SDL_strlcpy(snapshots[type].text,text ?: "",sizeof(snapshots[type].text));
    if (!updatePending) { updatePending=true; unsigned current=generation; dispatch_async(dispatch_get_main_queue(), ^{ { std::lock_guard<std::mutex> guard(snapshotMutex); if (generation!=current) return; updatePending=false; } [controller layoutPanels]; }); }
    return true;
}
void nativeOverlayAttach(void* window, const char* token) {
    if (controller && controller.parent == (NSWindow*)window) return;
    nativeOverlayDetach();
    if (actionEvent==(Uint32)-1) { Uint32 base=SDL_RegisterEvents(2); actionEvent=base == (Uint32)-1 ? base : base+1; }
    controller=[[MLOverlayController alloc] init]; controller.parent=(NSWindow*)window; controller.token=[NSString stringWithUTF8String:token];
    @try { [controller refresh]; configured=true; }
    @catch (NSException* error) { SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION, "Native overlay unavailable: %s", error.reason.UTF8String); nativeOverlayDetach(); }
}
void nativeOverlayDetach() {
    configured=false; { std::lock_guard<std::mutex> lock(snapshotMutex); generation++; updatePending=false; snapshots[0]={}; snapshots[1]={}; }
    if (actionEvent != (Uint32)-1) SDL_FlushEvent(actionEvent);
    [controller release]; controller=nil;
}
void nativeOverlaySetControlsVisible(bool visible) { controller.showingControls=visible; [controller refresh]; }
