import AppKit
import Combine

@MainActor final class NativeStatusMenu: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var open: (() -> Void)?
    var settings: (() -> Void)?
    private let crescent: NSImage?
    private let fullMoon: NSImage?
    private var windowObservation: AnyCancellable?

    init(resourceURL: URL? = Bundle.main.resourceURL) {
        func load(_ name: String) -> NSImage? {
            guard let url = resourceURL?.appendingPathComponent(name), let image = NSImage(contentsOf: url) else { return nil }
            image.size = NSSize(width: 18, height: 18)
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
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "Quit Moonlight Native Glass", action: #selector(quitFromMenu), keyEquivalent: "")
            quit.target = self; menu.addItem(quit)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else { open?() }
    }
    @objc private func openFromMenu() { open?() }
    @objc private func settingsFromMenu() { settings?() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }
}

