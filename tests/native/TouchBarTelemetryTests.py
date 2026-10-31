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
