import AppKit
import QuartzCore
import SwiftUI

/// Touch Bar artwork for the "Smoke accretion" theme.
/// Images live in the asset catalog (TouchBar*.imageset). Glyphs are template
/// images, so the system tints them like any other Touch Bar icon.
enum MoonlightLGTouchBarArt {
    enum State: Equatable { case idle, booting, connecting, connected, failed }

    /// Set to false to use only the still strip images (no live shader on the Touch Bar).
    static let configurationChanged = Notification.Name("MoonlightLG.TouchBarArtworkConfigurationChanged")
    static var liveAnimationEnabled = true {
        didSet {
            if oldValue != liveAnimationEnabled {
                NotificationCenter.default.post(name: configurationChanged, object: nil)
            }
        }
    }

    /// 18 pt template glyph: moon with a ring (library / app button).
    static var appGlyph: NSImage? { template("TouchBarMoonlightLG") }
    /// 18 pt template glyph: dashed ring, for "connecting".
    static var connectingGlyph: NSImage? { template("TouchBarConnecting") }
    /// 18 pt template glyph: moon with a status dot, for "connected".
    static var connectedGlyph: NSImage? { template("TouchBarConnected") }
    /// 18 pt template glyph: moon with a play cut-out, for "Continue to Stream" / resume.
    static var streamGlyph: NSImage? { template("TouchBarStream") }
    /// 22 pt full-colour app tile (not a template).
    static var appIconColor: NSImage? { NSImage(named: "TouchBarAppIconColor") }

    static func glyph(for state: State) -> NSImage? {
        switch state {
        case .idle, .booting: return appGlyph
        case .connecting: return connectingGlyph
        case .connected: return connectedGlyph
        case .failed: return NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Connection failed")
        }
    }

    /// 1085 × 30 pt still artwork (used when the live scene is off).
    static func strip(for state: State) -> NSImage? {
        NSImage(named: state == .connected ? "TouchBarStripConnected" : "TouchBarStripIdle")
    }

    private static func template(_ name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        return image
    }
}

// MARK: - Live strip scene

/// The Touch Bar framing of the scene (`smokeAccretionStrip` in SmokeAccretion.metal).
struct SmokeAccretionStripScene: View {
    var state: SmokeAccretionState

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.black)
                .colorEffect(ShaderLibrary.bundle(.main).smokeAccretionStrip(
                    .float2(Float(geometry.size.width), Float(geometry.size.height)),
                    .float(Float(state.time.truncatingRemainder(dividingBy: 3600))),
                    .float(Float(state.bootProgress)),
                    .float(state.isBoot ? 1 : 0),
                    .float(Float(state.connected)),
                    .float(Float(state.sinceConnect)),
                    .float(Float(state.progressFill))))
        }
    }
}

final class MoonlightLGTouchBarLiveModel: ObservableObject {
    @Published var state = SmokeAccretionState(time: 0)
    @Published var saturation: Double = 1
}

struct MoonlightLGTouchBarLiveView: View {
    @ObservedObject var model: MoonlightLGTouchBarLiveModel

    var body: some View {
        SmokeAccretionStripScene(state: model.state)
            .saturation(model.saturation)
            .accessibilityHidden(true)
    }
}

// MARK: - Full app-area Touch Bar decoration

/// Decorative artwork across the existing 30-point command row. The owning
/// coordinator controls presentation eligibility; this view never presents a
/// Touch Bar, changes its controls or handles input. There is no animation work
/// in the library, during streaming, or after its owner suspends/detaches it.
final class MoonlightLGTouchBarStripView: NSView {
    private(set) var state: MoonlightLGTouchBarArt.State = .idle
    private(set) var presentationActive = false
    var isAnimating: Bool { timer != nil }
    var sceneSnapshot: SmokeAccretionState { model.state }
    var sceneSaturation: Double { model.saturation }
    var connectionStartedAt: CFTimeInterval? { connectedAt }

