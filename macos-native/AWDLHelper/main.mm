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
static NSString* const InstalledHelper = @"/Library/PrivilegedHelperTools/com.moonlight-stream.NativeGlass.AWDLHelper";
static NSString* const InstalledPlist = @"/Library/LaunchDaemons/com.moonlight-stream.NativeGlass.AWDLHelper.plist";
static NSString* const TrustDirectory = @"/Library/Application Support/Moonlight Native Glass AWDL";
static NSString* const TrustFile = @"/Library/Application Support/Moonlight Native Glass AWDL/frontend.requirement";
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
static NSString* ExecutablePath() {
    uint32_t size = 0;
    _NSGetExecutablePath(NULL, &size);
    std::vector<char> path(size);
    if (_NSGetExecutablePath(path.data(), &size) != 0) return nil;
    return [[NSString stringWithUTF8String:path.data()] stringByResolvingSymlinksInPath];
}
static NSString* FrontendRequirement() {
    NSString* app = ExecutablePath();
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

static NSString* InstalledFrontendRequirement() {
    struct stat info = {};
    if (lstat(TrustFile.fileSystemRepresentation, &info) != 0 || !S_ISREG(info.st_mode) ||
        info.st_uid != 0 || (info.st_mode & 0777) != 0600 || info.st_nlink != 1 || info.st_size > 16384) return nil;
    int fd = open(TrustFile.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW);
    if (fd < 0) return nil;
    std::vector<char> bytes(16385, 0);
    ssize_t length = read(fd, bytes.data(), 16384);
    close(fd);
    if (length <= 0) return nil;
    NSString* text = [[NSString alloc] initWithBytes:bytes.data() length:(NSUInteger)length encoding:NSUTF8StringEncoding];
    SecRequirementRef requirement = NULL;
    if (!text || SecRequirementCreateWithString((__bridge CFStringRef)text, kSecCSDefaultFlags, &requirement) != errSecSuccess) return nil;
    CFRelease(requirement);
    return text;
}

static bool SafeDirectory(NSString* path) {
    NSFileManager* files = NSFileManager.defaultManager;
    if (![files createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:NULL]) return false;
    struct stat info = {};
    return lstat(path.fileSystemRepresentation, &info) == 0 && S_ISDIR(info.st_mode) &&
        info.st_uid == 0 && (info.st_mode & 0022) == 0;
}
static int Launchctl(NSArray<NSString*>* arguments) {
    NSTask* task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
    task.arguments = arguments;
    task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    NSError* error = nil;
    if (![task launchAndReturnError:&error]) return -1;
    [task waitUntilExit];
    return task.terminationStatus;
}
// Explicit administrator-authorized fallback for ad-hoc private builds. All
// destinations and commands are fixed; the daemon accepts no installer RPC.
static int InstallHelper() {
    NSString* requirement = FrontendRequirement();
    if (!requirement) { fprintf(stderr, "The app signature is invalid.\n"); return 1; }
    struct stat marker = {};
    if (lstat(JournalPath, &marker) == 0) {
        fprintf(stderr, "End all streams and wait for AWDL restoration before installing.\n"); return 1;
    }
    if (!SafeDirectory(@"/Library/PrivilegedHelperTools") || !SafeDirectory(@"/Library/LaunchDaemons") || !SafeDirectory(TrustDirectory)) {
        fprintf(stderr, "Helper installation directories are not safe.\n"); return 1;
    }
    // Pin the running installer binary, not an executable that could be swapped
    // in the app bundle while the administrator authorization dialog is open.
    SecCodeRef running = NULL;
    SecStaticCodeRef ownStatic = NULL;
    SecRequirementRef ownRequirement = NULL;
    if (SecCodeCopySelf(kSecCSDefaultFlags, &running) != errSecSuccess ||
        SecCodeCopyStaticCode(running, kSecCSDefaultFlags, &ownStatic) != errSecSuccess ||
        SecCodeCopyDesignatedRequirement(ownStatic, kSecCSDefaultFlags, &ownRequirement) != errSecSuccess) {
        if (running) CFRelease(running); if (ownStatic) CFRelease(ownStatic);
        fprintf(stderr, "Could not verify the bundled installer.\n"); return 1;
    }
    CFRelease(running); CFRelease(ownStatic);
    NSFileManager* files = NSFileManager.defaultManager;
    NSString* staging = [InstalledHelper stringByAppendingString:@".new"];
    [files removeItemAtPath:staging error:NULL];
    BOOL copied = [files copyItemAtPath:ExecutablePath() toPath:staging error:NULL];
    SecStaticCodeRef candidate = NULL;
    BOOL valid = copied && SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:staging], kSecCSDefaultFlags, &candidate) == errSecSuccess &&
        SecStaticCodeCheckValidity(candidate, kSecCSStrictValidate, ownRequirement) == errSecSuccess;
    if (candidate) CFRelease(candidate);
    CFRelease(ownRequirement);
    if (!valid) { [files removeItemAtPath:staging error:NULL]; fprintf(stderr, "Helper signature verification failed.\n"); return 1; }
    if (chown(staging.fileSystemRepresentation, 0, 0) != 0 || chmod(staging.fileSystemRepresentation, 0755) != 0) {
        [files removeItemAtPath:staging error:NULL]; return 1;
    }
    NSDictionary* plist = @{@"Label": Service, @"ProgramArguments": @[InstalledHelper],
        @"MachServices": @{Service: @YES}, @"RunAtLoad": @YES,
        @"KeepAlive": @{@"SuccessfulExit": @NO}, @"ThrottleInterval": @10,
        @"AssociatedBundleIdentifiers": @[@"com.moonlight-stream.NativeGlass"]};
    NSError* error = nil;
    NSData* plistData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    Launchctl(@[@"bootout", @"system", InstalledPlist]);
    BOOL ok = rename(staging.fileSystemRepresentation, InstalledHelper.fileSystemRepresentation) == 0 &&
        [requirement writeToFile:TrustFile atomically:YES encoding:NSUTF8StringEncoding error:&error] &&
        chown(TrustFile.fileSystemRepresentation, 0, 0) == 0 &&
        chmod(TrustFile.fileSystemRepresentation, 0600) == 0 &&
        [plistData writeToFile:InstalledPlist options:NSDataWritingAtomic error:&error] &&
        chown(InstalledPlist.fileSystemRepresentation, 0, 0) == 0 &&
        chmod(InstalledPlist.fileSystemRepresentation, 0644) == 0;
    if (!ok) { fprintf(stderr, "Could not write the helper configuration.\n"); return 1; }
    if (Launchctl(@[@"bootstrap", @"system", InstalledPlist]) != 0) {
        fprintf(stderr, "macOS did not start the installed helper.\n"); return 1;
    }
    return 0;
}
static int RemoveHelper() {
    struct stat marker = {};
    if (lstat(JournalPath, &marker) == 0) { fprintf(stderr, "AWDL restoration is pending; removal cancelled.\n"); return 1; }
    Launchctl(@[@"bootout", @"system", InstalledPlist]);
    NSFileManager* files = NSFileManager.defaultManager;
    for (NSString* path in @[InstalledHelper, InstalledPlist, TrustFile]) {
        if ([files fileExistsAtPath:path] && ![files removeItemAtPath:path error:NULL]) {
            fprintf(stderr, "Could not remove the installed helper files.\n"); return 1;
        }
    }
    [files removeItemAtPath:TrustDirectory error:NULL];
    return 0;
}

int main(int argc, const char* argv[]) {
    @autoreleasepool {
        if (geteuid() != 0) return 1;
        if (argc == 2 && strcmp(argv[1], "--install") == 0) return InstallHelper();
        if (argc == 2 && strcmp(argv[1], "--remove") == 0) return RemoveHelper();
        if (argc != 1) return 1;
        NSString* requirement = [ExecutablePath() isEqualToString:InstalledHelper] ? InstalledFrontendRequirement() : FrontendRequirement();
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
