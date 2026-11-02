#pragma once
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <deque>
#include <limits>
#include <vector>

namespace mlg {
// UI-only, bounded three-minute history. Missing values and inactive intervals
// break the line; refreshing or resizing a view cannot manufacture samples.
class TouchBarHistory {
public:
    static constexpr double window=180.;
    struct Sample { double time,value; };
    struct Range {
        double low=std::numeric_limits<double>::infinity(), high=-std::numeric_limits<double>::infinity();
        bool valid() const { return std::isfinite(low) && std::isfinite(high); }
        void include(Range other) { if (other.valid()) { low=std::min(low,other.low); high=std::max(high,other.high); } }
        Range padded() const {
            if (!valid()) return *this;
            double padding=std::max((high-low)*.1,std::max(std::abs(high)*.02,.01));
            return {std::max(0.,low-padding),high+padding};
        }
    };
    struct Point { double x,y; bool move; };
    void append(double time,double value) {
        if (!std::isfinite(time)) return;
        if (!data.empty() && (time<=data.back().time || std::floor(time)==std::floor(data.back().time))) return;
        if (!std::isfinite(value) || value<0) value=std::numeric_limits<double>::quiet_NaN();
        data.push_back({time,value});
        while (!data.empty() && data.front().time<time-window) data.pop_front();
        while (data.size()>181) data.pop_front();
    }
    Range range(double now) const {
        Range result;
        for (const auto& sample:data) if (sample.time>=now-window && sample.time<=now && std::isfinite(sample.value)) {
            result.low=std::min(result.low,sample.value); result.high=std::max(result.high,sample.value);
        }
        return result;
    }
    std::vector<Point> points(double now,Range scale) const {
        std::vector<Point> result;
        if (!std::isfinite(now) || !scale.valid() || scale.high<=scale.low) return result;
        bool move=true; double previous=0;
        for (const auto& sample:data) {
            if (sample.time<now-window || sample.time>now) continue;
            if (!std::isfinite(sample.value)) { move=true; continue; }
            result.push_back({std::clamp(1.-(now-sample.time)/window,0.,1.),
                              std::clamp((sample.value-scale.low)/(scale.high-scale.low),0.,1.),
                              move || sample.time-previous>2.5});
            previous=sample.time; move=false;
        }
        return result;
    }
    std::size_t size() const { return data.size(); }
private:
    std::deque<Sample> data;
};
}
