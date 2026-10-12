import AppKit
import SwiftUI

// Preview-only alternatives. The production app keeps its current choreography.
// All variants use the dedicated transparent boot logo resource.
private enum MoonlightMotion: String, CaseIterable {
    case orbit = "Orbit Reveal"
    case aurora = "Aurora Bloom"
    case starlight = "Starlight Weave"
    case eclipse = "Lunar Eclipse"
    case prism = "Prism Sweep"
    case warp = "Warp Arrival"
}

@MainActor private struct MoonlightAlternativePreview: View {
    let motion: MoonlightMotion
    @State private var replay = UUID()
    var body: some View {
        VStack(spacing: 12) {
            MoonlightAlternativeCycle(motion: motion).id(replay)
                .frame(width: 960, height: 640)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button("Replay " + motion.rawValue) { replay = UUID() }
        }.padding(16).preferredColorScheme(.dark)
    }
}

@MainActor private struct MoonlightAlternativeCycle: View {
    let motion: MoonlightMotion
    @StateObject private var boot = NativeBootPresentation(enabled: true, reduceMotion: false)
    @StateObject private var store = EngineStore(preview: true)
    var body: some View {
        ZStack(alignment: .topLeading) {
            NativeBootView.background
            if boot.blocksLibrary {
                MoonlightAlternativeArtwork(motion: motion, boot: boot)
                // Xcode Canvas has no real window chrome. The running app's
                // unchanged startup setup uses the genuine AppKit buttons.
                HStack(spacing: 8) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { color in
                        Circle().fill(color).frame(width: 12, height: 12)
                    }
                }.padding(16).accessibilityHidden(true)
            } else {
                LibraryView(store: store, sizesPreviewWindow: false).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: boot.phase)
        .onAppear { boot.start() }
        .onDisappear { boot.finishImmediately() }
    }
}

@MainActor private struct MoonlightAlternativeArtwork: View {
    let motion: MoonlightMotion
    @ObservedObject var boot: NativeBootPresentation
    private let cyan = Color(red: 0.36, green: 0.87, blue: 1)
    private let blue = Color(red: 0.36, green: 0.47, blue: 1)

