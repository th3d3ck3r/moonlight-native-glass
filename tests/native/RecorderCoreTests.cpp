#include "../../recording/AnnexB.h"
#include "../../recording/SourceVideoTiming.h"
#include "../../recording/RecorderABI.h"
#include "../../recording/KeyframeRecovery.h"
#include "../../recording/WriterReadiness.h"
#include "../../recording/FragmentCollector.h"
#include <cassert>
#include "../../recording/BoundedQueue.h"
#include <thread>
#include <memory>
#include <atomic>
int main() {
    struct Entry {Entry* next; const void* data; int length;};
    uint8_t byte=0x65; std::vector<Entry> fragments(MLG_RECORDER_MAX_CHUNKS+1);
    for(size_t i=0;i<fragments.size();i++) fragments[i]={i+1<fragments.size()?&fragments[i+1]:nullptr,&byte,1};
    mlg::FragmentCollector collector;
    fragments[127].next=nullptr;
    auto small=collector.collect(fragments.data());assert(!small.error && small.count==128);
    fragments[127].next=&fragments[128];fragments[2047].next=nullptr;
    auto large=collector.collect(fragments.data());assert(!large.error && large.count==2048);
    assert(large.chunks[2047].bytes==&byte && large.chunks[2047].size==1);
    assert(collector.collect(fragments.data()).chunks==large.chunks); // Reuses metadata.
    fragments[2047].next=&fragments[2048];
    assert(collector.collect(fragments.data()).error==MLG_REJECT_FRAGMENT_LIMIT);
    Entry invalid{nullptr,nullptr,1};assert(collector.collect(&invalid).error==MLG_REJECT_INVALID_FRAME);
    Entry oversized{nullptr,&byte,int(MLG_RECORDER_MAX_FRAME_BYTES)+1};
    assert(collector.collect(&oversized).error==MLG_REJECT_FRAME_BYTES);

    mlg::KeyframeRecovery recovery;
    assert(recovery.update(false,0)==mlg::KeyframeRecovery::None);
    assert(recovery.update(true,0)==mlg::KeyframeRecovery::Request);
    assert(recovery.update(true,2999)==mlg::KeyframeRecovery::None);
    assert(recovery.update(true,3000)==mlg::KeyframeRecovery::Request);
    assert(recovery.update(true,6000)==mlg::KeyframeRecovery::Request);
    assert(recovery.update(true,9000)==mlg::KeyframeRecovery::Timeout);
    assert(recovery.update(true,12000)==mlg::KeyframeRecovery::None);
    assert(recovery.update(false,12001)==mlg::KeyframeRecovery::None);
    assert(recovery.update(true,12002)==mlg::KeyframeRecovery::Request);
    recovery.reset();
    assert(recovery.update(false,20000)==mlg::KeyframeRecovery::None);

    const uint8_t sample[]={0,0,0,1,0x67,0x12,0,0,3,1,0,0,1,0x68,0x34,0,0,0,1,0x65,0x56,0,0};
    auto n=mlg::annexB(sample,sizeof(sample));
    assert(n.size()==3 && n[0].size()==6 && n[1][0]==0x68 && n[2].size()==2);
    assert(mlg::annexB(sample+4,2).empty());
    assert(mlg::extendRtp(5,0xfffffffa,1000)==1011);
    assert(mlg::extendRtp(95,100,1000)==995);
    using TimingResult=mlg::SourceVideoTiming::Result;
    mlg::SourceVideoTiming timing;
    int64_t previous=-1;
    auto expectTime=[&](int64_t raw, int64_t expected, TimingResult result) {
        assert(timing.normalize(raw,previous,60)==result);
        assert(raw==expected);
        if(result!=TimingResult::Discontinuity) previous=raw;
    };
    expectTime(0,0,TimingResult::Unchanged);
    expectTime(1500,1500,TimingResult::Unchanged);
    expectTime(1500,2250,TimingResult::RepairStarted);
    expectTime(0,3000,TimingResult::RepairContinued);
    expectTime(3100,3750,TimingResult::RepairContinued);
    expectTime(4500,4500,TimingResult::Unchanged);
    expectTime(9000,9000,TimingResult::Unchanged); // Preserve a real gap.
    expectTime(2999,2999,TimingResult::Discontinuity);
    expectTime(9000,9750,TimingResult::RepairStarted);
    for(unsigned i=0;i<7;i++)
        expectTime(previous,previous+750,TimingResult::RepairContinued);
    expectTime(previous,previous,TimingResult::Discontinuity);

    mlg::BoundedQueue<std::unique_ptr<unsigned>,64> queue;
    std::atomic<unsigned> done{0};
    auto producer=[&](unsigned base) {
        for(unsigned i=0;i<10000;i++) {auto p=std::make_unique<unsigned>(base+i);while(!queue.push(std::move(p))) std::this_thread::yield();}
        done++;
    };
    std::thread a(producer,0),b(producer,10000),c(producer,20000);
    unsigned received=0;unsigned long long total=0;std::unique_ptr<unsigned> p;
    while(received<30000) {if(queue.pop(p)) {received++;total+=*p;} else std::this_thread::yield();}
    a.join();b.join();c.join();assert(done==3 && total==29999ULL*30000/2);
    assert(!queue.pop(p));
    static_assert(MLG_RECORDER_ABI==5,"Explicit ABI version required");

    mlg::RecordingKeyframes periodic;
    assert(!periodic.update(false,true,50000,1));
    assert(!periodic.update(true,true,0,0));
    assert(!periodic.update(true,true,100,1));
    assert(!periodic.update(true,true,10099,1));
    assert(!periodic.update(true,false,10100,1));
    assert(periodic.update(true,true,10200,1));
    assert(!periodic.update(true,true,10201,1));
    assert(!periodic.update(true,true,12000,2)); // an appended keyframe restarts the cooldown
    assert(!periodic.update(true,true,21999,2));
    assert(periodic.update(true,true,22000,2));
    assert(!periodic.update(true,true,31999,2));
    assert(periodic.update(true,true,32000,2)); // missing response, still rate limited
    assert(!periodic.update(false,true,40000,2));
    assert(!periodic.update(true,true,45000,1)); // new clip

    unsigned waits=0;
    assert(mlg::waitForWriterReady(15, [] {return true;}, [&] {return waits==3;}, [&] {++waits;}));
    assert(waits==3);
    waits=0;
    assert(!mlg::waitForWriterReady(15, [] {return true;}, [] {return false;}, [&] {++waits;}));
    assert(waits==15);
    waits=0;
    assert(!mlg::waitForWriterReady(15, [&] {return waits<2;}, [] {return false;}, [&] {++waits;}));
    assert(waits==2);
}
