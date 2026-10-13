#pragma once
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <map>
#include <string>
#include <vector>
#include <utility>

namespace NativeStreamStats {
struct Row {
    std::string label,value,display;
    double number=NAN;
    bool metric=false,percentage=false;
};
inline std::vector<Row> parse(const std::string& text) {
    std::vector<Row> rows;
    size_t start=0;
    while (start<text.size()) {
        size_t end=text.find('\n',start); if (end==std::string::npos) end=text.size();
        std::string line=text.substr(start,end-start); start=end+1;
        if (line.empty()) continue;
        Row row; size_t colon=line.find(':');
        row.label=colon==std::string::npos ? "Details" : line.substr(0,colon);
        row.value=colon==std::string::npos ? line : line.substr(colon+1);
        while (!row.value.empty() && row.value.front()==' ') row.value.erase(0,1);
        row.display=row.label;
        if (row.label.find("Incoming frame rate")==0) row.display="Incoming FPS";
        else if (row.label=="Decoding frame rate") row.display="Decoding FPS";
        else if (row.label=="Rendering frame rate") row.display="Rendering FPS";
        else if (row.label.find("Host processing latency")==0) row.display="Host latency · min/max/avg";
        else if (row.label.find("Frames dropped by")==0) row.display="Network drops";
        else if (row.label.find("Frames dropped due")==0) row.display="Jitter drops";
        else if (row.label=="Average network latency") row.display="Network latency · RTT";
        else if (row.label=="Average decoding time") row.display="Decoding time";
        else if (row.label=="Average frame queue delay") row.display="Frame queue delay";
        else if (row.label.find("Average rendering time")==0) row.display="Rendering time · includes V-sync";
        // Only known measured fields produce graphs. Resolution/codec names
        // and unknown diagnostics are kept verbatim, never treated as samples.
        row.metric=row.display!=row.label || row.label=="Bitrate";
        row.percentage=row.label.find("Frames dropped")==0;
        if (row.metric) {
            char* tail=nullptr; const char* input=row.value.c_str();
            double number=std::strtod(input,&tail);
            bool valid=tail!=input;
            if (row.label.find("Host processing latency")==0) {
                // The chart is the average, not the first (minimum) figure.
                for (int i=0;i<2 && valid;++i) {
                    if (*tail!='/') { valid=false; break; }
                    input=tail+1; number=std::strtod(input,&tail); valid=tail!=input;
                }
            }
            if (valid && std::isfinite(number) && number>=0 && (!row.percentage || number<=100)) row.number=number;
        }
        rows.push_back(std::move(row));
    }
    return rows;
}
struct Point { double time,value; };
class History {
public:
    std::map<std::string,std::vector<Point>> samples;
    void append(const std::vector<Row>& rows,double time) {
        // Drop disappeared metrics rather than reviving stale values later.
        for (auto i=samples.begin();i!=samples.end();) {
            bool present=false; for (const Row& row:rows) if (row.metric && row.label==i->first) present=true;
            if (!present) i=samples.erase(i); else ++i;
        }
        for (const Row& row:rows) if (row.metric) {
            auto& points=samples[row.label];
            points.push_back({time,row.number});
            while (!points.empty() && (points.front().time<time-60 || points.size()>120)) points.erase(points.begin());
        }
    }
    void clear() { samples.clear(); }
};
}
