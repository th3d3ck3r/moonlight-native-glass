#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <SDL.h>
#import <SDL_syswm.h>
#include "nativeoverlay.h"
#include <cstdio>
#include <stdexcept>

// Run with nativeoverlay.mm/nativetitlebar.mm. All system-modal calls are
// replaced in this process before attaching a bar: never take over CI's bar.
static void check(bool okay,const char* message) {
    if (!okay) throw std::runtime_error(message);
}
static bool mockKey=true,mockVisible=true,mockActive=true,cleaning=false;
static bool reenterShow=false,reenterHide=false,loseFocusDuringShow=false;
static bool throwDuringShow=false,throwDuringHide=false;
static int shown=0,hidden=0;
static NSTouchBar* presented=nil;
static NSWindow* fixtureWindow=nil;
static IMP originalKeyGetter=nullptr,originalVisibleGetter=nullptr;

static void refresh(NSTouchBar* bar) {
    id owner=bar.delegate;
    check(owner && [owner respondsToSelector:@selector(updateTouchPresentation)],"Presentation owner must remain reachable while attached");
    [owner performSelector:@selector(updateTouchPresentation)];
}
static BOOL fakeKey(id receiver,SEL selector) {
    return receiver==fixtureWindow ? mockKey : ((BOOL(*)(id,SEL))originalKeyGetter)(receiver,selector);
}
static BOOL fakeVisible(id receiver,SEL selector) {
    return receiver==fixtureWindow ? mockVisible : ((BOOL(*)(id,SEL))originalVisibleGetter)(receiver,selector);
}
static BOOL fakeActive(id receiver,SEL selector) { return mockActive; }
static void fakeShow(id receiver,SEL selector,NSTouchBar* bar,long long placement,id tray) {
    if (cleaning) return;
    check(bar && placement==1 && tray==nil,"Request full app-region placement with no Control Strip tray item");
    check(presented==nil,"Do not present the same or another bar twice without releasing ownership");
    check(fixtureWindow.touchBar!=bar,"System-modal and ordinary responder hosts must never own the same Touch Bar simultaneously");
    NSDictionary* controls=[bar.delegate valueForKey:@"touchButtons"];
    check(bar.defaultItemIdentifiers.count>0,"Never invoke private presentation with an empty bar");
    for (NSString* identifier in bar.defaultItemIdentifiers)
        check(controls[identifier]!=nil,"Resolve every real top-level control before invoking private presentation");
    presented=bar; ++shown;
    if (throwDuringShow) {
        throwDuringShow=false;
        @throw [NSException exceptionWithName:@"InjectedPresentationFailure" reason:@"Partially claimed private presentation" userInfo:nil];
    }
    if (reenterShow) { reenterShow=false; refresh(bar); }
    if (loseFocusDuringShow) {
        loseFocusDuringShow=false; mockKey=false;
        [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidResignKeyNotification object:fixtureWindow];
    }
}
static void fakeHide(id receiver,SEL selector,NSTouchBar* bar) {
    if (cleaning) { presented=nil; return; }
    check(bar && presented==bar,"Dismiss only the bar actually owned by this session");
    presented=nil; ++hidden;
    if (throwDuringHide) {
        throwDuringHide=false;
        @throw [NSException exceptionWithName:@"InjectedDismissalFailure" reason:@"Private dismissal failed after release" userInfo:nil];
    }
    if (reenterHide) { reenterHide=false; refresh(bar); }
}
static void pump() {
    NSDate* end=[NSDate dateWithTimeIntervalSinceNow:.04];
    while (end.timeIntervalSinceNow>0)
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.004]];
}

