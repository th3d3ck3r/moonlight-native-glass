#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#include <opus_multistream.h>
#include "RecorderABI.h"
#include "AnnexB.h"
#include "BoundedQueue.h"
#include <atomic>
#include <mutex>
#include <thread>
#include <deque>
#include <vector>
#include <memory>
#include <algorithm>
#include <cstdio>
#include <functional>
#include <string>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>

namespace {
constexpr size_t MaxIngress=MLG_RECORDER_MAX_FRAME_BYTES, MaxPackets=256;
struct Spool {
    int fd=-1; off_t end=0;
    explicit Spool(NSString* directory) {
        NSString* file=[directory stringByAppendingPathComponent:@".MoonlightLG-replay-XXXXXX"];
        const char* representation=file.fileSystemRepresentation;
        std::vector<char> path(representation,representation+strlen(representation)+1);
        fd=mkstemp(path.data());
        if(fd>=0) {fcntl(fd,F_SETFD,FD_CLOEXEC);unlink(path.data());}
    }
    ~Spool() {if(fd>=0) close(fd);}
};
struct Sample {
    CMSampleBufferRef value=nullptr;
    CMFormatDescriptionRef format=nullptr;
    CMSampleTimingInfo timing{};
    CMItemCount count=1;
    size_t sampleSize=0;
    bool video=false, key=false;
    int64_t pts=0;
    size_t bytes=0;
    std::shared_ptr<Spool> spool;
    off_t offset=0;
    ~Sample() { if(value) CFRelease(value); if(format) CFRelease(format); }
    bool spill(std::shared_ptr<Spool> file) {
        if(!value || file->fd<0) return false;
        std::vector<uint8_t> data(bytes);
        if(CMBlockBufferCopyDataBytes(CMSampleBufferGetDataBuffer(value),0,bytes,data.data())) return false;
        offset=file->end;
        size_t written=0;
        while(written<bytes) {ssize_t n=pwrite(file->fd,data.data()+written,bytes-written,offset+written);if(n<=0)return false;written+=n;}
        file->end+=bytes;spool=file;
        format=CMSampleBufferGetFormatDescription(value);CFRetain(format);
        count=CMSampleBufferGetNumSamples(value);sampleSize=CMSampleBufferGetSampleSize(value,0);
        if(CMSampleBufferGetSampleTimingInfo(value,0,&timing)) return false;
        CFRelease(value);value=nullptr;return true;
    }
    CMSampleBufferRef read() const {
        if(value) {CFRetain(value);return value;}
        std::vector<uint8_t> data(bytes);size_t done=0;
        while(done<bytes) {ssize_t n=pread(spool->fd,data.data()+done,bytes-done,offset+done);if(n<=0)return nullptr;done+=n;}
        CMBlockBufferRef block=nullptr;CMSampleBufferRef sample=nullptr;
        if(CMBlockBufferCreateWithMemoryBlock(nullptr,nullptr,bytes,nullptr,nullptr,0,bytes,0,&block)) return nullptr;
        CMBlockBufferReplaceDataBytes(data.data(),block,0,bytes);
        OSStatus e=CMSampleBufferCreateReady(nullptr,block,format,count,1,&timing,1,&sampleSize,&sample);CFRelease(block);
        if(e) return nullptr;
        if(video && !key) CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sample,true),0),kCMSampleAttachmentKey_NotSync,kCFBooleanTrue);
        return sample;
    }
};
using SamplePtr=std::shared_ptr<Sample>;
struct Input {
    size_t cost=0;
    unsigned kind=0; uint32_t rtp=0; uint64_t clock=0; bool key=false,hdr=false;
    std::vector<uint8_t> data; CVPixelBufferRef pixel=nullptr; SamplePtr sample;
    ~Input() { if(pixel) CFRelease(pixel); }
};
NSData* channelLayout(unsigned channels) {
    size_t size=offsetof(AudioChannelLayout,mChannelDescriptions)+channels*sizeof(AudioChannelDescription);
    NSMutableData* data=[NSMutableData dataWithLength:size];
    auto layout=static_cast<AudioChannelLayout*>(data.mutableBytes);
    layout->mChannelLayoutTag=kAudioChannelLayoutTag_UseChannelDescriptions;layout->mNumberChannelDescriptions=channels;
    const AudioChannelLabel labels[]={kAudioChannelLabel_Left,kAudioChannelLabel_Right,kAudioChannelLabel_Center,kAudioChannelLabel_LFEScreen,kAudioChannelLabel_LeftSurround,kAudioChannelLabel_RightSurround,kAudioChannelLabel_LeftSurroundDirect,kAudioChannelLabel_RightSurroundDirect};
    for(unsigned i=0;i<channels;i++) layout->mChannelDescriptions[i].mChannelLabel=channels==1 ? kAudioChannelLabel_Mono : labels[i];
    return data;
}
struct Movie {
    AVAssetWriter* writer=nil;
    AVAssetWriterInput* video=nil;
    AVAssetWriterInput* audio=nil;
    NSString* path=nil;
    int64_t start=0;
    bool ready=false;
    ~Movie() { if(writer.status==AVAssetWriterStatusWriting) [writer cancelWriting]; }
    bool open(NSString* file, SamplePtr first, unsigned rate, unsigned channels, std::string& error) {
        path=file; start=first->pts;
        NSError* e=nil;
        writer=[[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:file] fileType:AVFileTypeQuickTimeMovie error:&e];
        if (!writer) { error=e.localizedDescription.UTF8String ?: "Cannot create recording"; return false; }
        writer.movieFragmentInterval=CMTimeMake(10,1);
        writer.initialMovieFragmentInterval=CMTimeMake(1,1);
        CMSampleBufferRef initial=first->read();
        if(!initial) {error="Replay cache could not be read";return false;}
        video=[[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil sourceFormatHint:CMSampleBufferGetFormatDescription(initial)];
        CFRelease(initial);
        video.expectsMediaDataInRealTime=YES;
        if (![writer canAddInput:video]) { error="Stream codec cannot be written. Try Custom Hardware Encoding."; return false; }
        [writer addInput:video];
        if (rate && channels) {
            NSDictionary* settings=@{AVFormatIDKey:@(kAudioFormatMPEG4AAC), AVSampleRateKey:@(rate), AVNumberOfChannelsKey:@(channels), AVEncoderBitRateKey:@(channels>2 ? 384000 : 192000), AVChannelLayoutKey:channelLayout(channels)};
            if (![writer canApplyOutputSettings:settings forMediaType:AVMediaTypeAudio]) { error="AAC encoder does not support this audio configuration"; return false; }
            audio=[[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:settings];
            audio.expectsMediaDataInRealTime=YES;
            if (![writer canAddInput:audio]) { error="Cannot add recording audio"; return false; }
            [writer addInput:audio];
        }
        if (![writer startWriting]) { error=writer.error.localizedDescription.UTF8String ?: "Cannot start recording"; return false; }
        [writer startSessionAtSourceTime:CMTimeMake(start,90000)]; ready=true; return true;
    }
    bool append(SamplePtr sample, bool realtime, std::string& error) {
        if (sample->pts<start) return true;
        AVAssetWriterInput* track=sample->video ? video : audio;
        if (!track) return true;
        // Export runs on its own thread; live ingestion never waits for a writer.
        for (unsigned i=0; !realtime && !track.readyForMoreMediaData && writer.status==AVAssetWriterStatusWriting && i<500; ++i)
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        CMSampleBufferRef buffer=sample->read();
        bool appended=buffer && track.readyForMoreMediaData && [track appendSampleBuffer:buffer];
        if(buffer) CFRelease(buffer);
        if (!appended) {
            error=writer.error.localizedDescription.UTF8String ?: "Recording writer overloaded; streaming continues"; return false;
        }
        return true;
    }
    void finish(std::function<void(bool,NSString*)> done) {
        if (!ready) { done(false,@"Recording never received a usable keyframe"); return; }
        [video markAsFinished]; if(audio) [audio markAsFinished];
        AVAssetWriter* keep=writer; NSString* file=path;
        [writer finishWritingWithCompletionHandler:^{
            if (keep.status==AVAssetWriterStatusCompleted) done(true,file);
            else done(false,keep.error.localizedDescription ?: @"Recording could not be finalized; partial movie retained");
        }];
        ready=false;
    }
};
struct Recorder {
    MLGRecorderConfig cfg{};
    NSString* directory=nil;
    std::mutex statusMutex;
    dispatch_semaphore_t wake=dispatch_semaphore_create(0);
    mlg::BoundedQueue<std::unique_ptr<Input>,MaxPackets> queue;
    std::deque<std::unique_ptr<Input>> pendingInput;
    std::atomic<size_t> queuedBytes{0};
    std::atomic<bool> quit{false};
    std::thread worker;
    dispatch_queue_t exportQueue;
    dispatch_group_t exports;
    std::atomic<unsigned> interest{0};
    std::atomic<uint32_t> overflow{0};
    std::atomic<uint64_t> drops{0};
    MLGRecorderStatus current{};
    bool recordWanted=false, replay=false, waitKey=true;
    std::shared_ptr<Movie> movie;
    std::deque<SamplePtr> ring;
    size_t ringBytes=0;
    std::shared_ptr<Spool> spool;
    CMVideoFormatDescriptionRef format=nullptr;
    std::vector<uint8_t> parameters[3];
    OpusMSDecoder* opus=nullptr;
    std::vector<float> pcm;
    CMAudioFormatDescriptionRef audioFormat=nullptr;
    uint64_t anchorClock=0;
    uint32_t lastRtp=0;
    int64_t ticks=0, lastVideo=-1, audioTicks=0;
    bool haveRtp=false, haveAudio=false;
    VTCompressionSessionRef encoder=nullptr;
    VTPixelTransferSessionRef transfer=nullptr;
    CVPixelBufferPoolRef pool=nullptr;
    int64_t lastEncoded=-1;
    Recorder(const MLGRecorderConfig& c):cfg(c) {
        directory=[[NSString alloc] initWithUTF8String:c.directory ?: ""];
        exportQueue=dispatch_queue_create("MoonlightLG.recorder.exports",DISPATCH_QUEUE_SERIAL);
        exports=dispatch_group_create();
        current.size=sizeof(current);
        replay=cfg.replay_seconds!=0;
        update("Ready");
        if(cfg.codec==0 && cfg.mode==0) fail("Original Stream Quality supports H.264/HEVC. Select Custom Hardware Encoding for this stream.");
        else refreshInterest();
        worker=std::thread([this]{
            @try {try {run();} catch(...) {interest.store(0);std::lock_guard<std::mutex> l(statusMutex);current.failed=1;snprintf(current.message,sizeof(current.message),"Recording worker failed; streaming continues");}}
            @catch(NSException* exception) {interest.store(0);std::lock_guard<std::mutex> l(statusMutex);current.failed=1;snprintf(current.message,sizeof(current.message),"Recording API rejected the media configuration; streaming continues");}
        });
    }
    ~Recorder() {
        interest.store(0);
        quit.store(true);
        dispatch_semaphore_signal(wake); worker.join();
        // No ingress remains. Complete hardware output before releasing its callback target.
        if(encoder) { VTCompressionSessionCompleteFrames(encoder,kCMTimeInvalid); VTCompressionSessionInvalidate(encoder); CFRelease(encoder); }
        if(transfer) { VTPixelTransferSessionInvalidate(transfer); CFRelease(transfer); }
        if(pool) CFRelease(pool);
        dispatch_group_wait(exports,DISPATCH_TIME_FOREVER);
        if(format) CFRelease(format);
        if(audioFormat) CFRelease(audioFormat);
        if(opus) opus_multistream_decoder_destroy(opus);
    }
    void update(const char* message) {
        std::lock_guard<std::mutex> l(statusMutex);
        current.active=interest.load()!=0; current.recording=recordWanted; current.buffering=replay;
        current.replay_ready=!ring.empty(); current.dropped=drops.load();
        current.waiting_keyframe=cfg.mode==0 && !current.failed && ((recordWanted && !movie) || (replay && ring.empty()));
        current.elapsed_seconds=movie && lastVideo>=movie->start ? (lastVideo-movie->start)/90000 : 0;
        current.buffered_seconds=ring.empty() || lastVideo<ring.front()->pts ? 0 : (lastVideo-ring.front()->pts)/90000;
        snprintf(current.message,sizeof(current.message),"%s",message);
    }
    void fail(const char* text) {
        interest.store(0); replay=false; recordWanted=false;
        { std::lock_guard<std::mutex> l(statusMutex); current.failed=1; }
        finishMovie();releaseEncoder();resetAudio(); update(text);
    }
    void resetAudio() {
        if(opus) {opus_multistream_decoder_destroy(opus);opus=nullptr;}
        if(audioFormat) {CFRelease(audioFormat);audioFormat=nullptr;}
        haveAudio=false;
    }
    void releaseEncoder() {
        if(encoder) {VTCompressionSessionInvalidate(encoder);CFRelease(encoder);encoder=nullptr;}
        if(transfer) {VTPixelTransferSessionInvalidate(transfer);CFRelease(transfer);transfer=nullptr;}
        if(pool) {CFRelease(pool);pool=nullptr;}
        lastEncoded=-1;
    }
    void refreshInterest() {
        unsigned bits=(replay||recordWanted) ? (cfg.mode==0 ? 1 : 2) : 0;
        if(bits && cfg.audio_channels) bits|=4;
        interest.store(bits);
    }
    void overload(uint32_t reason=MLG_REJECT_QUEUE_ITEMS) {
        uint32_t empty=0;overflow.compare_exchange_strong(empty,reason);
        drops++;dispatch_semaphore_signal(wake);
    }
    bool enqueue(std::unique_ptr<Input> input, size_t bytes, bool command=false) {
        if(bytes>MaxIngress) {overload(MLG_REJECT_FRAME_BYTES);return false;}
        if(quit.load() && input->kind!=4 && input->kind!=5) return false;
        size_t previous=queuedBytes.fetch_add(bytes,std::memory_order_relaxed);
        input->cost=bytes;
        const bool byteLimit=previous>MaxIngress-bytes;
        if(byteLimit || !queue.push(std::move(input))) {
            queuedBytes.fetch_sub(bytes,std::memory_order_relaxed);
            if(!command) overload(byteLimit ? MLG_REJECT_QUEUE_BYTES : MLG_REJECT_QUEUE_ITEMS);
            return false;
        }
        dispatch_semaphore_signal(wake);return true;
    }
    bool pop(std::unique_ptr<Input>& input) {
        if(!pendingInput.empty()) {input=std::move(pendingInput.front());pendingInput.pop_front();return true;}
        if(!queue.pop(input)) return false;
        queuedBytes.fetch_sub(input->cost,std::memory_order_relaxed);return true;
    }
    NSString* filename(NSString* kind) {
        NSError* e=nil;
        if(![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&e]) return nil;
        return [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"MoonlightLG-%@-%@.mov",kind,NSUUID.UUID.UUIDString]];
    }
    void finishMovie() {
        auto ending=movie; movie.reset(); if(!ending) return;
        dispatch_group_enter(exports);
        ending->finish([this,ending](bool ok,NSString* result) {
            { std::lock_guard<std::mutex> l(statusMutex); if(!ok) current.failed=1; snprintf(current.message,sizeof(current.message),"%s",result.UTF8String ?: "Finished"); }
            dispatch_group_leave(exports);
        });
    }
    void saveReplay() {
        { std::lock_guard<std::mutex> l(statusMutex); if(current.saving) return; }
        if(ring.empty()) { update("Replay is waiting for a usable keyframe"); return; }
        // Snapshot references, not a second copy of every payload. At most one export.
        std::vector<SamplePtr> snapshot(ring.begin(),ring.end());
        NSString* file=filename(@"Replay");
        if(!file) { fail("Cannot create recording folder"); return; }
        { std::lock_guard<std::mutex> l(statusMutex); current.saving=1; }
        dispatch_group_async(exports,exportQueue,^{
            @autoreleasepool {
                auto output=std::make_shared<Movie>(); std::string error;
                bool ok=output->open(file,snapshot.front(),cfg.audio_rate,cfg.audio_channels,error);
                for(auto sample:snapshot) if(ok) ok=output->append(sample,false,error);
                if(ok) {
                    dispatch_group_enter(exports);
                    output->finish([this,output](bool success,NSString* result) {
                        { std::lock_guard<std::mutex> l(statusMutex); current.saving=0; if(!success) current.failed=1; snprintf(current.message,sizeof(current.message),"%s",result.UTF8String); }
                        dispatch_group_leave(exports);
                    });
                } else {
                    std::lock_guard<std::mutex> l(statusMutex); current.saving=0; current.failed=1; snprintf(current.message,sizeof(current.message),"%s",error.c_str());
                }
            }
        });
    }
    void accept(SamplePtr sample) {
        if(sample->video) {
            lastVideo=sample->pts;
            if(waitKey && !sample->key && !movie) return;
            if(sample->key) waitKey=false;
            if(recordWanted && !movie) {
                if(!sample->key) return;
                NSString* file=filename(@"Recording"); std::string error;
                movie=std::make_shared<Movie>();
                if(!file || !movie->open(file,sample,cfg.audio_rate,cfg.audio_channels,error)) { fail(file ? error.c_str() : "Cannot create recording folder"); return; }
            }
        } else if(waitKey && !movie) return;
        if(movie) { std::string error; if(!movie->append(sample,true,error)) { fail(error.c_str()); return; } }
        if(replay && !waitKey) {
            if(cfg.replay_seconds>60) {
                if(!spool || (sample->video && sample->key)) spool=std::make_shared<Spool>(directory);
                if(!sample->spill(spool)) {fail("Replay disk cache failed; streaming continues");return;}
            }
            ring.push_back(sample); ringBytes+=sample->bytes;
            const size_t maxBytes=cfg.replay_seconds>60 ? size_t(2)*1024*1024*1024 : size_t(cfg.memory_megabytes)*1024*1024;
            // Remove whole GOPs, never a reference frame within a retained GOP.
            while(ringBytes>maxBytes || (!ring.empty() && lastVideo-ring.front()->pts>int64_t(cfg.replay_seconds)*90000)) {
                auto next=std::find_if(std::next(ring.begin()),ring.end(),[](SamplePtr p){return p->video && p->key;});
                if(next==ring.end()) {
                    if(ringBytes>maxBytes || lastVideo-ring.front()->pts>int64_t(cfg.replay_seconds)*90000) { ring.clear(); ringBytes=0; waitKey=true; update("Replay storage limit reached; waiting for requested host keyframe"); }
                    break;
                }
                size_t remove=std::distance(ring.begin(),next);
                while(remove--) { ringBytes-=ring.front()->bytes; ring.pop_front(); }
            }
        }
        update(recordWanted ? (movie ? "Recording" : "Waiting for keyframe") : "Replay buffering");
    }
    int64_t timestamp(uint32_t rtp,uint64_t clock) {
        if(!haveRtp) { haveRtp=true; lastRtp=rtp; ticks=0; anchorClock=clock; }
        else { ticks=mlg::extendRtp(rtp,lastRtp,ticks); lastRtp=rtp; }
        return ticks;
    }
    void compressed(const Input& input) {
        int64_t pts=timestamp(input.rtp,input.clock);
        auto nals=mlg::annexB(input.data.data(),input.data.size());
        std::vector<uint8_t> payload;
        bool changed=false;
        for(auto& nal:nals) {
            unsigned type=cfg.codec==1 ? nal[0]&31 : (nal[0]>>1)&63;
            int index=cfg.codec==1 ? (type==7?0:type==8?1:-1) : (type>=32&&type<=34?int(type-32):-1);
            if(index>=0) { if(parameters[index]!=nal) {parameters[index]=nal; changed=true;} continue; }
            uint32_t count=uint32_t(nal.size());
            payload.push_back(count>>24); payload.push_back(count>>16); payload.push_back(count>>8); payload.push_back(count);
            payload.insert(payload.end(),nal.begin(),nal.end());
        }
        if(changed || !format) {
            unsigned count=cfg.codec==1?2:3;
            const uint8_t* p[3]; size_t n[3];
            for(unsigned i=0;i<count;++i) {p[i]=parameters[i].data(); n[i]=parameters[i].size(); if(n[i]==0) return;}
            CMVideoFormatDescriptionRef fresh=nullptr;
            OSStatus e=cfg.codec==1 ? CMVideoFormatDescriptionCreateFromH264ParameterSets(nullptr,count,p,n,4,&fresh) : CMVideoFormatDescriptionCreateFromHEVCParameterSets(nullptr,count,p,n,4,nullptr,&fresh);
            if(e) { fail("Stream parameter sets cannot be muxed; select Custom Hardware Encoding"); return; }
            if(format && !CMFormatDescriptionEqual(format,fresh)) {
                CFRelease(fresh); fail("Stream format changed; recording stopped to preserve the file"); return;
            }
            if(format) CFRelease(format); format=fresh;
        }
        if(payload.empty()) return;
        if(lastVideo>=0 && pts<=lastVideo) { fail("Reordered stream timestamps require Custom Hardware Encoding"); return; }
        CMBlockBufferRef block=nullptr;
        if(CMBlockBufferCreateWithMemoryBlock(nullptr,nullptr,payload.size(),nullptr,nullptr,0,payload.size(),0,&block)) return;
        CMBlockBufferReplaceDataBytes(payload.data(),block,0,payload.size());
        CMSampleTimingInfo timing={CMTimeMake(1,cfg.fps),CMTimeMake(pts,90000),CMTimeMake(pts,90000)};
        size_t size=payload.size(); CMSampleBufferRef buffer=nullptr;
        OSStatus e=CMSampleBufferCreateReady(nullptr,block,format,1,1,&timing,1,&size,&buffer); CFRelease(block);
        if(e) {fail("Cannot create compressed recording sample"); return;}
        CFMutableDictionaryRef attachments=(CFMutableDictionaryRef)CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(buffer,true),0);
        if(!input.key) CFDictionarySetValue(attachments,kCMSampleAttachmentKey_NotSync,kCFBooleanTrue);
        auto sample=std::make_shared<Sample>(); sample->value=buffer; sample->video=true; sample->key=input.key; sample->pts=pts; sample->bytes=size; accept(sample);
    }
    static void encoded(void* ref,void*,OSStatus status,VTEncodeInfoFlags,CMSampleBufferRef buffer) {
        auto self=static_cast<Recorder*>(ref);
        if(status || !buffer) { auto input=std::make_unique<Input>(); input->kind=5; self->enqueue(std::move(input),0); return; }
        auto sample=std::make_shared<Sample>(); CFRetain(buffer); sample->value=buffer; sample->video=true;
        sample->pts=CMTimeConvertScale(CMSampleBufferGetPresentationTimeStamp(buffer),90000,kCMTimeRoundingMethod_Default).value;
        sample->bytes=CMSampleBufferGetTotalSampleSize(buffer);
        CFArrayRef a=CMSampleBufferGetSampleAttachmentsArray(buffer,false);
        sample->key=!a || CFArrayGetCount(a)==0 || CFDictionaryGetValue((CFDictionaryRef)CFArrayGetValueAtIndex(a,0),kCMSampleAttachmentKey_NotSync)!=kCFBooleanTrue;
        // Feed a bounded queue. The callback never writes files or dispatches
        // an unbounded collection of retained pixel/sample buffers.
        auto input=std::make_unique<Input>(); input->kind=4; input->sample=sample;
        self->enqueue(std::move(input),sample->bytes);
    }
    std::mutex encodeMutex;
    bool setupEncoder() {
        unsigned width=cfg.output_width?:cfg.width,height=cfg.output_height?:cfg.height;
        NSDictionary* spec=@{(__bridge NSString*)kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder:@YES};
        OSStatus e=VTCompressionSessionCreate(nullptr,width,height,cfg.output_codec==2?kCMVideoCodecType_HEVC:kCMVideoCodecType_H264,(__bridge CFDictionaryRef)spec,nullptr,nullptr,encoded,this,&encoder);
        if(e) { fail("Hardware encoder unavailable for these settings; no software fallback was started"); return false; }
        auto set=[&](CFStringRef key,CFTypeRef value){return VTSessionSetProperty(encoder,key,value)==noErr;};
        if(!set(kVTCompressionPropertyKey_RealTime,kCFBooleanTrue) || !set(kVTCompressionPropertyKey_AllowFrameReordering,kCFBooleanFalse) ||
           !set(kVTCompressionPropertyKey_AverageBitRate,(__bridge CFNumberRef)@(cfg.bitrate)) || !set(kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,(__bridge CFNumberRef)@2)) {
            fail("Hardware encoder does not support requested recording settings"); return false;
        }
        set(kVTCompressionPropertyKey_ExpectedFrameRate,(__bridge CFNumberRef)@(cfg.output_fps?:cfg.fps));
        if(VTCompressionSessionPrepareToEncodeFrames(encoder)) {fail("Hardware encoder could not prepare");return false;}
        CFTypeRef hardware=nullptr;
        e=VTSessionCopyProperty(encoder,kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder,nullptr,&hardware);
        bool supported=!e && hardware==kCFBooleanTrue; if(hardware) CFRelease(hardware);
        if(!supported) {fail("Hardware encoding could not be confirmed"); return false;}
        if(width!=cfg.width || height!=cfg.height) {
            NSDictionary* attrs=@{(__bridge NSString*)kCVPixelBufferWidthKey:@(width),(__bridge NSString*)kCVPixelBufferHeightKey:@(height),(__bridge NSString*)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),(__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
            if(CVPixelBufferPoolCreate(nullptr,nullptr,(__bridge CFDictionaryRef)attrs,&pool) || VTPixelTransferSessionCreate(nullptr,&transfer)) {fail("Hardware frame resizing unavailable");return false;}
        }
        return true;
    }
    void decoded(const Input& input) {
        if(input.hdr) {fail("Custom HDR recording is not enabled; use Original Stream Quality for HDR");return;}
        int64_t pts=timestamp(input.rtp,input.clock);
        unsigned fps=std::min(cfg.output_fps?:cfg.fps,cfg.fps);
        if(lastEncoded>=0 && pts-lastEncoded<90000/int64_t(fps)) return;
        if(!encoder && !setupEncoder()) return;
        CVPixelBufferRef image=input.pixel, resized=nullptr;
        if(pool) {
            if(CVPixelBufferPoolCreatePixelBuffer(nullptr,pool,&resized) || VTPixelTransferSessionTransferImage(transfer,image,resized)) {if(resized) CFRelease(resized);fail("Hardware frame resize failed");return;}
            image=resized;
        }
        OSStatus e=VTCompressionSessionEncodeFrame(encoder,image,CMTimeMake(pts,90000),CMTimeMake(1,fps),nullptr,nullptr,nullptr);
        if(resized) CFRelease(resized);
        lastEncoded=pts;
        if(e) fail("Hardware encode submission failed");
    }
    void sound(const Input& input) {
        if(!haveRtp) return;
        if(!opus) {
            int error=0;
            opus=opus_multistream_decoder_create(cfg.audio_rate,cfg.audio_channels,cfg.audio_streams,cfg.audio_coupled,cfg.audio_mapping,&error);
            if(!opus || error) {fail("Cannot initialize independent recording audio decoder");return;}
            AudioStreamBasicDescription asbd{};
            asbd.mSampleRate=cfg.audio_rate; asbd.mFormatID=kAudioFormatLinearPCM;
            asbd.mFormatFlags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked;
            asbd.mChannelsPerFrame=cfg.audio_channels; asbd.mBitsPerChannel=32; asbd.mFramesPerPacket=1;
            asbd.mBytesPerFrame=asbd.mBytesPerPacket=cfg.audio_channels*sizeof(float);
            NSData* layout=channelLayout(cfg.audio_channels);
            if(CMAudioFormatDescriptionCreate(nullptr,&asbd,layout.length,static_cast<const AudioChannelLayout*>(layout.bytes),0,nullptr,nullptr,&audioFormat)) {fail("Unsupported recording audio format");return;}
        }
        const unsigned char* packet=input.data.empty() ? nullptr : input.data.data();
        int capacity=packet ? opus_packet_get_nb_samples(packet,int(input.data.size()),cfg.audio_rate) : int(cfg.audio_frame_samples);
        if(capacity<=0 || capacity>int(cfg.audio_rate*120/1000)) {fail("Invalid recording audio packet duration");return;}
        pcm.resize(size_t(capacity)*cfg.audio_channels);
        // NULL is Moonlight's missing-packet notification. Conceal exactly the
        // negotiated duration so loss does not shorten the recording timeline.
        int frames=opus_multistream_decode_float(opus,packet,int(input.data.size()),pcm.data(),capacity,0);
        if(frames<0) {fail("Recording audio packet decode failed");return;}
        if(!haveAudio) { haveAudio=true; audioTicks=input.clock>=anchorClock ? int64_t((input.clock-anchorClock)*90000/1000000) : 0; }
        size_t bytes=size_t(frames)*cfg.audio_channels*sizeof(float);
        CMBlockBufferRef block=nullptr; CMSampleBufferRef buffer=nullptr;
        OSStatus e=CMBlockBufferCreateWithMemoryBlock(nullptr,nullptr,bytes,nullptr,nullptr,0,bytes,0,&block);
        if(e) return;
        CMBlockBufferReplaceDataBytes(pcm.data(),block,0,bytes);
        CMSampleTimingInfo timing={CMTimeMake(1,cfg.audio_rate),CMTimeMake(audioTicks,90000),kCMTimeInvalid};
        e=CMSampleBufferCreateReady(nullptr,block,audioFormat,frames,1,&timing,0,nullptr,&buffer); CFRelease(block);
        if(e) {fail("Cannot create recording audio sample");return;}
        auto sample=std::make_shared<Sample>(); sample->value=buffer; sample->pts=audioTicks; sample->bytes=bytes;
        audioTicks+=int64_t(frames)*90000/cfg.audio_rate;
        accept(sample);
    }
    void drainEncoded() {
        if(encoder) VTCompressionSessionCompleteFrames(encoder,kCMTimeInvalid);
        std::unique_ptr<Input> input;
        while(queue.pop(input)) {
            queuedBytes.fetch_sub(input->cost,std::memory_order_relaxed);
            if(input->kind==4) accept(input->sample);
            else if(input->kind==5) fail("Hardware encoder failed; streaming continues");
            else pendingInput.push_back(std::move(input));
        }
    }
    void run() {
        @autoreleasepool {
            NSError* error=nil;
            if(![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) fail("Recording folder cannot be created");
        }
        for(;;) {
            if(uint32_t reason=overflow.exchange(0)) {
                @autoreleasepool {
                    const char* message=reason==MLG_REJECT_FRAGMENT_LIMIT ? "Recording frame exceeds 65,536 fragments; streaming continues" :
                        reason==MLG_REJECT_FRAME_BYTES ? "Recording frame exceeds the 32 MB capture limit; streaming continues" :
                        reason==MLG_REJECT_QUEUE_BYTES ? "Recorder queue exceeded its 32 MB budget; recording stopped and streaming continues" :
                        reason==MLG_REJECT_MEMORY ? "Recorder could not allocate capture memory; streaming continues" :
                        reason==MLG_REJECT_INVALID_FRAME ? "Recorder received invalid frame fragments; streaming continues" :
                        "Recorder event queue congested (256-item limit); recording stopped and streaming continues";
                    fprintf(stderr,"MoonlightLG recorder rejection %u: queued bytes %zu, dropped %llu: %s\n",reason,queuedBytes.load(),(unsigned long long)drops.load(),message);
                    fail(message);
                }
            }
            std::unique_ptr<Input> input;
            if(!pop(input)) {
                if(quit.load()) break;
                // A counted wake closes publication/notification races without
                // a playback mutex or periodic idle polling.
                dispatch_semaphore_wait(wake,DISPATCH_TIME_FOREVER);continue;
            }
            @autoreleasepool {
                std::lock_guard<std::mutex> serial(encodeMutex);
                if(input->kind>=10) {
                    if(input->kind==11) {
                        if(cfg.mode==0 && cfg.codec==0) {fail("Original Stream Quality supports H.264/HEVC; select Custom Hardware Encoding");continue;}
                        if(recordWanted) {drainEncoded();recordWanted=false;finishMovie();if(!replay) {releaseEncoder();resetAudio();}}
                        else {if(!replay) resetAudio();recordWanted=true;}
                        {std::lock_guard<std::mutex> l(statusMutex);current.failed=0;}
                        refreshInterest(); update(recordWanted ? "Waiting for next keyframe" : "Recording stopped");
                    } else if(input->kind==12) saveReplay();
                    else if(input->kind==14) fail("Host did not provide a usable keyframe after three requests. Try Custom Hardware Encoding or reconnect.");
                    else { recordWanted=false; replay=false; interest.store(0); finishMovie(); update("Stopped"); }
                } else if(interest.load()) {
                    if(input->kind==1) compressed(*input);
                    else if(input->kind==2) decoded(*input);
                    else if(input->kind==3) sound(*input);
                    else if(input->kind==4) accept(input->sample);
                    else if(input->kind==6) fail("Custom recording requires the VideoToolbox decoder. Select it in Video settings.");
                    else fail("Hardware encoder failed; streaming continues");
                }
            }
        }
        drainEncoded();
        // Encoder callbacks are queued before finalization. The queue remains
        // alive until all callbacks/exports complete in the destructor.
        finishMovie();
        dispatch_group_wait(exports,DISPATCH_TIME_FOREVER);
    }
};
void* create(const MLGRecorderConfig* c) {
    if(!c || c->size!=sizeof(*c) || c->abi!=MLG_RECORDER_ABI || !c->width || !c->height || !c->fps || c->fps>240 || c->audio_channels>8 || c->memory_megabytes<16 || c->memory_megabytes>1024 || (c->audio_channels && (!c->audio_frame_samples || c->audio_frame_samples>c->audio_rate*120/1000))) return nullptr;
    try {return new Recorder(*c);} catch(...) {return nullptr;}
}
void destroy(void* p) {delete static_cast<Recorder*>(p);}
void command(void* p,uint32_t c) {
    auto self=static_cast<Recorder*>(p); auto input=std::make_unique<Input>();input->kind=10+c;
    // UI thread only; bounded retry is handled by reporting failure, never a playback wait.
    if(!self->enqueue(std::move(input),0,true)) {std::lock_guard<std::mutex> l(self->statusMutex);snprintf(self->current.message,sizeof(self->current.message),"Recorder busy; try the button again");}
}
uint32_t interest(void* p) {return static_cast<Recorder*>(p)->interest.load(std::memory_order_relaxed);}
int videoImpl(void* p,const MLGRecorderChunk* chunks,size_t count,uint32_t rtp,uint64_t clock,int key) {
    auto self=static_cast<Recorder*>(p); if(!(interest(p)&1)) return 0;
    if(count>MLG_RECORDER_MAX_CHUNKS) {self->overload(MLG_REJECT_FRAGMENT_LIMIT);return 0;}
    if(count && !chunks) {self->overload(MLG_REJECT_INVALID_FRAME);return 0;}
    size_t size=0; for(size_t i=0;i<count;i++) {
        if(chunks[i].size>MaxIngress-size) {self->overload(MLG_REJECT_FRAME_BYTES);return 0;}
        if(chunks[i].size && !chunks[i].bytes) {self->overload(MLG_REJECT_INVALID_FRAME);return 0;}
        size+=chunks[i].size;
    }
    auto input=std::make_unique<Input>();input->kind=1;input->rtp=rtp;input->clock=clock;input->key=key;input->data.reserve(size);
    for(size_t i=0;i<count;i++) {if(!chunks[i].size) continue;auto b=static_cast<const uint8_t*>(chunks[i].bytes);input->data.insert(input->data.end(),b,b+chunks[i].size);}
    return self->enqueue(std::move(input),size);
}
int pixelImpl(void* p,void* cv,uint32_t rtp,uint64_t clock,int hdr) {
    auto self=static_cast<Recorder*>(p);if(!(interest(p)&2)) return 0;
    auto input=std::make_unique<Input>();input->kind=2;input->rtp=rtp;input->clock=clock;input->hdr=hdr;
    if(!cv) {input->kind=6;return self->enqueue(std::move(input),0);}
    input->pixel=static_cast<CVPixelBufferRef>(cv);CFRetain(input->pixel);size_t cost=std::max(CVPixelBufferGetDataSize(input->pixel),CVPixelBufferGetWidth(input->pixel)*CVPixelBufferGetHeight(input->pixel)*size_t(4));return self->enqueue(std::move(input),cost);
}
int audioImpl(void* p,const void* bytes,size_t size,uint64_t clock) {
    auto self=static_cast<Recorder*>(p);if(!(interest(p)&4)) return 0;
    if(size>65536) {self->overload(MLG_REJECT_FRAME_BYTES);return 0;}
    auto input=std::make_unique<Input>();input->kind=3;input->clock=clock;
    auto data=static_cast<const uint8_t*>(bytes);if(size) input->data.assign(data,data+size);return self->enqueue(std::move(input),size);
}
int video(void* p,const MLGRecorderChunk* chunks,size_t count,uint32_t rtp,uint64_t clock,int key) {
    try {return videoImpl(p,chunks,count,rtp,clock,key);} catch(...) {static_cast<Recorder*>(p)->overload(MLG_REJECT_MEMORY);return 0;}
}
int pixel(void* p,void* cv,uint32_t rtp,uint64_t clock,int hdr) {
    try {return pixelImpl(p,cv,rtp,clock,hdr);} catch(...) {static_cast<Recorder*>(p)->overload(MLG_REJECT_MEMORY);return 0;}
}
int audio(void* p,const void* data,size_t size,uint64_t clock) {
    try {return audioImpl(p,data,size,clock);} catch(...) {static_cast<Recorder*>(p)->overload(MLG_REJECT_MEMORY);return 0;}
}
void status(void* p,MLGRecorderStatus* out) {
    auto self=static_cast<Recorder*>(p);if(!out||out->size!=sizeof(*out)) return;
    std::lock_guard<std::mutex> l(self->statusMutex);*out=self->current;
}
void reject(void* p,uint32_t reason) {static_cast<Recorder*>(p)->overload(reason ? reason : uint32_t(MLG_REJECT_INVALID_FRAME));}
const MLGRecorderAPI api={sizeof(api),MLG_RECORDER_ABI,create,destroy,command,interest,video,pixel,audio,status,reject};
}
extern "C" __attribute__((visibility("default"))) const MLGRecorderAPI* MoonlightLGRecorderGetAPI(uint32_t version) {
    return version==MLG_RECORDER_ABI ? &api : nullptr;
}
