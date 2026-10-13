#pragma once
/* Versioned, Qt/FFmpeg-free boundary. Borrowed ingress data is valid only during
 * the call. The plugin must copy/retain before returning. All ingress calls are
 * nonblocking and reject overload; playback must ignore their return values. */
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
#define MLG_RECORDER_ABI 4u
#define MLG_RECORDER_MAX_CHUNKS 65536u
#define MLG_RECORDER_MAX_FRAME_BYTES (32u*1024u*1024u)
enum MLGRecorderRejection {
    MLG_REJECT_FRAGMENT_LIMIT=1, MLG_REJECT_FRAME_BYTES=2,
    MLG_REJECT_QUEUE_BYTES=3, MLG_REJECT_QUEUE_ITEMS=4,
    MLG_REJECT_MEMORY=5, MLG_REJECT_INVALID_FRAME=6
};
typedef struct { const void* bytes; size_t size; } MLGRecorderChunk;
typedef struct {
    uint32_t size, abi, codec, width, height, fps; /* codec: 1 H264, 2 HEVC, 0 unsupported */
    uint32_t mode, output_codec, output_width, output_height, output_fps, bitrate;
    uint32_t replay_seconds, memory_megabytes, audio_rate, audio_channels;
    uint32_t audio_streams, audio_coupled, audio_frame_samples; uint8_t audio_mapping[8];
    const char* directory; /* copied by create; local filesystem path */
} MLGRecorderConfig;
typedef struct {
    uint32_t size, active, recording, buffering, replay_ready, saving, failed, waiting_keyframe;
    uint64_t elapsed_seconds, buffered_seconds, dropped;
    char message[512];
} MLGRecorderStatus;
typedef struct {
    uint32_t size, abi;
    void* (*create)(const MLGRecorderConfig*);
    void (*destroy)(void*); /* after ingress stopped; drains/finalizes */
    void (*command)(void*, uint32_t); /* 1 toggle record, 2 save replay, 3 stop, 4 keyframe timeout */
    uint32_t (*interest)(void*); /* bit1 compressed, bit2 decoded, bit4 audio */
    int (*video)(void*, const MLGRecorderChunk*, size_t, uint32_t rtp90k, uint64_t clock_us, int key);
    int (*pixel)(void*, void* cv_pixel_buffer, uint32_t rtp90k, uint64_t clock_us, int hdr);
    int (*audio)(void*, const void*, size_t, uint64_t clock_us);
    void (*status)(void*, MLGRecorderStatus*);
    void (*reject)(void*, uint32_t reason); /* atomic/nonallocating ingress failure */
} MLGRecorderAPI;
typedef const MLGRecorderAPI* (*MLGRecorderEntry)(uint32_t);
const MLGRecorderAPI* MoonlightLGRecorderGetAPI(uint32_t);
#ifdef __cplusplus
}
#endif
