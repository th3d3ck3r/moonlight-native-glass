#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#include "../../recording/RecorderABI.h"
#include <opus.h>
#include <dlfcn.h>
#include <thread>
#include <chrono>
#include <vector>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cmath>
static const MLGRecorderAPI* api;
static void pauseMs(unsigned ms) {std::this_thread::sleep_for(std::chrono::milliseconds(ms));}
static MLGRecorderStatus state(void* r) {MLGRecorderStatus s{};s.size=sizeof(s);api->status(r,&s);return s;}
struct Source {void* recorder;std::vector<uint8_t> annex,keyBytes;};
static void output(void* ref,void*,OSStatus error,VTEncodeInfoFlags,CMSampleBufferRef sample) {
    assert(!error && sample);auto source=static_cast<Source*>(ref);
    auto& bytes=source->annex;bytes.clear();
    CMFormatDescriptionRef format=CMSampleBufferGetFormatDescription(sample);
    for(size_t i=0;i<2;i++) {const uint8_t* p=nullptr;size_t n=0;int header=0;
        assert(!CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,i,&p,&n,nullptr,&header));
        bytes.insert(bytes.end(),{0,0,0,1});bytes.insert(bytes.end(),p,p+n);
    }
    CMBlockBufferRef block=CMSampleBufferGetDataBuffer(sample);size_t size=CMBlockBufferGetDataLength(block);
    std::vector<uint8_t> payload(size);assert(!CMBlockBufferCopyDataBytes(block,0,size,payload.data()));
    for(size_t i=0;i+4<=size;) {size_t n=(size_t(payload[i])<<24)|(size_t(payload[i+1])<<16)|(size_t(payload[i+2])<<8)|payload[i+3];i+=4;assert(n<=size-i);bytes.insert(bytes.end(),{0,0,0,1});bytes.insert(bytes.end(),payload.begin()+i,payload.begin()+i+n);i+=n;}
    CFArrayRef attachments=CMSampleBufferGetSampleAttachmentsArray(sample,false);
    bool key=!attachments||CFArrayGetCount(attachments)==0||CFDictionaryGetValue((CFDictionaryRef)CFArrayGetValueAtIndex(attachments,0),kCMSampleAttachmentKey_NotSync)!=kCFBooleanTrue;
    if(key) source->keyBytes=bytes;
    uint32_t rtp=uint32_t(CMTimeConvertScale(CMSampleBufferGetPresentationTimeStamp(sample),90000,kCMTimeRoundingMethod_Default).value);
    MLGRecorderChunk chunk={bytes.data(),bytes.size()};
    api->video(source->recorder,&chunk,1,rtp,1000000+uint64_t(rtp)*1000000/90000,key);
}
static void verify(NSString* file,bool audio) {
    AVURLAsset* asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:file] options:nil];
    NSArray* video=[asset tracksWithMediaType:AVMediaTypeVideo];assert(video.count==1);
    assert(CMTimeGetSeconds(asset.duration)>1);
    NSError* error=nil;AVAssetReader* reader=[[AVAssetReader alloc] initWithAsset:asset error:&error];assert(reader);
    AVAssetReaderTrackOutput* track=[[AVAssetReaderTrackOutput alloc] initWithTrack:video[0] outputSettings:@{(__bridge NSString*)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
    assert([reader canAddOutput:track]);[reader addOutput:track];assert([reader startReading]);
    unsigned frames=0;double last=-1;
    while(CMSampleBufferRef sample=[track copyNextSampleBuffer]) {double t=CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample));assert(t>=last);last=t;frames++;CFRelease(sample);}
    assert(reader.status==AVAssetReaderStatusCompleted && frames>30);
    if(audio) {
        NSArray* tracks=[asset tracksWithMediaType:AVMediaTypeAudio];assert(tracks.count==1);
        assert(fabs(CMTimeGetSeconds(((AVAssetTrack*)tracks[0]).timeRange.duration)-CMTimeGetSeconds(((AVAssetTrack*)video[0]).timeRange.duration))<0.12);
        AVAssetReader* ar=[[AVAssetReader alloc] initWithAsset:asset error:&error];
        AVAssetReaderTrackOutput* out=[[AVAssetReaderTrackOutput alloc] initWithTrack:tracks[0] outputSettings:@{AVFormatIDKey:@(kAudioFormatLinearPCM)}];[ar addOutput:out];assert([ar startReading]);
        unsigned count=0;while(CMSampleBufferRef sample=[out copyNextSampleBuffer]) {count++;CFRelease(sample);}assert(count>0 && ar.status==AVAssetReaderStatusCompleted);
    }
    fprintf(stderr,"Decoded recording: %s (%u frames)\n",file.UTF8String,frames);
}
int main(int argc,char** argv) {
    @autoreleasepool {
        assert(argc==3);void* library=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);if(!library) {fprintf(stderr,"%s\n",dlerror());return 1;}
        auto entry=reinterpret_cast<MLGRecorderEntry>(dlsym(library,"MoonlightLGRecorderGetAPI"));assert(entry && !entry(999) && !entry(2));api=entry(MLG_RECORDER_ABI);assert(api && api->size==sizeof(*api));
        NSString* dir=[NSString stringWithUTF8String:argv[2]];
        [[NSFileManager defaultManager] removeItemAtPath:dir error:nullptr];
        MLGRecorderConfig cfg{};cfg.size=sizeof(cfg);cfg.abi=MLG_RECORDER_ABI;cfg.codec=1;cfg.width=640;cfg.height=360;cfg.fps=60;cfg.memory_megabytes=16;cfg.directory=argv[2];
        // Recorder disabled: input is ignored without inspecting a null buffer.
        void* disabled=api->create(&cfg);assert(disabled && api->interest(disabled)==0);
        auto begin=std::chrono::steady_clock::now();for(unsigned i=0;i<100000;i++) assert(!api->video(disabled,nullptr,0,0,0,0));
        assert(!state(disabled).waiting_keyframe);
        fprintf(stderr,"Disabled 100000 submissions: %.3f ms\n",std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count());api->destroy(disabled);
        void* waiting=api->create(&cfg);api->command(waiting,1);pauseMs(100);
        assert(state(waiting).recording && state(waiting).waiting_keyframe);
        api->command(waiting,4);pauseMs(100);
        assert(state(waiting).failed && !state(waiting).waiting_keyframe && !api->interest(waiting));
        api->destroy(waiting);
        cfg.replay_seconds=300;cfg.audio_rate=48000;cfg.audio_channels=2;cfg.audio_streams=1;cfg.audio_coupled=1;cfg.audio_frame_samples=960;cfg.audio_mapping[1]=1;
        void* recorder=api->create(&cfg);assert(recorder);api->command(recorder,1);pauseMs(100);assert(api->interest(recorder)&1);
        Source source{recorder,{}};VTCompressionSessionRef encoder=nullptr;
        assert(!VTCompressionSessionCreate(nullptr,640,360,kCMVideoCodecType_H264,nullptr,nullptr,nullptr,output,&source,&encoder));
        assert(!VTSessionSetProperty(encoder,kVTCompressionPropertyKey_AllowFrameReordering,kCFBooleanFalse));
        assert(!VTSessionSetProperty(encoder,kVTCompressionPropertyKey_MaxKeyFrameInterval,(__bridge CFNumberRef)@60));
        CVPixelBufferRef image=nullptr;assert(!CVPixelBufferCreate(nullptr,640,360,kCVPixelFormatType_32BGRA,(__bridge CFDictionaryRef)@{(__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}},&image));
        CVPixelBufferLockBaseAddress(image,0);memset(CVPixelBufferGetBaseAddress(image),0x40,CVPixelBufferGetDataSize(image));CVPixelBufferUnlockBaseAddress(image,0);
        int err=0;OpusEncoder* opus=opus_encoder_create(48000,2,OPUS_APPLICATION_AUDIO,&err);assert(opus&&!err);
        std::vector<float> pcm(960*2,0.1f);uint8_t packet[4096];unsigned audioIndex=0;
        for(unsigned frame=0;frame<240;frame++) {
            assert(!VTCompressionSessionEncodeFrame(encoder,image,CMTimeMake(frame,60),CMTimeMake(1,60),nullptr,nullptr,nullptr));
            VTCompressionSessionCompleteFrames(encoder,kCMTimeInvalid);
            while(audioIndex*20<=(frame+1)*1000/60) {int size=opus_encode_float(opus,pcm.data(),960,packet,sizeof(packet));assert(size>0);api->audio(recorder,audioIndex%10==9 ? nullptr : packet,audioIndex%10==9 ? 0 : size,1000000+audioIndex*20000);audioIndex++;pauseMs(2);}
            pauseMs(16);
        }
        CFRelease(image);VTCompressionSessionInvalidate(encoder);CFRelease(encoder);opus_encoder_destroy(opus);
        pauseMs(300);auto s=state(recorder);fprintf(stderr,"Source status: %s, drops %llu\n",s.message,(unsigned long long)s.dropped);assert(!s.failed && s.recording && s.replay_ready);
        api->command(recorder,2);pauseMs(100);api->command(recorder,1);pauseMs(100);api->destroy(recorder);
        unsigned recordings=0;for(NSString* file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nullptr]) if([file.pathExtension isEqual:@"mov"]) {verify([dir stringByAppendingPathComponent:file],true);recordings++;}assert(recordings==2);
        // Record/stop/record with replay OFF and a timestamp gap. The second
        // audio decoder must re-anchor rather than omit audio until it catches up.
        cfg.replay_seconds=0;
        recorder=api->create(&cfg);assert(recorder);
        for(unsigned phase=0;phase<2;phase++) {
            api->command(recorder,1);pauseMs(100);
            opus=opus_encoder_create(48000,2,OPUS_APPLICATION_AUDIO,&err);assert(opus&&!err);
            unsigned packets=0;unsigned base=phase?600:0;
            for(unsigned i=0;i<120;i++) {
                MLGRecorderChunk chunk={source.keyBytes.data(),source.keyBytes.size()};
                api->video(recorder,&chunk,1,(base+i)*1500,1000000+uint64_t(base+i)*1000000/60,1);
                while(packets*20<=(i+1)*1000/60) {int size=opus_encode_float(opus,pcm.data(),960,packet,sizeof(packet));assert(size>0);api->audio(recorder,packet,size,1000000+uint64_t(base)*1000000/60+packets*20000);packets++;pauseMs(2);}
                pauseMs(16);
            }
            opus_encoder_destroy(opus);api->command(recorder,1);pauseMs(200);assert(!state(recorder).failed && !api->interest(recorder));
        }
        api->destroy(recorder);
        recordings=0;for(NSString* file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nullptr]) if([file.pathExtension isEqual:@"mov"]) {verify([dir stringByAppendingPathComponent:file],true);recordings++;}assert(recordings==4);
        // Hardware path: one encoder, a replay buffer and a manual writer.
        cfg.mode=1;cfg.output_codec=2;cfg.output_width=320;cfg.output_height=180;cfg.output_fps=30;cfg.bitrate=5000000;cfg.audio_channels=0;cfg.replay_seconds=30;
        recorder=api->create(&cfg);assert(recorder);api->command(recorder,1);pauseMs(100);
        assert(!CVPixelBufferCreate(nullptr,640,360,kCVPixelFormatType_32BGRA,(__bridge CFDictionaryRef)@{(__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}},&image));
        for(unsigned i=0;i<180;i++) {api->pixel(recorder,image,i*1500,1000000+i*16667,0);pauseMs(17);}
        s=state(recorder);fprintf(stderr,"Hardware status: %s\n",s.message);
        bool hardware=!s.failed;
        if(hardware) {assert(s.replay_ready && !s.waiting_keyframe);api->command(recorder,2);pauseMs(100);}
        else assert(strstr(s.message,"Hardware") || strstr(s.message,"hardware"));
        CFRelease(image);api->destroy(recorder);
        if(hardware) {
            unsigned count=0;
            for(NSString* file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nullptr]) if([file.pathExtension isEqual:@"mov"]) {
                NSString* path=[dir stringByAppendingPathComponent:file];
                AVAssetTrack* track=[[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil] tracksWithMediaType:AVMediaTypeVideo].firstObject;
                if(track.naturalSize.width==320) {verify(path,false);assert(track.naturalSize.height==180 && track.nominalFrameRate<=31);count++;}
            }
            assert(count==2);
        }
        // Bounded overload fails closed without crashing the ingress caller.
        cfg.mode=0;cfg.replay_seconds=30;recorder=api->create(&cfg);assert(recorder);
        MLGRecorderChunk oversized={nullptr,size_t(33)*1024*1024};api->video(recorder,&oversized,1,0,0,1);pauseMs(100);
        assert(state(recorder).failed && !api->interest(recorder));api->destroy(recorder);
        // Failure is isolated: an unwritable destination does not abort callers.
        cfg.directory="/dev/null/MoonlightLG";recorder=api->create(&cfg);pauseMs(100);assert(state(recorder).failed);api->destroy(recorder);
        // Match the host: retain the module through process exit so system
        // completion blocks can safely finish unwinding.
        fprintf(stderr,"Recorder ABI, disabled path, source mux, audio, replay disk cache, hardware gate and disk error verified\n");
    }
}
