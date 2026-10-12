import AppKit
import SwiftUI

// One finite, native animation per process. No media decoder, window replacement,
// network work, or streaming changes are involved in startup presentation.
@MainActor final class NativeBootPresentation: ObservableObject {
    enum Phase { case playing, fading, finished }
    @Published private(set) var phase: Phase
    @Published private(set) var startedAt: Date?
    let logo: NSImage?
    static let duration = 4.1
    private var completion: Task<Void, Never>?
    private var fadeCompletion: Task<Void, Never>?
    private var motionNotification: NSObjectProtocol?
    private var windowNotification: NSObjectProtocol?
    private var escapeMonitor: Any?
    private weak var watchedWindow: NSWindow?
    private var chrome: Chrome?

    private struct Chrome {
        let title: NSWindow.TitleVisibility
        let transparent: Bool
        let fullSize: Bool
        let separator: NSTitlebarSeparatorStyle
        let background: NSColor
        let movable: Bool
        let toolbar: NSToolbar?
        let toolbarVisible: Bool
    }
    var blocksLibrary: Bool { phase != .finished }

    init(enabled: Bool, resource: URL? = Bundle.main.url(forResource: "boot-moon", withExtension: "png"),
         reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
        logo = resource.flatMap { NSImage(contentsOf: $0) }
        phase = enabled && !reduceMotion && logo != nil ? .playing : .finished
    }

    func start() {
        guard startedAt == nil, phase == .playing else { return }
        startedAt = Date()
        motionNotification = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self?.finishImmediately() }
            }
        }
        completion = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(Self.duration * 1_000_000_000)) } catch { return }
            self?.finish()
        }
    }

    func watchWindow(_ window: NSWindow?) {
        guard phase == .playing, let window, watchedWindow == nil else { return }
        // Apply synchronously, before the first window paint. The library is
        // not constructed until startup finishes, so it cannot flash through.
        watchedWindow = window
        chrome = Chrome(title: window.titleVisibility, transparent: window.titlebarAppearsTransparent,
                        fullSize: window.styleMask.contains(.fullSizeContentView),
                        separator: window.titlebarSeparatorStyle, background: window.backgroundColor, movable: window.isMovableByWindowBackground,
                        toolbar: window.toolbar, toolbarVisible: window.toolbar?.isVisible ?? false)
        let frame = window.frame
        window.backgroundColor = NSColor(red: 7 / 255, green: 12 / 255, blue: 25 / 255, alpha: 1)
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar?.isVisible = false
        window.isMovableByWindowBackground = true
        window.setFrame(frame, display: false)
        // SwiftUI can finish applying its scene chrome after view attachment.
        // Reassert the transparent title region once that pass has completed.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, self.blocksLibrary, let window, self.watchedWindow === window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.toolbar?.isVisible = false
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard event.window === window, event.keyCode == 53,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  self?.blocksLibrary == true else { return event }
            self?.finish()
            return nil
        }
        windowNotification = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finishImmediately() }
        }
    }

    func finish() {
        guard phase == .playing else { return }
        completion?.cancel(); completion = nil
        withAnimation(.easeInOut(duration: 0.35)) { phase = .fading }
        fadeCompletion = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            self?.finishImmediately()
        }
    }

    func finishImmediately() {
        completion?.cancel(); completion = nil
        fadeCompletion?.cancel(); fadeCompletion = nil
        if let window = watchedWindow, let chrome {
            let frame = window.frame // Preserve the user's latest size/position.
            if !chrome.fullSize { window.styleMask.remove(.fullSizeContentView) }
            window.titleVisibility = chrome.title
            window.titlebarAppearsTransparent = chrome.transparent
            window.titlebarSeparatorStyle = chrome.separator
            window.backgroundColor = chrome.background
            window.isMovableByWindowBackground = chrome.movable
            chrome.toolbar?.isVisible = chrome.toolbarVisible
            window.setFrame(frame, display: false)
        }
        chrome = nil; watchedWindow = nil
        if let motionNotification { NSWorkspace.shared.notificationCenter.removeObserver(motionNotification) }
        motionNotification = nil
        if let windowNotification { NotificationCenter.default.removeObserver(windowNotification) }
        windowNotification = nil
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        phase = .finished
    }

    deinit {
        completion?.cancel(); fadeCompletion?.cancel()
        if let motionNotification { NSWorkspace.shared.notificationCenter.removeObserver(motionNotification) }
        if let windowNotification { NotificationCenter.default.removeObserver(windowNotification) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
    }
}

