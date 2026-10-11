import AppKit
import SwiftUI

@main struct BootPlaybackTests {
    @MainActor static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
    @MainActor static func wait(_ seconds: Double, until condition: () -> Bool) {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while !condition() && ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        require(condition(), "Native startup condition timed out")
    }
    @MainActor static func window() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 960, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        window.title = "Original title"
        window.toolbar = NSToolbar(identifier: "original-toolbar")
        window.makeKeyAndOrderFront(nil)
        return window
    }
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let resource = URL(fileURLWithPath: CommandLine.arguments[1])
        require(!NativeBootPresentation(enabled: true, resource: nil, reduceMotion: false).blocksLibrary, "Missing artwork must not block")
        require(!NativeBootPresentation(enabled: true, resource: resource, reduceMotion: true).blocksLibrary, "Reduce Motion must bypass startup")
        let invalid = resource.deletingLastPathComponent().appendingPathComponent("boot-animation.mp4")
        require(!NativeBootPresentation(enabled: true, resource: invalid, reduceMotion: false).blocksLibrary, "Non-image artwork must bypass startup")
        let clean = NativeBootLogo.image(resource)!
        let cleanCG = clean.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let pixels = NSBitmapImageRep(cgImage: cleanCG)
        require((pixels.colorAt(x: 0, y: 0)?.alphaComponent ?? 1) < 0.01, "Remove the baked square background")
        let artworkX = Int(Double(cleanCG.width) * 0.37)
        let artworkY = cleanCG.height / 2
        require((pixels.colorAt(x: artworkX, y: artworkY)?.alphaComponent ?? 0) > 0.95, "Preserve the actual moon artwork")
        let first = NativeBootPresentation(enabled: true, resource: resource, reduceMotion: false)
        let w = window(); let frame = w.frame; let content = w.contentView
        let mask = w.styleMask; let title = w.titleVisibility; let transparent = w.titlebarAppearsTransparent
        let toolbarVisible = w.toolbar!.isVisible
        first.watchWindow(w); first.watchWindow(w); first.start(); first.start()
        require(w.contentView === content, "Startup must never replace or reparent window content")
        require(w.frame == frame, "Hiding chrome must retain the window frame")
        require(w.titleVisibility == .hidden && w.titlebarAppearsTransparent && !w.toolbar!.isVisible, "Hide title and toolbar synchronously")
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            require(w.standardWindowButton(kind) != nil, "Retain genuine AppKit window buttons")
        }
        // Respect a resize performed during startup, including on skip.
        var resized = frame; resized.size.width += 50; w.setFrame(resized, display: false)
        first.finish(); first.finish()
        wait(2) { !first.blocksLibrary }
        require(w.frame == resized && w.contentView === content, "Reveal must preserve latest window frame/content")
        require(w.styleMask == mask && w.titleVisibility == title && w.titlebarAppearsTransparent == transparent && w.toolbar!.isVisible == toolbarVisible, "Restore original window chrome")
        first.watchWindow(w); first.start()
        require(!first.blocksLibrary, "Reopening must not replay startup")
        w.close()
        let natural = NativeBootPresentation(enabled: true, resource: resource, reduceMotion: false)
        let nw = window(); natural.watchWindow(nw); natural.start()
        wait(7) { !natural.blocksLibrary }
        require(nw.titleVisibility == .visible && nw.toolbar!.isVisible, "Natural completion must restore chrome")
        nw.close()
        let closing = NativeBootPresentation(enabled: true, resource: resource, reduceMotion: false)
        let cw = window(); closing.watchWindow(cw); closing.start(); cw.close()
        wait(2) { !closing.blocksLibrary }
        require(cw.titleVisibility == .visible, "Close during startup must restore chrome")
        print("Native finite timeline, unchanged content/frame, resize, chrome restoration, completion, skip, close, missing/invalid artwork and Reduce Motion passed")
    }
}
