#pragma once
#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstdint>
// Shared between the AppKit controls and the audio thread. Playback PCM only;
// encoded source packets have already been handed to the recorder unchanged.
inline std::atomic<float>& nativePlaybackGainStorage() {
    static std::atomic<float> gain{1.0f};
    return gain;
}
inline float nativePlaybackVolume() { return nativePlaybackGainStorage().load(std::memory_order_relaxed); }
inline void nativePlaybackSetVolume(float gain) {
    if (!std::isfinite(gain)) return;
    nativePlaybackGainStorage().store(std::max(0.0f,std::min(1.0f,gain)),std::memory_order_relaxed);
}
inline void nativePlaybackScale(void* buffer,int bytes,bool floating) {
    float gain=nativePlaybackVolume();
    if (!buffer || bytes<=0 || gain==1.0f) return;
    if (floating) {
        float* samples=static_cast<float*>(buffer);
        for (int i=0;i<bytes/int(sizeof(float));++i) samples[i]*=gain;
    } else {
        int16_t* samples=static_cast<int16_t*>(buffer);
        for (int i=0;i<bytes/int(sizeof(int16_t));++i) samples[i]=int16_t(std::lround(samples[i]*gain));
    }
}
