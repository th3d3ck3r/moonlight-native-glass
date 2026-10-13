#include "../../recording/AnnexB.h"
#include "../../recording/RecorderABI.h"
#include "../../recording/KeyframeRecovery.h"
#include <cassert>
#include "../../recording/BoundedQueue.h"
#include <thread>
#include <memory>
#include <atomic>
int main() {
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
    static_assert(MLG_RECORDER_ABI==3,"Explicit ABI version required");
}
