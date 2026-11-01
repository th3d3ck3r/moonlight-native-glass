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
        precondition(bar.principalItemIdentifier == nil,
                     "The library/Apollo canvas must fill its app region, not request physical-bar centering")
        _ = bar.item(forIdentifier: .init("native.commandRow"))
        let button = owner.buttons["apollo.continue"]!
        button.performClick(nil); precondition(presses == 0 && !button.isEnabled)
        var connected = disabled; connected.enabled = true
        owner.update([connected], crimson: true)
        precondition(window.touchBar === bar, "State updates must preserve the current bar and its focus")
        button.performClick(nil); precondition(presses == 1)
        let compactContinue = NativeTouchBarCommand("apollo.continue", "Continue", "play.fill", width: 104,
            accessibilityTitle: "Continue to Stream") { presses += 1 }
        owner.update([compactContinue], crimson: true)
        precondition(button.title == "Continue" && button.accessibilityLabel() == "Continue to Stream" && button.toolTip == "Continue to Stream",
                     "Deliberate short labels retain the full accessible meaning")
        owner.update([connected], crimson: true)
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
                     "An inactive library keeps its backdrop without scheduling animation")
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
                     "An inactive library must reuse the surface without scheduling frames")
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
        exerciseFlexibleAllocation()
        exerciseClippedHost()
        exerciseModalPresentation()
        window.close()
        print("PASS: frontend Touch Bar actions, physical layout, full-width focus lifetime, unsupported fallback and legacy preference recovery")
    }
    @MainActor private static func exerciseFlexibleAllocation() {
        let window = NSWindow(contentRect: NSRect(x: 20, y: 50, width: 1085, height: 30),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let status = NativeTouchBarButton(title: "Th3D3ck3r-R7\nReady to stream", target: nil, action: nil)
        status.statusOnly = true
        let labels: [(String, CGFloat)] = [("Back", 50), ("Next", 50), ("Refresh", 82), ("Select game", 104), ("Add", 58), ("Settings", 86)]
        let row = NativeTouchBarRow(buttons: [(status, 178)] + labels.map {
            (NativeTouchBarButton(title: $0.0, target: nil, action: nil) as NSButton, $0.1)
        }, pinnedStatus: true)
        let strip = MoonlightLGTouchBarStripView(frame: .zero,
            clock: { 100 }, reduceMotion: { false }, rendersLiveContent: false)
        row.installStrip(strip)
        precondition(row.intrinsicContentSize.width == NSView.noIntrinsicMetric,
                     "NSTouchBar must classify the home canvas as flexible rather than content-sized")
        let system = NSView(); system.translatesAutoresizingMaskIntoConstraints = false
        let reservation = system.widthAnchor.constraint(equalToConstant: 240)
        reservation.isActive = true
        system.heightAnchor.constraint(equalToConstant: 30).isActive = true
        system.setContentHuggingPriority(.required, for: .horizontal)
        system.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = NSStackView(views: [row, system])
        stack.orientation = .horizontal; stack.distribution = .fill
        stack.spacing = 0; stack.alignment = .centerY; stack.detachesHiddenViews = true
        window.contentView = stack; window.orderFront(nil)
        defer { row.removeStrip(); window.close() }
        let folder = URL(fileURLWithPath: "build/touchbar-previews")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Let actual Auto Layout allocate the flexible row. There is no row
        // width constraint and no direct row.frame assignment in this fixture.
        for (index, reserved) in [CGFloat(0), 240, 350, 500, 240, 0].enumerated() {
            system.isHidden = reserved == 0; reservation.constant = max(1, reserved)
            stack.needsLayout = true; stack.layoutSubtreeIfNeeded(); row.layoutControls()
            let available = stack.bounds.width - reserved
            precondition(abs(row.frame.width - available) < 1,
                         "Home row \(row.frame.width) must fill \(available) points with \(reserved) reserved by the system Control Strip")
            precondition(abs(row.layoutViewport.width - available) < 1 && strip.frame == row.layoutViewport,
                         "The artwork and controls must follow the allocated canvas on every resize")
            precondition(row.layoutViewport.contains(row.scroll.frame) && row.layoutViewport.contains(row.status!.frame))
            let end = max(0, row.document.frame.width - row.scroll.contentView.bounds.width)
            for (control, _) in row.controls {
                row.scroll.contentView.scroll(to: NSPoint(x: min(end, control.frame.minX), y: 0))
                precondition(row.scroll.contentView.bounds.contains(control.frame), "Every command stays fully reachable")
            }
            row.scroll.contentView.scroll(to: .zero)
            let bitmap = row.bitmapImageRepForCachingDisplay(in: row.bounds)!
            row.cacheDisplay(in: row.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("touchbar-home-system-allocation-\(index).png"))
        }
        print("PASS: flexible home row consumes full allocation as the Control Strip appears, expands and disappears")
    }

    @MainActor private static func exerciseClippedHost() {
        let window = NSWindow(contentRect: NSRect(x: 20, y: 50, width: 800, height: 120),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSClipView(frame: NSRect(x: 0, y: 0, width: 685, height: 30))
        window.contentView!.addSubview(host)
        let status = NativeTouchBarButton(title: "Th3D3ck3r-R7\nOffline · 4 games", target: nil, action: nil)
        status.statusOnly = true
        let widths: [CGFloat] = [36, 36, 82, 126, 58, 86]
        let controls = widths.enumerated().map { index, width in
            (NativeTouchBarButton(title: "Action \(index)", target: nil, action: nil) as NSButton, width)
        }
        let row = NativeTouchBarRow(buttons: [(status as NSButton, CGFloat(178))] + controls, pinnedStatus: true)
        let strip = MoonlightLGTouchBarStripView(frame: .zero,
            clock: { 100 }, reduceMotion: { false }, rendersLiveContent: false)
        row.installStrip(strip)
        host.documentView = row
        window.orderFront(nil)
        defer { row.removeStrip(); window.close() }
        precondition(!row.constraints.contains { $0.firstAttribute == .width && $0.relation == .equal && $0.constant == 1085 },
                     "The app must never demand the physical maximum width from a normal bar")
        precondition(row.contentCompressionResistancePriority(for: .horizontal).rawValue < 250,
                     "AppKit must be allowed to compress the row instead of omitting its only item")
        // Reproduce the physical photograph: a wide document exists, but the
        // host clips it to the real app allocation beside the Control Strip.
        for width in [CGFloat(685), 400, 800] {
            host.frame.size.width = width
            row.frame = NSRect(x: 0, y: 0, width: 1085, height: 30)
            host.scroll(to: .zero)
            row.layoutControls()
            precondition(abs(row.visibleRect.width - width) < 0.1, "Fixture must really clip the oversized row")
            precondition(abs(row.layoutViewport.width - width) < 0.1,
                         "Layout must use host clipping bounds, not the stale 1085-point frame")
            precondition(strip.frame == row.layoutViewport && abs(strip.frame.midX - width / 2) < 0.1,
                         "The moon must stay centered in the visible app region")
            precondition(row.layoutViewport.contains(row.status!.frame) && row.layoutViewport.contains(row.scroll.frame),
                         "Pinned status and every controls viewport must remain inside the visible bar")
            if !row.more.isHidden { precondition(row.layoutViewport.contains(row.more.frame)) }
            if width == 400 {
                precondition(!row.more.isHidden, "A clipped normal bar must expose its overflow navigation")
                row.scrollMore()
                precondition(row.scroll.contentView.bounds.origin.x > 0)
            } else {
                let needsScrolling = row.document.frame.width > row.scroll.contentView.bounds.width
                precondition(row.more.isHidden != needsScrolling,
                             "The moon gap may require scrolling; overflow must always expose that navigation")
                precondition(row.scroll.frame.minX >= width / 2 + 48,
                             "The ordinary physical allocation must keep the authored central moon clear")
            }
            precondition(row.controls.allSatisfy { $0.1 <= row.scroll.contentView.bounds.width },
                         "Every full touch target must fit the scroll viewport even on a narrow bar")
            // A gesture can fully expose every command; an offscreen control
            // is never permanently lost behind the system strip.
            let end = max(0, row.document.frame.width - row.scroll.contentView.bounds.width)
            for (control, _) in row.controls {
                row.scroll.contentView.scroll(to: NSPoint(x: min(end, control.frame.minX), y: 0))
                precondition(row.scroll.contentView.bounds.contains(control.frame),
                             "Every retained command must be reachable through the clipped scroll viewport")
            }
        }
        print("PASS: oversized 1085-point row inside real 400/685/800-point hosts keeps artwork, controls and overflow in bounds")
    }

    @MainActor private static func exerciseModalPresentation() {
        let window = NSWindow(contentRect: NSRect(x: 20, y: 50, width: 800, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let original = NSTouchBar(); window.touchBar = original
        var enabled = false, eligible = true, ready = true, allowShow = true
        var loseFocusDuringShow = false, detachDuringShow = false
        var shows = 0, hides = 0, failures = 0, actions = 0, validations = 0
        var presented: NSTouchBar?
        var owner: NativeTouchBarAccessory.Coordinator!
        let session = NativeTouchBarPresentation.Session(show: { candidate in
            shows += 1
            precondition(candidate !== window.touchBar, "System-modal presentation must not reuse the window-owned bar")
            precondition(candidate.principalItemIdentifier == nil,
                         "The independent full-width canvas must also avoid principal-item centering")
            let item = candidate.item(forIdentifier: .init("native.commandRow")) as? NSCustomTouchBarItem
            precondition(item?.view != nil && item?.view === owner.modalSurface?.row,
                         "Modal controls must be fully materialized before entering the presentation API")
            precondition(item?.visibilityPriority == .high, "The only command item must not be discarded as low priority")
            if loseFocusDuringShow {
                loseFocusDuringShow = false; eligible = false; owner.requestPresentation()
            }
            if allowShow { presented = candidate }
            if detachDuringShow { detachDuringShow = false; owner.detach() }
            return allowShow
        }, hide: { candidate in
            precondition(presented === candidate, "Dismiss only the owned modal bar")
            hides += 1; presented = nil
        })
        owner = NativeTouchBarAccessory.Coordinator(presentation: session,
            fullWidthEnabled: { enabled }, ownerEligible: { _ in eligible },
            contentReady: { candidate, row in
                validations += 1
                precondition(candidate === owner.modalSurface?.bar && row === owner.modalSurface?.row)
                return ready
            }, fullWidthFailed: { failures += 1 })
        func pump(_ seconds: TimeInterval = 0.05) {
            let end = Date().addingTimeInterval(seconds)
            while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
        }
        func waitFor(_ message: String, _ condition: () -> Bool) {
            let end = Date().addingTimeInterval(2)
            while !condition() && Date() < end { pump(0.01) }
            precondition(condition(), message)
        }
        var command = NativeTouchBarCommand("apollo.continue", "Continue", "play.fill", width: 150) { actions += 1 }
        let status = NativeTouchBarCommand("apollo.status", "Th3D3ck3r-R7\nReady", "moon.fill", width: 200, enabled: false)
        owner.update([status, command], crimson: true, artState: .idle)
        owner.attach(window)
        let normal = owner.bar!
        precondition(normal.principalItemIdentifier == nil,
                     "Normal fallback must preserve edge-to-edge allocation beside the Control Strip")
        _ = normal.item(forIdentifier: .init("native.commandRow"))
        let normalRow = owner.row!, normalStrip = owner.strip!, normalButton = owner.buttons[command.id]!
        pump()
        precondition(shows == 0 && window.touchBar === normal, "Full width is off until explicitly enabled")
        normalButton.performClick(nil); precondition(actions == 1)
        enabled = true; owner.requestPresentation()
        waitFor("Enabling must prepare and present the independent modal surface") { shows == 1 && session.presented != nil }
        let firstSurface = owner.modalSurface!, firstModal = firstSurface.bar!, firstButton = firstSurface.buttons[command.id]!
        precondition(window.touchBar === normal && firstModal !== normal,
                     "The ordinary bar must remain installed as an immediate fallback")
        precondition(firstSurface.row !== normalRow && firstSurface.strip !== normalStrip && firstButton !== normalButton,
                     "Normal and modal presentation must never share an AppKit view or live renderer")
        precondition(normal.item(forIdentifier: .init("native.commandRow")) !== firstModal.item(forIdentifier: .init("native.commandRow")))
        normalButton.performClick(nil); precondition(actions == 1, "Inactive normal controls cannot trigger during modal presentation")
        firstButton.performClick(nil); precondition(actions == 2, "The current modal control must retain the real action")
        for _ in 0..<5 { owner.refreshPresentation() }
        precondition(shows == 1, "Metadata/focus refreshes must not repeatedly present a system-modal bar")
        waitFor("The accepted surface must receive one bounded content check") { validations == 1 }
        command.title = "Opening…"; command.enabled = false
        owner.update([status, command], crimson: true, artState: .idle); pump()
        precondition(normalButton.title == command.title && firstButton.title == command.title && !firstButton.isEnabled,
                     "Both independent surfaces must receive state and enabled-state changes")
        firstButton.performClick(nil); precondition(actions == 2)
        eligible = false; owner.requestPresentation()
        waitFor("Focus loss must dismiss the modal presentation") { session.presented == nil && owner.modalSurface == nil }
        precondition(window.touchBar === normal && owner.row === normalRow && hides == 1)
        firstButton.performClick(nil); precondition(actions == 2, "Retired modal controls must lose their action targets")
        eligible = true; command.enabled = true
        owner.update([status, command], crimson: true, artState: .idle)
        waitFor("Focus regain must create a fresh, independent modal surface") { shows == 2 && session.presented != nil }
        precondition(owner.modalSurface !== firstSurface && session.presented !== firstModal)
        enabled = false; owner.requestPresentation()
        waitFor("Disabling must restore normal presentation") { session.presented == nil }
        precondition(window.touchBar === normal && owner.modalSurface == nil && failures == 0)

        // A selector can exist even when AppKit gives it no usable content.
        // Keep the preference logically ON in this injected failure callback to
        // prove the rejection latch also prevents repeated blackouts by itself.
        ready = false; enabled = true; owner.requestPresentation()
        waitFor("Unusable modal content must be dismissed and reported") { failures == 1 }
        precondition(session.presented == nil && owner.modalSurface == nil && window.touchBar === normal)
        let rejectedShows = shows
        for _ in 0..<5 { owner.refreshPresentation() }; pump(0.35)
        precondition(shows == rejectedShows && failures == 1, "A rejected full-width surface must not retry on every state update")
        enabled = false; owner.refreshPresentation(); ready = true
        enabled = true; owner.requestPresentation()
        waitFor("A new explicit toggle may retry after restoring normal mode") { shows == rejectedShows + 1 && session.presented != nil }
        enabled = false; owner.requestPresentation(); waitFor("Disable accepted retry") { session.presented == nil }

        // Synchronous AppKit focus notifications must be deferred until the
        // currently constructing/presenting surface has returned.
        eligible = true; loseFocusDuringShow = true; enabled = true; owner.requestPresentation()
        let beforeReentrant = shows
        waitFor("Focus loss during show must unwind to the normal bar") { shows > beforeReentrant && session.presented == nil }
        precondition(window.touchBar === normal && owner.modalSurface == nil)
        eligible = true; enabled = false; owner.refreshPresentation()
        allowShow = false; enabled = true; owner.requestPresentation()
        let priorFailures = failures
        waitFor("A refused API presentation must fall back without dismissing an unowned bar") { failures == priorFailures + 1 }
        precondition(session.presented == nil && window.touchBar === normal)
        enabled = false; owner.refreshPresentation(); allowShow = true; enabled = true
        owner.requestPresentation(); waitFor("Prepare final presentation before detach") { session.presented != nil }
        owner.detach(); pump(0.4)
        precondition(session.presented == nil && window.touchBar === original && owner.modalSurface == nil,
                     "Detach must cancel delayed acceptance work and restore the previous window bar")
        // Close/handoff can occur synchronously inside the system call. It
        // must dismiss ownership without reporting a capability failure or
        // rewriting the user's saved full-width option.
        let beforeClose = shows, failuresBeforeClose = failures
        detachDuringShow = true
        owner.attach(window); owner.requestPresentation()
        waitFor("Detach inside presentation must unwind without a false failure") {
            shows > beforeClose && session.presented == nil && window.touchBar === original
        }
        precondition(failures == failuresBeforeClose && owner.modalSurface == nil)
        owner = nil; window.close()
        print("PASS: independent full-width hosts, prepared controls, routing/state sync, focus/reentry, refusal/blank fallback, retry latch and teardown")
    }

}
