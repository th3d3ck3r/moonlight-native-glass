import AppKit
import Combine

@MainActor final class NativeStatusMenu: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var open: (() -> Void)?
    var settings: (() -> Void)?
    var controls: (() -> Void)?
    var library: (() -> Void)?
    var perform: ((Int) -> Void)?
    var state = NativeMenuState() {
        didSet {
            if let activeMenu { refreshMenu(activeMenu) }
        }
    }
    private var stateObservation: AnyCancellable?
    private var activeMenu: NSMenu?
    private var restoreInputAfterMenu = true
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
    func bindState(to publisher: Published<NativeMenuState>.Publisher) {
        stateObservation = publisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.state = $0 }
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
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            guard let button = item.button else { return }
            restoreInputAfterMenu = true
            perform?(213)
            let menu = makeMenu(); activeMenu = menu
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            activeMenu = nil
            perform?(restoreInputAfterMenu ? 214 : 215)
        } else { open?() }
    }
    @objc func menuAction(_ sender: NSMenuItem) {
        let tag = sender.tag
        if tag < 0 { restoreInputAfterMenu = false }
        switch tag {
        case -1: library?()
        case -2: settings?()
        case -3:
            try? FileManager.default.createDirectory(at: nativeEngineLogDirectory(), withIntermediateDirectories: true)
            NSWorkspace.shared.open(nativeEngineLogDirectory())
        case -4: about?()
        case -6: NSApp.terminate(nil)
        case 200: if state.exists { if state.visible { perform?(200) } else { open?() } }
        case 209:
            guard state.exists else { return }
            let token = state.token
            perform?(213)
            let alert = NSAlert(); alert.messageText = "Disconnect and exit the host game?"
            alert.informativeText = "This closes the game on the host computer. Unsaved progress may be lost."
            alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Disconnect and Exit")
            let confirmed = alert.runModal() == .alertSecondButtonReturn
            if state.exists && state.token == token {
                perform?(confirmed ? 209 : 214)
            }
        default: if state.exists { perform?(tag) }
        }
    }
    var about: (() -> Void)?
}
