// TouchBarMoonPulse.metal — MoonlightLG Touch Bar background, "Moon pulse".
//
// The moon in its crimson smoke disk with a glowing bar along the bottom, framed for
// the 30 pt Touch Bar, always in its connected look, beating every `period` seconds
// (shockwave ring out from the moon, rim flash, the bar flaring as the wave passes).
//
// Self-contained: its own namespace (`mlgtb`), so it never clashes with the app's
// startup/connection shader (SmokeAccretion.metal) or anything else in the target.
// Used from SwiftUI through `ShaderLibrary.touchBarMoonPulse` with `.colorEffect`.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

namespace mlgtb {

constant float3 A = float3(1.00, 0.46, 0.57);   // highlight
constant float3 C = float3(0.95, 0.19, 0.31);   // crimson
constant float3 R = float3(0.57, 0.02, 0.23);   // ruby

inline float ss(float a, float b, float x) {
    float t = clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
inline float h21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
inline float n2(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + float2(1, 0)), f.x),
               mix(h21(i + float2(0, 1)), h21(i + float2(1, 1)), f.x), f.y);
}
inline float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * n2(p); p = p * 2.03 + float2(1.7, 9.2); a *= 0.5; }
    return v;
}
inline float2 rot(float2 v, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float3 stars(float2 uv, float t) {
    float3 c = float3(0.0);
    for (int i = 0; i < 3; i++) {
        float s = float(i);
        float2 g = uv * (16.0 + s * 13.0) + s * 7.31;
        float2 id = floor(g);
        float2 f = fract(g) - 0.5;
        float r = h21(id + s * 3.7);
        if (r > 0.86) {
            float2 o = float2(h21(id + 3.1), h21(id + 5.7)) - 0.5;
            float d = length(f - o * 0.6);
            float tw = 0.55 + 0.45 * sin(t * (1.5 + r * 4.0) + r * 40.0);
            float3 tint = r > 0.97 ? float3(A) : (r > 0.93 ? float3(1.0, 0.86, 0.78) : float3(1.0));
            c += tint * (ss(0.07, 0.0, d) * 0.9 + ss(0.25, 0.0, d) * 0.12) * tw * (0.35 + s * 0.22);
        }
    }
    return c;
}

float crat(float2 u) {
    float2 id = floor(u), f = fract(u);
    float h = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 g = float2(float(i), float(j));
            float2 o = float2(h21(id + g), h21(id + g + 7.3));
            if (h21(id + g + 1.9) > 0.55) {
                float rad = 0.18 + 0.3 * h21(id + g + 3.1);
                float d = length(g + o - f);
                float x = d / rad;
                h += (-max(0.0, 1.0 - x * x) * 0.55 + exp(-(x - 1.0) * (x - 1.0) * 30.0) * 0.22) * rad;
            }
        }
    }
    return h;
}
float hgt(float3 m) {
    float2 u = float2(atan2(m.z, m.x) * 1.2, asin(clamp(m.y, -1.0, 1.0)) * 1.2);
    return crat(u * 3.0) + crat(u * 7.0 + 11.0) * 0.45 + fbm(u * 8.0) * 0.05;
}

// rgb = shaded moon, a = coverage.
float4 moon(float2 p, float R0, float la, float spin, float rim, float under) {
    float rr = length(p);
    if (R0 < 0.003 || rr >= R0) return float4(0.0);
    float3 n = float3(p / R0, sqrt(max(0.0, 1.0 - dot(p, p) / (R0 * R0))));
    float3 m = float3(n.x * cos(spin) + n.z * sin(spin), n.y, -n.x * sin(spin) + n.z * cos(spin));
    float e1 = 0.012;
    float h0 = hgt(m);
    float hx = hgt(normalize(m + float3(e1, 0, 0)));
    float hy = hgt(normalize(m + float3(0, e1, 0)));
    float3 nb = normalize(n - float3(hx - h0, hy - h0, 0.0) * 3.0);
    float3 L = normalize(float3(-sin(la), 0.4, cos(la)));
    float dif = max(dot(nb, L), 0.0);
    float ul = max(dot(nb, normalize(float3(0.0, -0.75, 0.65))), 0.0);   // light from the disk below
    float2 uu = float2(atan2(m.z, m.x), m.y);
    float alb = 0.6 + 0.22 * fbm(uu * 3.0) - 0.22 * ss(0.45, 0.7, fbm(uu * 1.4 + 3.0));
    float3 surf = float3(0.95, 0.9, 0.92) * alb * dif * 1.2
                + C * ul * ul * under * 0.6
                + C * pow(max(1.0 - n.z, 0.0), 2.5) * rim * 0.8
                + R * 0.035;
    return float4(surf, ss(R0, R0 - 0.003, rr));
}

