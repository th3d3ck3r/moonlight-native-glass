#pragma once
#include <stdint.h>
namespace mlg {
// Called only by the engine's UI/status poll, never by a decoder callback.
// Ask once immediately, retry twice at three-second intervals, then report
// failure. Optional requests for an active recording use a separate policy.
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

class RecordingKeyframes {
public:
    void reset() { written=0; lastActivity=0; }

    bool update(bool enabled, bool writerHealthy, uint64_t nowMs, uint64_t writtenKeyframes) {
        if(!enabled || !writtenKeyframes) {
            reset();
            return false;
        }
        if(written!=writtenKeyframes || nowMs<lastActivity) {
            written=writtenKeyframes;
            lastActivity=nowMs;
            return false;
        }
        // The same cooldown applies if the host does not answer. A missed
        // response never triggers startup recovery or stops the recorder.
        if(!writerHealthy || nowMs-lastActivity<10000) return false;
        lastActivity=nowMs;
        return true;
    }

private:
    uint64_t written=0;
    uint64_t lastActivity=0;
};
}