    private let imageLayer = CALayer()
    private let model = MoonlightLGTouchBarLiveModel()
    private var hostingView: NSHostingView<MoonlightLGTouchBarLiveView>?
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private let clock: () -> CFTimeInterval
    private let motionReduced: () -> Bool
    private let rendersLiveContent: Bool
    private var clockStart: CFTimeInterval
    private var stateStart: CFTimeInterval
    private var connectedAt: CFTimeInterval?
    private var bootDuration: TimeInterval = 3.8
    private var configured = false
    private var liveWasVisible = false
    private var updatingLive = false

    override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, clock: CACurrentMediaTime,
                  reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    }

    /// Inject only the clock/motion source for deterministic lifecycle tests.
    /// `rendersLiveContent: false` tests the scheduling policy without a GPU.
    init(frame frameRect: NSRect, clock: @escaping () -> CFTimeInterval,
         reduceMotion: @escaping () -> Bool, rendersLiveContent: Bool = true) {
        self.clock = clock; motionReduced = reduceMotion
        self.rendersLiveContent = rendersLiveContent
        let initialTime = clock()
        clockStart = initialTime; stateStart = initialTime
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        clock = CACurrentMediaTime
        motionReduced = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        rendersLiveContent = true
        let initialTime = CACurrentMediaTime()
        clockStart = initialTime; stateStart = initialTime
        super.init(coder: coder)
        setUp()
    }

    deinit {
        timer?.invalidate()
        for (center, observer) in observers { center.removeObserver(observer) }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping (MoonlightLGTouchBarStripView) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            if let self { action(self) }
        }
        observers.append((center, token))
    }

    private func setUp() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 6; layer?.masksToBounds = true
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.masksToBounds = true
        layer?.addSublayer(imageLayer)
        setAccessibilityElement(false)
        observe(NSWorkspace.shared.notificationCenter,
                NSWorkspace.accessibilityDisplayOptionsDidChangeNotification) { $0.refreshPresentation() }
        observe(.default, MoonlightLGTouchBarArt.configurationChanged) { $0.refreshPresentation() }
        // The existing Touch Bar coordinator is the single authority for app
        // and owning-window focus. A hosting window can have different AppKit
        // activation semantics; never override the parent's eligibility here.
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification] {
            observe(.default, name) { $0.refreshPresentation() }
        }
        for name in [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification] {
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, let changed = note.object as? NSView,
                      changed === self || self.isDescendant(of: changed) else { return }
                self.refreshPresentation()
            }
            observers.append((.default, token))
        }
        configured = true
        updateStillImage(animated: false)
    }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 30) }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        if configured { refreshPresentation() }
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refreshPresentation() }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); refreshPresentation() }
    override func viewDidHide() { super.viewDidHide(); refreshPresentation() }
    override func viewDidUnhide() { super.viewDidUnhide(); refreshPresentation() }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateStillImage(animated: false)
    }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        CATransaction.commit()
        hostingView?.frame = bounds
        refreshPresentation()
    }

    /// Called by the existing coordinator on focus, close, handoff and detach.
    /// Becoming active never transfers ownership from a streaming window.
    func setPresentationActive(_ active: Bool) {
        presentationActive = active
        refreshPresentation()
    }

    /// Re-evaluate after clipping/visibility or an accessibility preference change.
    func refreshPresentation() {
        guard configured else { return }
        updateLive()
    }

    /// Transfer the presentation to an independent host without replaying boot
    /// or the connected shockwave. Each host retains its own view and renderer.
    func adoptScene(from other: MoonlightLGTouchBarStripView) {
        let now = clock(), oldNow = other.clock()
        clockStart = now - max(0, oldNow - other.clockStart)
        stateStart = now - max(0, oldNow - other.stateStart)
        connectedAt = other.connectedAt.map { now - max(0, oldNow - $0) }
        state = other.state; bootDuration = other.bootDuration
        model.state = other.model.state; model.saturation = other.model.saturation
        updateStillImage(animated: false); refreshPresentation()
    }

    /// Called once for the current boot, using the screen's start date if known.
    func playBoot(duration: TimeInterval = 3.8, startedAt: Date? = nil) {
        bootDuration = max(duration, 0.1)
        stateStart = clock() - max(0, startedAt.map { Date().timeIntervalSince($0) } ?? 0)
        connectedAt = nil; state = .booting
        updateStillImage(animated: false)
        updateLive()
    }

    /// Repeated connection updates preserve its clock and one-time shockwave.
    func show(_ newState: MoonlightLGTouchBarArt.State, animated: Bool = true) {
        let previous = state
        guard newState != previous else { refreshPresentation(); return }
        state = newState; stateStart = clock()
        if newState == .connected { connectedAt = stateStart }
        else if newState != .failed { connectedAt = nil }
        if newState == .failed {
            // Keep the last rendered frame. Repeated refreshes must not advance
            // a paused scene, even when metadata or other controls change.
            model.saturation = 0.25
        } else { model.saturation = 1 }
        updateStillImage(animated: animated)
        updateLive()
    }

    private var visibleToOwner: Bool {
        // The DFR hosting window may be offscreen by design. Its isVisible
        // flag is not the owning app window's visibility; the coordinator
        // supplies that eligibility through presentationActive.
        presentationActive && window != nil && !isHiddenOrHasHiddenAncestor && !visibleRect.isEmpty
            && bounds.width > 0 && bounds.height > 0
    }
    private var wantsLive: Bool {
        visibleToOwner && MoonlightLGTouchBarArt.liveAnimationEnabled && !motionReduced() && state != .idle
    }

    private func updateStillImage(animated: Bool) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        if animated && visibleToOwner && !motionReduced() {
            let fade = CATransition(); fade.type = .fade; fade.duration = 0.35
            imageLayer.add(fade, forKey: "stateFade")
        }
        imageLayer.contents = MoonlightLGTouchBarArt.strip(for: state)?.layerContents(forContentsScale: scale)
        imageLayer.contentsScale = scale
        imageLayer.opacity = state == .failed ? 0.45 : 1
        // No persistent CALayer breathing animation: only the visible live scene
        // animates, and Reduce Motion must stop all animation immediately.
    }

    private func clearLiveContent() {
        liveWasVisible = false
        stopTimer()
        let oldHost = hostingView; hostingView = nil
        oldHost?.removeFromSuperview()
        imageLayer.removeAllAnimations()
    }

    private func updateLive() {
        // NSHostingView initialization/layout can synchronously post AppKit
        // frame notifications before the hostingView assignment completes.
        // Never construct another renderer from those reentrant callbacks.
        guard !updatingLive else { return }
        updatingLive = true
        defer { updatingLive = false }
        guard wantsLive else { clearLiveContent(); return }
        if !liveWasVisible && state != .failed { advanceScene() }
        guard wantsLive else { clearLiveContent(); return }
        liveWasVisible = true
        if rendersLiveContent && hostingView == nil {
            let view = NSHostingView(rootView: MoonlightLGTouchBarLiveView(model: model))
            view.frame = bounds; view.autoresizingMask = [.width, .height]
            hostingView = view
            addSubview(view)
        }
        // Eligibility can change synchronously while the renderer attaches.
        guard wantsLive else { clearLiveContent(); return }
        if state == .failed { stopTimer() }
        else { startTimer() }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let next = Timer(timeInterval: 1 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(next, forMode: .common); timer = next
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }
    private func tick() {
        guard wantsLive && state != .failed else { updateLive(); return }
        advanceScene()
    }
    private func advanceScene() {
        let now = clock(), elapsed = max(0, now - clockStart)
        var scene = SmokeAccretionState(time: elapsed)
        scene.progressFill = (elapsed * 0.3).truncatingRemainder(dividingBy: 1)
        switch state {
        case .booting:
            let since = max(0, now - stateStart)
            scene.time = since; scene.isBoot = true
            scene.bootProgress = min(since / bootDuration, 1)
            model.state = scene
            if scene.bootProgress >= 1 { show(.idle); return }
        case .connected:
            if let connectedAt {
                let since = max(0, now - connectedAt)
                scene.sinceConnect = since
                let t = min(1, since / 1.2)
                scene.connected = t * t * t * (t * (t * 6 - 15) + 10)
            }
        case .idle, .connecting, .failed: break
        }
        model.state = scene
    }
}
