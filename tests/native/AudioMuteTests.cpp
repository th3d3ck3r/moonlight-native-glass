// Exercise the actual production callback; only devices/Opus/recorder sinks are
// substituted. The unchanged recorder plugin's real audio mux/decode is covered
// by RecorderTests. No host, sound device or microphone is required here.
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <initializer_list>
#define Q_OS_MACOS
using Uint32 = uint32_t;
#define SDL_THREAD_PRIORITY_HIGH 1
#define SDL_LOG_CATEGORY_APPLICATION 0
#define SDL_TICKS_PASSED(now, end) (int32_t((now)-(end)) >= 0)
#define SDL_assert assert
static Uint32 SDL_GetTicks() { return 100; }
static int SDL_SetThreadPriority(int) { return 0; }
static const char* SDL_GetError() { return "fixture"; }
template<class... T> static void SDL_LogWarn(int,const char*,T...) {}
template<class... T> static void SDL_LogInfo(int,const char*,T...) {}
static int recorded, played, decoded, recreated;
static char* lastPacket;
static int lastLength;
static void nativeRecorderAudio(char* packet,int length) { ++recorded; lastPacket=packet; lastLength=length; }
struct OpusDecoder {};
static int opus_multistream_decode_float(OpusDecoder*,unsigned char*,int,float*,int count,int) { ++decoded; return count; }
static int opus_multistream_decode(OpusDecoder*,unsigned char*,int,short*,int count,int) { ++decoded; return count; }
static void opus_multistream_decoder_destroy(OpusDecoder*) {}
class IAudioRenderer {
public:
    enum class AudioFormat { Float32NE };
    float samples[8]{};
    int getAudioBufferSampleSize() { return sizeof(float); }
    void* getAudioBuffer(int*) { return samples; }
    AudioFormat getAudioBufferFormat() { return AudioFormat::Float32NE; }
    bool submitAudio(int bytes) { assert(bytes==sizeof(samples)); ++played; return true; }
};
class Session {
public:
    static Session* s_ActiveSession;
    bool m_AudioMuted=false;
    int m_AudioSampleCount=1;
    Uint32 m_DropAudioEndTime=0;
    IAudioRenderer* m_AudioRenderer=nullptr;
    OpusDecoder* m_OpusDecoder=nullptr;
    struct { int channelCount=2; int samplesPerFrame=4; } m_ActiveAudioConfig;
    bool initializeAudioRenderer() { ++recreated; return false; }
    static void arDecodeAndPlaySample(char*,int);
};
Session* Session::s_ActiveSession;
#include "NativeAudioCallback.inc"
int main() {
    Session session; IAudioRenderer renderer; OpusDecoder decoder;
    Session::s_ActiveSession=&session;
    session.m_AudioRenderer=&renderer; session.m_OpusDecoder=&decoder;
    char packet[]="source Opus packet";
    for (bool mute : {false,true,true,false}) {
        int before=played; session.m_AudioMuted=mute;
        Session::arDecodeAndPlaySample(packet,sizeof(packet));
        assert(lastPacket==packet && lastLength==sizeof(packet));
        assert(played==before+(mute ? 0 : 1));
    }
    assert(recorded==4 && played==2 && decoded==2);
    // Capture must also precede playback catch-up/device drop windows.
    session.m_AudioMuted=true; session.m_DropAudioEndTime=200;
    Session::arDecodeAndPlaySample(nullptr,0);
    assert(recorded==5 && lastPacket==nullptr && lastLength==0 && played==2 && !recreated);
    puts("PASS: production audio callback preserves source recording packets across playback mute/unmute and playback drop windows");
}