// Keplerian smoke flow with two cross-faded phases, so shear never piles up.
float diskDens(float2 dp, float t, float boost) {
    float rd = length(dp);
    float w = (0.55 + boost) * 0.12 / pow(max(rd, 0.1), 1.5);
    float T = 6.0;
    float a = fract(t / T), b = fract(t / T + 0.5);
    float wa = 1.0 - abs(2.0 * a - 1.0);
    float2 q1 = rot(dp, -w * a * T) * 3.2 + float2(floor(t / T) * 1.7, 0.0);
    float2 q2 = rot(dp, -w * b * T) * 3.2 + float2(floor(t / T + 0.5) * 1.7 + 5.0, 3.0);
    float f1 = fbm(q1 + 1.4 * float2(fbm(q1 * 0.7 + 3.1), fbm(q1 * 0.7 + 8.3)));
    float f2 = fbm(q2 + 1.4 * float2(fbm(q2 * 0.7 + 3.1), fbm(q2 * 0.7 + 8.3)));
    return mix(f2, f1, wa);
}

float3 embers(float2 p, float t, float R0, float tilt, float sc, float mA) {
    float3 c = float3(0.0);
    for (int i = 0; i < 36; i++) {
        float fi = float(i);
        float r = mix(R0 * 1.25, 0.58, h21(float2(fi, 1.0)));
        float w = 0.1 / pow(r, 1.5);
        float a = h21(float2(fi, 2.0)) * 6.2832 + t * w;
        float2 e = float2(cos(a) * r, sin(a) * r * tilt) * sc;
        float d = length(p - e);
        float vis = mix(1.0, 1.0 - mA, step(0.0, sin(a)));
        float tw = 0.6 + 0.4 * sin(t * 3.0 + fi * 7.0);
        c += mix(A, float3(1.0, 0.9, 0.93), h21(float2(fi, 3.0)))
           * (exp(-d * 420.0) * 1.2 + exp(-d * 90.0) * 0.15) * vis * tw;
    }
    return c;
}

float3 progressRing(float2 p, float rr, float fillIn, float uC) {
    float rad = 0.47;
    float a01 = fract(atan2(p.x, p.y) / 6.2832);
    float fill = mix(fillIn, 1.0, uC);
    float ring = exp(-abs(rr - rad) * 500.0);
    float glowr = exp(-abs(rr - rad) * 90.0);
    float on = ss(fill + 0.002, fill - 0.002, a01);
    float tail = on * (0.3 + 0.7 * ss(fill - 0.35, fill, a01));
    float2 hp = rad * float2(sin(fill * 6.2832), cos(fill * 6.2832));
    float head = exp(-length(p - hp) * 60.0) * (1.0 - uC);
    float3 c = float3(0.25, 0.12, 0.15) * ring * 0.35;
    c += mix(A, C, uC) * (ring * 1.2 + glowr * 0.25) * mix(tail, 1.0, uC);
    c += float3(1.0, 0.88, 0.92) * head * 1.5;
    return c;
}

