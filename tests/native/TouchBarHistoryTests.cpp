#include "../../app/native/touchbarhistory.h"
#include <cassert>
#include <cmath>
int main() {
    using H=mlg::TouchBarHistory;
    H h;
    assert(!h.range(0).valid());
    h.append(0,60); h.append(.1,1); h.append(0,2);
    assert(h.size()==1); // Repaints, duplicate/out-of-order callbacks add nothing.
    auto flat=h.range(0).padded(); assert(flat.low<60 && flat.high>60);
    for (int t=1;t<=600;++t) h.append(t,t==420 ? 10000 : 60+t%3);
    assert(h.size()==181 && h.range(600).high==10000);
    h.append(601,61);
    auto scale=h.range(601).padded(); assert(scale.high<100); // Expired spike no longer sets the scale.
    auto points=h.points(601,scale); assert(points.size()==181 && points.front().x==0 && points.back().x==1);
    for (auto p:points) assert(p.x>=0 && p.x<=1 && p.y>=0 && p.y<=1);
    h.append(602,NAN); h.append(603,60); h.append(610,62);
    points=h.points(610,h.range(610).padded());
    assert(points[points.size()-2].move && points.back().move); // Missing/inactive intervals stay gaps.
    assert(!h.range(791).valid()); // History expires by time, not refresh count.
    H zero; zero.append(0,0); assert(zero.points(0,zero.range(0).padded()).size()==1);
    H missing; missing.append(0,-1); missing.append(1,INFINITY); assert(!missing.range(1).valid());
    H other; other.append(1,100); auto both=zero.range(1); both.include(other.range(1));
    assert(both.low==0 && both.high==100); // RX/TX can share one scale.
    H copy=h; assert(copy.size()==h.size());
}
