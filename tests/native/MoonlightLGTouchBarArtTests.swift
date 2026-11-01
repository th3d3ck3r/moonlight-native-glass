import AppKit
import QuartzCore

@main struct MoonlightLGTouchBarArtTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.finishLaunching()
        let window = NSWindow(contentRect: NSRect(x: 20, y: 40, width: 400, height: 140),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        func pump() {
            let deadline = Date().addingTimeInterval(0.05)
            while Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
        }
        func waitFor(_ description: String, _ condition: () -> Bool) {
            let deadline = Date().addingTimeInterval(2)
            while !condition() && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
            precondition(condition(), description)
        }
        waitFor("AppKit fixture must own an active key window") { NSApp.isActive && window.isKeyWindow }
        let oldEnabled = MoonlightLGTouchBarArt.liveAnimationEnabled
        defer { MoonlightLGTouchBarArt.liveAnimationEnabled = oldEnabled; window.close() }
        MoonlightLGTouchBarArt.liveAnimationEnabled = true
        // Run inside the fixture .app so the same asset lookup as production is
        // exercised. Missing assets must fail rather than quietly becoming nil.
        for state in [MoonlightLGTouchBarArt.State.idle, .booting, .connecting, .connected, .failed] {
            precondition(MoonlightLGTouchBarArt.strip(for: state) != nil, "Every state requires still artwork")
            precondition(MoonlightLGTouchBarArt.glyph(for: state) != nil, "Every state requires a glyph")
        }
        for glyph in [MoonlightLGTouchBarArt.appGlyph, MoonlightLGTouchBarArt.connectingGlyph,
                      MoonlightLGTouchBarArt.connectedGlyph, MoonlightLGTouchBarArt.streamGlyph] {
            precondition(glyph?.isTemplate == true, "Touch Bar glyphs must remain templates")
        }
        precondition(MoonlightLGTouchBarArt.appIconColor?.isTemplate == false, "The color app tile retains its colors")

        var now: CFTimeInterval = 100
        var reducedMotion = false
        let strip = MoonlightLGTouchBarStripView(frame: NSRect(x: 0, y: 0, width: 240, height: 30),
            clock: { now }, reduceMotion: { reducedMotion }, rendersLiveContent: false)
        window.contentView!.addSubview(strip)
        strip.setPresentationActive(true)
        precondition(strip.state == .idle && !strip.isAnimating, "Library artwork must not run a timer")
        precondition(strip.hitTest(NSPoint(x: 10, y: 10)) == nil, "Decoration must never intercept a control tap")
        strip.show(.connecting); pump()
        precondition(strip.isAnimating, "Visible connecting artwork must animate")
        now = 101
        waitFor("Registered timer must advance the injected clock; active=\(strip.presentationActive), timer=\(strip.isAnimating), attached=\(strip.window != nil), visible=\(strip.visibleRect), hidden=\(strip.isHiddenOrHasHiddenAncestor)") { strip.sceneSnapshot.time == 1 }
        strip.setFrameSize(NSSize(width: 72, height: 30)); strip.refreshPresentation(); pump()
        precondition(strip.isAnimating && strip.bounds.width == 72,
                     "Actual compact status-tile framing must preserve live scheduling")
        strip.show(.connected); pump()
        let connectedAt = strip.connectionStartedAt
        precondition(connectedAt == now)
        now = 101.7
        waitFor("Registered timer must advance the connected shockwave") { strip.sceneSnapshot.connected > 0 && strip.sceneSnapshot.connected < 1 }
        let phase = strip.sceneSnapshot.connected
        precondition(phase > 0 && phase < 1)
        strip.show(.connected); strip.refreshPresentation(); pump()
        precondition(strip.connectionStartedAt == connectedAt && strip.sceneSnapshot.connected == phase,
                     "Metadata refresh must not restart the connected shockwave")
        now = 102.3
        waitFor("Registered timer must finish connected easing") { strip.sceneSnapshot.connected == 1 }
        strip.show(.failed)
        let frozen = strip.sceneSnapshot
        precondition(!strip.isAnimating && strip.sceneSaturation == 0.25)
        now = 110; strip.show(.failed); strip.refreshPresentation(); pump()
        precondition(strip.sceneSnapshot.time == frozen.time && strip.sceneSnapshot.sinceConnect == frozen.sinceConnect,
                     "Failed artwork must freeze even when state notifications repeat")

        strip.show(.connecting); pump()
        precondition(strip.isAnimating && strip.connectionStartedAt == nil)
        strip.setPresentationActive(false)
        precondition(!strip.isAnimating, "Owning window focus loss must stop animation immediately")
        let suspended = strip.sceneSnapshot.time
        now = 112; pump()
        precondition(strip.sceneSnapshot.time == suspended)
        strip.setPresentationActive(true); pump(); precondition(strip.isAnimating)
        reducedMotion = true
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        pump(); precondition(!strip.isAnimating, "Reduce Motion changes must stop an existing timer")
        reducedMotion = false; strip.refreshPresentation(); pump(); precondition(strip.isAnimating)
        MoonlightLGTouchBarArt.liveAnimationEnabled = false
        pump(); precondition(!strip.isAnimating, "Runtime still-art fallback must stop existing live animation")
        MoonlightLGTouchBarArt.liveAnimationEnabled = true
        pump(); precondition(strip.isAnimating)

        strip.isHidden = true; strip.refreshPresentation()
        precondition(!strip.isAnimating, "Hidden artwork must not animate")
        strip.isHidden = false; strip.refreshPresentation(); pump(); precondition(strip.isAnimating)
        strip.frame.origin.x = 600; strip.refreshPresentation()
        precondition(!strip.isAnimating, "A fully clipped tile must not animate")
        strip.frame.origin.x = 0; strip.refreshPresentation(); pump(); precondition(strip.isAnimating)
        window.orderOut(nil); strip.setPresentationActive(false)
        precondition(!strip.isAnimating, "The owning window's hidden state must suspend its decoration")
        window.makeKeyAndOrderFront(nil); strip.setPresentationActive(true); pump()
        strip.show(.idle); precondition(!strip.isAnimating, "Returning to the library removes all live scheduling")
        strip.playBoot(duration: 3.8); pump(); precondition(strip.isAnimating)
        now += 4
        waitFor("Registered timer must finish the finite Touch Bar boot") { strip.state == .idle }
        precondition(strip.state == .idle && !strip.isAnimating, "Boot must terminate rather than reschedule an idle timer")
        strip.show(.connecting); pump(); precondition(strip.isAnimating)
        strip.removeFromSuperview(); pump(); precondition(!strip.isAnimating, "Detach must stop the timer")
        window.contentView!.addSubview(strip); strip.setPresentationActive(true); pump()
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        precondition(!strip.isAnimating && !strip.presentationActive, "Application deactivation must suspend, never steal the bar back")
        strip.removeFromSuperview()

        weak var released: MoonlightLGTouchBarStripView?
        autoreleasepool {
            let temporary = MoonlightLGTouchBarStripView(frame: NSRect(x: 0, y: 0, width: 240, height: 30),
                clock: { now }, reduceMotion: { false }, rendersLiveContent: false)
            released = temporary
            window.contentView!.addSubview(temporary)
            temporary.setPresentationActive(true); temporary.show(.connecting)
            precondition(temporary.isAnimating)
            temporary.removeFromSuperview()
        }
        pump()
        precondition(released == nil, "Timer and notification observers must not retain a detached decoration")
        print("PASS: Touch Bar artwork resources, templates, single connected shockwave, failed freeze, Reduce Motion, clipping, focus, finite boot and teardown")
    }
}
