import AppKit
import Combine
import ScreenCaptureKit

@MainActor final class NativeStatusMenu: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var open: (() -> Void)?
    var settings: (() -> Void)?
    var controls: (() -> Void)?
    var library: (() -> Void)?
    var perform: ((Int) -> Void)?
    var state = NativeMenuState() {
        didSet {
            if state.token != oldValue.token || !state.exists { dismissPreview(); cacheTask?.cancel(); cachedThumbnail = nil }
            if streaming && state.exists && state.visible && (!oldValue.visible || oldValue.windowNumber == 0 && state.windowNumber != 0) { cacheVisibleThumbnail() }
            if let activeMenu { refreshMenu(activeMenu) }
        }
    }
    var thumbnailProvider: (UInt32) async -> NSImage? = { id in
        guard id != 0, CGPreflightScreenCaptureAccess() else { return nil }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let window = content.windows.first(where: { $0.windowID == id }) else { return nil }
            let config = SCStreamConfiguration()
            config.width = 640
            config.height = max(1, Int(640 * window.frame.height / max(1, window.frame.width)))
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        } catch { return nil }
    }
    private var stateObservation: AnyCancellable?
    private var startedObservation: AnyCancellable?
    private var streaming = false
    private var cacheTask: Task<Void, Never>?
    private var activeMenu: NSMenu?
    private var hoverTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var cachedThumbnail: NSImage?
    private var tracking: NSTrackingArea?
    private(set) var previewPanel: NSPanel?
    private var hovering = false
    private var previewGeneration = UUID()
    var captureAllowed: () -> Bool = { CGPreflightScreenCaptureAccess() }
    private(set) var previewUnavailable = false
    var hoverDelay: Duration = .milliseconds(1500)
    private let crescent: NSImage?
    private let fullMoon: NSImage?
    private var windowObservation: AnyCancellable?

    init(resourceURL: URL? = Bundle.main.resourceURL) {
        func load(_ name: String) -> NSImage? {
            guard let url = resourceURL?.appendingPathComponent(name), let source = NSImage(contentsOf: url) else { return nil }
            let size = NSSize(width: 18, height: 18)
            // Dock icons receive macOS's rounded mask. Status items render the
            // raw resource, so clip both cached states to the same rounded shape.
            let image = NSImage(size: size, flipped: false) { bounds in
                NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).addClip()
                source.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
                return true
            }
            image.isTemplate = false
            return image
        }
        crescent = load("moonlight.icns")
        fullMoon = load("full-moon.png")
        super.init()
        updateWindowState(false)
        item.button?.setAccessibilityIdentifier("native-status-item")
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        if let button = item.button {
            let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
            button.addTrackingArea(area); tracking = area
        }
    }
    func bind(to windowState: Published<Bool>.Publisher) {
        windowObservation = windowState.removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] exists in
            self?.updateWindowState(exists)
        }
    }
    private func updateWindowState(_ exists: Bool) {
        item.button?.image = exists ? (fullMoon ?? crescent) : crescent
        let state = exists ? "stream window open" : "no stream window"
        item.button?.setAccessibilityLabel("Moonlight Native Glass — " + state)
        item.button?.toolTip = nil
        item.button?.setAccessibilityHelp("Click to restore the stream window or open the library. Right-click for stream actions and settings.")
    }
    func bindStarted(to publisher: Published<Bool>.Publisher) {
        startedObservation = publisher.removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] started in
            self?.streaming = started
            if started { self?.cacheVisibleThumbnail() }
        }
    }
    private func cacheVisibleThumbnail() {
        cacheTask?.cancel()
        guard state.exists, state.visible, state.windowNumber != 0, CGPreflightScreenCaptureAccess() else { return }
        let token = state.token
        cacheTask = Task { [weak self] in
            // One snapshot at startup/restore supplies a hidden-window fallback. No live
            // capture loop, decoder hooks or background frame subscription.
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled, let self, state.exists, state.token == token, state.visible else { return }
            let image = await thumbnailProvider(state.windowNumber)
            if !Task.isCancelled, state.exists, state.token == token, let image { cachedThumbnail = image }
        }
    }
    func bindState(to publisher: Published<NativeMenuState>.Publisher) {
        stateObservation = publisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.state = $0 }
    }
    @objc func mouseEntered(with event: NSEvent) { beginHover() }
    @objc func mouseExited(with event: NSEvent) { endHover() }
    func beginHover() {
        hovering = true; closeTask?.cancel(); hoverTask?.cancel()
        guard state.exists else { return }
        perform?(210)
        let token = state.token, generation = UUID()
        previewGeneration = generation
        hoverTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: hoverDelay)
            guard !Task.isCancelled, hovering, state.exists, state.token == token else { return }
            // Show the cached image or a useful restore target at the promised
            // delay, even if ScreenCaptureKit is slow, denied or has no window.
            previewUnavailable = cachedThumbnail == nil
            showThumbnail(cachedThumbnail ?? unavailableThumbnail())
            let image = await thumbnailProvider(state.windowNumber)
            guard !Task.isCancelled, hovering, state.exists, state.token == token, previewGeneration == generation else { return }
            if let image { cachedThumbnail = image; previewUnavailable = false; showThumbnail(image) }
        }
    }
    func endHover() {
        hovering = false; hoverTask?.cancel()
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, !hovering else { return }
            dismissPreview()
        }
    }
    func dismissPreview() {
        previewGeneration = UUID(); hoverTask?.cancel(); closeTask?.cancel()
        previewPanel?.orderOut(nil); previewPanel = nil
    }
    private func unavailableThumbnail() -> NSImage {
        let message = captureAllowed() ? "Preview unavailable" : "Allow Screen Recording for previews"
        return NSImage(size: NSSize(width: 280, height: 158), flipped: false) { rect in
            NSColor.windowBackgroundColor.setFill(); rect.fill()
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            (message as NSString).draw(in: NSRect(x: 12, y: 70, width: 256, height: 36), withAttributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
            ("Click to restore stream" as NSString).draw(in: NSRect(x: 12, y: 42, width: 256, height: 22), withAttributes: [
                .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph])
            return true
        }
    }
    private func showThumbnail(_ image: NSImage) {
        guard let button = item.button, let window = button.window else { return }
        let width: CGFloat = 280, height = max(80, min(240, width * image.size.height / max(1, image.size.width)))
        let panel = ThumbnailPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.hidesOnDeactivate = false; panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let view = ThumbnailView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.image = image; view.imageScaling = .scaleProportionallyUpOrDown
        view.wantsLayer = true; view.layer?.cornerRadius = 10; view.layer?.masksToBounds = true
        view.setAccessibilityElement(true); view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("Restore stream window")
        view.entered = { [weak self] in self?.hovering = true; self?.closeTask?.cancel() }
        view.exited = { [weak self] in self?.endHover() }
        let token = state.token
        view.clicked = { [weak self] in
            guard let self, state.exists, state.token == token else { return }
            dismissPreview(); open?()
        }
        panel.contentView = view
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchor
        panel.setFrameOrigin(NSPoint(x: max(screen.minX, min(anchor.midX - width / 2, screen.maxX - width)), y: anchor.minY - height - 6))
        previewPanel?.orderOut(nil); previewPanel = panel; panel.orderFrontRegardless()
    }
    func makeMenu() -> NSMenu {
        let menu = NSMenu(); menu.autoenablesItems = false
        func entry(_ title: String, _ tag: Int, _ enabled: Bool = true) {
            let item = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: "")
            item.target = self; item.tag = tag; item.isEnabled = enabled; menu.addItem(item)
        }
        entry(state.visible ? "Hide Stream Window" : "Restore Stream Window", 200, state.exists)
        entry("Open Library", -1)
        entry(state.controls ? "Hide Stream Controls" : "Show Stream Controls", 100, state.exists)
        entry(state.captured ? "Release Input" : "Capture Input", state.captured ? 202 : 201, state.exists)
        entry(state.statistics ? "Hide Statistics" : "Show Statistics", state.statistics ? 208 : 203, state.exists)
        let modes = NSMenu(); modes.autoenablesItems = false
        for (index, title) in ["Windowed", "Full Screen", "Borderless Full Screen"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: "")
            item.target = self; item.tag = 204 + index; item.state = state.nextMode == index && state.exists ? .on : .off
            item.isEnabled = state.exists; modes.addItem(item)
        }
        let mode = NSMenuItem(title: "Window Mode (Next Stream)", action: nil, keyEquivalent: ""); mode.submenu = modes; mode.isEnabled = state.exists; menu.addItem(mode)
        entry(state.muted ? "Unmute Stream Audio" : "Mute Stream Audio", 207, state.exists)
        menu.addItem(.separator())
        entry("Disconnect", 212, state.exists)
        entry("Disconnect and Exit Host Game…", 209, state.exists)
        menu.addItem(.separator())
        // Keep this row present while permissions change, so an open menu's
        // item positions and tags never shift under the pointer.
        entry(CGPreflightScreenCaptureAccess() ? "Screen Recording Settings…" : "Allow Stream Thumbnails…", -5)
        entry("Settings…", -2); entry("Open Engine Logs", -3); entry("About Moonlight Native Glass", -4)
        menu.addItem(.separator()); entry("Quit Moonlight Native Glass", -6)
        return menu
    }
    private func refreshMenu(_ menu: NSMenu) {
        let fresh = makeMenu()
        for (item, updated) in zip(menu.items, fresh.items) {
            guard !item.isSeparatorItem else { continue }
            item.title = updated.title; item.tag = updated.tag; item.isEnabled = updated.isEnabled
            if let submenu = item.submenu {
                for mode in submenu.items { mode.isEnabled = state.exists; mode.state = state.exists && mode.tag == 204 + state.nextMode ? .on : .off }
            }
        }
    }
    @objc private func clicked() {
        dismissPreview()
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            guard let button = item.button else { return }
            perform?(210)
            let menu = makeMenu(); activeMenu = menu
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            activeMenu = nil
        } else { open?() }
    }
    @objc func menuAction(_ sender: NSMenuItem) {
        let tag = sender.tag
        switch tag {
        case -1: library?()
        case -2: settings?()
        case -3:
            try? FileManager.default.createDirectory(at: nativeEngineLogDirectory(), withIntermediateDirectories: true)
            NSWorkspace.shared.open(nativeEngineLogDirectory())
        case -4: about?()
        case -5:
            if CGPreflightScreenCaptureAccess() || !CGRequestScreenCaptureAccess(), let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            cacheVisibleThumbnail()
        case -6: NSApp.terminate(nil)
        case 200: if state.exists { if state.visible { perform?(200) } else { open?() } }
        case 209:
            guard state.exists else { return }
            let token = state.token
            let alert = NSAlert(); alert.messageText = "Disconnect and exit the host game?"
            alert.informativeText = "This closes the game on the host computer. Unsaved progress may be lost."
            alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Disconnect and Exit")
            if alert.runModal() == .alertSecondButtonReturn && state.exists && state.token == token { perform?(209) }
        default: if state.exists { perform?(tag) }
        }
    }
    var about: (() -> Void)?
}

@MainActor private final class ThumbnailPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor private final class ThumbnailView: NSImageView {
    var entered: (() -> Void)?
    var exited: (() -> Void)?
    var clicked: (() -> Void)?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { entered?() }
    override func mouseExited(with event: NSEvent) { exited?() }
    override func mouseUp(with event: NSEvent) { clicked?() }
    override func accessibilityPerformPress() -> Bool { clicked?(); return true }
}
