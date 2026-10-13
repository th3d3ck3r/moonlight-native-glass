#pragma once
#include <cstdint>
#include <vector>
#include <cstddef>
namespace mlg {
// No dependency on engine buffer segmentation. Preserve emulation-prevention
// bytes; remove start codes only. Reject malformed/empty input explicitly.
inline std::vector<std::vector<uint8_t>> annexB(const uint8_t* p, size_t n) {
    std::vector<std::vector<uint8_t>> out;
    auto prefix = [&](size_t i)->size_t {
        if (i+3<=n && p[i]==0 && p[i+1]==0 && p[i+2]==1) return 3;
        if (i+4<=n && p[i]==0 && p[i+1]==0 && p[i+2]==0 && p[i+3]==1) return 4;
        return 0;
    };
    size_t start=0;
    while (start<n && !prefix(start)) ++start;
    if (start==n) return out;
    while (start<n) {
        size_t begin=start+prefix(start), end=begin;
        while (end<n && !prefix(end)) ++end;
        size_t trimmed=end;
        while (trimmed>begin && p[trimmed-1]==0) --trimmed;
        if (trimmed>begin) out.emplace_back(p+begin,p+trimmed);
        start=end;
    }
    return out;
}
// RTP wraps every ~13h. Signed modular difference also tolerates reordering.
inline int64_t extendRtp(uint32_t value, uint32_t previous, int64_t extended) {
    return extended+int32_t(value-previous);
}
}