float3 scene(float2 p, float t, float boot, float uP, float uC, float s, float fillIn, float icon, float ring) {
    p *= mix(1.0, 0.8, icon);
    float r0 = length(p);
    float wv = (1.0 - boot) * uC * (1.0 - ss(1.2, 3.0, s)) * (1.0 - icon);
    float shock = exp(-abs(r0 - s * 0.5) * 14.0) * wv;
    p += p / max(r0, 0.001) * sin(r0 * 50.0 - s * 12.0) * shock * 0.012;
    float rr = length(p);

    float form = mix(1.0, ss(0.05, 0.62, uP), boot);
    float scaleIn = mix(1.0, mix(2.6, 1.0, ss(0.05, 0.65, uP)), boot);
    float swirl = boot * (1.0 - ss(0.0, 0.7, uP)) * 3.0;
    float R0 = mix(0.165, 0.165 * ss(0.3, 0.75, uP), boot);
    R0 = mix(R0, 0.2, icon);
    float boost = uC * 0.35 * (1.0 - ss(0.6, 3.0, s));

    // Background nebula and stars.
    float2 bq = p * 1.1 + float2(t * 0.008, 0.0);
    float bw = fbm(bq * 1.6 + float2(fbm(bq * 1.2 + t * 0.02), fbm(bq * 1.2 + 4.0 - t * 0.02)) * 1.6);
    float bootIn = mix(1.0, ss(0.0, 0.3, uP), boot);
    float3 col = stars(p, t) * 0.75 * bootIn;
    col += mix(R * 0.35, C * 0.6, ss(0.45, 0.85, bw)) * bw * bw * 0.55 * bootIn;

    // Smoke accretion disk.
    float tilt = 0.23;
    float2 dp = float2(p.x, p.y / tilt) / scaleIn;
    dp = rot(dp, swirl * (1.0 - length(dp)));
    float rd = length(dp);
    float f = diskDens(dp, t, boost);
    float inner = R0 * 1.12;
    float band = ss(inner, inner + 0.06, rd) * ss(0.64, 0.3, rd);
    float temp = ss(0.6, inner, rd) * mix(1.0, ss(0.25, 0.7, uP), boot);
    float dop = 1.0 + 0.55 * clamp(dp.x / max(rd, 0.001), -1.0, 1.0);
    float filam = ss(0.35, 0.9, f);
    float dens = (f * f * f * 3.2 + 0.08) * band * form * mix(1.0, mix(0.35, 1.0, ss(0.3, 0.65, uP)), boot);
    float3 dcol = mix(R * 0.8, mix(C, float3(1.0, 0.8, 0.86), ss(0.7, 1.0, temp)), temp);
    dcol = mix(dcol, float3(1.0, 0.88, 0.92), filam * ss(0.6, 1.0, temp) * 0.45);
    float3 disk = dcol * dens * dop * (1.35 + uC * 0.5);
    float haze = exp(-abs(p.y) * 9.0) * ss(0.62, 0.2, abs(p.x)) * ss(inner * 0.9, inner * 1.6, abs(p.x));
    disk += C * 0.12 * haze * form;
    float isFront = ss(0.003, -0.003, p.y);
    col += C * 0.28 * exp(-rd * 3.2) * form * (1.0 + uC * 0.5);
    col += disk * (1.0 - isFront);

    // Far side of the disk, lensed over the top of the moon (plus a thin under-arc).
    float lr = rr - R0 * 1.04;
    float2 ldp = (p / max(rr, 0.001)) * (inner + lr * 1.6);
    ldp = rot(ldp, swirl * (1.0 - length(ldp)));
    float lf = diskDens(ldp * float2(1.0, -1.0), t, boost);
    float up = ss(-0.15, 0.35, p.y / max(rr, 0.001));
    float arcBand = ss(R0, R0 * 1.1, rr) * ss(R0 * 2.1, R0 * 1.3, rr);
    float under = ss(R0, R0 * 1.06, rr) * ss(R0 * 1.22, R0 * 1.08, rr) * ss(0.1, -0.4, p.y / max(rr, 0.001));
    col += mix(C, float3(1.0, 0.82, 0.88), ss(R0 * 1.6, R0 * 1.08, rr) * 0.7)
         * (lf * lf * lf * 3.0 + 0.08) * (arcBand * up + under * 0.6) * form
         * 1.05 * (1.0 + uC * 0.35) * mix(1.0, ss(0.35, 0.7, uP), boot);

    // Moon.
    col += C * 0.5 * exp(-max(rr - R0, 0.0) * 14.0) * ss(0.0, 0.04, R0);
    float la = mix(0.55 + 0.12 * sin(t * 0.2), mix(2.7, 0.55, ss(0.3, 0.95, uP)), boot);
    float4 m = moon(p, R0, la, t * 0.06, 1.1 + uC * 0.8, 0.9 * form);
    col = mix(col, m.rgb, m.a);

    col += embers(p, t, R0, tilt, scaleIn, m.a) * form;
    col += disk * isFront;
    col += A * exp(-abs(rr - R0) * 120.0) * 0.55 * ss(0.0, 0.04, R0);

    // Boot lock-in flash.
    float fe = (uP - 0.64) / 0.04;
    col += float3(1.0, 0.85, 0.9) * exp(-fe * fe) * boot
         * (exp(-abs(rr - R0 * 1.2) * 30.0) * 1.5 + exp(-rr * 4.0) * 0.6);

    col += progressRing(p, rr, fillIn, uC) * (1.0 - boot) * ring;
    col += float3(1.0, 0.8, 0.86) * shock * 0.5;
    return col;
}

} // namespace mlgtb