struct Fixture {
    NSUserDefaults* preferences=nil;
    id savedValue=nil;
    id savedFailure=nil;
    Class meta=Nil,applicationClass=Nil,windowGetterClass=Nil;
    IMP originalShow=nullptr,originalHide=nullptr,originalActive=nullptr;
    const char* activeEncoding=nullptr;
    const char* keyEncoding=nullptr;
    const char* visibleEncoding=nullptr;
    SEL showSelector=NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:");
    SEL hideSelector=NSSelectorFromString(@"dismissSystemModalTouchBar:");
    SDL_Window* stream=nullptr;
    NSTouchBar* originalBar=nil;
    NSTouchBar* retainedBar=nil;
    bool sdlReady=false;
    Fixture() {
        preferences=[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass"];
        savedValue=[[preferences objectForKey:@"touchBarFullWidth"] retain];
        savedFailure=[[preferences objectForKey:@"touchBarFullWidthUnavailable"] retain];
        [preferences removeObjectForKey:@"touchBarFullWidth"]; [preferences synchronize];
        meta=object_getClass(NSTouchBar.class);
        Method show=class_getClassMethod(NSTouchBar.class,showSelector),hide=class_getClassMethod(NSTouchBar.class,hideSelector);
        originalShow=show ? method_getImplementation(show) : nullptr;
        originalHide=hide ? method_getImplementation(hide) : nullptr;
        class_replaceMethod(meta,showSelector,(IMP)fakeShow,"v@:@q@");
        class_replaceMethod(meta,hideSelector,(IMP)fakeHide,"v@:@");
        applicationClass=object_getClass(NSApp);
        Method active=class_getInstanceMethod(applicationClass,@selector(isActive));
        originalActive=method_getImplementation(active); activeEncoding=method_getTypeEncoding(active);
        class_replaceMethod(applicationClass,@selector(isActive),(IMP)fakeActive,activeEncoding);
    }
    void enable(bool enabled) {
        [preferences setBool:enabled forKey:@"touchBarFullWidth"]; [preferences synchronize];
        if (retainedBar && retainedBar.delegate) {
            NSNotification* changed=[NSNotification notificationWithName:@"com.moonlight-stream.NativeGlass.touchBarPresentationChanged" object:nil];
            [retainedBar.delegate performSelector:NSSelectorFromString(@"touchPresentationChanged:") withObject:changed];
        }
    }
    void retainCurrentBar() {
        [retainedBar release]; retainedBar=[(fixtureWindow.touchBar ?: presented) retain];
    }
    ~Fixture() {
        // Also restore preferences and IMPs on a failed assertion.
        cleaning=true;
        nativeOverlayDetach();
        [retainedBar release]; [originalBar release];
        if (windowGetterClass && originalKeyGetter) class_replaceMethod(windowGetterClass,@selector(isKeyWindow),originalKeyGetter,keyEncoding);
        if (windowGetterClass && originalVisibleGetter) class_replaceMethod(windowGetterClass,@selector(isVisible),originalVisibleGetter,visibleEncoding);
        if (stream) SDL_DestroyWindow(stream);
        fixtureWindow=nil;
        if (sdlReady) SDL_Quit();
        if (originalActive) class_replaceMethod(applicationClass,@selector(isActive),originalActive,activeEncoding);
        if (originalShow) class_replaceMethod(meta,showSelector,originalShow,"v@:@q@");
        if (originalHide) class_replaceMethod(meta,hideSelector,originalHide,"v@:@");
        if (savedValue) [preferences setObject:savedValue forKey:@"touchBarFullWidth"];
        else [preferences removeObjectForKey:@"touchBarFullWidth"];
        if (savedFailure) [preferences setObject:savedFailure forKey:@"touchBarFullWidthUnavailable"]; else [preferences removeObjectForKey:@"touchBarFullWidthUnavailable"];
        [preferences synchronize]; [savedFailure release]; [savedValue release]; [preferences release];
    }
};

static void notify(NSString* name,id object) {
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:object]; pump();
}
static void run(Fixture& fixture) {
    SDL_SetMainReady(); check(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_GAMECONTROLLER)==0,"Initialize SDL fixture");
    fixture.sdlReady=true;
    fixture.stream=SDL_CreateWindow("Touch Bar presentation fixture",80,100,960,540,SDL_WINDOW_SHOWN|SDL_WINDOW_RESIZABLE);
    check(fixture.stream!=nullptr,"Create stream fixture");
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    check(SDL_GetWindowWMInfo(fixture.stream,&info),"Resolve SDL Cocoa window");
    fixtureWindow=info.info.cocoa.window;
    // Keep AppKit's original isa/computed-property metadata intact. Override
    // these getters only on the existing class and forward all other windows.
    fixture.windowGetterClass=object_getClass(fixtureWindow);
    Method key=class_getInstanceMethod(fixture.windowGetterClass,@selector(isKeyWindow));
    Method visible=class_getInstanceMethod(fixture.windowGetterClass,@selector(isVisible));
    check(key && visible,"Locate the native focus/visibility getters");
    originalKeyGetter=method_getImplementation(key); originalVisibleGetter=method_getImplementation(visible);
    fixture.keyEncoding=method_getTypeEncoding(key); fixture.visibleEncoding=method_getTypeEncoding(visible);
    class_replaceMethod(fixture.windowGetterClass,@selector(isKeyWindow),(IMP)fakeKey,fixture.keyEncoding);
    class_replaceMethod(fixture.windowGetterClass,@selector(isVisible),(IMP)fakeVisible,fixture.visibleEncoding);
    fprintf(stderr,"Presentation fixture: original window class %s, getter overrides installed\n",class_getName(fixture.windowGetterClass));
    fixture.originalBar=[[NSTouchBar alloc] init]; fixtureWindow.touchBar=fixture.originalBar;
    fprintf(stderr,"Presentation fixture: attaching normal bar\n");
    nativeOverlayAttach(fixtureWindow,"presentation-fixture"); pump(); fixture.retainCurrentBar();
    NSTouchBar* bar=fixture.retainedBar;
    check(bar && bar!=fixture.originalBar && shown==0 && hidden==0,"Missing full-width preference must retain normal Control Strip presentation");

    fprintf(stderr,"Presentation fixture: enable and focus transitions\n");
    reenterShow=true; fixture.enable(true);
    check(shown==1 && hidden==0 && presented==bar,"Enabling must invoke full-width presentation exactly once despite synchronous refresh");
    check(fixtureWindow.touchBar==nil,"Full width transfers the retained bar out of the responder host");
    NSDictionary* modalButtons=[(id)bar.delegate valueForKey:@"touchButtons"];
    NSButton* capture=modalButtons[@"touch.capture"];
    [capture performClick:nil]; SDL_Event command; bool routed=false;
    while (SDL_PollEvent(&command)) if (command.type==nativeOverlayEventType() && (command.user.code==201 || command.user.code==202)) routed=true;
    check(routed,"Transferred modal controls must preserve native SDL action routing");
    refresh(bar); refresh(bar); check(shown==1,"Repeated state refresh must not steal presentation again");
    mockKey=false; notify(NSWindowDidResignKeyNotification,fixtureWindow);
    check(hidden==1 && presented==nil && fixtureWindow.touchBar==bar,"Losing window key status must release full width and restore the normal responder host");
    mockKey=true; notify(NSWindowDidBecomeKeyNotification,fixtureWindow);
    check(shown==2 && presented==bar,"Regaining the active stream window may reacquire full width");
    mockActive=false; notify(NSApplicationDidResignActiveNotification,NSApp);
    check(hidden==2 && presented==nil,"Switching applications must restore the system strip");
    mockActive=true; notify(NSApplicationDidBecomeActiveNotification,NSApp);
    check(shown==3 && presented==bar,"Returning to the owning app may reacquire full width");
    mockVisible=false; notify(NSWindowDidMiniaturizeNotification,fixtureWindow);
    check(hidden==3 && presented==nil,"An invisible or minimized stream must not own the full bar");
    mockVisible=true; notify(NSWindowDidChangeOcclusionStateNotification,fixtureWindow);
    check(shown==4 && presented==bar,"A visible key stream may reacquire full width");
    reenterHide=true; fixture.enable(false);
    check(hidden==4 && presented==nil && fixtureWindow.touchBar==bar,"Disabling must release ownership once and restore normal controls despite synchronous refresh");

    fprintf(stderr,"Presentation fixture: focus loss inside show callback\n");
    loseFocusDuringShow=true; fixture.enable(true);
    check(shown==5 && hidden==5 && presented==nil,"Focus loss during presentation must cancel ownership rather than restoring stale state");
    check(![[(id)bar.delegate valueForKey:@"touchFullWidthPresented"] boolValue],"Reentrant focus loss must clear the native ownership flag");
    mockKey=true; notify(NSWindowDidBecomeKeyNotification,fixtureWindow);
    check(shown==6 && presented==bar,"Reentrant cancellation must not prevent a later genuine focus gain");

    fprintf(stderr,"Presentation fixture: detach and reconnect\n");
    nativeOverlayDetach(); pump();
    check(hidden==6 && presented==nil && fixtureWindow.touchBar==fixture.originalBar,"Detach must dismiss full width and restore the previous responder bar");
    check(bar.delegate==nil,"Detach must remove the old presentation owner");
    notify(NSWindowDidBecomeKeyNotification,fixtureWindow);
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.touchBarPresentationChanged" object:nil userInfo:nil deliverImmediately:YES]; pump();
    check(shown==6 && hidden==6,"Late focus or settings notifications must not revive a detached bar");
    nativeOverlayAttach(fixtureWindow,"presentation-fixture-next"); pump(); fixture.retainCurrentBar();
    check(shown==7 && presented==fixture.retainedBar,"A later session must own only its newly attached bar");
    nativeOverlayDetach(); nativeOverlayDetach(); pump();
    check(hidden==7 && presented==nil && fixtureWindow.touchBar==fixture.originalBar,"Repeated detach must be idempotent");
    fixture.enable(false);
    nativeOverlayAttach(fixtureWindow,"presentation-fixture-disabled"); pump(); fixture.retainCurrentBar();
    check(shown==7 && presented==nil,"Disabled full width must remain disabled across reconnects");
    nativeOverlayDetach();

    fprintf(stderr,"Presentation fixture: content guards and private API rejection\n");
    nativeOverlayAttach(fixtureWindow,"presentation-fixture-fallback"); pump(); fixture.retainCurrentBar();
    bar=fixture.retainedBar;
    NSArray* originalItems=[bar.defaultItemIdentifiers copy];
    bar.defaultItemIdentifiers=@[];
    fixture.enable(true);
    check(shown==7 && hidden==7 && presented==nil && fixtureWindow.touchBar==bar,
          "An empty bar must retain ordinary window controls without invoking private presentation");
    refresh(bar); refresh(bar);
    check(shown==7,"A rejected empty bar must not retry private presentation during telemetry refresh");
    bar.defaultItemIdentifiers=originalItems; [originalItems release];
    fixture.enable(false);
    throwDuringShow=true; fixture.enable(true);
    check(shown==8 && hidden==8 && presented==nil && fixtureWindow.touchBar==bar,
          "A throwing private presentation must dismiss partial ownership and retain ordinary controls");
    check(![[(id)bar.delegate valueForKey:@"touchFullWidthPresented"] boolValue],
          "Private API rejection must never claim full-width ownership");
    check(![fixture.preferences boolForKey:@"touchBarFullWidth"] && [fixture.preferences boolForKey:@"touchBarFullWidthUnavailable"],
          "Rejected presentation must report the normal-width fallback in shared frontend settings");
    refresh(bar); refresh(bar);
    check(shown==8 && hidden==8,"A rejected private API must not flash/retry on every state update");
    fixture.enable(false); fixture.enable(true);
    check(shown==9 && presented==bar,"An explicit setting change can retry a recovered presentation");
    throwDuringHide=true; fixture.enable(false);
    check(hidden==9 && presented==nil && fixtureWindow.touchBar==bar,
          "A throwing private dismissal must not crash normal controls or preserve stale ownership");
    nativeOverlayDetach();
    check(fixtureWindow.touchBar==fixture.originalBar && bar.delegate==nil,"Fallback cleanup must restore the previous bar and release delegates");
    fprintf(stderr,"PASS: native full-width content guards, private API exception fallback, retry suppression, default, focus/visibility, reentrancy and cleanup\n");
}

int main() { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; [NSApp finishLaunching];
    Fixture fixture;
    try { run(fixture); return 0; }
    catch (const std::exception& error) { fprintf(stderr,"FAIL: %s\n",error.what()); return 1; }
} }