// Time-driven vector drawing scales to the window's actual backing resolution.
// All elements share one timeline: expansion, particles, construction rings,
// contraction and the transparent boot Moonlight logo.
struct NativeBootView: View {
    @ObservedObject var presentation: NativeBootPresentation
    var previewTime: Double? = nil
    static let background = Color(red: 7 / 255, green: 12 / 255, blue: 25 / 255)

    private func ease(_ time: Double, _ start: Double, _ duration: Double) -> Double {
        let p = min(1, max(0, (time - start) / duration))
        return p * p * p * (10 + p * (-15 + 6 * p))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: previewTime != nil || presentation.phase != .playing)) { timeline in
            let t = previewTime ?? max(0, timeline.date.timeIntervalSince(presentation.startedAt ?? timeline.date))
            GeometryReader { geometry in
                let size = geometry.size
                let diameter = min(96.0, min(size.width, size.height) * 0.16)
                let fullRadius = hypot(size.width, size.height) * 0.55
                let expand = ease(t, 0.12, 0.7)
                let collapse = ease(t, 2.55, 0.8)
                let radius = (7 + (fullRadius - 7) * expand) * (1 - collapse) + diameter * 0.5 * collapse
                ZStack {
                    Self.background
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let disk = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        var backdrop = context
                        backdrop.opacity = 1 - ease(t, 3.05, 0.38)
                        backdrop.fill(Path(ellipseIn: disk), with: .linearGradient(
                            Gradient(colors: [Color(red: 0.29, green: 0.81, blue: 0.96), Color(red: 0.25, green: 0.39, blue: 0.91)]),
                            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)))

                        // Four bright dots separate from the initial seed and
                        // dissolve while the fine construction lines emerge.
                        let scatter = ease(t, 0.85, 0.55)
                        let dotOpacity = ease(t, 0.55, 0.2) * (1 - ease(t, 1.45, 0.4))
                        let distance = (12 + 74 * scatter) * min(canvasSize.width / 680, 1.5)
                        let dotRadius = 6 * (1 - scatter) + 1.4
                        var particles = context; particles.opacity = dotOpacity
                        for i in 0..<4 {
                            let angle = Double(i) * .pi / 2 - .pi / 2
                            let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                            particles.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius,
                                                                 width: dotRadius * 2, height: dotRadius * 2)), with: .color(.white))
                        }

                        let lines = ease(t, 1.3, 0.7) * (1 - ease(t, 2.55, 0.5))
                        let spread = ease(t, 1.15, 1.3)
                        var rings = context; rings.opacity = lines * 0.52
                        for i in 0..<3 {
                            let r = (diameter * 0.5 + Double(i) * 32 + 105 * spread) * (1 - collapse)
                            var arc = Path()
                            let rotation = t * 27 + Double(i) * 85
                            arc.addArc(center: center, radius: r, startAngle: .degrees(rotation),
                                       endAngle: .degrees(rotation + 285), clockwise: false)
                            rings.stroke(arc, with: .color(.white), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                        }

                    }
                    if let logo = presentation.logo {
                        Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: diameter, height: diameter)
                            .clipShape(RoundedRectangle(cornerRadius: diameter * 0.22, style: .continuous))
                            .scaleEffect(0.86 + 0.14 * ease(t, 2.95, 0.5))
                            .opacity(ease(t, 2.95, 0.38))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .opacity(presentation.phase == .fading ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Moonlight startup animation. Press Escape to skip.")
        .accessibilityIdentifier("native-boot-animation")
        .accessibilityAction(named: Text("Skip startup animation")) { presentation.finish() }
        .onAppear { if previewTime == nil { presentation.start() } }
    }
}
