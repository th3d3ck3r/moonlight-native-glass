import AppKit
import SwiftUI

// The user's Warp Arrival (lane 45), shared by production startup and Canvas.
// One finite coordinator owns the lifetime; rendering stops when it finishes.
struct NativeWarpBootView: View {
    @ObservedObject var presentation: NativeBootPresentation
    var previewTime: Double? = nil
    private var cyan: Color { NativeCrimsonTheme.enabled ? NativeCrimsonTheme.highlight : Color(red: 0.36, green: 0.87, blue: 1) }
    private var blue: Color { NativeCrimsonTheme.enabled ? NativeCrimsonTheme.ruby : Color(red: 0.36, green: 0.47, blue: 1) }
    private func ease(_ time: Double, _ start: Double, _ length: Double) -> Double {
        let p = min(1, max(0, (time - start) / length))
        return p * p * p * (10 + p * (-15 + 6 * p))
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: previewTime != nil || presentation.phase != .playing)) { timeline in
            let t = previewTime ?? max(0, timeline.date.timeIntervalSince(presentation.startedAt ?? timeline.date))
            GeometryReader { geometry in
                let diameter = min(96.0, min(geometry.size.width, geometry.size.height) * 0.16)
                ZStack {
                    NativeBootView.background
                    Canvas { context, size in
                        drawWarp(context, size, CGPoint(x: size.width / 2, y: size.height / 2),
                                 Double(min(size.width, size.height)) / 640, t)
                    }
                    if let logo = presentation.logo {
                        Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(0.12 + 0.88 * ease(t, 1.65, 1.1))
                            .opacity(ease(t, 1.55, 0.85))
                            .accessibilityLabel("MoonlightLG icon")
                            .accessibilityIdentifier("startup-project-icon")
                    }
                    NativeBootProjectName(diameter: diameter)
                        .opacity(ease(t, 2.0, 0.65))
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
    // the destination. No random regeneration, timers, or external media.
    private func drawWarp(_ context: GraphicsContext, _ size: CGSize, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let speed = ease(t, 0, 0.6) * (1 - ease(t, 1.35, 1.05))
        let travel = 2.8 * ease(t, 0, 2.4)
        let arrival = ease(t, 1.8, 0.85)
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
            var c = context
            c.opacity = edge * (0.3 + (1 - z) * 0.65) * (0.65 + speed * 0.35)
            var streak = Path(); streak.move(to: tail); streak.addLine(to: point)
            c.stroke(streak, with: .linearGradient(Gradient(colors: [.clear, cyan, .white]),
                startPoint: tail, endPoint: point),
                style: StrokeStyle(lineWidth: (0.6 + (1 - z) * 1.2) * scale, lineCap: .round))
            let dot = (0.6 + (1 - z) * 0.8) * scale
            c.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot,
                width: dot * 2, height: dot * 2)), with: .color(.white))
        }
        glow(context, center, 120 * scale, arrival * 0.3)
        for i in 0..<2 {
            let angle = Double(i) * .pi + t * 0.5
            let radius = (83 + Double(i) * 21) * scale
            let point = CGPoint(x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius * 0.65)
            var c = context; c.opacity = arrival
            c.translateBy(x: point.x, y: point.y)
            c.rotate(by: .radians(sin(t * 0.4 + Double(i)) * 0.25))
            // Two solar panels, connecting boom, metallic body and dish.
            for side in [-1.0, 1.0] {
                let panel = CGRect(x: side < 0 ? -15 * scale : 6 * scale,
                    y: -5 * scale, width: 9 * scale, height: 10 * scale)
                c.fill(Path(roundedRect: panel, cornerRadius: scale), with: .color(blue.opacity(0.85)))
                c.stroke(Path(roundedRect: panel, cornerRadius: scale), with: .color(cyan.opacity(0.7)), lineWidth: 0.6 * scale)
            }
            var boom = Path(); boom.move(to: CGPoint(x: -6 * scale, y: 0)); boom.addLine(to: CGPoint(x: 6 * scale, y: 0))
            c.stroke(boom, with: .color(.white.opacity(0.8)), lineWidth: scale)
            c.fill(Path(roundedRect: CGRect(x: -3 * scale, y: -4 * scale, width: 6 * scale, height: 8 * scale), cornerRadius: scale),
                with: .linearGradient(Gradient(colors: [.white, cyan.opacity(0.65)]),
                    startPoint: CGPoint(x: -3 * scale, y: -4 * scale), endPoint: CGPoint(x: 3 * scale, y: 4 * scale)))
            c.fill(Path(ellipseIn: CGRect(x: -2 * scale, y: -8 * scale, width: 4 * scale, height: 3 * scale)), with: .color(.white.opacity(0.85)))
        }
    }

}
