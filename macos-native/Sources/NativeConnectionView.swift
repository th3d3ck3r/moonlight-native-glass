import AppKit
import SwiftUI
import ObjectiveC.runtime

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

// Full width is opt-in and owned only while this app/window is active. AppKit
// has no public Control Strip hiding API. Resolve its system-modal selectors at
// runtime; unsupported systems keep the ordinary bar. Never edit global prefs
// or restart TouchBarServer/ControlStrip. This private-build hook needs hardware QA.
enum NativeTouchBarPresentation {
    static let key = "touchBarFullWidth"
    static let backupKey = "touchBarPresentationBackup"
    static let applications = ["com.moonlight-stream.NativeGlass", "com.moonlight-stream.NativeGlass.Engine"]
    static let agentDomain = "com.apple.touchbar.agent"
    static let sharedPreferences = UserDefaults(suiteName: applications[0])!
    static func enabled(in preferences: UserDefaults = sharedPreferences) -> Bool {
        preferences.synchronize()
        return supported && preferences.bool(forKey: key)
    }
    static let changed = Notification.Name("com.moonlight-stream.NativeGlass.touchBarPresentationChanged")
    private static let showSelector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
    private static let hideSelector = NSSelectorFromString("dismissSystemModalTouchBar:")
    static var supported: Bool { NSTouchBar.responds(to: showSelector) && NSTouchBar.responds(to: hideSelector) }
    private static func present(_ bar: NSTouchBar) -> Bool {
        guard supported, let method = class_getClassMethod(NSTouchBar.self, showSelector) else { return false }
        typealias Show = @convention(c) (AnyClass, Selector, NSTouchBar, Int64, NSString?) -> Void
        let show = unsafeBitCast(method_getImplementation(method), to: Show.self)
        show(NSTouchBar.self, showSelector, bar, 1, nil)
        return true
    }
    private static func dismiss(_ bar: NSTouchBar) {
        guard let method = class_getClassMethod(NSTouchBar.self, hideSelector) else { return }
        typealias Hide = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void
        unsafeBitCast(method_getImplementation(method), to: Hide.self)(NSTouchBar.self, hideSelector, bar)
    }
    final class Session {
        private(set) var presented: NSTouchBar?
        private var revision = 0
        let show: (NSTouchBar) -> Bool
        let hide: (NSTouchBar) -> Void
        init(show: @escaping (NSTouchBar) -> Bool = NativeTouchBarPresentation.present,
             hide: @escaping (NSTouchBar) -> Void = NativeTouchBarPresentation.dismiss) {
            self.show = show; self.hide = hide
        }
        func update(_ bar: NSTouchBar?, enabled: Bool, eligible: Bool) {
            let next = enabled && eligible ? bar : nil
            guard presented !== next else { return }
            revision += 1; let current = revision
            let old = presented; presented = nil
            if let old { hide(old); if revision != current { return } }
            if let next {
                presented = next // AppKit can synchronously send focus notifications.
                let accepted = show(next)
                if revision == current && !accepted { presented = nil }
            }
        }
        deinit { if let presented { hide(presented) } }
    }
    // Restore only the two entries written by build 43. Preserve later manual
    // edits and other apps. New full-width presentation writes no agent prefs.
    static func restoreLegacy(preferences: UserDefaults, agent: UserDefaults?) -> Bool {
        guard let backup = preferences.dictionary(forKey: backupKey), !backup.isEmpty else { return true }
        guard let agent else { return false }; agent.synchronize()
        let raw = agent.object(forKey: "PresentationModePerApp")
        guard raw == nil || raw is [String: Any] else { return false }
        var modes = raw as? [String: Any] ?? [:]
        for app in applications {
            guard let entry = backup[app] as? [String: Any], modes[app] as? String == "app" else { continue }
            if entry["present"] as? Bool == true { modes[app] = entry["value"] }
            else { modes.removeValue(forKey: app) }
        }
        if modes.isEmpty && backup["hadDictionary"] as? Bool == false { agent.removeObject(forKey: "PresentationModePerApp") }
        else { agent.set(modes, forKey: "PresentationModePerApp") }
        guard agent.synchronize(), NSDictionary(dictionary: agent.dictionary(forKey: "PresentationModePerApp") ?? [:]).isEqual(to: modes) else { return false }
        preferences.removeObject(forKey: backupKey)
        return true
    }
    static func apply(_ enabled: Bool, preferences: UserDefaults = .standard,
                      agent: UserDefaults? = UserDefaults(suiteName: agentDomain), reapply: Bool = false,
                      available: Bool = supported) -> Bool {
        if enabled && !available {
            preferences.set(false, forKey: key); preferences.synchronize()
            NotificationCenter.default.post(name: changed, object: nil)
            return false
        }
        guard restoreLegacy(preferences: preferences, agent: agent) else { return false }
        preferences.set(enabled, forKey: key); preferences.synchronize()
        NotificationCenter.default.post(name: changed, object: nil)
        DistributedNotificationCenter.default().postNotificationName(changed, object: nil, userInfo: nil, deliverImmediately: true)
        return true
    }
}
// A fixed 30-point canvas avoids the larger NSButtonCell font/insets applied
// by the physical Touch Bar. Keep NSButton actions/accessibility and the same
// nonblocking event handling used by Apollo; only presentation is custom.
final class NativeTouchBarButton: ConnectionActionButton {
    var statusOnly = false
    private var pressOrigin = NSPoint.zero
    override func mouseDown(with event: NSEvent) { pressOrigin = event.locationInWindow; super.mouseDown(with: event) }
    override func mouseDragged(with event: NSEvent) {
        if hypot(event.locationInWindow.x - pressOrigin.x, event.locationInWindow.y - pressOrigin.y) > 5 { cancelPress() }
        super.mouseDragged(with: event)
    }
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 70, height: 30) }
    var labelRects: [NSRect] {
        let count = title.contains("\n") ? 2 : 1
        let x: CGFloat = image == nil ? 7 : 29
        return (0..<count).map { row in
            NSRect(x: x, y: count == 1 ? 8 : CGFloat(3 + row * 12),
                   width: max(0, bounds.width - x - 7), height: count == 1 ? 15 : 12)
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        let background = bezelColor ?? NSColor(white: 0.13, alpha: 1)
        (cell?.isHighlighted == true ? background.blended(withFraction: 0.2, of: .white)! : background).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        let opacity: CGFloat = isEnabled || statusOnly ? 1 : 0.4
        if let image {
            let tint = (contentTintColor ?? .controlAccentColor).withAlphaComponent(opacity)
            let icon = image.withSymbolConfiguration(.init(hierarchicalColor: tint)) ?? image
            let x = title.isEmpty ? (bounds.width - 15) / 2 : 7
            icon.draw(in: NSRect(x: x, y: (bounds.height - 15) / 2, width: 15, height: 15),
                      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        let lines = title.components(separatedBy: "\n")
        for (row, rect) in labelRects.enumerated() {
            let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingMiddle
            let font = NSFont.systemFont(ofSize: lines.count > 1 ? (row == 0 ? 10.5 : 9) : 11, weight: .semibold)
            (lines[row] as NSString).draw(in: rect, withAttributes: [
                .font: font, .foregroundColor: NSColor.white.withAlphaComponent(opacity * (row == 0 ? 1 : 0.8)),
                .paragraphStyle: paragraph])
        }
    }
}

// A single Touch Bar item preserves composition. Keep host status pinned and
// allow the remaining controls to scroll when the system supplies less width.
final class NativeTouchBarRow: NSView {
    let scroll = NSScrollView()
    let document = NSView()
    let more = NativeTouchBarButton(title: "", target: nil, action: nil)
    var status: NSButton?
    var statusWidth: CGFloat = 0
    var controls: [(NSButton, CGFloat)] = []
    override var intrinsicContentSize: NSSize {
        NSSize(width: statusWidth + (status == nil ? 0 : 6) + document.frame.width, height: 30)
    }
    init(buttons: [(NSButton, CGFloat)], pinnedStatus: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 30))
        identifier = .init("TouchBarCommandRow")
        scroll.drawsBackground = false; scroll.borderType = .noBorder
        scroll.hasVerticalScroller = false; scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .allowed; scroll.verticalScrollElasticity = .none
        scroll.documentView = document; addSubview(scroll)
        more.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        more.bezelColor = NSColor(srgbRed: 0.12, green: 0.035, blue: 0.055, alpha: 1)
        more.contentTintColor = NSColor(srgbRed: 0.95, green: 0.19, blue: 0.32, alpha: 1)
        more.target = self; more.action = #selector(scrollMore)
        more.setAccessibilityLabel("Scroll to more Touch Bar controls; tap again at the end to return")
        more.toolTip = "Swipe controls or tap for more"; addSubview(more)
        var remaining = buttons
        if pinnedStatus, let first = remaining.first {
            status = first.0; statusWidth = first.1; first.0.frame = NSRect(x: 0, y: 0, width: first.1, height: 30)
            addSubview(first.0); remaining.removeFirst()
        }
        controls = remaining
        var x: CGFloat = 0
        for (button, width) in remaining {
            button.frame = NSRect(x: x, y: 0, width: width, height: 30)
            document.addSubview(button); x += width + 6
        }
        document.frame = NSRect(x: 0, y: 0, width: max(0, x - 6), height: 30)
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setFrameSize(frame.size)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        let pinned = status == nil ? 0 : min(statusWidth, max(100, size.width * 0.4))
        if let status { status.frame = NSRect(x: 0, y: 0, width: pinned, height: 30) }
        let start = pinned + (status == nil ? 0 : 6)
        let available = max(0, size.width - start)
        let overflow = document.frame.width > available
        more.isHidden = !overflow
        more.frame = NSRect(x: max(start, size.width - 30), y: 0, width: 30, height: 30)
        scroll.frame = NSRect(x: start, y: 0, width: max(0, available - (overflow ? 34 : 0)), height: 30)
        let limit = max(0, document.frame.width - scroll.contentView.bounds.width)
        scroll.contentView.scroll(to: NSPoint(x: min(limit, scroll.contentView.bounds.origin.x), y: 0))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
    @objc func scrollMore() {
        let clip = scroll.contentView
        let end = max(0, document.frame.width - clip.bounds.width)
        let next = clip.bounds.origin.x >= end - 1 ? 0 : min(end, clip.bounds.origin.x + max(100, clip.bounds.width * 0.75))
        clip.scroll(to: NSPoint(x: next, y: 0)); scroll.reflectScrolledClipView(clip)
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
        let presentation = NativeTouchBarPresentation.Session()
        var observers: [NSObjectProtocol] = []
        var distributedObserver: NSObjectProtocol?
        var detaching = false
        var row: NativeTouchBarRow?
        func refreshPresentation() {
            let eligible = !detaching && window?.isKeyWindow == true && window?.isVisible == true && NSApp.isActive && window?.touchBar === bar
            presentation.update(bar, enabled: !CommandLine.arguments.contains("--design-preview") && NativeTouchBarPresentation.enabled(), eligible: eligible)
        }
        func attach(_ next: NSWindow?) {
            if window === next, bar != nil { return }
            detach()
            guard let next, !commands.isEmpty else { return }
            window = next; previous = next.touchBar
            let bar = NSTouchBar(); bar.delegate = self
            bar.defaultItemIdentifiers = [.init("native.commandRow")]
            self.bar = bar; next.touchBar = bar
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didMiniaturizeNotification, NSApplication.didBecomeActiveNotification,
                         NSApplication.didResignActiveNotification, NativeTouchBarPresentation.changed] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refreshPresentation() })
            }
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: next, queue: .main) { [weak self] _ in
                self?.detach()
            })
            distributedObserver = DistributedNotificationCenter.default().addObserver(forName: NativeTouchBarPresentation.changed, object: nil, queue: .main) { [weak self] _ in self?.refreshPresentation() }
            refreshPresentation()
        }
        func detach() {
            detaching = true
            presentation.update(nil, enabled: false, eligible: false)
            if let distributedObserver { DistributedNotificationCenter.default().removeObserver(distributedObserver) }; distributedObserver = nil
            for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
            if let window, window.touchBar === bar { window.touchBar = previous }
            for button in buttons.values { button.target = nil; button.action = nil }
            buttons.removeAll(); row = nil; bar?.delegate = nil; bar = nil; previous = nil; window = nil; detaching = false
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
            (button as? NativeTouchBarButton)?.statusOnly = command.action == nil
            button.needsDisplay = true
        }
        func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
            guard identifier.rawValue == "native.commandRow" else { return nil }
            let item = NSCustomTouchBarItem(identifier: identifier)
            var views: [(NSButton, CGFloat)] = []
            for command in commands {
                let button = NativeTouchBarButton(title: command.title, target: self, action: #selector(press(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(command.id)
                style(button, command); buttons[command.id] = button; views.append((button, command.width))
            }
            let row = NativeTouchBarRow(buttons: views, pinnedStatus: commands.first?.action == nil)
            self.row = row; item.view = row
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
class ConnectionActionButton: NSButton {
    private var mousePressed = false
    func cancelPress() { mousePressed = false; highlight(false) }
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

