import AppKit
import SwiftUI
import ObjectiveC.runtime

// Connection screen: "Smoke accretion".
// The cratered moon sits inside a spinning crimson smoke accretion disk while a
// liquid progress ring sweeps around it. On connect, a gravitational shockwave
// rolls outward, the disk spins up and brightens, and the ring closes.
// Rendered by SmokeAccretion.metal through SmokeAccretionScene.
// The status panel, buttons and accessibility identifiers are unchanged.
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
    @State private var frozenAt: Date?
    private var accent: Color { crimson ? NativeCrimsonTheme.highlight : Color(red: 0.4, green: 0.8, blue: 1) }
    private var ready: Bool { journey.phase == .connected || journey.phase == .entering }
    /// Seconds for the scene to ease into its connected state.
    private static let connectEase = 1.2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MoonlightLG").font(.headline).tracking(0.8)
                Spacer()
                Text("APOLLO RENDEZVOUS").font(.caption).tracking(2).foregroundStyle(.secondary)
            }.padding(.horizontal, 28).padding(.top, 24)
            TimelineView(.animation(minimumInterval: 1 / 60,
                paused: reduceMotion || journey.phase == .failed || previewTime != nil)) { timeline in
                let sceneDate = previewTime != nil ? startedAt : frozenAt ?? timeline.date
                let time = reduceMotion ? 8 : previewTime ?? max(0, sceneDate.timeIntervalSince(startedAt))
                let since: Double? = journey.connectedAt.map {
                    reduceMotion ? 60 : max(0, sceneDate.timeIntervalSince($0))
                }
                SmokeAccretionScene(state: SmokeAccretionState(
                    time: time,
                    connected: since.map { smoother($0 / Self.connectEase) } ?? 0,
                    sinceConnect: since ?? 0,
                    progressFill: reduceMotion ? 0.65 : fract(time * 0.3)))
                .saturation(journey.phase == .failed ? 0.25 : 1)
                .accessibilityElement()
                .accessibilityLabel(ready ? "The moon inside a spinning crimson smoke disk. Connected."
                                          : "The moon inside a spinning crimson smoke disk. Connecting.")
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
        ], crimson: crimson, artState: journey.phase == .failed ? .failed : ready ? .connected : .connecting).frame(width: 0, height: 0))
        .onAppear { if journey.phase == .failed { frozenAt = Date() } }
        .onChange(of: journey.phase) { _, phase in
            // A paused TimelineView can still rebuild for status/Touch Bar
            // changes. Keep failure at one fixed scene date through those updates.
            frozenAt = phase == .failed ? Date() : nil
        }
        .onChange(of: journey.id) { _, _ in
            startedAt = Date()
            frozenAt = journey.phase == .failed ? startedAt : nil
        }
    }

    private func smoother(_ value: Double) -> Double {
        let p = min(1, max(0, value)); return p * p * p * (p * (6 * p - 15) + 10)
    }
    private func fract(_ value: Double) -> Double { value - floor(value) }
}

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
    static let failedKey = "touchBarFullWidthUnavailable"
    static let backupKey = "touchBarPresentationBackup"
    static let applications = ["com.moonlight-stream.NativeGlass", "com.moonlight-stream.NativeGlass.Engine"]
    static let agentDomain = "com.apple.touchbar.agent"
    // The frontend already owns this domain. Opening it again as a suite can
    // return nil (observed on macOS 27.2); never force-unwrap preference access
    // while attaching the first window. The engine-hosted view must not fall
    // back to its own standard domain if the frontend suite is unavailable.
    static func preferenceStore(bundleIdentifier: String? = Bundle.main.bundleIdentifier,
                                suite: (String) -> UserDefaults? = { UserDefaults(suiteName: $0) }) -> UserDefaults? {
        if bundleIdentifier == applications[0] { return .standard }
        return suite(applications[0])
    }
    static var sharedPreferences: UserDefaults? { preferenceStore() }
    static func enabled(in preferences: UserDefaults? = sharedPreferences) -> Bool {
        guard let preferences else { return false }
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
    static func restoreAfterFailedPresentation() {
        // The connection scene can run inside the engine process. Write only
        // the frontend's shared option, never the engine's standard domain.
        guard let preferences = sharedPreferences else { return }
        preferences.set(false, forKey: key); preferences.set(true, forKey: failedKey)
        preferences.synchronize()
        NotificationCenter.default.post(name: changed, object: nil)
        DistributedNotificationCenter.default().postNotificationName(changed, object: nil, userInfo: nil, deliverImmediately: true)
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
        let recoveredLegacy = restoreLegacy(preferences: preferences, agent: agent)
        if enabled && !available {
            preferences.set(false, forKey: key); preferences.synchronize()
            NotificationCenter.default.post(name: changed, object: nil)
            return false
        }
        guard recoveredLegacy else { return false }
        preferences.removeObject(forKey: failedKey)
        preferences.set(enabled, forKey: key); preferences.synchronize()
        NotificationCenter.default.post(name: changed, object: nil)
        DistributedNotificationCenter.default().postNotificationName(changed, object: nil, userInfo: nil, deliverImmediately: true)
        return true
    }
}
// A fixed 30-point canvas avoids the larger NSButtonCell font/insets applied
// by the physical Touch Bar. Keep NSButton actions/accessibility and the same
// nonblocking event handling used by Apollo; only presentation is custom.
private final class NativeTouchBarGlyphView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class NativeTouchBarButton: ConnectionActionButton {
    var statusOnly = false
    var artworkBehind = false
    private var templateImageView: NSImageView?
    var templateGlyph: NSImage? {
        didSet {
            if templateGlyph != nil && templateImageView == nil {
                let view = NativeTouchBarGlyphView(); view.imageScaling = .scaleProportionallyDown
                view.setAccessibilityElement(false); addSubview(view); templateImageView = view
            }
            templateImageView?.image = templateGlyph
            layoutArt()
        }
    }
    private func layoutArt() {
        templateImageView?.frame = NSRect(x: title.isEmpty ? (bounds.width - 18) / 2 : 7, y: 6, width: 18, height: 18)
        templateImageView?.isHidden = templateGlyph == nil
    }
    override func setFrameSize(_ size: NSSize) { super.setFrameSize(size); layoutArt() }
    private var pressOrigin = NSPoint.zero
    override func mouseDown(with event: NSEvent) { pressOrigin = event.locationInWindow; super.mouseDown(with: event) }
    override func mouseDragged(with event: NSEvent) {
        if hypot(event.locationInWindow.x - pressOrigin.x, event.locationInWindow.y - pressOrigin.y) > 5 { cancelPress() }
        super.mouseDragged(with: event)
    }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
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
        let base = bezelColor ?? NSColor(white: 0.13, alpha: 1)
        let background = artworkBehind ? NSColor.black.withAlphaComponent(statusOnly ? 0.28 : 0.58) : base
        (cell?.isHighlighted == true ? background.blended(withFraction: 0.2, of: .white)! : background).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        let opacity: CGFloat = isEnabled || statusOnly ? 1 : 0.4
        if let image, templateGlyph == nil {
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
            let drawn = lines[row]
            (drawn as NSString).draw(in: rect, withAttributes: [
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
    private(set) var strip: MoonlightLGTouchBarStripView?
    var statusWidth: CGFloat = 0
    private var scrollObserver: NSObjectProtocol?
    private var geometryObservers: [NSObjectProtocol] = []
    private(set) var layoutViewport = NSRect.zero
    private var layingOut = false
    var controls: [(NSButton, CGFloat)] = []
    override var intrinsicContentSize: NSSize {
        NSSize(width: max(320, statusWidth + (status == nil ? 0 : 6) + document.frame.width), height: 30)
    }
    init(buttons: [(NSButton, CGFloat)], pinnedStatus: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 30))
        identifier = .init("TouchBarCommandRow")
        scroll.drawsBackground = false; scroll.contentView.drawsBackground = false; scroll.borderType = .noBorder
        scroll.hasVerticalScroller = false; scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .allowed; scroll.verticalScrollElasticity = .none
        scroll.documentView = document; addSubview(scroll)
        more.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        more.bezelColor = NSColor(srgbRed: 0.12, green: 0.035, blue: 0.055, alpha: 1)
        more.contentTintColor = NSColor(srgbRed: 0.95, green: 0.19, blue: 0.32, alpha: 1)
        more.target = self; more.action = #selector(scrollMore)
        more.setAccessibilityLabel("Scroll to more Touch Bar controls; tap again at the end to return")
        more.toolTip = "Swipe controls or tap for more"; addSubview(more)
        scroll.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in self?.cancelPendingPresses(); self?.updateOverflowHint() }
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
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.init(rawValue: 50), for: .horizontal)
        setContentCompressionResistancePriority(.init(rawValue: 50), for: .horizontal)
        // Never request a physical bar width. AppKit owns the allocation and
        // reserves space for the Control Strip and system modal close button.
        for name in [NSView.frameDidChangeNotification, NSView.boundsDidChangeNotification] {
            geometryObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, let view = note.object as? NSView,
                      view !== self, self.isDescendant(of: view) else { return }
                self.layoutControls()
            })
        }
        setFrameSize(frame.size)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    /// One decoration spans the entire allocated item, behind the existing
    /// nonblocking controls. Keep the moon's centre open by docking actions right.
    func installStrip(_ view: MoonlightLGTouchBarStripView) {
        if strip !== view { removeStrip(); strip = view; addSubview(view, positioned: .below, relativeTo: nil) }
        view.frame = bounds
        for button in ([status].compactMap { $0 } + controls.map { $0.0 } + [more]) {
            (button as? NativeTouchBarButton)?.artworkBehind = true
            button.needsDisplay = true
        }
        invalidateIntrinsicContentSize()
        setFrameSize(frame.size)
    }
    func removeStrip() {
        strip?.setPresentationActive(false); strip?.removeFromSuperview(); strip = nil
        for button in ([status].compactMap { $0 } + controls.map { $0.0 } + [more]) {
            (button as? NativeTouchBarButton)?.artworkBehind = false
            button.needsDisplay = true
        }
        invalidateIntrinsicContentSize()
        setFrameSize(frame.size)
    }
    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        layoutControls()
    }
    override func layout() { super.layout(); layoutControls() }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); layoutControls() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); layoutControls() }
    func layoutControls() {
        guard !layingOut else { return }
        layingOut = true
        defer { layingOut = false }
        let clipped = visibleRect.intersection(bounds)
        let area = !clipped.isEmpty ? clipped : bounds
        layoutViewport = NSRect(x: area.minX, y: bounds.minY, width: area.width, height: 30)
        let width = layoutViewport.width, origin = layoutViewport.minX
        strip?.frame = layoutViewport
        let pinned = status == nil ? 0 : min(statusWidth, max(100, width * (strip == nil ? 0.4 : 0.3)))
        if let status { status.frame = NSRect(x: origin, y: 0, width: pinned, height: 30) }
        let start = pinned + (status == nil ? 0 : 6)
        let available = max(0, width - start)
        let overflow = document.frame.width > available
        more.isHidden = !overflow
        more.frame = NSRect(x: origin + max(start, width - 30), y: 0, width: 30, height: 30)
        let viewport = max(0, available - (overflow ? 34 : 0))
        let controlWidth = strip == nil ? viewport : min(document.frame.width, viewport)
        scroll.frame = NSRect(x: origin + (strip == nil ? start : width - (overflow ? 34 : 0) - controlWidth),
                              y: 0, width: controlWidth, height: 30)
        let limit = max(0, document.frame.width - scroll.contentView.bounds.width)
        scroll.contentView.scroll(to: NSPoint(x: min(limit, scroll.contentView.bounds.origin.x), y: 0))
        scroll.reflectScrolledClipView(scroll.contentView)
        updateOverflowHint()
    }
    func setCrimson(_ enabled: Bool) {
        more.bezelColor = enabled ? NSColor(srgbRed: 0.12, green: 0.035, blue: 0.055, alpha: 1) : nil
        more.contentTintColor = enabled ? NSColor(srgbRed: 0.95, green: 0.19, blue: 0.32, alpha: 1) : nil
        more.needsDisplay = true
    }
    func updateOverflowHint() {
        let end = max(0, document.frame.width - scroll.contentView.bounds.width)
        let atEnd = end > 0 && scroll.contentView.bounds.origin.x >= end - 1
        more.image = NSImage(systemSymbolName: atEnd ? "chevron.left" : "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
        more.setAccessibilityLabel(atEnd ? "Return to first Touch Bar controls" : "Scroll to more Touch Bar controls")
        more.needsDisplay = true
    }
    func cancelPendingPresses() {
        for (button, _) in controls { (button as? ConnectionActionButton)?.cancelPress() }
        more.cancelPress()
    }
    @objc func scrollMore() {
        cancelPendingPresses()
        let clip = scroll.contentView
        let end = max(0, document.frame.width - clip.bounds.width)
        let next = clip.bounds.origin.x >= end - 1 ? 0 : min(end, clip.bounds.origin.x + max(100, clip.bounds.width * 0.75))
        clip.scroll(to: NSPoint(x: next, y: 0)); scroll.reflectScrolledClipView(clip)
    }
    deinit {
        if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
        for observer in geometryObservers { NotificationCenter.default.removeObserver(observer) }
        more.target = nil; more.action = nil
    }
}

