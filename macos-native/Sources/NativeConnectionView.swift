import AppKit
import SwiftUI

// Procedural Apollo rendezvous: the same TimelineView/Canvas drawing style as
// Warp Arrival, with no video, external assets, random regeneration or timers.
//
// Refinement pass (same layout, panel, buttons, palette and star lanes):
// - Braking is integrated from speed, so the star field slows smoothly
//   instead of jumping backwards when the connection completes.
// - Parallax dust and a faint nebula behind the warp lanes.
// - Apollo pitches gently with its motion, engine fades out (no pop),
//   flickering two-layer flame, exhaust particles and a blinking nav light.
// - Curved approach into orbit starting on the near side of the moon,
//   perspective scaling around the orbit and a correctly layered orbit path.
// - Shaded full moon with maria, limb-darkened craters and a rim light,
//   plus a one-time lock-on pulse when the connection is ready.
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
    private var deep: Color { crimson ? NativeCrimsonTheme.ruby : Color(red: 0.16, green: 0.3, blue: 0.85) }
    private var ready: Bool { journey.phase == .connected || journey.phase == .entering }
    private static let arrivalDuration = 2.2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MoonlightLG").font(.headline).tracking(0.8)
                Spacer()
                Text("APOLLO RENDEZVOUS").font(.caption).tracking(2).foregroundStyle(.secondary)
            }.padding(.horizontal, 28).padding(.top, 24)
            TimelineView(.animation(minimumInterval: 1 / 60,
                paused: reduceMotion || journey.phase == .failed || previewTime != nil)) { timeline in
                let time = reduceMotion ? 0 : previewTime ?? max(0, timeline.date.timeIntervalSince(startedAt))
                let sinceConnect: Double? = journey.connectedAt.map {
                    reduceMotion ? 60 : max(0, timeline.date.timeIntervalSince($0))
                }
                Canvas { context, size in
                    drawSpace(context, size: size, time: time, since: sinceConnect)
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
                        NativeConnectionButton("Continue to Stream", identifier: "connection-continue", accent: NSColor(accent), action: proceed)
                    } else if journey.phase == .entering {
                        ProgressView().controlSize(.small).padding(8)
                    } else if journey.phase == .failed {
                        NativeConnectionButton("Retry", identifier: "connection-retry", enabled: canRetry, action: retry)
                    }
                    NativeConnectionButton(journey.phase == .failed ? "Back to Library" : "Cancel", identifier: "connection-cancel", action: cancel)
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
        .background(NativeTouchBarAccessory(commands: [
            .init("apollo.status", "\(journey.computer.name)\n\(journey.detail)", "moon.fill", width: 240, enabled: false),
            .init("apollo.continue", journey.phase == .entering ? "Opening…" : "Continue to Stream", "play.fill", width: 150,
                  enabled: journey.phase == .connected && !journey.continueRequested, action: proceed),
            .init("apollo.retry", "Retry", "arrow.clockwise", width: 65, enabled: journey.phase == .failed && canRetry, action: retry),
            .init("apollo.cancel", journey.phase == .failed ? "Library" : "Cancel", "xmark", width: 80, action: cancel)
        ], crimson: crimson).frame(width: 0, height: 0))
    }

    // MARK: - Timing

    private func smoother(_ value: Double) -> Double {
        let p = min(1, max(0, value)); return p * p * p * (p * (6 * p - 15) + 10)
    }
    private func fract(_ value: Double) -> Double { value - floor(value) }
    private func arrival(_ since: Double?) -> Double {
        since.map { smoother($0 / Self.arrivalDuration) } ?? 0
    }
    // Integral of arrival over time since connection (closed form of the
    // smootherstep integral), so the brake reduces speed rather than distance.
    private func brakedTime(_ since: Double?) -> Double {
        guard let since else { return 0 }
        let d = Self.arrivalDuration
        let p = min(1, max(0, since / d))
        let p4 = p * p * p * p
        return d * (p4 * p * p - 3 * p4 * p + 2.5 * p4) + max(0, since - d)
    }
    private func ellipsePoint(_ center: CGPoint, _ rx: Double, _ ry: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * rx, y: center.y + sin(angle) * ry)
    }

    // MARK: - Scene

    private struct Layout {
        let scale: Double
        let center: CGPoint
        let moonRadius: Double
        let orbitX: Double
        let orbitY: Double
    }
    private func layout(_ size: CGSize) -> Layout {
        let scale = min(size.width / 800, size.height / 400)
        let moonRadius = max(24, min(66 * scale, size.width * 0.12))
        return Layout(scale: scale, center: CGPoint(x: size.width * 0.56, y: size.height * 0.48),
                      moonRadius: moonRadius, orbitX: min(size.width * 0.29, moonRadius * 2.5), orbitY: moonRadius * 0.78)
    }
    private func orbitAngle(_ since: Double?) -> Double { Double.pi + (since ?? 0) * 0.48 }
    private func shipPosition(_ l: Layout, size: CGSize, time: Double, since: Double?) -> CGPoint {
        let a = arrival(since)
        let flight = CGPoint(x: size.width * 0.38 + sin(time * 0.35) * 18 * l.scale,
                             y: l.center.y + sin(time * 0.9) * 8 * l.scale)
        let orbit = ellipsePoint(l.center, l.orbitX, l.orbitY, orbitAngle(since))
        // Slight upward arc on the approach rather than a straight slide.
        let lift = sin(a * .pi) * 16 * l.scale
        return CGPoint(x: flight.x + (orbit.x - flight.x) * a,
                       y: flight.y + (orbit.y - flight.y) * a - lift)
    }

    private func drawSpace(_ context: GraphicsContext, size: CGSize, time: Double, since: Double?) {
        let l = layout(size)
        let arrive = arrival(since)
        let speed = 1 - arrive
        let fieldScale = Double(min(size.width, size.height)) / 640
        let fieldCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let velocity = 420 * fieldScale
        let travel = reduceMotion ? 0 : velocity * (time - 0.92 * brakedTime(since))
        let width = max(1, size.width + 40)
        let bounds = Path(CGRect(origin: .zero, size: size))

        // Faint nebula, drifting very slowly with the flight.
        let drift = travel * 0.02
        context.fill(bounds, with: .radialGradient(Gradient(colors: [deep.opacity(0.22), .clear]),
            center: CGPoint(x: size.width * 0.28 - drift.truncatingRemainder(dividingBy: size.width * 0.4), y: size.height * 0.3),
            startRadius: 0, endRadius: Double(size.width) * 0.6))
        context.fill(bounds, with: .radialGradient(Gradient(colors: [accent.opacity(0.07), .clear]),
            center: CGPoint(x: size.width * 0.82, y: size.height * 0.78), startRadius: 0, endRadius: Double(size.width) * 0.45))

        // Distant parallax dust: slower than the warp lanes for depth.
        for i in 0..<90 {
            let x0 = fract(Double(i) * 0.618034) * width
            let y = fract(Double(i) * 0.754878 + 0.13) * Double(size.height)
            let x = (x0 - travel * 0.16).truncatingRemainder(dividingBy: width)
            let r = (0.45 + fract(Double(i) * 0.371) * 0.6) * fieldScale
            var dust = context
            dust.opacity = (0.18 + fract(Double(i) * 0.529) * 0.3) * (0.8 + 0.2 * sin(time * 1.7 + Double(i)))
            dust.fill(Path(ellipseIn: CGRect(x: (x < 0 ? x + width : x) - r, y: y - r, width: r * 2, height: r * 2)),
                      with: .color(.white))
        }

        // The startup warp's golden-angle lanes, translated sideways.
        for i in 0..<150 {
            let angle = Double(i) * 2.399963
            let lane = 45 + Double((i * 47) % 210)
            let depth = Double((i * 73) % 151) / 151
            let z = 0.15 + depth * 0.85
            let radius = lane * fieldScale / z
            let x = (fieldCenter.x + cos(angle) * radius - travel).truncatingRemainder(dividingBy: width)
            let point = CGPoint(x: x < 0 ? x + width : x, y: fieldCenter.y + sin(angle) * radius)
            let edge = max(0, min(1, (z - 0.15) / 0.12))
            let twinkle = 1 - arrive * 0.25 * (0.5 + 0.5 * sin(time * 2.4 + Double(i) * 1.7))
            let alpha = edge * twinkle * (0.3 + (1 - z) * 0.65) * (0.65 + speed * 0.35)
            let lineWidth = (0.6 + (1 - z) * 1.2) * fieldScale
            let tail = CGPoint(x: point.x + (12 + 115 * (1 - z)) * fieldScale * speed, y: point.y)
            var streak = Path(); streak.move(to: tail); streak.addLine(to: point)
            if speed > 0.05 && z < 0.45 {
                var bloom = context
                bloom.blendMode = .plusLighter
                bloom.opacity = alpha * speed * 0.3
                bloom.stroke(streak, with: .color(accent), style: StrokeStyle(lineWidth: lineWidth * 3.5, lineCap: .round))
            }
            var star = context
            star.opacity = alpha
            star.stroke(streak, with: .linearGradient(Gradient(colors: [.clear, accent, .white]),
                startPoint: tail, endPoint: point),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            let dot = (0.6 + (1 - z) * 0.8) * fieldScale
            star.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot,
                                             width: dot * 2, height: dot * 2)), with: .color(.white))
        }

        // Moon glides in slightly ahead of the ship.
        let moonIn = since.map { smoother($0 / (Self.arrivalDuration * 0.85)) } ?? 0
        let moon = CGPoint(x: size.width + l.moonRadius * 1.6 + (l.center.x - size.width - l.moonRadius * 1.6) * moonIn, y: l.center.y)
        let angle = orbitAngle(since)
        let ship = shipPosition(l, size: size, time: time, since: since)

        // Heading from motion: forward flight plus bob, then the orbit tangent.
        let dt = 1.0 / 60
        let next = shipPosition(l, size: size, time: time + dt, since: since.map { $0 + dt })
        let forward = velocity * 0.25 * speed * dt
        let dx = Double(next.x - ship.x) + forward
        let dy = Double(next.y - ship.y)
        let heading = abs(dx) + abs(dy) < 0.0001 ? 0 : atan2(dy, dx)

        if moonIn > 0 {
            var halo = context
            halo.opacity = moonIn * (0.85 + 0.15 * sin(time * 1.6))
            halo.fill(Path(ellipseIn: CGRect(x: moon.x - l.moonRadius * 2, y: moon.y - l.moonRadius * 2,
                                             width: l.moonRadius * 4, height: l.moonRadius * 4)),
                with: .radialGradient(Gradient(colors: [accent.opacity(0.2), accent.opacity(0.06), .clear]),
                                      center: moon, startRadius: l.moonRadius * 0.85, endRadius: l.moonRadius * 2))
        }
        // Far half of the orbit path sits behind the moon.
        drawOrbitPath(context, l, from: .pi, to: 2 * .pi, time: time, alpha: arrive)

        let shipScale = max(0.65, l.scale) * (1 + 0.14 * sin(angle) * arrive)
        let behind = arrive > 0.9 && sin(angle) < 0
        if behind {
            drawApollo(context, at: ship, scale: shipScale, angle: heading, time: time, thrust: speed, dim: 0.82)
        }
        drawMoon(context, at: moon, radius: l.moonRadius)
        drawOrbitPath(context, l, from: 0, to: .pi, time: time, alpha: arrive)
        if let since { drawLockOn(context, at: moon, radius: l.moonRadius, since: since) }
        if !behind {
            drawApollo(context, at: ship, scale: shipScale, angle: heading, time: time, thrust: speed, dim: 1)
        }

        // Soft vignette.
        let span = Double(max(size.width, size.height))
        context.fill(bounds, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.4)]),
            center: fieldCenter, startRadius: span * 0.3, endRadius: span * 0.75))
    }

    private func drawOrbitPath(_ context: GraphicsContext, _ l: Layout, from: Double, to: Double, time: Double, alpha: Double) {
        guard alpha > 0 else { return }
        var path = Path()
        for k in 0...48 {
            let p = ellipsePoint(l.center, l.orbitX, l.orbitY, from + (to - from) * Double(k) / 48)
            if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        var c = context
        c.opacity = alpha
        c.stroke(path, with: .color(accent.opacity(0.22)),
                 style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [3, 7], dashPhase: CGFloat(reduceMotion ? 0 : -time * 8)))
    }

    // One-time pulse when the moon is reached: the "connected" moment.
    private func drawLockOn(_ context: GraphicsContext, at point: CGPoint, radius: Double, since: Double) {
        for k in 0..<2 {
            let p = (since - Self.arrivalDuration * 0.75 - Double(k) * 0.4) / 1.4
            guard p > 0 && p < 1 else { continue }
            let r = radius * (1.05 + 0.85 * (1 - pow(1 - p, 3)))
            var ring = context
            ring.blendMode = .plusLighter
            ring.opacity = (1 - p) * 0.45
            ring.stroke(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                        with: .color(accent), lineWidth: 1.6 * (1 - p) + 0.4)
        }
    }

    private func drawMoon(_ context: GraphicsContext, at point: CGPoint, radius: Double) {
        let bounds = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        let disc = Path(ellipseIn: bounds)
        let light = CGPoint(x: point.x - radius * 0.35, y: point.y - radius * 0.35)
        // Sphere lit from the upper left.
        context.fill(disc, with: .radialGradient(Gradient(colors: [Color(white: 0.97), Color(white: 0.74), Color(white: 0.42)]),
            center: light, startRadius: 0, endRadius: radius * 1.55))
        var c = context; c.clip(to: disc)
        // Maria: broad darker plains.
        let maria: [(Double, Double, Double, Double)] = [(-0.28, -0.22, 0.42, 0.3), (0.18, -0.35, 0.3, 0.22),
                                                         (0.05, 0.12, 0.36, 0.26), (-0.42, 0.25, 0.24, 0.2)]
        for (mx, my, w, h) in maria {
            let mw = w * radius * 1.6, mh = h * radius * 1.6
            c.fill(Path(ellipseIn: CGRect(x: point.x + mx * radius - mw / 2, y: point.y + my * radius - mh / 2,
                                          width: mw, height: mh)),
                   with: .color(Color(white: 0.3).opacity(0.13)))
        }
        // Craters, fading toward the limb.
        for i in 0..<22 {
            let a = Double(i) * 2.399963
            let distance = radius * sqrt(Double(i + 1) / 25) * 0.82
            let limb = 1 - pow(distance / radius, 4) * 0.7
            let r = radius * (0.07 + Double((i * 7) % 5) * 0.015)
            let rect = CGRect(x: point.x + cos(a) * distance - r, y: point.y + sin(a) * distance - r, width: r * 2, height: r * 1.7)
            c.fill(Path(ellipseIn: rect), with: .color(.black.opacity((0.08 + Double(i % 3) * 0.025) * limb)))
            c.stroke(Path(ellipseIn: rect.offsetBy(dx: 0.5, dy: 0.7)), with: .color(.white.opacity(0.17 * limb)), lineWidth: 0.7)
        }
        // Terminator shading toward the lower right.
        c.fill(disc, with: .radialGradient(Gradient(colors: [.black.opacity(0.32), .clear]),
            center: CGPoint(x: point.x + radius * 0.7, y: point.y + radius * 0.7), startRadius: 0, endRadius: radius * 1.3))
        // Rim light.
        var rim = context
        rim.blendMode = .plusLighter
        rim.stroke(disc, with: .color(accent.opacity(0.28)), lineWidth: 1.4)
        context.stroke(disc, with: .color(.white.opacity(0.3)), lineWidth: 0.7)
    }

    private func drawApollo(_ context: GraphicsContext, at point: CGPoint, scale: Double, angle: Double,
                            time: Double, thrust: Double, dim: Double) {
        var c = context
        c.opacity = dim
        c.translateBy(x: point.x, y: point.y); c.rotate(by: .radians(angle)); c.scaleBy(x: scale, y: scale)
        // Exhaust: particles, glow and core all fade with thrust.
        if thrust > 0.01 {
            var fx = c
            fx.blendMode = .plusLighter
            for k in 0..<10 {
                let phase = fract(time * 1.8 + Double(k) * 0.1)
                let r = 2.4 * (1 - phase) + 0.4
                let p = CGPoint(x: -32 - phase * 70, y: sin(Double(k) * 12.9 + time) * phase * 6)
                fx.opacity = dim * (1 - phase) * 0.45 * thrust
                fx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(accent))
            }
            let flicker = sin(time * 13) * 3 + sin(time * 29 + 1.3) * 2
            for (length, width, alpha) in [((44 + flicker) * thrust, 9.0, 0.45), ((30 + flicker) * thrust, 5.5, 1.0)] {
                var flame = Path()
                flame.move(to: CGPoint(x: -26, y: -width))
                flame.addQuadCurve(to: CGPoint(x: -26 - length, y: 0), control: CGPoint(x: -26 - length * 0.45, y: -width * 1.2))
                flame.addQuadCurve(to: CGPoint(x: -26, y: width), control: CGPoint(x: -26 - length * 0.45, y: width * 1.2))
                flame.closeSubpath()
                fx.opacity = dim * alpha * thrust
                fx.fill(flame, with: .linearGradient(Gradient(colors: [.clear, accent.opacity(0.75), .white]),
                    startPoint: CGPoint(x: -26 - length, y: 0), endPoint: CGPoint(x: -26, y: 0)))
            }
        }
        // Bell nozzle, cylindrical service module and tapered Apollo capsule.
        var nozzle = Path(); nozzle.move(to: CGPoint(x: -29, y: -7)); nozzle.addLine(to: CGPoint(x: -19, y: -4)); nozzle.addLine(to: CGPoint(x: -19, y: 4)); nozzle.addLine(to: CGPoint(x: -29, y: 7)); nozzle.closeSubpath()
        c.fill(nozzle, with: .linearGradient(Gradient(colors: [Color(white: 0.45), Color(white: 0.22)]),
            startPoint: CGPoint(x: -24, y: -7), endPoint: CGPoint(x: -24, y: 7)))
        let module = Path(roundedRect: CGRect(x: -21, y: -11, width: 26, height: 22), cornerRadius: 2)
        c.fill(module, with: .linearGradient(Gradient(colors: [Color(white: 0.95), Color(white: 0.45), Color(white: 0.75)]), startPoint: CGPoint(x: 0, y: -11), endPoint: CGPoint(x: 0, y: 11)))
        for x in [-15.0, -6.0] { c.fill(Path(CGRect(x: x, y: -10, width: 3, height: 20)), with: .color(Color(white: 0.25))) }
        // Specular highlight along the top of the module.
        c.fill(Path(roundedRect: CGRect(x: -20, y: -10, width: 24, height: 2.2), cornerRadius: 1), with: .color(.white.opacity(0.55)))
        var capsule = Path(); capsule.move(to: CGPoint(x: 4, y: -13)); capsule.addLine(to: CGPoint(x: 25, y: -3)); capsule.addQuadCurve(to: CGPoint(x: 25, y: 3), control: CGPoint(x: 28, y: 0)); capsule.addLine(to: CGPoint(x: 4, y: 13)); capsule.closeSubpath()
        c.fill(capsule, with: .linearGradient(Gradient(colors: [Color(red: 0.95, green: 0.87, blue: 0.66), Color(red: 0.8, green: 0.72, blue: 0.55), Color(white: 0.55)]), startPoint: CGPoint(x: 10, y: -12), endPoint: CGPoint(x: 10, y: 12)))
        c.stroke(capsule, with: .color(.white.opacity(0.55)), lineWidth: 0.6)
        c.fill(Path(roundedRect: CGRect(x: 12, y: -4, width: 6, height: 4), cornerRadius: 1), with: .color(Color(red: 0.05, green: 0.1, blue: 0.16)))
        // Window glint.
        c.fill(Path(roundedRect: CGRect(x: 13, y: -3.5, width: 2, height: 1.2), cornerRadius: 0.5), with: .color(accent.opacity(0.7)))
        var antenna = Path(); antenna.move(to: CGPoint(x: -4, y: -10)); antenna.addLine(to: CGPoint(x: -9, y: -19)); antenna.addLine(to: CGPoint(x: -14, y: -19))
        c.stroke(antenna, with: .color(.white.opacity(0.75)), lineWidth: 0.8)
        c.fill(Path(ellipseIn: CGRect(x: -17, y: -23, width: 6, height: 5)), with: .color(Color(white: 0.8)))
        // Blinking navigation light.
        let blink = fract(time * 0.8) < 0.08 ? 1.0 : 0.15
        var nav = c
        nav.blendMode = .plusLighter
        nav.fill(Path(ellipseIn: CGRect(x: -3, y: 9.5, width: 3, height: 3)), with: .color(accent.opacity(blink)))
    }
}

