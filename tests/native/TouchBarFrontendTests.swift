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
        let agentName = "MoonlightLG.TouchBarTests.Agent.\(UUID().uuidString)"
        let prefsName = "MoonlightLG.TouchBarTests.Prefs.\(UUID().uuidString)"
        let agent = UserDefaults(suiteName: agentName)!, prefs = UserDefaults(suiteName: prefsName)!
        defer { agent.removePersistentDomain(forName: agentName); prefs.removePersistentDomain(forName: prefsName) }
        let originalModes = ["example.other": "functionKeys", NativeTouchBarPresentation.applications[0]: "fullControlStrip"]
        agent.set(originalModes, forKey: "PresentationModePerApp")
        agent.set("appWithControlStrip", forKey: "PresentationModeGlobal")
        agent.set(["appWithControlStrip": "fullControlStrip"], forKey: "PresentationModeFnModes")
        precondition(NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent))
        var modes = agent.dictionary(forKey: "PresentationModePerApp")!
        precondition(modes["example.other"] as? String == "functionKeys")
        for app in NativeTouchBarPresentation.applications { precondition(modes[app] as? String == "app") }
        precondition(agent.string(forKey: "PresentationModeGlobal") == "appWithControlStrip")
        precondition(agent.dictionary(forKey: "PresentationModeFnModes") as? [String: String] == ["appWithControlStrip": "fullControlStrip"])
        precondition(NativeTouchBarPresentation.apply(false, preferences: prefs, agent: agent))
        precondition(agent.dictionary(forKey: "PresentationModePerApp") as? [String: String] == originalModes)
        precondition(!prefs.bool(forKey: NativeTouchBarPresentation.key) && prefs.object(forKey: NativeTouchBarPresentation.backupKey) == nil)
        precondition(NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent))
        modes = agent.dictionary(forKey: "PresentationModePerApp")!
        modes["example.addedLater"] = "fullControlStrip"
        modes[NativeTouchBarPresentation.applications[1]] = "functionKeys"
        agent.set(modes, forKey: "PresentationModePerApp")
        precondition(NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent, reapply: true))
        precondition(NativeTouchBarPresentation.apply(false, preferences: prefs, agent: agent))
        modes = agent.dictionary(forKey: "PresentationModePerApp")!
        precondition(modes["example.addedLater"] as? String == "fullControlStrip")
        precondition(modes[NativeTouchBarPresentation.applications[1]] as? String == "functionKeys", "Respect a later manual change")
        precondition(modes[NativeTouchBarPresentation.applications[0]] as? String == "fullControlStrip")
        agent.set("unexpected format", forKey: "PresentationModePerApp")
        precondition(!NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent), "Do not overwrite unknown system preference formats")
        window.close()
        print("PASS: frontend Touch Bar actions, ownership and reversible app-only full-width preferences")
    }
}
