import AppKit
import SwiftUI

@main struct TouchBarFrontendTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let previous = NSTouchBar(); window.touchBar = previous
        let owner = NativeTouchBarAccessory.Coordinator()
        var presses = 0
        let disabled = NativeTouchBarCommand("apollo.continue", "Continue to Stream", "play.fill", width: 150,
                                            enabled: false) { presses += 1 }
        owner.update([disabled], crimson: true); owner.attach(window)
        let bar = window.touchBar!
        precondition(bar !== previous)
        let item = bar.item(forIdentifier: NSTouchBarItem.Identifier("apollo.continue")) as! NSCustomTouchBarItem
        let button = item.view as! NSButton
        button.performClick(nil); precondition(presses == 0 && !button.isEnabled)
        var connected = disabled; connected.enabled = true
        owner.update([connected], crimson: true)
        precondition(window.touchBar === bar, "State updates must preserve the current bar and its focus")
        button.performClick(nil); precondition(presses == 1)
        precondition(button.image != nil && button.contentTintColor != nil, "Use native symbols and Crimson Glass tint")
        precondition(button.constraints.contains { $0.firstAttribute == .width && $0.constant == 150 })
        owner.detach(); precondition(window.touchBar === previous)
        button.performClick(nil); precondition(presses == 1, "Detached controls must not invoke an old connection")
        owner.update([connected], crimson: true); owner.attach(window)
        let engineBar = NSTouchBar(); window.touchBar = engineBar
        owner.detach(); precondition(window.touchBar === engineBar, "Frontend cleanup must not remove the stream's bar")
        for _ in 0..<20 { owner.attach(window); owner.detach(); precondition(window.touchBar === engineBar) }
        window.close()
        print("PASS: frontend Touch Bar action gating, state updates, symbols and responder ownership")
    }
}
