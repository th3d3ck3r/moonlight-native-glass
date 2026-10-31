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
        // Reproduce the two-line status and narrow labels from the owner's
        // physical M1 bar at its actual 30-point height, not a regular cell.
        let status = NativeTouchBarCommand("library.status", "Th3D3ck3r-R7\nReady to stream · 4 games", "moon.fill", width: 178, enabled: false)
        let labels: [(String, String, CGFloat)] = [("Refresh", "arrow.clockwise", 82), ("Add", "plus", 58), ("Settings", "gearshape", 86)]
        owner.update([status] + labels.enumerated().map { index, value in
            NativeTouchBarCommand("layout.\(index)", value.0, value.1, width: value.2) {}
        }, crimson: true)
        let folder = URL(fileURLWithPath: "build/touchbar-previews")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for command in owner.commands {
            let item = window.touchBar!.item(forIdentifier: .init(command.id)) as! NSCustomTouchBarItem
            let view = item.view as! NativeTouchBarButton
            view.frame = NSRect(x: 0, y: 0, width: command.width, height: 30)
            precondition(view.labelRects.allSatisfy { view.bounds.contains($0) }, "All status lines must fit inside the physical bar height")
            if !command.title.contains("\n") {
                let textWidth = (command.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold)]).width
                precondition(textWidth <= view.labelRects[0].width, "\(command.title) needs \(textWidth) points, has \(view.labelRects[0].width): static labels must fit without truncation")
            }
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("touchbar-\(command.id).png"))
        }
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
        precondition(NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent, available: true))
        precondition(agent.dictionary(forKey: "PresentationModePerApp") as? [String: String] == originalModes, "New full width must not edit the Touch Bar agent")
        precondition(agent.string(forKey: "PresentationModeGlobal") == "appWithControlStrip")
        precondition(agent.dictionary(forKey: "PresentationModeFnModes") as? [String: String] == ["appWithControlStrip": "fullControlStrip"])
        precondition(NativeTouchBarPresentation.apply(false, preferences: prefs, agent: agent))
        precondition(!prefs.bool(forKey: NativeTouchBarPresentation.key))
        // Migrate build 43's saved overrides; leave a later user edit alone.
        prefs.set(["hadDictionary": true,
                   NativeTouchBarPresentation.applications[0]: ["present": true, "value": "fullControlStrip"],
                   NativeTouchBarPresentation.applications[1]: ["present": false]], forKey: NativeTouchBarPresentation.backupKey)
        agent.set(["example.other": "functionKeys", NativeTouchBarPresentation.applications[0]: "app",
                   NativeTouchBarPresentation.applications[1]: "functionKeys"], forKey: "PresentationModePerApp")
        precondition(NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent, available: true))
        let modes = agent.dictionary(forKey: "PresentationModePerApp")!
        precondition(modes[NativeTouchBarPresentation.applications[0]] as? String == "fullControlStrip")
        precondition(modes[NativeTouchBarPresentation.applications[1]] as? String == "functionKeys")
        precondition(modes["example.other"] as? String == "functionKeys" && prefs.object(forKey: NativeTouchBarPresentation.backupKey) == nil)
        precondition(NativeTouchBarPresentation.apply(false, preferences: prefs, agent: agent))
        precondition(!NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent, available: false))
        precondition(!prefs.bool(forKey: NativeTouchBarPresentation.key), "Unsupported full width must not claim to be enabled")
        var shown: [NSTouchBar] = [], hidden: [NSTouchBar] = []
        let session = NativeTouchBarPresentation.Session(show: { shown.append($0); return true }, hide: { hidden.append($0) })
        session.update(bar, enabled: false, eligible: true); precondition(shown.isEmpty)
        session.update(bar, enabled: true, eligible: true); precondition(shown.count == 1 && session.presented === bar)
        session.update(bar, enabled: true, eligible: true); precondition(shown.count == 1, "Do not repeatedly steal the bar")
        session.update(bar, enabled: true, eligible: false); precondition(hidden.count == 1 && session.presented == nil, "Restore on app/window focus loss")
        session.update(engineBar, enabled: true, eligible: true)
        session.update(engineBar, enabled: false, eligible: true); precondition(hidden.last === engineBar)
        let unavailable = NativeTouchBarPresentation.Session(show: { _ in false }, hide: { _ in preconditionFailure("Never dismiss an unowned bar") })
        unavailable.update(bar, enabled: true, eligible: true); precondition(unavailable.presented == nil)
        unavailable.update(nil, enabled: false, eligible: false)
        window.close()
        print("PASS: frontend Touch Bar actions, physical layout, full-width focus lifetime, unsupported fallback and legacy preference recovery")
    }
}
