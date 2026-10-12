#import <AppKit/AppKit.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include <cstdio>
#include <cstdlib>
#include "nativeapplication.h"
#include "nativeoverlay.h"
#include "TitlebarFixture.h"
void configureNativeStreamWindow(const char*);
static void check(bool okay,const char* message) { if (!okay) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static NSWindow* cocoa(SDL_Window* window) { SDL_SysWMinfo i; SDL_VERSION(&i.version); check(SDL_GetWindowWMInfo(window,&i),"SDL Cocoa window"); return i.info.cocoa.window; }
static void drain(double seconds) { NSDate* end=[NSDate dateWithTimeIntervalSinceNow:seconds]; while(end.timeIntervalSinceNow>0) { SDL_PumpEvents(); [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; } }
static NSView* host(NSView* view) { if ([view.identifier isEqualToString:@"stream-connection-host"]) return view; for(NSView* child in view.subviews) { NSView* found=host(child); if(found) return found; } return nil; }
int main(int argc,char** argv) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; [NSApp finishLaunching]; SDL_SetMainReady();
    configureNativeStreamWindow("connection-window-fixture"); nativeSetConnectionWaiting(true);
    int action=0; nativeSetConnectionCommand([&action](int value) { action=value; });
    check(nativeCreateConnectionWindow("Gaming PC","Desktop",600,420,0),"Connection window must open before any host/Session starts");
    SDL_Window* window=nativeConnectionWindow(); check(window!=nullptr,"Real SDL window created first");
    Uint32 id=SDL_GetWindowID(window); NSWindow* original=cocoa(window); NSView* content=original.contentView;
    drain(.3); check(original.visible && host(content)!=nil,"Apollo hosted inside the SDL content view");
    check(!nativeOverlayConfigured(),"Stream controls/input presentation must wait for Continue");
    nativeUpdateConnectionWindow("Starting video stream…",0); drain(.1);
    nativeUpdateConnectionWindow("",1); drain(2.2);
    check(nativeConnectionWindow()==window && cocoa(window)==original && original.contentView==content,"Connected orbit must retain window/content identity");
    check(host(content)!=nil && nativeConnectionWaiting(),"Orbit must remain until explicit Continue");
    if(argc>1) {
        [NSFileManager.defaultManager createDirectoryAtPath:[NSString stringWithUTF8String:argv[1]] withIntermediateDirectories:YES attributes:nil error:nil];
        NSTask* task=[[[NSTask alloc] init] autorelease]; task.launchPath=@"/usr/sbin/screencapture";
        task.arguments=@[@"-x",[[NSString stringWithUTF8String:argv[1]] stringByAppendingPathComponent:@"apollo-inside-stream-window.png"]];
        [task launch]; [task waitUntilExit]; check(task.terminationStatus==0,"Composited stream-window capture");
    }
    // The red button cancels the connection instead of destroying the SDL view.
    [original performClose:nil]; check(action==2 && original.visible,"Close must route to Cancel while connecting/orbiting");
    nativeSetConnectionWaiting(false); nativeDetachConnectionWindowView();
    check(host(content)==nil && original.contentView==content && SDL_GetWindowID(window)==id,"Continue removes only the temporary hosting subview");
    nativeAttachStreamWindow(window); drain(.2);
    check(nativeOverlayConfigured() && nativeConnectionWindow()==window,"Same SDL window accepts the normal stream controls after handoff");
    stopNativeStreamWindow(); nativeEndConnectionWindow();
    check(nativeConnectionWindow()==nullptr,"All connection-window ownership must clear before shutdown");
    puts("PASS: actual SDL window opens before connection, hosts Apollo, orbits, handles Close/Cancel, and retains the same window/content on Continue");
} }
