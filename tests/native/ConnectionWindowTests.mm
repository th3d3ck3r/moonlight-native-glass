#import <AppKit/AppKit.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include <QGuiApplication>
#include <QCoreApplication>
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include "nativeapplication.h"
#include "nativeoverlay.h"
#include "TitlebarFixture.h"
void configureNativeStreamWindow(const char*);
static void check(bool okay,const char* message) { if (!okay) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static NSWindow* cocoa(SDL_Window* window) { SDL_SysWMinfo i; SDL_VERSION(&i.version); check(SDL_GetWindowWMInfo(window,&i),"SDL Cocoa window"); return i.info.cocoa.window; }
static void drain(double seconds) { NSDate* end=[NSDate dateWithTimeIntervalSinceNow:seconds]; while(end.timeIntervalSinceNow>0) { QCoreApplication::processEvents(); SDL_PumpEvents(); [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; } }
static NSButton* button(NSView* view, NSString* title) {
    if ([view isKindOfClass:NSButton.class] && [((NSButton*)view).title isEqualToString:title]) return (NSButton*)view;
    for(NSView* child in view.subviews) { NSButton* found=button(child,title); if(found) return found; } return nil;
}
static NSView* host(NSView* view) { if ([view.identifier isEqualToString:@"stream-connection-host"]) return view; for(NSView* child in view.subviews) { NSView* found=host(child); if(found) return found; } return nil; }
static void click(NSWindow* window, NSButton* element) {
    NSRect frame=[element convertRect:element.bounds toView:nil];
    NSPoint location=NSMakePoint(NSMidX(frame),NSMidY(frame));
    check([window.contentView hitTest:[window.contentView convertPoint:location fromView:nil]]==element,
        "Connection button must receive hits inside the SDL content view");
    for (NSNumber* type in @[@(NSEventTypeLeftMouseDown),@(NSEventTypeLeftMouseUp)]) {
        NSEvent* event=[NSEvent mouseEventWithType:(NSEventType)type.integerValue location:location modifierFlags:0
            timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
        [NSApp postEvent:event atStart:NO];
    }
    drain(.3);
}
int main(int argc,char** argv) { QGuiApplication app(argc,argv); @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; [NSApp finishLaunching]; SDL_SetMainReady();
    NSUserDefaults* defaults=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Overlay"] autorelease];
    id previousCrimson=[[defaults objectForKey:@"crimsonGlass"] retain];
    [defaults setBool:YES forKey:@"crimsonGlass"]; [defaults synchronize];
    configureNativeStreamWindow("connection-window-fixture"); nativeSetConnectionWaiting(true);
    int action=0; nativeSetConnectionCommand([&action](int value) { action=value; if(value==1) nativeSetConnectionWaiting(false); });
    check(nativeCreateConnectionWindow("Gaming PC","Desktop",600,420,SDL_WINDOW_METAL),"Connection window must open before any host/Session starts");
    SDL_Window* window=nativeConnectionWindow(); check(window!=nullptr,"Real SDL window created first");
    Uint32 windowID=SDL_GetWindowID(window); NSWindow* original=cocoa(window); NSView* content=original.contentView;
    drain(.3); check([original.effectiveAppearance.name isEqualToString:NSAppearanceNameDarkAqua],"Connecting title bar must match Crimson Glass");
    check(original.visible && host(content)!=nil,"Apollo hosted inside the SDL content view");
    check(!nativeOverlayConfigured(),"Stream controls/input presentation must wait for Continue");
    nativeUpdateConnectionWindow("Starting video stream…",0); drain(.1);
    nativeUpdateConnectionWindow("Connection warning fixture",5); drain(.1);
    nativeUpdateConnectionWindow("",1); drain(2.2);
    check(nativeConnectionWindow()==window && cocoa(window)==original && original.contentView==content,"Connected orbit must retain window/content identity");
    check(host(content)!=nil && nativeConnectionWaiting(),"Orbit must remain until explicit Continue");
    if(argc>1) {
        [NSFileManager.defaultManager createDirectoryAtPath:[NSString stringWithUTF8String:argv[1]] withIntermediateDirectories:YES attributes:nil error:nil];
        NSTask* task=[[[NSTask alloc] init] autorelease]; task.launchPath=@"/usr/sbin/screencapture";
        task.arguments=@[@"-x",[[NSString stringWithUTF8String:argv[1]] stringByAppendingPathComponent:@"apollo-inside-stream-window.png"]];
        [task launch]; [task waitUntilExit]; check(task.terminationStatus==0,"Composited stream-window capture");
    }
    SDL_MinimizeWindow(window); drain(.2); nativeRestoreConnectionWindow(); drain(.2);
    check(original.visible && !(SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED),"Restore must bring back the connecting stream window");
    nativeConfirmConnectionQuit("Previous host game"); drain(.2);
    check(original.attachedSheet!=nil,"Host-game confirmation must be a sheet on the stream window");
    NSButton* confirm=button(original.attachedSheet.contentView,@"Quit and Start"); check(confirm!=nil,"Confirmation button");
    [confirm performClick:nil]; drain(.2); check(action==4 && original.attachedSheet==nil,"Confirmation must route through the owner without closing the stream window");
    // The red button cancels the connection instead of destroying the SDL view.
    [original performClose:nil]; check(action==2 && original.visible,"Close must route to Cancel while connecting/orbiting");
    action=0;
    NSButton* cancel=button(host(content),@"Cancel"); check(cancel!=nil,"Native Cancel control");
    click(original,cancel); check(action==2 && nativeConnectionWaiting(),"Cancel mouse click must reach the bridge");
    action=0;
    NSButton* proceed=button(host(content),@"Continue to Stream");
    check(proceed!=nil,"Continue must be a native control inside the real SDL hosting view");
    click(original,proceed);
    check(action==1,"Mouse click on real Continue must invoke the bridge callback");
    check(!nativeConnectionWaiting(),"Actual Continue callback must release the connection gate"); nativeDetachConnectionWindowView();
    check(host(content)==nil && original.contentView==content && SDL_GetWindowID(window)==windowID,"Continue removes only the temporary hosting subview");
    NSScreen* selectedScreen=original.screen;
    for (NSSize size : {NSMakeSize(640,360),NSMakeSize(900,520),NSMakeSize(480,640)}) {
        SDL_SetWindowPosition(window,20,20); drain(.1);
        selectedScreen=original.screen;
        nativeResizeAndCenterStreamWindow(window,int(size.width),int(size.height)); drain(.1);
        NSRect usable=selectedScreen.visibleFrame;
        check(fabs(NSMidX(original.frame)-NSMidX(usable))<1 && fabs(NSMidY(original.frame)-NSMidY(usable))<1,"Final stream frame must center after resolution/aspect changes");
        check(original.contentView==content && nativeConnectionWindow()==window,"Centering must retain the same SDL window/content");
    }
    nativeAttachStreamWindow(window); drain(.2);
    check(nativeOverlayConfigured() && nativeConnectionWindow()==window,"Same SDL window accepts the normal stream controls after handoff");
    stopNativeStreamWindow(); nativeEndConnectionWindow();
    check(nativeConnectionWindow()==nullptr,"All connection-window ownership must clear before shutdown");
    if(previousCrimson) [defaults setObject:previousCrimson forKey:@"crimsonGlass"]; else [defaults removeObjectForKey:@"crimsonGlass"];
    [defaults synchronize]; [previousCrimson release];
    puts("PASS: actual SDL window opens before connection, hosts Apollo, orbits, handles Close/Cancel, and retains the same window/content on Continue");
} }
