import AppKit
import SwiftUI

// Procedural Apollo rendezvous: the same TimelineView/Canvas drawing style as
// Warp Arrival, with no video, external assets, random regeneration or timers.
struct NativeConnectionView: View {
    let journey: ConnectionJourney
    var warnings: [String] = []
    var canRetry = false
    var previewTime: Double? = nil
    var reduceMotionOverride: Bool? = nil
    var cancel: () -> Void
    var proceed: () -> Void
    var retry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }
    @Environment(\.crimsonGlassEnabled) private var crimson
    @State private var startedAt = Date()
    private var accent: Color { crimson ? NativeCrimsonTheme.highlight : Color(red: 0.4, green: 0.8, blue: 1) }
    private var ready: Bool { journey.phase == .connected || journey.phase == .entering }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MoonlightLG").font(.headline).tracking(0.8)
                Spacer()
                Text("APOLLO RENDEZVOUS").font(.caption).tracking(2).foregroundStyle(.secondary)
            }.padding(.horizontal, 28).padding(.top, 24)
            TimelineView(.animation(minimumInterval: 1 / 30,
                paused: reduceMotion || journey.phase == .failed || previewTime != nil)) { timeline in
                let time = reduceMotion ? 0 : previewTime ?? max(0, timeline.date.timeIntervalSince(startedAt))
                let arrival = journey.connectedAt != nil ? (reduceMotion ? 1 : smooth(max(0, timeline.date.timeIntervalSince(journey.connectedAt ?? timeline.date)) / 1.8)) : 0
                Canvas { context, size in
                    drawSpace(context, size: size, time: time, arrival: arrival)
                }
                .accessibilityLabel(ready ? "Apollo spacecraft orbiting the full moon" : "Apollo spacecraft flying through space")
                .accessibilityIdentifier("connection-apollo-scene")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(journey.phase == .failed ? "Connection failed" : ready ? "Connected" : "Connecting")
                            .font(.title2.weight(.semibold)).accessibilityIdentifier("connection-heading")
                        Text("\(journey.computer.name) · \(journey.game.name)")
                            .font(.callout).foregroundStyle(.secondary)
                        Text(journey.detail).font(.callout).textSelection(.enabled)
                            .accessibilityIdentifier("connection-detail")
                    }
                    Spacer(minLength: 12)
                    if journey.phase == .connected {
                        Button("Continue to Stream", action: proceed)
                            .buttonStyle(.borderedProminent).tint(accent)
                            .accessibilityIdentifier("connection-continue")
                    } else if journey.phase == .entering {
                        ProgressView().controlSize(.small).padding(8)
                    } else if journey.phase == .failed {
                        Button("Retry", action: retry).disabled(!canRetry)
                            .accessibilityIdentifier("connection-retry")
                    }
                    Button(journey.phase == .failed ? "Back to Library" : "Cancel", action: cancel)
                        .accessibilityIdentifier("connection-cancel")
                }
                if let error = journey.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.red).textSelection(.enabled)
                }
                if !warnings.isEmpty {
                    Text(warnings.joined(separator: "\n")).font(.caption).foregroundStyle(.secondary)
                }
                if journey.phase == .connected {
                    Text("Ready when you are. Stream audio and input begin after Continue.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .foregroundStyle(.white)
        .background(Color(red: 0.015, green: 0.02, blue: 0.035))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("connection-journey")
        .environment(\.colorScheme, .dark)
    }

    private func smooth(_ value: Double) -> Double {
        let p = min(1, max(0, value)); return p * p * (3 - 2 * p)
    }
    private func drawSpace(_ context: GraphicsContext, size: CGSize, time: Double, arrival: Double) {
        let scale = min(size.width / 800, size.height / 400)
        let center = CGPoint(x: size.width * 0.56, y: size.height * 0.48)
        // Repeat a deterministic sideways flight field; rendezvous slows it down.
        for i in 0..<140 {
            let depth = Double((i * 37) % 100) / 100
            let travel = time * (12 + depth * 32) * (1 - arrival * 0.92)
            let width = max(1, size.width + 40)
            let x = (Double((i * 79) % 997) / 997 * width - travel).truncatingRemainder(dividingBy: width)
            let point = CGPoint(x: x < 0 ? x + width : x, y: Double((i * 131) % 991) / 991 * size.height)
            let radius = (0.5 + depth) * max(0.7, scale)
            var streak = Path(); streak.move(to: point)
            streak.addLine(to: CGPoint(x: point.x + (2 + depth * 13) * (1 - arrival), y: point.y))
            context.stroke(streak, with: .color(accent.opacity(0.18 + depth * 0.4)), lineWidth: radius)
            context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: radius, height: radius)), with: .color(.white.opacity(0.3 + depth * 0.6)))
        }
        let moonRadius = max(24, min(66 * scale, size.width * 0.12))
        let moon = CGPoint(x: size.width + moonRadius + (center.x - size.width - moonRadius) * arrival, y: center.y)
        let orbitX = min(size.width * 0.29, moonRadius * 2.5)
        let orbitY = moonRadius * 0.78
        let angle = Double.pi + time * 0.48
        let flight = CGPoint(x: size.width * 0.38 + sin(time * 0.35) * 18 * scale,
                             y: center.y + sin(time * 0.9) * 8 * scale)
        let orbit = CGPoint(x: center.x + cos(angle) * orbitX, y: center.y + sin(angle) * orbitY)
        let ship = CGPoint(x: flight.x + (orbit.x - flight.x) * arrival,
                           y: flight.y + (orbit.y - flight.y) * arrival)
        if arrival > 0 {
            var glow = context; glow.opacity = arrival
            glow.fill(Path(ellipseIn: CGRect(x: moon.x - moonRadius * 1.8, y: moon.y - moonRadius * 1.8,
                                             width: moonRadius * 3.6, height: moonRadius * 3.6)),
                with: .radialGradient(Gradient(colors: [accent.opacity(0.18), .clear]), center: moon, startRadius: moonRadius * 0.8, endRadius: moonRadius * 1.8))
            glow.stroke(Path(ellipseIn: CGRect(x: center.x - orbitX, y: center.y - orbitY,
                                               width: orbitX * 2, height: orbitY * 2)),
                        with: .color(accent.opacity(0.18)), style: StrokeStyle(lineWidth: 0.7, dash: [3, 7]))
        }
        let behind = arrival > 0.9 && sin(angle) < 0
        let rotation = atan2(cos(angle) * orbitY, -sin(angle) * orbitX) * arrival
        if behind { drawApollo(context, at: ship, scale: max(0.65, scale), angle: rotation, time: time, orbiting: ready) }
        drawMoon(context, at: moon, radius: moonRadius)
        if !behind { drawApollo(context, at: ship, scale: max(0.65, scale), angle: rotation, time: time, orbiting: ready) }
    }
    private func drawMoon(_ context: GraphicsContext, at point: CGPoint, radius: Double) {
        let bounds = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        let disc = Path(ellipseIn: bounds)
        context.fill(disc, with: .linearGradient(Gradient(colors: [Color(white: 0.95), Color(white: 0.66), Color(white: 0.4)]),
            startPoint: CGPoint(x: point.x - radius, y: point.y - radius), endPoint: CGPoint(x: point.x + radius, y: point.y + radius)))
        var c = context; c.clip(to: disc)
        for i in 0..<22 {
            let a = Double(i) * 2.399963
            let distance = radius * sqrt(Double(i + 1) / 25) * 0.82
            let r = radius * (0.07 + Double((i * 7) % 5) * 0.015)
            let rect = CGRect(x: point.x + cos(a) * distance - r, y: point.y + sin(a) * distance - r, width: r * 2, height: r * 1.7)
            c.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.08 + Double(i % 3) * 0.025)))
            c.stroke(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 0.7)), with: .color(.white.opacity(0.15)), lineWidth: 0.7)
        }
        context.stroke(disc, with: .color(.white.opacity(0.35)), lineWidth: 0.8)
    }
    private func drawApollo(_ context: GraphicsContext, at point: CGPoint, scale: Double, angle: Double, time: Double, orbiting: Bool) {
        var c = context; c.translateBy(x: point.x, y: point.y); c.rotate(by: .radians(angle)); c.scaleBy(x: scale, y: scale)
        // Bell nozzle, cylindrical service module and tapered Apollo capsule.
        if !orbiting {
            let length = 34 + sin(time * 13) * 4
            var flame = Path(); flame.move(to: CGPoint(x: -26, y: -6)); flame.addQuadCurve(to: CGPoint(x: -26 - length, y: 0), control: CGPoint(x: -40, y: -8)); flame.addQuadCurve(to: CGPoint(x: -26, y: 6), control: CGPoint(x: -40, y: 8)); flame.closeSubpath()
            c.fill(flame, with: .linearGradient(Gradient(colors: [.clear, accent.opacity(0.7), .white]), startPoint: CGPoint(x: -26 - length, y: 0), endPoint: CGPoint(x: -26, y: 0)))
        }
        var nozzle = Path(); nozzle.move(to: CGPoint(x: -29, y: -7)); nozzle.addLine(to: CGPoint(x: -19, y: -4)); nozzle.addLine(to: CGPoint(x: -19, y: 4)); nozzle.addLine(to: CGPoint(x: -29, y: 7)); nozzle.closeSubpath()
        c.fill(nozzle, with: .color(Color(white: 0.3)))
        let module = Path(roundedRect: CGRect(x: -21, y: -11, width: 26, height: 22), cornerRadius: 2)
        c.fill(module, with: .linearGradient(Gradient(colors: [Color(white: 0.95), Color(white: 0.45), Color(white: 0.75)]), startPoint: CGPoint(x: 0, y: -11), endPoint: CGPoint(x: 0, y: 11)))
        for x in [-15.0, -6.0] { c.fill(Path(CGRect(x: x, y: -10, width: 3, height: 20)), with: .color(Color(white: 0.25))) }
        var capsule = Path(); capsule.move(to: CGPoint(x: 4, y: -13)); capsule.addLine(to: CGPoint(x: 25, y: -3)); capsule.addQuadCurve(to: CGPoint(x: 25, y: 3), control: CGPoint(x: 28, y: 0)); capsule.addLine(to: CGPoint(x: 4, y: 13)); capsule.closeSubpath()
        c.fill(capsule, with: .linearGradient(Gradient(colors: [Color(red: 0.92, green: 0.83, blue: 0.61), Color(white: 0.65)]), startPoint: CGPoint(x: 10, y: -12), endPoint: CGPoint(x: 10, y: 12)))
        c.stroke(capsule, with: .color(.white.opacity(0.55)), lineWidth: 0.6)
        c.fill(Path(roundedRect: CGRect(x: 12, y: -4, width: 6, height: 4), cornerRadius: 1), with: .color(Color(red: 0.05, green: 0.1, blue: 0.16)))
        var antenna = Path(); antenna.move(to: CGPoint(x: -4, y: -10)); antenna.addLine(to: CGPoint(x: -9, y: -19)); antenna.addLine(to: CGPoint(x: -14, y: -19))
        c.stroke(antenna, with: .color(.white.opacity(0.75)), lineWidth: 0.8)
        c.fill(Path(ellipseIn: CGRect(x: -17, y: -23, width: 6, height: 5)), with: .color(Color(white: 0.8)))
    }
}
