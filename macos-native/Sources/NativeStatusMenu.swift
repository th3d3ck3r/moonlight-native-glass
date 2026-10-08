import AppKit
import Combine

@MainActor final class NativeStatusMenu: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var open: (() -> Void)?
    var settings: (() -> Void)?
    var controls: (() -> Void)?
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
        item.button?.toolTip = "Moonlight: " + state + ". Click to restore the stream window or open Moonlight. Right-click for Settings and Quit."
    }
    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            guard let button = item.button else { return }
            let menu = NSMenu()
            for (title, action) in [("Open Moonlight or Stream", #selector(openFromMenu)),
                                    ("Settings…", #selector(settingsFromMenu))] {
                let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
                entry.target = self; menu.addItem(entry)
            }
            let controlsItem = NSMenuItem(title: "Show / Hide Stream Controls", action: #selector(controlsFromMenu), keyEquivalent: "")
            controlsItem.target = self; controlsItem.isEnabled = controls != nil; menu.addItem(controlsItem)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "Quit Moonlight Native Glass", action: #selector(quitFromMenu), keyEquivalent: "")
            quit.target = self; menu.addItem(quit)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else { open?() }
    }
    @objc private func openFromMenu() { open?() }
    @objc private func settingsFromMenu() { settings?() }
    @objc private func controlsFromMenu() { controls?() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }
}

