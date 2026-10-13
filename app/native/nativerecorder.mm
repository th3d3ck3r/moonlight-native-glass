#import <Foundation/Foundation.h>
#include "nativerecorder.h"
#include "nativetitlebar.h"
#include "nativeoverlay.h"
#include "../../recording/RecorderABI.h"
#include <SDL.h>
#include <dlfcn.h>
#include <atomic>
#include <shared_mutex>
#include <mutex>
extern "C" {
#include <libavutil/frame.h>
#include <libavutil/pixfmt.h>
}
namespace {
MLGRecorderConfig config{};
const MLGRecorderAPI* api=nullptr;
void* instance=nullptr;
void* library=nullptr;
std::shared_mutex lifetime;
std::atomic<unsigned> wanted{0};
SDL_TimerID timer=0;
std::atomic<bool> stopped{true};
Uint32 tick(Uint32 interval,void*) { nativeOverlayPerformAction(218);return interval; }
void poll() {
    if(stopped.load() || !instance) return;
    wanted.store(api->interest(instance),std::memory_order_release);
    MLGRecorderStatus status{};status.size=sizeof(status);api->status(instance,&status);
    nativeTitlebarSetRecording(true,status.recording,status.buffering,status.replay_ready,status.saving,status.failed,status.elapsed_seconds,status.message);
}
}
void nativeRecorderVideoConfig(int format,int width,int height,int fps) {
    config.size=sizeof(config);config.abi=MLG_RECORDER_ABI;
    // AV1/4:4:4 are explicitly gated; never silently transcode source-copy mode.
    config.codec=(format==VIDEO_FORMAT_H264)?1:((format==VIDEO_FORMAT_H265||format==VIDEO_FORMAT_H265_MAIN10)?2:0);
    config.width=width;config.height=height;config.fps=fps;
}
void nativeRecorderAudioConfig(const OPUS_MULTISTREAM_CONFIGURATION* audio) {
    config.audio_rate=audio->sampleRate;config.audio_channels=audio->channelCount;
    config.audio_streams=audio->streams;config.audio_coupled=audio->coupledStreams;
    memcpy(config.audio_mapping,audio->mapping,sizeof(config.audio_mapping));
}
void nativeRecorderStart() {
    NSUserDefaults* prefs=[[[NSUserDefaults alloc] initWithSuiteName:@"com.moonlight-stream.NativeGlass.Recording"] autorelease];
    if(![prefs boolForKey:@"enabled"]) {nativeTitlebarSetRecording(false,false,false,false,false,false,0,"Enable recording in Settings before starting a stream");return;}
    NSString* path=[NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libMoonlightLGRecorder.dylib"];
    library=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);
    if(library) {
        auto entry=reinterpret_cast<MLGRecorderEntry>(dlsym(library,"MoonlightLGRecorderGetAPI"));
        api=entry ? entry(MLG_RECORDER_ABI) : nullptr;
    }
    if(!api || api->size!=sizeof(MLGRecorderAPI) || api->abi!=MLG_RECORDER_ABI) {
        nativeTitlebarSetRecording(false,false,false,false,false,true,0,"Recording plugin missing or incompatible; streaming continues");return;
    }
    config.mode=[prefs integerForKey:@"mode"]==1?1:0;
    config.output_codec=[prefs integerForKey:@"codec"]==2?2:1;
    unsigned resolution=[prefs integerForKey:@"resolution"];
    config.output_width=resolution==720?1280:resolution==1080?1920:resolution==1440?2560:resolution==2160?3840:0;
    config.output_height=config.output_width?resolution:0;
    unsigned fps=[prefs integerForKey:@"fps"];
    config.output_fps=(fps==30||fps==60||fps==120)?fps:0;
    config.bitrate=unsigned(MAX(5,MIN(150,[prefs objectForKey:@"bitrate"] ? [prefs integerForKey:@"bitrate"] : 30)))*1000000;
    unsigned seconds=[prefs integerForKey:@"replaySeconds"];
    config.replay_seconds=[prefs boolForKey:@"replay"] ? ((seconds==30||seconds==300)?seconds:60) : 0;
    config.memory_megabytes=256;
    NSString* directory=[prefs stringForKey:@"directory"];
    if(!directory.length) directory=[NSSearchPathForDirectoriesInDomains(NSMoviesDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"MoonlightLG"];
    config.directory=directory.fileSystemRepresentation;
    {std::unique_lock<std::shared_mutex> lock(lifetime);instance=api->create(&config);}
    if(!instance) {nativeTitlebarSetRecording(false,false,false,false,false,true,0,"Recording plugin could not start; streaming continues");return;}
    stopped.store(false);poll();timer=SDL_AddTimer(1000,tick,nullptr);
}
void nativeRecorderQuiesce() {
    stopped.store(true);
    wanted.store(0,std::memory_order_release);
    if(timer) {SDL_RemoveTimer(timer);timer=0;}
}
void nativeRecorderStop() {
    nativeRecorderQuiesce();
    void* ending=nullptr;
    {std::unique_lock<std::shared_mutex> lock(lifetime);ending=instance;instance=nullptr;}
    if(ending) api->destroy(ending);
    if(library) {dlclose(library);library=nullptr;}api=nullptr;
}
void nativeRecorderCommand(unsigned action) {
    if(stopped.load()) return;
    if(instance && action!=218) api->command(instance,action==217?1:2);
    poll();
}
void nativeRecorderVideo(PDECODE_UNIT du) {
    if(!(wanted.load(std::memory_order_acquire)&1)) return;
    std::shared_lock<std::shared_mutex> lock(lifetime,std::try_to_lock);
    if(!lock || !instance) return;
    MLGRecorderChunk chunks[MLG_RECORDER_MAX_CHUNKS];size_t count=0;
    for(PLENTRY p=du->bufferList;p;p=p->next) {
        if(count==MLG_RECORDER_MAX_CHUNKS) {api->video(instance,nullptr,count+1,du->rtpTimestamp,du->receiveTimeUs,du->frameType==FRAME_TYPE_IDR);return;}
        chunks[count++]={p->data,size_t(p->length)};
    }
    api->video(instance,chunks,count,du->rtpTimestamp,du->receiveTimeUs,du->frameType==FRAME_TYPE_IDR);
}
void nativeRecorderPixel(const AVFrame* frame) {
    if(!(wanted.load(std::memory_order_acquire)&2)) return;
    std::shared_lock<std::shared_mutex> lock(lifetime,std::try_to_lock);
    if(!lock || !instance) return;
    if(frame->format==AV_PIX_FMT_VIDEOTOOLBOX && frame->data[3])
        api->pixel(instance,frame->data[3],uint32_t(frame->pts),LiGetMicroseconds(),LiGetCurrentHostDisplayHdrMode());
    else api->pixel(instance,nullptr,uint32_t(frame->pts),LiGetMicroseconds(),0);
}
void nativeRecorderAudio(const void* bytes,int size) {
    if(!(wanted.load(std::memory_order_acquire)&4)) return;
    std::shared_lock<std::shared_mutex> lock(lifetime,std::try_to_lock);
    if(lock && instance && size>0) api->audio(instance,bytes,size_t(size),LiGetMicroseconds());
}