    private func ease(_ time: Double, _ start: Double, _ length: Double) -> Double {
        let p = min(1, max(0, (time - start) / length))
        return p * p * p * (10 + p * (-15 + 6 * p))
    }
    private func envelope(_ t: Double) -> Double {
        ease(t, 0, 0.7) * (1 - ease(t, 2.45, 0.85))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: boot.phase != .playing)) { timeline in
            let t = max(0, timeline.date.timeIntervalSince(boot.startedAt ?? timeline.date))
            GeometryReader { geometry in
                let diameter = min(96.0, min(geometry.size.width, geometry.size.height) * 0.16)
                ZStack {
                    NativeBootView.background
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let scale = Double(min(size.width, size.height)) / 640
                        switch motion {
                        case .orbit: drawOrbit(context, center, scale, t)
                        case .aurora: drawAurora(context, size, center, scale, t)
                        case .starlight: drawStarlight(context, center, scale, t)
                        case .eclipse: drawEclipse(context, center, scale, t)
                        case .prism: drawPrism(context, size, center, scale, t)
                        case .warp: drawWarp(context, size, center, scale, t)
                        }
                    }
                    if let logo = boot.logo {
                        Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(logoScale(t))
                            .opacity(logoOpacity(t))
                            .offset(y: motion == .aurora ? 10 * (1 - ease(t, 1.9, 1)) : 0)
                            .mask {
                                if motion == .eclipse {
                                    GeometryReader { imageGeometry in
                                        let w = imageGeometry.size.width
                                        LinearGradient(colors: [.white, .white, .clear], startPoint: .leading, endPoint: .trailing)
                                            .frame(width: w * 3)
                                            .offset(x: -w * 3 + w * 3 * ease(t, 0.5, 1.6))
                                    }
                                } else { Color.white }
                            }
                    }
                }
            }
        }
        .opacity(boot.phase == .fading ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(motion.rawValue + " startup animation preview")
    }

    private func logoScale(_ t: Double) -> Double {
        switch motion {
        case .warp: return 0.12 + 0.88 * ease(t, 1.65, 1.1)
        case .aurora: return 0.83 + 0.17 * ease(t, 1.6, 1.2)
        case .starlight: return 0.94 + 0.06 * ease(t, 2, 0.9)
        default: return 0.9 + 0.1 * ease(t, 0.7, 1.9)
        }
    }
    private func logoOpacity(_ t: Double) -> Double {
        switch motion {
        case .orbit: return ease(t, 1.6, 1.05)
        case .aurora: return ease(t, 1.5, 1.15)
        case .starlight: return ease(t, 1.9, 0.9)
        case .eclipse: return ease(t, 0.1, 0.55)
        case .prism: return ease(t, 1.3, 1.3)
        case .warp: return ease(t, 1.55, 0.85)
        }
    }

    private func glow(_ context: GraphicsContext, _ center: CGPoint, _ radius: Double, _ alpha: Double) {
        var c = context; c.opacity = alpha
        c.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
               with: .radialGradient(Gradient(colors: [cyan.opacity(0.4), blue.opacity(0.08), .clear]),
                                     center: center, startRadius: 0, endRadius: radius))
    }

    private func drawOrbit(_ context: GraphicsContext, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let visible = envelope(t)
        glow(context, center, 180 * scale, visible * 0.7)
        for i in 0..<3 {
            let r = (125 + Double(i) * 24) * scale * (1 - 0.63 * ease(t, 1.7, 1.15))
            let angle = t * (95 - Double(i) * 13) + Double(i) * 120
            var arc = Path()
            arc.addArc(center: center, radius: r, startAngle: .degrees(angle), endAngle: .degrees(angle + 245), clockwise: false)
            var c = context; c.opacity = visible * 0.65
            c.stroke(arc, with: .linearGradient(Gradient(colors: [.clear, blue, cyan]),
                startPoint: CGPoint(x: center.x - r, y: center.y + r), endPoint: CGPoint(x: center.x + r, y: center.y - r)),
                style: StrokeStyle(lineWidth: 1.35 * scale, lineCap: .round))
            let a = (angle + 245) * .pi / 180
            let point = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            glow(c, point, 13 * scale, 0.8)
            c.fill(Path(ellipseIn: CGRect(x: point.x - 2 * scale, y: point.y - 2 * scale, width: 4 * scale, height: 4 * scale)), with: .color(cyan))
        }
    }

    private func drawAurora(_ context: GraphicsContext, _ size: CGSize, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let visible = envelope(t)
        for i in 0..<5 {
            let drift = sin(t * 0.9 + Double(i) * 0.75)
            let point = CGPoint(x: center.x + drift * 90 * scale, y: center.y + cos(t + Double(i)) * 46 * scale)
            glow(context, point, (170 + Double(i) * 22) * scale, visible * 0.27)
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -20, y: center.y + 75 * scale))
            ribbon.addCurve(to: CGPoint(x: size.width + 20, y: center.y - 55 * scale),
                control1: CGPoint(x: size.width * 0.29, y: center.y - (95 + drift * 45) * scale),
                control2: CGPoint(x: size.width * 0.63, y: center.y + (90 + drift * 50) * scale))
            var c = context; c.opacity = visible * (0.12 + Double(i) * 0.035)
            c.stroke(ribbon, with: .linearGradient(Gradient(colors: [.clear, cyan, blue, .clear]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height)),
                style: StrokeStyle(lineWidth: (2 + Double(i) * 2) * scale, lineCap: .round))
        }
    }

    private func drawStarlight(_ context: GraphicsContext, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let gather = ease(t, 0.45, 1.8)
        let visible = envelope(t)
        glow(context, center, 150 * scale, ease(t, 1.1, 0.8) * visible * 0.75)
        for i in 0..<28 {
            let a = Double(i) * 2.39996 + t * 0.13
            let r = (82 + Double((i * 37) % 145)) * scale * (1 - gather * 0.84)
            let point = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r * 0.8)
            let tail = CGPoint(x: center.x + cos(a - 0.12) * (r + 20 * scale), y: center.y + sin(a - 0.12) * (r + 20 * scale) * 0.8)
            var c = context; c.opacity = visible * (0.45 + 0.25 * sin(t * 2 + Double(i)))
            var path = Path(); path.move(to: tail); path.addLine(to: point)
            c.stroke(path, with: .linearGradient(Gradient(colors: [.clear, cyan]), startPoint: tail, endPoint: point), lineWidth: 0.8 * scale)
            let dot = (i % 6 == 0 ? 2.0 : 1.0) * scale
            c.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)), with: .color(.white))
        }
    }

    private func drawEclipse(_ context: GraphicsContext, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let visible = envelope(t)
        glow(context, center, 155 * scale, visible * 0.45)
        let sweep = ease(t, 0.25, 2.4)
        var rim = Path()
        rim.addArc(center: center, radius: 67 * scale, startAngle: .degrees(-115 + sweep * 280),
                   endAngle: .degrees(-45 + sweep * 280), clockwise: false)
        var c = context; c.opacity = visible * 0.6
        c.stroke(rim, with: .linearGradient(Gradient(colors: [.clear, cyan, .clear]),
            startPoint: CGPoint(x: center.x - 70 * scale, y: center.y - 70 * scale),
            endPoint: CGPoint(x: center.x + 70 * scale, y: center.y + 70 * scale)),
            style: StrokeStyle(lineWidth: 1.25 * scale, lineCap: .round))
    }

    // Deterministic perspective field: accelerate, brake smoothly, then hold
    // the destination. No random regeneration, timers, or external media.
    private func drawWarp(_ context: GraphicsContext, _ size: CGSize, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let speed = ease(t, 0, 0.6) * (1 - ease(t, 1.35, 1.05))
        let travel = 2.8 * ease(t, 0, 2.4)
        let arrival = ease(t, 1.8, 0.85)
        for i in 0..<150 {
            let angle = Double(i) * 2.399963
            let lane = 20 + Double((i * 47) % 210)
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

    private func drawPrism(_ context: GraphicsContext, _ size: CGSize, _ center: CGPoint, _ scale: Double, _ t: Double) {
        let visible = envelope(t)
        let travel = ease(t, 0.2, 2.4)
        glow(context, center, 160 * scale, visible * 0.45)
        for i in 0..<7 {
            let x = -size.width * 0.35 + size.width * 1.7 * travel + Double(i - 3) * 14 * scale
            let top = CGPoint(x: x + 65 * scale, y: -20)
            let bottom = CGPoint(x: x - 65 * scale, y: size.height + 20)
            var path = Path(); path.move(to: top); path.addLine(to: bottom)
            var c = context; c.opacity = visible * (0.2 + Double(i % 3) * 0.09)
            c.stroke(path, with: .linearGradient(Gradient(colors: [.clear, cyan, blue, .clear]), startPoint: top, endPoint: bottom),
                style: StrokeStyle(lineWidth: (i == 3 ? 5 : 1.4) * scale, lineCap: .round))
        }
    }
}

#Preview("Moonlight · Orbit Reveal") { MoonlightAlternativePreview(motion: .orbit) }
#Preview("Moonlight · Aurora Bloom") { MoonlightAlternativePreview(motion: .aurora) }
#Preview("Moonlight · Starlight Weave") { MoonlightAlternativePreview(motion: .starlight) }
#Preview("Moonlight · Lunar Eclipse") { MoonlightAlternativePreview(motion: .eclipse) }
#Preview("Moonlight · Prism Sweep") { MoonlightAlternativePreview(motion: .prism) }

#Preview("Moonlight · Warp Arrival") { MoonlightAlternativePreview(motion: .warp) }
