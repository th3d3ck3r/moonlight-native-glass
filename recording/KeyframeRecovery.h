#pragma once
#include <stdint.h>
namespace mlg {
// Called only by the engine's UI/status poll, never by a decoder callback.
// Ask once immediately, retry twice at three-second intervals, then report
// failure. No periodic IDRs while a usable recording/replay keyframe exists.
class KeyframeRecovery {
public:
    enum Result { None, Request, Timeout };
    void reset() { attempts=0; last=0; failed=false; }
    Result update(bool waiting, uint64_t nowMs) {
        if (!waiting) { reset(); return None; }
        if (failed) return None;
        if (!attempts || nowMs-last>=3000) {
            if (attempts==3) { failed=true; return Timeout; }
            ++attempts; last=nowMs; return Request;
        }
        return None;
    }
private:
    unsigned attempts=0;
    uint64_t last=0;
    bool failed=false;
};
}