// Inputs (all driven by MoonlightLGTouchBarBackdropView):
//   size          view size in points
//   time          animation clock, seconds
//   period        seconds between beats (MoonlightLGTouchBarArt.beatPeriod, 10 s)
//   bootProgress  0...1 through the startup sweep (used when isBoot = 1)
//   isBoot        1 while the startup sweep plays, else 0
//   connected     0...1 eased: 0 = connecting look (bar sweeping), 1 = connected look
//   sinceConnect  seconds since the connection completed (drives the connect shockwave);
//                 60 when there is no fresh connection
//   progressFill  0...1 sweep of the glowing bar while connecting; < 0 = full bar
// Library / streaming: isBoot 0, connected 1, sinceConnect 60, progressFill -1 — the
// plain Moon pulse. The heartbeat only plays in that settled connected look.
[[ stitchable ]] half4 touchBarMoonPulse(float2 position, half4 color, float2 size, float time,
                                        float period, float bootProgress, float isBoot,
                                        float connected, float sinceConnect, float progressFill) {
    float2 p = (position - 0.5 * size) / size.y;
    p.y = -p.y;
    float2 q = p * 0.5;                              // scene units: the moon fills the bar height

    // Heartbeat: only in the settled connected look — not during startup or connecting,
    // and not until the connect shockwave has finished.
    float beatOn = (1.0 - isBoot) * connected * mlgtb::ss(3.0, 4.0, sinceConnect);
    float s = fract(time / period) * period;         // seconds since the last beat
    float R0 = 0.165;
    float r0 = length(q);
    float wv = (1.0 - mlgtb::ss(0.6, 2.6, s)) * beatOn;
    float front = R0 + s * 2.6;
    float shock = exp(-abs(r0 - front) * 14.0) * wv;
    q += q / max(r0, 0.001) * sin(r0 * 50.0 - s * 12.0) * shock * 0.012;

    // The scene itself plays the startup sweep (isBoot) and the connect shockwave
    // (connected + sinceConnect), exactly as on the first Touch Bar strip.
    float3 c = mlgtb::scene(q, time, isBoot, bootProgress, connected, sinceConnect, 0.0, 0.0, 0.0);

    float rr = length(q);
    float beat = exp(-s * 2.2) * beatOn;
    c += mlgtb::C * exp(-max(rr - R0, 0.0) * 12.0) * 0.45 * beat;    // halo flash
    c += mlgtb::A * exp(-abs(rr - R0) * 120.0) * 0.5 * beat;          // rim flash
    c += float3(1.0, 0.8, 0.86) * shock * 0.5;                        // the beat's wave

    // Glowing bar along the bottom.
    //   connecting: a liquid sweep with a bright head;
    //   on connect: fills and flashes;
    //   connected: always lit, flaring on each beat as the wave crosses it.
    float dist = size.y - position.y;                                 // points above the bottom edge
    float u = position.x / max(size.x, 1.0);
    float fill = progressFill < 0.0 ? 1.0 : mix(progressFill, 1.0, connected);
    float lit = mlgtb::ss(fill + 0.003, fill - 0.003, u);
    float tail = lit * (0.3 + 0.7 * mlgtb::ss(fill - 0.35, fill, u));
    float cover = mix(tail, 1.0, connected);
    float bar = exp(-dist * 1.0) * 1.15 + exp(-dist * 0.3) * 0.16;
    float connectFlash = 1.0 + 1.2 * exp(-sinceConnect * 3.0) * mlgtb::ss(0.0, 0.05, connected);
    float flare = mix(0.9, 0.6 + 0.5 * beat + 0.9 * exp(-abs(abs(q.x) - front) * 8.0) * wv, connected)
                * connectFlash;
    float head = exp(-length(float2((u - fill) * size.x, dist)) * 0.22) * (1.0 - connected);
    float barIn = mix(1.0, mlgtb::ss(0.8, 1.0, bootProgress), isBoot);   // fades in at the end of startup
    c += (mix(mlgtb::A, mlgtb::C, connected) * bar * cover * flare
          + float3(1.0, 0.88, 0.92) * head * 1.3) * barIn;

    c = (c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14);   // ACES-style tone map
    float halfW = 0.5 * size.x / size.y;
    c *= mlgtb::ss(halfW, halfW - 1.6, abs(p.x));                     // fade into the bezel
    c += (mlgtb::h21(position + fract(time)) - 0.5) / 255.0;
    return half4(half3(clamp(c, 0.0, 1.0)), 1.0h);
}
