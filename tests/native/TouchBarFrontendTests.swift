import AppKit
import SwiftUI

@main struct TouchBarFrontendTests {
    @MainActor static func main() {
        // Reproduce the shipped startup trap without depending on the runner's
        // Foundation version: shared suite creation is allowed to return nil.
        var suiteCalls = 0
        let unavailableSuite: (String) -> UserDefaults? = { name in
            suiteCalls += 1
            precondition(name == NativeTouchBarPresentation.applications[0])
            return nil
        }
        let frontendPrefs = NativeTouchBarPresentation.preferenceStore(
            bundleIdentifier: NativeTouchBarPresentation.applications[0], suite: unavailableSuite)
        precondition(frontendPrefs === UserDefaults.standard && suiteCalls == 0,
                     "Frontend must reuse its existing standard preferences")
        let hostedPrefs = NativeTouchBarPresentation.preferenceStore(
            bundleIdentifier: NativeTouchBarPresentation.applications[1], suite: unavailableSuite)
        precondition(hostedPrefs == nil && suiteCalls == 1)
        precondition(!NativeTouchBarPresentation.enabled(in: hostedPrefs),
                     "Unavailable frontend preferences must safely keep normal width")
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
        _ = bar.item(forIdentifier: .init("native.commandRow"))
        let button = owner.buttons["apollo.continue"]!
        button.performClick(nil); precondition(presses == 0 && !button.isEnabled)
        var connected = disabled; connected.enabled = true
        owner.update([connected], crimson: true)
        precondition(window.touchBar === bar, "State updates must preserve the current bar and its focus")
        button.performClick(nil); precondition(presses == 1)
        let iconPoint = NSPoint(x: button.frame.minX + 12, y: button.frame.minY + 15)
        precondition(button.hitTest(iconPoint) === button, "The template glyph must forward icon taps to the nonblocking native button")
        precondition(button.image != nil && button.contentTintColor != nil, "Use native symbols and Crimson Glass tint")
        precondition(button.frame.width == 150 && button.frame.height == 30)
        // Reproduce the two-line status and narrow labels from the owner's
        // physical M1 bar at its actual 30-point height, not a regular cell.
        let status = NativeTouchBarCommand("library.status", "Th3D3ck3r-R7\nReady to stream · 4 games", "moon.fill", width: 178, enabled: false)
        let labels: [(String, String, CGFloat)] = [("", "chevron.left", 36), ("", "chevron.right", 36), ("Refresh", "arrow.clockwise", 82), ("Select a game", "play.fill", 126), ("Add", "plus", 58), ("Settings", "gearshape", 86)]
        var scrollPresses = 0
        owner.update([status] + labels.enumerated().map { index, value in
            NativeTouchBarCommand("layout.\(index)", value.0, value.1, width: value.2) { scrollPresses += 1 }
        }, crimson: true, artState: .idle)
        let folder = URL(fileURLWithPath: "build/touchbar-previews")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = window.touchBar!.item(forIdentifier: .init("native.commandRow"))
        for command in owner.commands {
            let view = owner.buttons[command.id] as! NativeTouchBarButton
            let originalFrame = view.frame
            view.frame = NSRect(x: 0, y: 0, width: command.width, height: 30)
            precondition(view.labelRects.allSatisfy { view.bounds.contains($0) }, "All status lines must fit inside the physical bar height")
            if !command.title.contains("\n") {
                let textWidth = (command.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold)]).width
                precondition(textWidth <= view.labelRects[0].width, "\(command.title) needs \(textWidth) points, has \(view.labelRects[0].width): static labels must fit without truncation")
            }
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("touchbar-\(command.id).png"))
            view.frame = originalFrame
        }
        let row = owner.row!
        precondition(owner.strip != nil && row.strip === owner.strip && owner.strip?.state == .idle && owner.strip?.isAnimating == false,
                     "Library keeps the full-bar still artwork without a live renderer")
        let originalStrip = owner.strip
        owner.update(owner.commands, crimson: true, artState: .connecting)
        precondition(originalStrip != nil && originalStrip?.superview === row,
                     "Artwork belongs to the full command row, never the status button")
        for width in [CGFloat(685), 400, 1085] {
            row.frame = NSRect(x: 0, y: 0, width: width, height: 30)
            precondition(originalStrip?.frame == row.bounds, "Artwork must span every allocated physical width")
            precondition(originalStrip?.hitTest(NSPoint(x: width / 2, y: 15)) == nil,
                         "Whole-bar artwork must never intercept native actions")
        }
        owner.update(owner.commands, crimson: true, artState: .connecting)
        precondition(owner.strip === originalStrip && owner.strip?.state == .connecting,
                     "Connection updates must reuse the artwork and existing command row")
        owner.update(owner.commands, crimson: true, artState: .connected)
        let connectedAt = owner.strip?.connectionStartedAt
        owner.update(owner.commands, crimson: true, artState: .connected)
        precondition(owner.strip?.connectionStartedAt == connectedAt,
                     "Metadata updates must not replay the connect shockwave")
        owner.update(owner.commands, crimson: true, artState: .idle)
        precondition(row.strip === originalStrip && originalStrip?.isAnimating == false,
                     "Returning to library must stop the live surface and reuse still artwork")
        owner.update(owner.commands, crimson: true)
        precondition(row.strip == nil && originalStrip?.superview == nil,
                     "Removing artwork ownership must fully detach the row-wide surface")
        var previousEnd: CGFloat = -6
        for (control, _) in row.controls {
            precondition(control.frame.minX >= previousEnd + 6, "Scrollable controls must retain distinct non-overlapping document frames")
            previousEnd = control.frame.maxX
        }
        for width in [CGFloat(685), 400, 1085] {
            row.frame = NSRect(x: 0, y: 0, width: width, height: 30)
            let bitmap = row.bitmapImageRepForCachingDisplay(in: row.bounds)!
            row.cacheDisplay(in: row.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("touchbar-library-row-\(Int(width)).png"))
            precondition(row.status!.frame.maxY <= 30 && row.scroll.frame.maxX <= width, "Pinned host and scroll viewport fit real bar bounds")
            if width == 400 {
                precondition(!row.more.isHidden, "Narrow layouts must expose scrollable controls")
                row.scrollMore()
                precondition(row.scroll.contentView.bounds.origin.x > 0, "More control must reveal offscreen actions")
                row.scrollMore(); row.scrollMore()
            }
            if width == 1085 { precondition(row.more.isHidden && row.status!.frame.width == 178, "Full width restores the balanced host width") }
        }
        row.frame = NSRect(x: 0, y: 0, width: 400, height: 30)
        window.contentView!.addSubview(row)
        let scrollButton = owner.buttons["layout.2"] as! NativeTouchBarButton
        func pointer(_ kind: NSEvent.EventType) -> NSEvent {
            let point = scrollButton.convert(NSPoint(x: scrollButton.bounds.midX, y: scrollButton.bounds.midY), to: nil)
            return NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        }
        scrollButton.mouseDown(with: pointer(.leftMouseDown))
        row.scrollMore()
        scrollButton.mouseUp(with: pointer(.leftMouseUp))
        precondition(scrollPresses == 0, "Scrolling must cancel a pending action instead of treating release as a tap")
        scrollButton.mouseDown(with: pointer(.leftMouseDown))
        row.scroll.contentView.scroll(to: .zero)
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: row.scroll.contentView)
        scrollButton.mouseUp(with: pointer(.leftMouseUp))
        precondition(scrollPresses == 0, "Gesture-driven clip scrolling must cancel pending actions too")
        owner.update(owner.commands, crimson: false)
        precondition(row.more.contentTintColor == nil && row.more.bezelColor == nil, "Overflow navigation must respect disabling Crimson Glass")
        row.removeFromSuperview()
        owner.detach(); precondition(window.touchBar === previous)
        precondition(originalStrip?.isAnimating == false && originalStrip?.superview == nil,
                     "Detach must remove artwork and all animation work")
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
        prefs.set(["hadDictionary": true, NativeTouchBarPresentation.applications[0]: ["present": true, "value": "fullControlStrip"]], forKey: NativeTouchBarPresentation.backupKey)
        agent.set(["example.other": "functionKeys", NativeTouchBarPresentation.applications[0]: "app"], forKey: "PresentationModePerApp")
        precondition(!NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent, available: false))
        precondition(agent.dictionary(forKey: "PresentationModePerApp")?[NativeTouchBarPresentation.applications[0]] as? String == "fullControlStrip", "Unsupported full width must still restore legacy overrides")
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
        // AppKit may synchronously emit notifications inside presentation.
        var reentrant: NativeTouchBarPresentation.Session!
        var showCount = 0, hideCount = 0
        reentrant = NativeTouchBarPresentation.Session(show: { value in
            showCount += 1; reentrant.update(value, enabled: true, eligible: true); return true
        }, hide: { _ in hideCount += 1; reentrant.update(nil, enabled: false, eligible: false) })
        reentrant.update(bar, enabled: true, eligible: true)
        reentrant.update(nil, enabled: false, eligible: false)
        precondition(showCount == 1 && hideCount == 1 && reentrant.presented == nil)
        var interrupted: NativeTouchBarPresentation.Session!
        interrupted = NativeTouchBarPresentation.Session(show: { value in
            interrupted.update(nil, enabled: false, eligible: false); return true
        }, hide: { _ in })
        interrupted.update(bar, enabled: true, eligible: true)
        precondition(interrupted.presented == nil, "Focus loss during show must not leave stale ownership")
        prefs.set(true, forKey: NativeTouchBarPresentation.key)
        precondition(!NativeTouchBarPresentation.apply(true, preferences: prefs, agent: agent, available: false))
        precondition(!prefs.bool(forKey: NativeTouchBarPresentation.key), "Unsupported persisted ON must be cleared")
        reentrant = nil; interrupted = nil
        window.close()
        print("PASS: frontend Touch Bar actions, physical layout, full-width focus lifetime, unsupported fallback and legacy preference recovery")
    }
}
