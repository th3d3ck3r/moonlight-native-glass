#pragma once
#include <cstdint>

namespace mlg {
// Source copy expects low-delay video in decode order. A brief overlap on the
// host clock can be repaired without sorting or discarding reference frames.
class SourceVideoTiming {
public:
    enum class Result { Unchanged, RepairStarted, RepairContinued, Discontinuity };

    Result normalize(int64_t& pts, int64_t previous, unsigned fps) {
        if (previous < 0) return Result::Unchanged;

        const int64_t frameTicks = 90000 / fps;
        const int64_t minimumStep = frameTicks / 2;
        if (pts > previous && (!repairCount || pts - previous >= minimumStep)) {
            repairCount = 0;
            return Result::Unchanged;
        }
        // The shorter step lets the input clock catch up, including after an
        // exactly duplicated timestamp. Bound both the skew and the run length.
        if (previous - pts > 4 * frameTicks || repairCount >= 8) {
            return Result::Discontinuity;
        }
        pts = previous + minimumStep;
        return ++repairCount == 1 ? Result::RepairStarted : Result::RepairContinued;
    }

private:
    unsigned repairCount = 0;
};
}
