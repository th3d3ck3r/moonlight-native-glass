#pragma once
#include "RecorderABI.h"
#include <array>
#include <vector>
namespace mlg {
// Engine-owned pointer metadata only; never copies the video payload here.
// The 128-fragment fast path does not allocate. Larger frames reuse a bounded
// thread-local vector; maximum metadata is 1 MiB on 64-bit architectures.
class FragmentCollector {
    std::array<MLGRecorderChunk,128> small;
    std::vector<MLGRecorderChunk> large;
public:
    struct Result { const MLGRecorderChunk* chunks=nullptr; size_t count=0; uint32_t error=0; };
    template<class Entry> Result collect(Entry* head) noexcept {
        size_t count=0, bytes=0;
        for (auto p=head;p;p=p->next) {
            if (count==MLG_RECORDER_MAX_CHUNKS) return {nullptr,0,MLG_REJECT_FRAGMENT_LIMIT};
            size_t size=size_t(p->length);
            if (size>MLG_RECORDER_MAX_FRAME_BYTES-bytes) return {nullptr,0,MLG_REJECT_FRAME_BYTES};
            if (size && !p->data) return {nullptr,0,MLG_REJECT_INVALID_FRAME};
            bytes+=size; ++count;
        }
        if (!count || !bytes) return {nullptr,0,MLG_REJECT_INVALID_FRAME};
        if (count<=small.size()) {
            size_t i=0;for(auto p=head;p;p=p->next) small[i++]={p->data,size_t(p->length)};
            return {small.data(),count,0};
        }
        try {
            large.clear(); large.reserve(count);
            for(auto p=head;p;p=p->next) large.push_back({p->data,size_t(p->length)});
            return {large.data(),count,0};
        } catch (...) { return {nullptr,0,MLG_REJECT_MEMORY}; }
    }
};
}
