#include "../../app/native/nativestreamstats.h"
#include <cassert>
#include <cstdio>
using namespace NativeStreamStats;
int main() {
    auto rows=parse("Video stream: 3840x2160 60.00 FPS (Codec: HEVC 10-bit HDR)\nBitrate: 25.1 Mbps, Peak (8s): 48.4\nIncoming frame rate from network: 59.98 FPS\nHost processing latency min/max/average: 1.0/8.0/3.2 ms\nAverage network latency: 12 ms (variance: 2 ms)\nFrames dropped by your network connection: 0.01%\nAverage decoding time: N/A\nDiagnostic: 999\nUnknown details");
    assert(rows.size()==9 && !rows[0].metric && std::isnan(rows[0].number));
    assert(rows[0].value=="3840x2160 60.00 FPS (Codec: HEVC 10-bit HDR)");
    assert(rows[1].number==25.1 && rows[1].value.find("48.4")!=std::string::npos);
    assert(rows[2].number==59.98 && rows[3].number==3.2 && rows[4].number==12);
    assert(rows[5].percentage && rows[5].number==.01 && std::isnan(rows[6].number));
    assert(!rows[7].metric && rows[8].value=="Unknown details");
    for (auto value:{"N/A","nan ms","inf ms","-1 ms"}) assert(std::isnan(parse(std::string("Average decoding time: ")+value)[0].number));
    assert(std::isnan(parse("Host processing latency min/max/average: 1.0 ms")[0].number));
    History history;
    for (int i=0;i<200;++i) history.append(rows,i*.25);
    assert(history.samples.at(rows[2].label).size()==120);
    history.append(rows,120);
    assert(history.samples.at(rows[2].label).size()==1);
    assert(std::isnan(history.samples.at(rows[6].label).back().value));
    history.append(parse("Video codec: H.264"),121); assert(history.samples.empty());
    history.append(rows,122); history.clear(); assert(history.samples.empty());
    puts("PASS: unchanged stream readings, average latency selection, unavailable values, bounded history and disappeared metrics");
}