struct NativeTouchBarAccessory: NSViewRepresentable {
    var commands: [NativeTouchBarCommand]
    var crimson = true
    var artState: MoonlightLGTouchBarArt.State? = nil
    var bootStartedAt: Date? = nil
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
        let presentation: NativeTouchBarPresentation.Session
        private let fullWidthEnabled: () -> Bool
        private let ownerEligible: (NSWindow) -> Bool
        private let contentReady: (NSTouchBar, NativeTouchBarRow) -> Bool
        private let fullWidthFailed: () -> Void
        private weak var surfaceOwner: Coordinator?
        private(set) var modalSurface: Coordinator?
        var observers: [NSObjectProtocol] = []
        var distributedObserver: NSObjectProtocol?
        var detaching = false
        var row: NativeTouchBarRow?
        var artState: MoonlightLGTouchBarArt.State?
        var bootStartedAt: Date?
        var strip: MoonlightLGTouchBarStripView?
        private var playingBoot: Date?
        private var bootPlayed = false
        private var generation = 0
        private var presentationPending = false
        private var validationWork: DispatchWorkItem?
        private var rejected = false

        init(presentation: NativeTouchBarPresentation.Session = .init(),
             fullWidthEnabled: @escaping () -> Bool = { !CommandLine.arguments.contains("--design-preview") && NativeTouchBarPresentation.enabled() },
             ownerEligible: @escaping (NSWindow) -> Bool = { $0.isKeyWindow && $0.isVisible && NSApp.isActive },
             contentReady: @escaping (NSTouchBar, NativeTouchBarRow) -> Bool = {
                 !$0.itemIdentifiers.isEmpty && $1.window != nil && !$1.visibleRect.isEmpty && $1.bounds.width > 0
             },
             fullWidthFailed: @escaping () -> Void = NativeTouchBarPresentation.restoreAfterFailedPresentation) {
            self.presentation = presentation; self.fullWidthEnabled = fullWidthEnabled
            self.ownerEligible = ownerEligible; self.contentReady = contentReady
            self.fullWidthFailed = fullWidthFailed
            super.init()
        }
        private func makeBar() -> NSTouchBar {
            let result = NSTouchBar(); result.delegate = self
            result.defaultItemIdentifiers = [.init("native.commandRow")]
            result.principalItemIdentifier = .init("native.commandRow")
            return result
        }
        func configureArt() {
            guard let row else { return }
            if artState == nil {
                row.removeStrip(); strip = nil; playingBoot = nil; bootPlayed = false
            } else if strip == nil {
                let view = MoonlightLGTouchBarStripView(frame: row.bounds)
                strip = view; row.installStrip(view)
            }
        }
        func refreshArt() {
            guard let strip, let artState else { return }
            if artState == .booting {
                if !bootPlayed || playingBoot != bootStartedAt {
                    bootPlayed = true; playingBoot = bootStartedAt
                    strip.playBoot(duration: 3.8, startedAt: bootStartedAt)
                }
            } else { playingBoot = nil; bootPlayed = false; strip.show(artState) }
        }
        private func updateContents() {
            for command in commands { if let button = buttons[command.id] { style(button, command) } }
            row?.setCrimson(crimson); configureArt(); refreshArt()
        }
        private func prepareModal() -> Coordinator? {
            if let modalSurface { return modalSurface }
            let surface = Coordinator()
            surface.surfaceOwner = self; surface.window = window
            surface.commands = commands; surface.crimson = crimson
            surface.artState = artState; surface.bootStartedAt = bootStartedAt
            surface.bar = surface.makeBar()
            // Complete item creation before invoking the system-modal API. Its
            // views are independent of the ordinary window-owned bar's views.
            guard surface.bar?.item(forIdentifier: .init("native.commandRow")) != nil,
                  surface.row != nil else { surface.detach(); return nil }
            if let original = strip { surface.strip?.adoptScene(from: original) }
            surface.bootPlayed = bootPlayed; surface.playingBoot = playingBoot
            modalSurface = surface
            return surface
        }
        private func releaseModal() {
            validationWork?.cancel(); validationWork = nil
            let old = modalSurface; modalSurface = nil
            old?.detach()
        }
        func requestPresentation() {
            guard surfaceOwner == nil, !presentationPending, !detaching else { return }
            presentationPending = true
            let expected = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == expected else { return }
                self.presentationPending = false; self.refreshPresentation()
            }
        }
        private var eligible: Bool {
            !detaching && window.map(ownerEligible) == true && window?.touchBar === bar && bar != nil
        }
        private func rejectModal() {
            rejected = true
            presentation.update(nil, enabled: false, eligible: false)
            releaseModal()
            strip?.setPresentationActive(eligible)
            fullWidthFailed()
        }
        func refreshPresentation() {
            guard surfaceOwner == nil else { return }
            let eligible = eligible, enabled = fullWidthEnabled()
            if !enabled { rejected = false }
            guard eligible && enabled && !rejected else {
                presentation.update(nil, enabled: false, eligible: false)
                releaseModal(); strip?.setPresentationActive(eligible)
                return
            }
            // Never present from makeItemForIdentifier or share an NSView
            // between normal and modal hosts. The normal bar remains installed
            // as the window's ownership anchor and immediate fallback.
            _ = bar?.item(forIdentifier: .init("native.commandRow"))
            guard let surface = prepareModal(), let candidate = surface.bar, let modalRow = surface.row else {
                rejectModal(); return
            }
            let wasPresented = presentation.presented === candidate
            presentation.update(candidate, enabled: true, eligible: true)
            guard presentation.presented === candidate else { rejectModal(); return }
            strip?.setPresentationActive(false)
            surface.strip?.setPresentationActive(true)
            if !wasPresented {
                let expected = generation
                let work = DispatchWorkItem { [weak self, weak candidate, weak modalRow] in
                    guard let self, let candidate, let modalRow,
                          self.generation == expected, self.eligible,
                          self.presentation.presented === candidate else { return }
                    // Structural acceptance is not a claim about physical OLED
                    // pixels. Missing/unhosted content must restore normal mode.
                    if !self.contentReady(candidate, modalRow) { self.rejectModal() }
                }
                validationWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            }
        }
        func attach(_ next: NSWindow?) {
            if window === next, bar != nil { return }
            detach()
            guard let next, !commands.isEmpty else { return }
            window = next; previous = next.touchBar
            let bar = makeBar(); self.bar = bar; next.touchBar = bar
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
                         NSWindow.didChangeOcclusionStateNotification, NSApplication.didBecomeActiveNotification,
                         NSApplication.didResignActiveNotification, NSApplication.didHideNotification,
                         NSApplication.didUnhideNotification, NativeTouchBarPresentation.changed] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.requestPresentation() })
            }
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: next, queue: .main) { [weak self] _ in self?.detach() })
            distributedObserver = DistributedNotificationCenter.default().addObserver(forName: NativeTouchBarPresentation.changed, object: nil, queue: .main) { [weak self] _ in self?.requestPresentation() }
            requestPresentation()
        }
        func detach() {
            detaching = true; generation += 1; presentationPending = false
            validationWork?.cancel(); validationWork = nil
            presentation.update(nil, enabled: false, eligible: false)
            releaseModal()
            strip?.setPresentationActive(false); row?.removeStrip()
            strip = nil; playingBoot = nil; bootPlayed = false
            if let distributedObserver { DistributedNotificationCenter.default().removeObserver(distributedObserver) }; distributedObserver = nil
            for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
            if let window, window.touchBar === bar { window.touchBar = previous }
            for button in buttons.values { button.target = nil; button.action = nil }
            buttons.removeAll(); row = nil; bar?.delegate = nil; bar = nil
            previous = nil; window = nil; rejected = false; detaching = false
        }
        func update(_ commands: [NativeTouchBarCommand], crimson: Bool,
                    artState: MoonlightLGTouchBarArt.State? = nil, bootStartedAt: Date? = nil) {
            self.artState = artState; self.bootStartedAt = bootStartedAt
            let identifiersChanged = self.commands.map(\.id) != commands.map(\.id)
            self.commands = commands; self.crimson = crimson
            if identifiersChanged { let current = window; detach(); attach(current) }
            updateContents()
            if let surface = modalSurface {
                surface.commands = commands; surface.crimson = crimson
                surface.artState = artState; surface.bootStartedAt = bootStartedAt
                surface.updateContents()
            }
            requestPresentation()
        }
        func style(_ button: NSButton, _ command: NativeTouchBarCommand) {
            button.title = command.title; button.isEnabled = command.enabled && command.action != nil
            button.image = NSImage(systemSymbolName: command.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
            let glyph: NSImage?
            switch command.id {
            case "library.status", "boot.status": glyph = MoonlightLGTouchBarArt.appGlyph
            case "apollo.status": glyph = MoonlightLGTouchBarArt.glyph(for: artState ?? .connecting)
            case "apollo.continue": glyph = MoonlightLGTouchBarArt.streamGlyph
            default: glyph = nil
            }
            (button as? NativeTouchBarButton)?.templateGlyph = glyph
            if let glyph { button.image = glyph }
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
            item.visibilityPriority = .high
            var views: [(NSButton, CGFloat)] = []
            for command in commands {
                let button = NativeTouchBarButton(title: command.title, target: self, action: #selector(press(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(command.id)
                style(button, command); buttons[command.id] = button; views.append((button, command.width))
            }
            let row = NativeTouchBarRow(buttons: views, pinnedStatus: commands.first?.action == nil)
            row.setCrimson(crimson); self.row = row; item.view = row
            configureArt(); refreshArt(); requestPresentation()
            return item
        }
        @objc func press(_ sender: NSButton) {
            guard sender.isEnabled, let id = sender.identifier?.rawValue, buttons[id] === sender,
                  let command = commands.first(where: { $0.id == id }), command.enabled else { return }
            if let owner = surfaceOwner {
                guard owner.eligible, owner.presentation.presented === bar else { return }
            } else {
                guard window?.touchBar === bar, presentation.presented == nil else { return }
            }
            command.action?()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> AccessoryView {
        let view = AccessoryView(); view.owner = context.coordinator
        context.coordinator.update(commands, crimson: crimson, artState: artState, bootStartedAt: bootStartedAt); return view
    }
    func updateNSView(_ view: AccessoryView, context: Context) {
        context.coordinator.update(commands, crimson: crimson, artState: artState, bootStartedAt: bootStartedAt); context.coordinator.attach(view.window)
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

