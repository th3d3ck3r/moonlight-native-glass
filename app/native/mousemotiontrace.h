#pragma once

#include <SDL.h>
#include <algorithm>

// Aggregated, opt-in diagnostics. Never records positions or movement deltas.
struct MouseMotionTrace {
    enum Mode { Off, NativeCapture, StockFocus };
    Mode mode = Off;
    Uint32 started = 0, windowStart = 0, previousEvent = 0;
    bool havePreviousEvent = false;
    struct Counts {
        unsigned events = 0, zeroDeltas = 0, uncaptured = 0, relativeBatches = 0;
        unsigned largestBatch = 0, peakQueueMs = 0, peakEventGapMs = 0;
        unsigned captureChanges = 0, relativeChanges = 0, focusLost = 0, focusGained = 0;
        unsigned repairRequests = 0;
    } counts;

    bool enabled() const { return mode != Off; }
    bool stockFocus(bool absolute) const { return mode == StockFocus && !absolute; }

    void start() {
        started = windowStart = SDL_GetTicks();
        SDL_Log("[mouse-trace] mode=%s; event gaps exclude idle periods >=250 ms",
                mode == StockFocus ? "stock-focus" : "native-capture");
    }

    void event(const SDL_MouseMotionEvent& motion, Uint32 now, bool captured) {
        ++counts.events;
        if (!captured) ++counts.uncaptured;
        if (!motion.xrel && !motion.yrel) ++counts.zeroDeltas;
        const Uint32 age = now - motion.timestamp;
        if (age < 0x80000000u) counts.peakQueueMs = std::max(counts.peakQueueMs, age);
        if (havePreviousEvent) {
            const Uint32 gap = motion.timestamp - previousEvent;
            if (gap < 250) counts.peakEventGapMs = std::max(counts.peakEventGapMs, gap);
        }
        previousEvent = motion.timestamp;
        havePreviousEvent = true;
    }

    void batch(unsigned size) {
        ++counts.relativeBatches;
        counts.largestBatch = std::max(counts.largestBatch, size);
    }

    void flush(Uint32 now, bool finishing = false) {
        if (!finishing && now - windowStart < 1000) return;
        if (counts.events || counts.captureChanges || counts.relativeChanges ||
            counts.focusLost || counts.focusGained || counts.repairRequests) {
            SDL_Log("[mouse-trace] elapsed_ms=%u span_ms=%u events=%u zero=%u uncaptured=%u "
                    "relative_batches=%u largest_batch=%u peak_queue_ms=%u peak_event_gap_ms=%u "
                    "capture_changes=%u relative_changes=%u focus_lost=%u focus_gained=%u repair_requests=%u",
                    now - started, now - windowStart, counts.events, counts.zeroDeltas,
                    counts.uncaptured, counts.relativeBatches, counts.largestBatch,
                    counts.peakQueueMs, counts.peakEventGapMs, counts.captureChanges,
                    counts.relativeChanges, counts.focusLost, counts.focusGained, counts.repairRequests);
        }
        counts = {};
        windowStart = now;
    }
};
