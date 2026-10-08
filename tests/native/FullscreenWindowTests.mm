#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <SDL.h>
#import <SDL_metal.h>
#import <SDL_syswm.h>
#include <cstdio>
#include <cstdlib>
#include "nativeapplication.h"
#include "nativeoverlay.h"
#include "nativetitlebar.h"

void configureNativeStreamWindow(const char* token);
void stopNativeStreamWindow();
static int fullscreenExits, fullscreenRestores;
static bool fixtureTransition(SDL_Window* window, Uint32 flags) {
    if (flags) ++fullscreenRestores; else ++fullscreenExits;
    return SDL_SetWindowFullscreen(window, flags)==0;
}
static void check(bool okay, const char* message) {
    if (!okay) { std::fprintf(stderr,"FAIL: %s (SDL: %s)\n",message,SDL_GetError()); std::exit(1); }
}
static void pump(double seconds=.3) {
    NSDate* end=[NSDate dateWithTimeIntervalSinceNow:seconds];
    do {
        SDL_PumpEvents();
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        // Match Session: handle restoration after returning from AppKit callbacks.
        SDL_Event restore;
        if (nativeRestoreStreamWindowEventType())
            while (SDL_PeepEvents(&restore,1,SDL_GETEVENT,nativeRestoreStreamWindowEventType(),nativeRestoreStreamWindowEventType())==1)
                nativeRestoreStreamWindow(restore.user.windowID);
    } while (end.timeIntervalSinceNow>0);
}
static NSWindow* cocoa(SDL_Window* window) {
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    check(SDL_GetWindowWMInfo(window,&info),"Cocoa window unavailable");
    return info.info.cocoa.window;
}
static void draw(CAMetalLayer* layer, id<MTLCommandQueue> queue) {
    for (int i=0; i<3; ++i) {
        id<CAMetalDrawable> drawable=[layer nextDrawable];
        check(drawable!=nil,"Fullscreen Metal drawable unavailable");
        MTLRenderPassDescriptor* pass=[MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture=drawable.texture;
        pass.colorAttachments[0].loadAction=MTLLoadActionClear;
        pass.colorAttachments[0].storeAction=MTLStoreActionStore;
        pass.colorAttachments[0].clearColor=MTLClearColorMake(.08,.65,.85,1);
        id<MTLCommandBuffer> command=[queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder=[command renderCommandEncoderWithDescriptor:pass];
        check(encoder!=nil,"Fullscreen Metal render encoder unavailable");
        [encoder endEncoding]; [command presentDrawable:drawable]; [command commit];
        [command waitUntilCompleted];
        check(command.status==MTLCommandBufferStatusCompleted,"Fullscreen Metal presentation failed");
        pump(.1);
    }
}
static void capture(NSString* directory, NSString* name, bool stream) {
    NSString* path=[directory stringByAppendingPathComponent:name];
    NSTask* task=[[[NSTask alloc] init] autorelease];
    task.executableURL=[NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
    task.arguments=@[@"-x",@"-m",path];
    check([task launchAndReturnError:nil],"Composited screenshot could not launch");
    [task waitUntilExit]; check(task.terminationStatus==0,"Composited screenshot failed");
    NSBitmapImageRep* image=(NSBitmapImageRep*)[NSBitmapImageRep imageRepWithContentsOfFile:path];
    check(image!=nil,"Composited screenshot unreadable");
    NSColor* color=[[image colorAtX:image.pixelsWide/2 y:image.pixelsHigh/2] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    std::printf("PIXEL %s: %.3f %.3f %.3f\n",name.UTF8String,color.redComponent,color.greenComponent,color.blueComponent);
    check(stream ? (color.redComponent<.3 && color.greenComponent>.4 && color.blueComponent>.6)
                 : (color.redComponent>.6 && color.greenComponent<.3 && color.blueComponent>.4),
          stream ? "Fullscreen is not presenting the Metal stream fixture onscreen"
                 : "Hiding fullscreen left a black/covered desktop instead of the underlying window");
}
int main(int argc, char** argv) { @autoreleasepool {
    check(argc==3,"Usage: fullscreen-window-tests spaces(0/1) capture-directory");
    const bool spaces=atoi(argv[1])!=0;
    NSString* directory=[NSString stringWithUTF8String:argv[2]];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    [NSApplication sharedApplication]; [NSApp finishLaunching];
    SDL_SetMainReady();
    // Session uses desktop fullscreen in both macOS modes. Full Screen disables
    // Spaces; Borderless Full Screen enables Spaces, before SDL video init.
    SDL_SetHint(SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES,spaces ? "1" : "0");
    configureNativeStreamWindow("fullscreen-start-fixture");
    nativeSetStreamFullscreenTransition(fixtureTransition);
    check(SDL_Init(SDL_INIT_VIDEO)==0,"SDL initialization failed");
    NSWindow* desktop=[[[NSWindow alloc] initWithContentRect:NSScreen.mainScreen.frame
        styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO] autorelease];
    desktop.releasedWhenClosed=NO;
    desktop.backgroundColor=[NSColor colorWithSRGBRed:.85 green:.08 blue:.65 alpha:1];
    [desktop makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES]; pump();
    SDL_Window* window=SDL_CreateWindow("Fullscreen startup fixture",100,100,640,360,
        SDL_WINDOW_RESIZABLE|SDL_WINDOW_ALLOW_HIGHDPI|SDL_WINDOW_METAL);
    check(window!=nullptr,"SDL stream creation failed");
    // Match Session startup: enter fullscreen before the first decoder/view.
    check(SDL_SetWindowFullscreen(window,SDL_WINDOW_FULLSCREEN_DESKTOP)==0,"Initial fullscreen entry failed");
    SDL_MetalView view=SDL_Metal_CreateView(window);
    check(view!=nullptr,"SDL Metal view unavailable");
    CAMetalLayer* layer=(CAMetalLayer*)SDL_Metal_GetLayer(view);
    layer.device=MTLCreateSystemDefaultDevice(); layer.pixelFormat=MTLPixelFormatBGRA8Unorm;
    id<MTLCommandQueue> queue=[layer.device newCommandQueue];
    check(queue!=nil,"Metal command queue unavailable");
    [NSApp activateIgnoringOtherApps:YES]; [cocoa(window) makeKeyAndOrderFront:nil]; pump(1);
    check(NSApp.activationPolicy==NSApplicationActivationPolicyAccessory,"Fullscreen created an engine Dock icon");
    check(nativeOverlayConfigured(),"Native stream presentation did not attach");
    // Reattach synchronously to catch even a transient toolbar/layout mutation.
    NSRect frame=cocoa(window).frame, content=cocoa(window).contentView.bounds;
    NSView* contentView=cocoa(window).contentView;
    nativeTitlebarAttach(cocoa(window));
    check(cocoa(window).toolbar==nil,"Initial fullscreen attached a native title toolbar");
    check(cocoa(window).contentView==contentView && NSEqualRects(frame,cocoa(window).frame)
        && NSEqualRects(content,cocoa(window).contentView.bounds),"Native attachment changed fullscreen video geometry");
    pump(); draw(layer,queue);
    capture(directory,@"initial.png",true);
    const Uint32 id=SDL_GetWindowID(window);
    for (int attempt=0; attempt<2; ++attempt) {
        // Unlike the old lifecycle test, hide while the host still has capture.
        check(SDL_SetRelativeMouseMode(SDL_TRUE)==0,"Initial stream capture failed");
        SDL_SetWindowKeyboardGrab(window,SDL_TRUE);
        SDL_FlushEvents(SDL_FIRSTEVENT,SDL_LASTEVENT);
        check(nativeHideStreamWindow(window),"Native close-window shortcut failed"); pump(1);
        check(!cocoa(window).visible && SDL_GetWindowFromID(id)==window,"Hide destroyed or retained a visible stream window");
        check(nativeStreamWindowHasHiddenFullscreen(window),"Hidden fullscreen capture intent was lost");
        SDL_Event event;
        while (SDL_PollEvent(&event)) check(event.type!=SDL_QUIT && !(event.type==SDL_WINDOWEVENT
            && event.window.event==SDL_WINDOWEVENT_CLOSE),"Hide queued session termination");
        capture(directory,[NSString stringWithFormat:@"hidden-%d.png",attempt],false);
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.moonlight-stream.NativeGlass.restoreStreamWindow"
            object:@"fullscreen-start-fixture" userInfo:nil deliverImmediately:YES]; pump(1);
        check(SDL_GetKeyboardFocus()==window && cocoa(window).visible,"Restore lost the original stream focus");
        check(SDL_GetWindowFlags(window)&SDL_WINDOW_FULLSCREEN,"Restore lost the requested fullscreen mode");
        check(!nativeStreamWindowHasHiddenFullscreen(window) && SDL_GetRelativeMouseMode(),"Restore lost fullscreen capture intent");
        check(cocoa(window).toolbar==nil,"Restore installed fullscreen title controls");
        draw(layer,queue);
        capture(directory,[NSString stringWithFormat:@"restored-%d.png",attempt],true);
        SDL_SetRelativeMouseMode(SDL_FALSE); SDL_SetWindowKeyboardGrab(window,SDL_FALSE);
    }
    check(fullscreenExits==2 && fullscreenRestores==2,"Hide/restore must route every fullscreen change through the supplied Session transition");
    check(SDL_SetWindowFullscreen(window,0)==0,"Return to windowed failed"); pump(1);
    check(cocoa(window).toolbar!=nil,"Returning to windowed lost the native title controls");
    [queue release]; SDL_Metal_DestroyView(view); SDL_DestroyWindow(window); pump();
    nativeSetStreamFullscreenTransition(nullptr);
    stopNativeStreamWindow(); [desktop orderOut:nil]; SDL_Quit();
    std::printf("PASS: %s startup, composited Metal output, captured hide/desktop/restore and windowed return (no host/decode test)\n",
        spaces ? "Borderless Full Screen" : "Full Screen");
    return 0;
} }