// A native responder accessory shared by the library and hosted Apollo view.
// Updating labels never replaces a visible bar. Targets are cleared before the
// view leaves its window, including the connection-to-video handoff.
struct NativeTouchBarCommand {
    let id: String
    var title: String
    var symbol: String
    var width: CGFloat
    var enabled: Bool
    var action: (() -> Void)?
    init(_ id: String, _ title: String, _ symbol: String, width: CGFloat = 70,
         enabled: Bool = true, action: (() -> Void)? = nil) {
        self.id = id; self.title = title; self.symbol = symbol
        self.width = width; self.enabled = enabled; self.action = action
    }
}

// macOS has no public NSTouchBar API that hides the Control Strip. This optional
// private-build feature uses the system's per-application presentation preference,
// rather than private DFR APIs, global settings, or restarting system processes.
// Keep a reversible backup for just our two bundle identities. Other apps and
// global/Fn settings are never modified. Injected suites keep tests off real prefs.
enum NativeTouchBarPresentation {
    static let key = "touchBarFullWidth"
    static let backupKey = "touchBarPresentationBackup"
    static let applications = ["com.moonlight-stream.NativeGlass", "com.moonlight-stream.NativeGlass.Engine"]
    static let agentDomain = "com.apple.touchbar.agent"
    static func apply(_ enabled: Bool, preferences: UserDefaults = .standard,
                      agent: UserDefaults? = UserDefaults(suiteName: agentDomain), reapply: Bool = false) -> Bool {
        guard let agent else { return false }
        agent.synchronize()
        let raw = agent.object(forKey: "PresentationModePerApp")
        guard raw == nil || raw is [String: Any] else { return false }
        var modes = raw as? [String: Any] ?? [:]
        var backup = preferences.dictionary(forKey: backupKey) ?? [:]
        let hadBackup = !backup.isEmpty
        if enabled {
            // A manually changed system preference takes precedence on relaunch.
            // The Settings toggle itself is an explicit new request (reapply=false).
            if reapply && hadBackup { return true }
            if backup.isEmpty { backup["hadDictionary"] = raw != nil }
            for app in applications {
                if backup[app] == nil {
                    var entry: [String: Any] = ["present": modes[app] != nil]
                    if let value = modes[app] { entry["value"] = value }
                    backup[app] = entry
                }
                modes[app] = "app"
            }
            // Persist recovery data before changing the agent's presentation map.
            preferences.set(backup, forKey: backupKey); preferences.synchronize()
        } else {
            guard hadBackup else { return true }
            for app in applications {
                guard let entry = backup[app] as? [String: Any] else { continue }
                // Do not undo a later change made by the user or another tool.
                guard modes[app] as? String == "app" else { continue }
                if entry["present"] as? Bool == true { modes[app] = entry["value"] }
                else { modes.removeValue(forKey: app) }
            }
        }
        if modes.isEmpty && backup["hadDictionary"] as? Bool == false {
            agent.removeObject(forKey: "PresentationModePerApp")
        } else { agent.set(modes, forKey: "PresentationModePerApp") }
        guard agent.synchronize() else { return false }
        let saved = agent.dictionary(forKey: "PresentationModePerApp") ?? [:]
        guard NSDictionary(dictionary: saved).isEqual(to: modes) else { return false }
        if !enabled { preferences.removeObject(forKey: backupKey) }
        preferences.set(enabled, forKey: key)
        return true
    }
}
struct NativeTouchBarAccessory: NSViewRepresentable {
    var commands: [NativeTouchBarCommand]
    var crimson = true
    final class AccessoryView: NSView {
        weak var owner: Coordinator?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); owner?.attach(window) }
    }
    final class Coordinator: NSObject, NSTouchBarDelegate {
        var commands: [NativeTouchBarCommand] = []
        var crimson = true
        weak var window: NSWindow?
        var previous: NSTouchBar?
        var bar: NSTouchBar?
        var buttons: [String: NSButton] = [:]
        func attach(_ next: NSWindow?) {
            if window === next, bar != nil { return }
            detach()
            guard let next, !commands.isEmpty else { return }
            window = next; previous = next.touchBar
            let bar = NSTouchBar(); bar.delegate = self
            bar.defaultItemIdentifiers = commands.map { NSTouchBarItem.Identifier($0.id) }
            self.bar = bar; next.touchBar = bar
        }
        func detach() {
            if let window, window.touchBar === bar { window.touchBar = previous }
            for button in buttons.values { button.target = nil; button.action = nil }
            buttons.removeAll(); bar?.delegate = nil; bar = nil; previous = nil; window = nil
        }
        func update(_ commands: [NativeTouchBarCommand], crimson: Bool) {
            let identifiersChanged = self.commands.map(\.id) != commands.map(\.id)
            self.commands = commands; self.crimson = crimson
            if identifiersChanged { let current = window; detach(); attach(current) }
            for command in commands { if let button = buttons[command.id] { style(button, command) } }
        }
        func style(_ button: NSButton, _ command: NativeTouchBarCommand) {
            button.title = command.title; button.isEnabled = command.enabled && command.action != nil
            button.image = NSImage(systemSymbolName: command.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
            button.imagePosition = .imageLeft
            button.font = .systemFont(ofSize: command.title.contains("\n") ? 10 : 11, weight: .medium)
            button.lineBreakMode = .byTruncatingMiddle
            button.bezelColor = crimson ? NSColor(srgbRed: 0.12, green: 0.035, blue: 0.055, alpha: 1) : nil
            button.contentTintColor = crimson ? NSColor(srgbRed: 0.95, green: 0.19, blue: 0.32, alpha: 1) : nil
            button.setAccessibilityLabel(command.title.replacingOccurrences(of: "\n", with: "; "))
            button.toolTip = command.title
        }
        func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
            guard let command = commands.first(where: { $0.id == identifier.rawValue }) else { return nil }
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = ConnectionActionButton(title: command.title, target: self, action: #selector(press(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(command.id)
            button.widthAnchor.constraint(equalToConstant: command.width).isActive = true
            style(button, command); buttons[command.id] = button; item.view = button
            return item
        }
        @objc func press(_ sender: NSButton) {
            guard sender.isEnabled, let window, window.touchBar === bar,
                  let command = commands.first(where: { $0.id == sender.identifier?.rawValue }), command.enabled else { return }
            command.action?()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> AccessoryView {
        let view = AccessoryView(); view.owner = context.coordinator
        context.coordinator.update(commands, crimson: crimson); return view
    }
    func updateNSView(_ view: AccessoryView, context: Context) {
        context.coordinator.update(commands, crimson: crimson); context.coordinator.attach(view.window)
    }
    static func dismantleNSView(_ view: AccessoryView, coordinator: Coordinator) { coordinator.detach(); view.owner = nil }
}

// SDL and Qt own this window's event loop. Use AppKit target/action controls
// so connection actions do not depend on SwiftUI gesture dispatch in that loop.
private final class ConnectionActionButton: NSButton {
    private var mousePressed = false
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    // NSButton's default mouseDown runs an NSCell tracking loop until mouse-up.
    // This window is pumped by Qt/SDL rather than NSApplication.run. Keep its
    // pump free between real press/release events instead of nesting tracking.
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        mousePressed = true
        highlight(true)
    }
    override func mouseDragged(with event: NSEvent) {
        guard mousePressed else { return }
        highlight(bounds.contains(convert(event.locationInWindow, from: nil)))
    }
    override func mouseUp(with event: NSEvent) {
        guard mousePressed else { return }
        mousePressed = false
        highlight(false)
        guard isEnabled, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        sendAction(action, to: target)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { mousePressed = false; highlight(false) }
    }
}
private struct NativeConnectionButton: NSViewRepresentable {
    let title: String
    let identifier: String
    var enabled = true
    var accent: NSColor? = nil
    let action: () -> Void
    init(_ title: String, identifier: String, enabled: Bool = true, accent: NSColor? = nil, action: @escaping () -> Void) {
        self.title = title; self.identifier = identifier; self.enabled = enabled; self.accent = accent; self.action = action
    }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func press(_ sender: NSButton) { action() }
    }
    func makeCoordinator() -> Coordinator { Coordinator(action) }
    func makeNSView(context: Context) -> NSButton {
        let button = ConnectionActionButton(title: title, target: context.coordinator, action: #selector(Coordinator.press(_:)))
        button.setButtonType(.momentaryPushIn); button.bezelStyle = .rounded
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.title = title; button.isEnabled = enabled; button.bezelColor = accent
        button.contentTintColor = accent == nil ? nil : .white
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.setAccessibilityIdentifier(identifier)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSButton, context: Context) -> CGSize? { nsView.fittingSize }
}

