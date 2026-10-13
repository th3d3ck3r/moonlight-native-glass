#pragma once
#include <atomic>
#include <array>
#include <cstddef>
#include <cstdint>
#include <utility>
namespace mlg {
// Multiple producers, one consumer. Fixed slots; enqueue has a finite retry
// budget. Ownership is published with release/acquire, never a playback mutex.
template<class T,size_t Capacity> class BoundedQueue {
    static_assert(Capacity && (Capacity&(Capacity-1))==0,"Power-of-two capacity");
    struct Cell {std::atomic<size_t> sequence;T value{};};
    std::array<Cell,Capacity> cells;
    std::atomic<size_t> producer{0};
    size_t consumer=0;
public:
    BoundedQueue() {for(size_t i=0;i<Capacity;i++) cells[i].sequence.store(i);}
    bool push(T&& value) {
        size_t pos=producer.load(std::memory_order_relaxed);
        for(unsigned attempt=0;attempt<16;attempt++) {
            Cell& cell=cells[pos&(Capacity-1)];
            intptr_t delta=intptr_t(cell.sequence.load(std::memory_order_acquire))-intptr_t(pos);
            if(delta==0) {
                if(producer.compare_exchange_weak(pos,pos+1,std::memory_order_relaxed)) {
                    cell.value=std::move(value);cell.sequence.store(pos+1,std::memory_order_release);return true;
                }
            } else if(delta<0) return false;
            else pos=producer.load(std::memory_order_relaxed);
        }
        return false;
    }
    bool pop(T& value) {
        Cell& cell=cells[consumer&(Capacity-1)];
        if(cell.sequence.load(std::memory_order_acquire)!=consumer+1) return false;
        value=std::move(cell.value);cell.sequence.store(consumer+Capacity,std::memory_order_release);consumer++;return true;
    }
};
}
