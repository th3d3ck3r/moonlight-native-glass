#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <mach-o/dyld.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <net/if.h>
#include <fcntl.h>
#include <unistd.h>
#include <memory>
#include <vector>
#include <atomic>
#include "AWDLLeaseCore.h"

static NSString* const Service = @"com.moonlight-stream.NativeGlass.AWDLHelper";
static const char* JournalPath = "/var/run/com.moonlight-stream.NativeGlass.awdl-restore";
static dispatch_queue_t Worker;
static std::unique_ptr<AWDLLeaseCore> Core;
static double RemovalUntil = 0;

@protocol NativeAWDLControl
- (void)renewLeaseWithReply:(void (^)(BOOL, NSString*))reply;
- (void)releaseLeaseWithReply:(void (^)(BOOL, NSString*))reply;
- (void)prepareRemovalWithReply:(void (^)(BOOL, NSString*))reply;
@end

static std::optional<bool> ReadInterface() {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return std::nullopt;
    struct ifreq request = {};
    strlcpy(request.ifr_name, "awdl0", sizeof(request.ifr_name));
    int result = ioctl(fd, SIOCGIFFLAGS, &request);
    close(fd);
    if (result != 0) return std::nullopt;
    return (request.ifr_flags & IFF_UP) != 0;
}
static bool SetInterface(bool up) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return false;
    struct ifreq request = {};
    strlcpy(request.ifr_name, "awdl0", sizeof(request.ifr_name));
    bool ok = ioctl(fd, SIOCGIFFLAGS, &request) == 0;
    if (ok) {
        if (up) request.ifr_flags |= IFF_UP; else request.ifr_flags &= ~IFF_UP;
        ok = ioctl(fd, SIOCSIFFLAGS, &request) == 0;
    }
    close(fd);
    auto actual = ReadInterface();
    return ok && actual && *actual == up;
}
static bool ValidJournal() {
    struct stat info = {};
    return lstat(JournalPath, &info) == 0 && S_ISREG(info.st_mode) &&
        info.st_uid == 0 && (info.st_mode & 0777) == 0600 && info.st_nlink == 1;
}
static bool Journal(bool pending) {
    if (!pending) return ValidJournal() && unlink(JournalPath) == 0;
    int fd = open(JournalPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (fd < 0) return false;
    const char marker = '1';
    bool ok = write(fd, &marker, 1) == 1 && fsync(fd) == 0;
    close(fd);
    if (!ok) unlink(JournalPath);
    return ok;
}
static double Now() { return NSProcessInfo.processInfo.systemUptime; }
static NSString* Message() { return [NSString stringWithUTF8String:Core->error.c_str()]; }

@interface AWDLClient : NSObject <NativeAWDLControl>
@property unsigned long owner;
@property BOOL closed; // Worker queue only
@end
@implementation AWDLClient
- (void)renewLeaseWithReply:(void (^)(BOOL, NSString*))reply {
    dispatch_async(Worker, ^{
        if (self.closed) { reply(NO, @"AWDL connection closed."); return; }
        if (Now() < RemovalUntil) { reply(NO, @"AWDL helper removal is in progress."); return; }
        BOOL ok = Core->renew(self.owner, Now());
        reply(ok, Message());
    });
}
- (void)releaseLeaseWithReply:(void (^)(BOOL, NSString*))reply {
    dispatch_async(Worker, ^{ BOOL ok = Core->release(self.owner); reply(ok, Message()); });
}
- (void)prepareRemovalWithReply:(void (^)(BOOL, NSString*))reply {
    dispatch_async(Worker, ^{
        if (Core->activeCount() != 0) { reply(NO, @"Another Moonlight session is using the helper. End all streams before removing it."); return; }
        BOOL ok = Core->restore();
        if (ok) RemovalUntil = Now() + 10.0;
        reply(ok, Message());
    });
}
@end

@interface AWDLListener : NSObject <NSXPCListenerDelegate>
@end
@implementation AWDLListener
- (BOOL)listener:(NSXPCListener*)listener shouldAcceptNewConnection:(NSXPCConnection*)connection {
    (void)listener;
    static std::atomic_ulong nextOwner{0};
    AWDLClient* client = [AWDLClient new];
    client.owner = ++nextOwner;
    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(NativeAWDLControl)];
    connection.exportedObject = client;
    void (^cleanup)(void) = ^{
        dispatch_async(Worker, ^{ client.closed = YES; Core->release(client.owner); });
    };
    connection.invalidationHandler = cleanup;
    connection.interruptionHandler = cleanup;
    [connection resume];
    return YES;
}
@end

// Derive the exact approved frontend's designated requirement from its signed
// bundle. For ad-hoc builds this pins its cdhash, rather than trusting a caller-
// supplied bundle identifier or a PID susceptible to reuse. XPC verifies peers.
static NSString* FrontendRequirement() {
    uint32_t size = 0;
    _NSGetExecutablePath(NULL, &size);
    std::vector<char> path(size);
    if (_NSGetExecutablePath(path.data(), &size) != 0) return nil;
    NSString* app = [[NSString stringWithUTF8String:path.data()] stringByResolvingSymlinksInPath];
    for (int i = 0; i < 4; i++) app = app.stringByDeletingLastPathComponent;
    if (![app.pathExtension isEqualToString:@"app"]) return nil;
    NSDictionary* info = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Contents/Info.plist"]];
    if (![info[@"CFBundleIdentifier"] isEqualToString:@"com.moonlight-stream.NativeGlass"]) return nil;
    SecStaticCodeRef code = NULL;
    SecRequirementRef requirement = NULL;
    CFStringRef text = NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:app], kSecCSDefaultFlags, &code) != errSecSuccess) return nil;
    if (SecStaticCodeCheckValidity(code, kSecCSStrictValidate, NULL) == errSecSuccess &&
        SecCodeCopyDesignatedRequirement(code, kSecCSDefaultFlags, &requirement) == errSecSuccess)
        SecRequirementCopyString(requirement, kSecCSDefaultFlags, &text);
    if (requirement) CFRelease(requirement);
    CFRelease(code);
    return CFBridgingRelease(text);
}

int main() {
    @autoreleasepool {
        if (geteuid() != 0) return 1;
        NSString* requirement = FrontendRequirement();
        if (!requirement) return 1; // Refuse unsigned/misconfigured app bundles.
        // Do not overwrite an unexpected file at the fixed journal location.
        struct stat existing = {};
        bool exists = lstat(JournalPath, &existing) == 0;
        if (exists && !ValidJournal()) return 1;
        Worker = dispatch_queue_create("com.moonlight-stream.NativeGlass.awdl", DISPATCH_QUEUE_SERIAL);
        Core = std::make_unique<AWDLLeaseCore>(ReadInterface, SetInterface, Journal, exists);
        dispatch_sync(Worker, ^{ Core->restore(); });
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, Worker);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_SEC / 10);
        dispatch_source_set_event_handler(timer, ^{ Core->tick(Now()); });
        dispatch_resume(timer);
        AWDLListener* delegate = [AWDLListener new];
        NSXPCListener* listener = [[NSXPCListener alloc] initWithMachServiceName:Service];
        [listener setConnectionCodeSigningRequirement:requirement];
        listener.delegate = delegate;
        [listener resume];
        [NSRunLoop.currentRunLoop run];
        return 0;
    }
}
