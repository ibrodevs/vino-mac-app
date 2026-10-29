// Signed-system-interpreter transport informed by ungive/mediaremote-adapter.
// See NOTICE.md for provenance. This helper only reads the active media session.
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

typedef void (*GetInfo)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetPID)(dispatch_queue_t, void (^)(int));

__attribute__((visibility("default"))) void vino_read(void) {
    @autoreleasepool {
        void *framework = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
        GetInfo getInfo = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingInfo") : NULL;
        GetPID getPID = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingApplicationPID") : NULL;
        if (!getInfo || !getPID) { puts("null"); return; }
        dispatch_queue_t queue = dispatch_queue_create("app.vino.media-reader", DISPATCH_QUEUE_SERIAL);
        dispatch_group_t group = dispatch_group_create();
        __block NSDictionary *info = nil;
        __block int pid = 0;
        dispatch_group_enter(group);
        getInfo(queue, ^(NSDictionary *value) { info = [value copy]; dispatch_group_leave(group); });
        dispatch_group_enter(group);
        getPID(queue, ^(int value) { pid = value; dispatch_group_leave(group); });
        if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC))) {
            puts("null"); return;
        }
        id (^value)(NSString *) = ^id(NSString *suffix) {
            return info[[@"kMRMediaRemoteNowPlayingInfo" stringByAppendingString:suffix]];
        };
        NSString *(^text)(NSString *) = ^NSString *(NSString *suffix) {
            id result = value(suffix);
            return [result isKindOfClass:NSString.class] ? result : @"";
        };
        NSNumber *(^number)(NSString *) = ^NSNumber *(NSString *suffix) {
            id result = value(suffix);
            return [result isKindOfClass:NSNumber.class] ? result : @0;
        };
        double rate = number(@"PlaybackRate").doubleValue;
        double elapsed = number(@"ElapsedTime").doubleValue;
        id timestamp = value(@"Timestamp");
        if ([timestamp isKindOfClass:NSDate.class] && rate > 0) {
            elapsed += MAX(0, -[timestamp timeIntervalSinceNow]) * rate;
        }
        id artwork = value(@"ArtworkData");
        id encoded = [artwork isKindOfClass:NSData.class] ? [artwork base64EncodedStringWithOptions:0] : NSNull.null;
        NSString *source = pid ? [NSRunningApplication runningApplicationWithProcessIdentifier:pid].localizedName : nil;
        NSDictionary *snapshot = @{
            @"title": text(@"Title"), @"artist": text(@"Artist"), @"album": text(@"Album"),
            @"duration": number(@"Duration"), @"elapsed": @(MAX(0, elapsed)),
            @"playbackRate": @(rate), @"artworkBase64": encoded,
            @"sourceApp": source ?: @""
        };
        NSData *json = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
        if (json) { fwrite(json.bytes, 1, json.length, stdout); fputc('\n', stdout); }
        else puts("null");
        fflush(stdout);
    }
}
