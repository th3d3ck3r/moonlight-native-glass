"""Exercise the production one-second publication branch with both UI sinks."""
from pathlib import Path
import os,subprocess,tempfile
source=Path('app/streaming/video/ffmpeg.cpp').read_text()
start=source.index('        // Reuse the existing one-second measurements')
end=source.index('        // Accumulate these values into the global stats',start)
assert 'measurementStartUs + 1000000' in source[start-180:start]
branch=source[start:end]
harness=r'''
#include <cassert>
#include <cstdio>
#include <cstring>
namespace Overlay { enum Type { OverlayDebug }; }
struct VIDEO_STATS { int value=0; };
VIDEO_STATS m_LastWndVideoStats{1},m_ActiveWndVideoStats{2};
bool nativeEnabled=false;int published=0,formatted=0,notified=0;
struct Manager {
 bool visible=false;char text[1024]{};
 bool isOverlayEnabled(Overlay::Type) { return visible; }
 char* getOverlayText(Overlay::Type) { return text; }
 int getOverlayMaxTextLength() { return sizeof(text); }
 void setOverlayTextUpdated(Overlay::Type) { ++notified; }
};
struct Session { Manager manager; static Session* get() { static Session value;return &value; } Manager& getOverlayManager() { return manager; } };
bool nativeOverlayConfigured() { return nativeEnabled; }
void nativeOverlayPresentStatistics(const char* text) { assert(!std::strcmp(text,"sum=3"));++published; }
void addVideoStats(VIDEO_STATS& source,VIDEO_STATS& target) { target.value+=source.value; }
void stringifyVideoStats(VIDEO_STATS& stats,char* text,int size) { ++formatted;std::snprintf(text,size,"sum=%d",stats.value); }
void tick() {
'''+branch+r'''
}
int main() {
 for(int window=0;window<2;++window) for(int native=0;native<2;++native) {
  Session::get()->manager.visible=window;nativeEnabled=native;
  published=formatted=notified=0;tick();
#ifdef Q_OS_MACOS
  assert(formatted==(window||native));assert(published==(native&&!window));
#else
  assert(formatted==window);assert(published==0);
#endif
  assert(notified==window);assert(Session::get()->manager.visible==bool(window));
 }
 std::puts("PASS: Touch Bar telemetry without window overlay, unchanged aggregation and non-macOS path");
}
'''
with tempfile.TemporaryDirectory() as temporary:
 root=Path(temporary);cpp=root/'telemetry.cpp';cpp.write_text(harness)
 for mac in [False,True]:
  binary=root/('mac' if mac else 'other')
  subprocess.run([os.environ.get('CXX','c++'),'-std=c++17',*(['-DQ_OS_MACOS'] if mac else []),str(cpp),'-o',str(binary)],check=True)
  subprocess.run([str(binary)],check=True)


# Compile the actual formatter section, with the platform define read from the
# production qmake project. The tracker already collects bytes on every frame;
# enabling its existing formatting branch must expose changing measurements.
import re,shlex
project=Path('app/app.pro').read_text()
mac_defines=[]
for line in project.splitlines():
 match=re.fullmatch(r'\s*macx:\s*DEFINES\s*\+=\s*(.*?)\s*',line)
 if match: mac_defines.extend(shlex.split(match.group(1)))
assert 'DISPLAY_BITRATE' in mac_defines, 'macOS packages must include measured bitrate text'
start=source.index('        if (m_VideoDecoderCtx != nullptr) {',source.index('    if (stats.receivedFps > 0) {'))
end=source.index('\n\n        ret = snprintf',start)
formatter=source[start:end]
format_harness=r"""
#include <cassert>
#include <cstdio>
#include <cstring>
#define SDL_assert assert
struct Decoder { int width=2560,height=1440; } decoder;
Decoder* m_VideoDecoderCtx=&decoder;
struct Stats { double totalFps=60; } stats;
struct Tracker {
 double average=27.5,peak=44.2;
 double GetAverageMbps() { return average; }
 double GetPeakMbps() { return peak; }
 unsigned GetWindowSeconds() { return 10; }
} m_BwTracker;
void format(char* output,int length) {
 int offset=0,ret=0;
 const char* codecString="HEVC 10-bit HDR";
"""+formatter+r"""
 output[offset]=0;
}
int main() {
 char output[1024]{};format(output,sizeof(output));
 assert(std::strstr(output,"Video stream: 2560x1440 60.00 FPS (Codec: HEVC 10-bit HDR)"));
#ifdef DISPLAY_BITRATE
 assert(std::strstr(output,"Bitrate: 27.5 Mbps, Peak (10s): 44.2"));
 m_BwTracker.average=11.7;m_BwTracker.peak=30.9;
 format(output,sizeof(output));
 assert(std::strstr(output,"Bitrate: 11.7 Mbps, Peak (10s): 30.9"));
 assert(!std::strstr(output,"27.5"));
#else
 assert(!std::strstr(output,"Bitrate:"));
#endif
 std::puts("PASS: production codec/bitrate formatter, changing measurements and platform build gating");
}
"""
with tempfile.TemporaryDirectory() as temporary:
 root=Path(temporary);cpp=root/'formatter.cpp';cpp.write_text(format_harness)
 for mac in [False,True]:
  binary=root/('mac' if mac else 'other')
  defines=['-D'+flag for flag in mac_defines] if mac else []
  subprocess.run([os.environ.get('CXX','c++'),'-std=c++17',*defines,str(cpp),'-o',str(binary)],check=True)
  subprocess.run([str(binary)],check=True)
