import AppKit
import SwiftUI

// The user's Warp Arrival (lane 45), shared by production startup and Canvas.
// One finite coordinator owns the lifetime; rendering stops when it finishes.
//
// Refinement pass (same timing, layout, palette and star lanes):
// - Soft nebula wash and a vanishing-point flare while the jump is at speed.
// - Far stars fade in instead of popping at the centre; near streaks bloom.
// - A landing shockwave, breathing halo and a gentle settle on the icon.
// - Satellites pass in front of and behind the icon, with trails and beacons.
// - The field keeps a very slow drift and twinkle after arrival.
// Still deterministic: no random regeneration, timers or external media.
struct NativeWarpBootView: View {
    @ObservedObject var presentation: NativeBootPresentation
    var previewTime: Double? = nil
    private var cyan: Color { NativeCrimsonTheme.enabled ? NativeCrimsonTheme.highlight : Color(red: 0.36, green: 0.87, blue: 1) }
    private var blue: Color { NativeCrimsonTheme.enabled ? NativeCrimsonTheme.ruby : Color(red: 0.36, green: 0.47, blue: 1) }

    private func ease(_ time: Double, _ start: Double, _ length: Double) -> Double {
        let p = min(1, max(0, (time - start) / length))
        return p * p * p * (10 + p * (-15 + 6 * p))
    }
    // Ease-out with a ~5% overshoot, used for the icon landing.
    private func settle(_ time: Double, _ start: Double, _ length: Double) -> Double {
        let p = min(1, max(0, (time - start) / length))
        let q = p - 1
        return 1 + 2.2 * q * q * q + 1.2 * q * q
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 120, paused: previewTime != nil || presentation.phase != .playing)) { timeline in
            let t = previewTime ?? max(0, timeline.date.timeIntervalSince(presentation.startedAt ?? timeline.date))
            GeometryReader { geometry in
                let diameter = min(96.0, min(geometry.size.width, geometry.size.height) * 0.16)
                let reveal = ease(t, 2.0, 0.65)
                ZStack {
                    NativeBootView.background
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let scale = Double(min(size.width, size.height)) / 640
                        drawWarp(context, size, center, scale, t)
                        drawSatellites(context, center, scale, t, front: false)
                    }
                    if let logo = presentation.logo {
                        Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: diameter, height: diameter)
                            .shadow(color: cyan.opacity(0.5 * ease(t, 1.85, 0.7)), radius: diameter * 0.2)
                            .scaleEffect(0.12 + 0.88 * settle(t, 1.65, 1.1))
                            .opacity(ease(t, 1.55, 0.85))
                            .accessibilityLabel("MoonlightLG icon")
                            .accessibilityIdentifier("startup-project-icon")
                    }
                    // Satellites on the near half of their orbit pass in front of the icon.
                    Canvas { context, size in
                        drawSatellites(context, CGPoint(x: size.width / 2, y: size.height / 2),
                                       Double(min(size.width, size.height)) / 640, t, front: true)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    NativeBootProjectName(diameter: diameter)
                        .blur(radius: 5 * (1 - reveal))
                        .offset(y: 10 * (1 - reveal))
                        .opacity(reveal)
                }
            }
        }
        .ignoresSafeArea()
        .opacity(presentation.phase == .fading ? 0 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MoonlightLG warp startup animation. Press Escape to skip.")
        .accessibilityIdentifier("native-boot-animation")
        .accessibilityAction(named: Text("Skip startup animation")) { presentation.finish() }
        .onAppear { if previewTime == nil { presentation.start() } }
    }

    private func glow(_ context: GraphicsContext, _ center: CGPoint, _ radius: Double, _ alpha: Double) {
        var c = context; c.opacity = alpha
        c.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
               with: .radialGradient(Gradient(colors: [cyan.opacity(0.4), blue.opacity(0.08), .clear]),
                                     center: center, startRadius: 0, endRadius: radius))
    }

    // Deterministic perspective field: accelerate, brake smoothly, then hold
    // the destination with a slow drift.
    private func drawWarp(_ context: GraphicsContext, _ size: CGSize, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let speed = ease(t, 0, 0.6) * (1 - ease(t, 1.35, 1.05))
        let travel = 2.8 * ease(t, 0, 2.4) + 0.015 * t
        let arrival = ease(t, 1.8, 0.85)
        let span = Double(max(size.width, size.height))
        let bounds = Path(CGRect(origin: .zero, size: size))

        // Nebula wash: swells with speed, settles into a faint glow.
        var nebula = context
        nebula.opacity = 0.35 * speed + 0.18 * arrival
        nebula.fill(bounds, with: .radialGradient(Gradient(colors: [blue.opacity(0.55), blue.opacity(0.12), .clear]),
                                                  center: center, startRadius: 0, endRadius: span * 0.75))

        // Vanishing-point flare while the jump is at full speed.
        var core = context
        core.blendMode = .plusLighter
        core.opacity = speed * 0.55
        let coreRadius = 70 * scale
        core.fill(Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius,
                                         width: coreRadius * 2, height: coreRadius * 2)),
                  with: .radialGradient(Gradient(colors: [.white.opacity(0.7), cyan.opacity(0.35), .clear]),
                                        center: center, startRadius: 0, endRadius: coreRadius))

        for i in 0..<150 {
            let angle = Double(i) * 2.399963
            let lane = 45 + Double((i * 47) % 210)
            let depth = Double((i * 73) % 151) / 151 - travel
            let z = 0.15 + (depth - floor(depth)) * 0.85
            let radius = lane * scale / z
            let point = CGPoint(x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius)
            let tailRadius = max(0, radius - (12 + 115 * (1 - z)) * scale * speed)
            let tail = CGPoint(x: center.x + cos(angle) * tailRadius,
                               y: center.y + sin(angle) * tailRadius)
            let edge = max(0, min(1, (z - 0.15) / 0.12))
            // Fade in at the far end so recycled stars never pop at the centre.
            let far = max(0, min(1, (1 - z) / 0.1))
            let twinkle = 1 - arrival * 0.3 * (0.5 + 0.5 * sin(t * 2.6 + Double(i) * 1.7))
            let alpha = edge * far * twinkle * (0.3 + (1 - z) * 0.65) * (0.65 + speed * 0.35)
            let width = (0.6 + (1 - z) * 1.2) * scale
            var streak = Path(); streak.move(to: tail); streak.addLine(to: point)
            if speed > 0.05 && z < 0.45 {
                var bloom = context
                bloom.blendMode = .plusLighter
                bloom.opacity = alpha * speed * 0.35
                bloom.stroke(streak, with: .color(cyan), style: StrokeStyle(lineWidth: width * 3.5, lineCap: .round))
            }
            var c = context
            c.opacity = alpha
            c.stroke(streak, with: .linearGradient(Gradient(colors: [.clear, blue, cyan, .white]),
                startPoint: tail, endPoint: point),
                style: StrokeStyle(lineWidth: width, lineCap: .round))
            let dot = (0.6 + (1 - z) * 0.8) * scale
            c.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot,
                width: dot * 2, height: dot * 2)), with: .color(.white))
        }

        // Landing shockwave as the icon arrives.
        let wave = min(1, max(0, (t - 1.7) / 1.0))
        if wave > 0 && wave < 1 {
            let grow = 1 - pow(1 - wave, 3)
            let r = (24 + 300 * grow) * scale
            var ring = context
            ring.blendMode = .plusLighter
            ring.opacity = (1 - wave) * 0.55
            ring.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                        with: .color(cyan), lineWidth: (0.6 + 2.4 * (1 - wave)) * scale)
        }

        // Halo behind the icon, breathing slowly once it has landed.
        glow(context, center, 120 * scale, arrival * (0.3 + 0.06 * sin(t * 2.1)))

        // Vignette keeps the eye on the centre.
        context.fill(bounds, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.45)]),
                                                   center: center, startRadius: span * 0.3, endRadius: span * 0.8))
    }

    private func drawSatellites(_ context: GraphicsContext, _ center: CGPoint, _ scale: Double, _ t: Double, front: Bool) {
        let arrival = ease(t, 1.8, 0.85)
        guard arrival > 0 else { return }
        for i in 0..<2 {
            let angle = Double(i) * .pi + t * 0.5
            let depth = sin(angle) // > 0 is the near (lower) half of the orbit.
            guard (depth >= 0) == front else { continue }
            let rx = (83 + Double(i) * 21) * scale
            let ry = rx * 0.65
            let point = CGPoint(x: center.x + cos(angle) * rx, y: center.y + sin(angle) * ry)
            let size = 1 + 0.14 * depth
            let shade = 0.72 + 0.28 * (depth + 1) / 2

            // Fading trail along the orbit.
            var trail = Path()
            for k in 0...20 {
                let a = angle - Double(k) * 0.045
                let p = CGPoint(x: center.x + cos(a) * rx, y: center.y + sin(a) * ry)
                if k == 0 { trail.move(to: p) } else { trail.addLine(to: p) }
            }
            let tailAngle = angle - 0.9
            let tailPoint = CGPoint(x: center.x + cos(tailAngle) * rx, y: center.y + sin(tailAngle) * ry)
            var tc = context
            tc.blendMode = .plusLighter
            tc.opacity = arrival * 0.45 * shade
            tc.stroke(trail, with: .linearGradient(Gradient(colors: [cyan, .clear]), startPoint: point, endPoint: tailPoint),
                      style: StrokeStyle(lineWidth: 0.9 * scale, lineCap: .round))

            var c = context
            c.opacity = arrival * shade
            c.translateBy(x: point.x, y: point.y)
            c.rotate(by: .radians(sin(t * 0.4 + Double(i)) * 0.25))
            c.scaleBy(x: size, y: size)
            // Two solar panels, connecting boom, metallic body and dish.
            for side in [-1.0, 1.0] {
                let panel = CGRect(x: side < 0 ? -15 * scale : 6 * scale,
                    y: -5 * scale, width: 9 * scale, height: 10 * scale)
                c.fill(Path(roundedRect: panel, cornerRadius: scale), with: .color(blue.opacity(0.85)))
                c.stroke(Path(roundedRect: panel, cornerRadius: scale), with: .color(cyan.opacity(0.7)), lineWidth: 0.6 * scale)
                // Panel cell line catches the light as the satellite turns.
                var cell = Path()
                cell.move(to: CGPoint(x: panel.midX, y: panel.minY + scale))
                cell.addLine(to: CGPoint(x: panel.midX, y: panel.maxY - scale))
                c.stroke(cell, with: .color(cyan.opacity(0.35 + 0.25 * sin(t * 1.3 + side))), lineWidth: 0.4 * scale)
            }
            var boom = Path(); boom.move(to: CGPoint(x: -6 * scale, y: 0)); boom.addLine(to: CGPoint(x: 6 * scale, y: 0))
            c.stroke(boom, with: .color(.white.opacity(0.8)), lineWidth: scale)
            c.fill(Path(roundedRect: CGRect(x: -3 * scale, y: -4 * scale, width: 6 * scale, height: 8 * scale), cornerRadius: scale),
                with: .linearGradient(Gradient(colors: [.white, cyan.opacity(0.65)]),
                    startPoint: CGPoint(x: -3 * scale, y: -4 * scale), endPoint: CGPoint(x: 3 * scale, y: 4 * scale)))
            c.fill(Path(ellipseIn: CGRect(x: -2 * scale, y: -8 * scale, width: 4 * scale, height: 3 * scale)), with: .color(.white.opacity(0.85)))
            // Beacon blink on the dish.
            let blink = (t * 0.9 + Double(i) * 0.45).truncatingRemainder(dividingBy: 1) < 0.1 ? 1.0 : 0.2
            var beacon = c
            beacon.blendMode = .plusLighter
            beacon.fill(Path(ellipseIn: CGRect(x: -1.3 * scale, y: -10.6 * scale, width: 2.6 * scale, height: 2.6 * scale)),
                        with: .color(cyan.opacity(blink)))
        }
    }
}
