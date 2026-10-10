import AppKit
import AVFoundation

@main struct BootPlaybackTests {
    @MainActor final class ReportingView: NSView {
        var report: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            report?(window)
        }
    }
    @MainActor static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
    @MainActor static func wait(_ seconds: Double, until condition: () -> Bool) {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while !condition() && ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        require(condition(), "Boot playback condition timed out")
    }
    @MainActor static func window() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        window.makeKeyAndOrderFront(nil)
        return window
    }
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let resource = URL(fileURLWithPath: CommandLine.arguments[1])
        require(!NativeBootPresentation(enabled: true, resource: nil, reduceMotion: false).blocksLibrary,
                "Missing media must not block the library")
        require(!NativeBootPresentation(enabled: true, resource: resource, reduceMotion: true).blocksLibrary,
                "Reduce Motion must bypass the movie")

        let first = NativeBootPresentation(enabled: true, resource: resource, reduceMotion: false)
        let firstWindow = window()
        let content = firstWindow.contentView!
        let reporter = ReportingView(frame: .zero)
        reporter.report = { first.watchWindow($0) }
        content.addSubview(reporter)
        first.watchWindow(firstWindow)
        first.watchWindow(firstWindow)
        wait(3) { firstWindow.contentView !== content }
        let container = firstWindow.contentView!
        require(container !== content && content.superview === container,
                "Movie and disabled library must be siblings in the same window")
        first.start()
        wait(5) { (first.player?.currentTime().seconds ?? 0) > 0.15 }
        require(container.subviews.count == 2, "Overlay must be attached to the actual window")
        first.watchWindow(firstWindow)
        require(firstWindow.contentView === container && container.subviews.count == 2, "Repeated window reports must not duplicate overlays")
        first.finish(); first.finish()
        wait(3) { !first.blocksLibrary }
        require(first.player == nil && container.subviews.count == 1 && content.superview === container, "Completion must release player and overlay while retaining library")
        first.watchWindow(firstWindow); first.start()
        require(!first.blocksLibrary && container.subviews.count == 1, "Reopening must not replay in the same process")
        firstWindow.close()

        let closing = NativeBootPresentation(enabled: true, resource: resource, reduceMotion: false)
        let closingWindow = window()
        closing.watchWindow(closingWindow); closing.start()
        wait(5) { (closing.player?.currentTime().seconds ?? 0) > 0.1 }
        closingWindow.close()
        wait(3) { !closing.blocksLibrary }
        require(closing.player == nil, "Closing the window must release the player")

        let corrupt = NativeBootPresentation(enabled: true, resource: resource.deletingLastPathComponent().appendingPathComponent("full-moon.png"), reduceMotion: false)
        corrupt.start()
        wait(5) { !corrupt.blocksLibrary }
        require(corrupt.player == nil, "Invalid media must clear the player and reveal the library")

        let stalled = NativeBootPresentation(enabled: true, resource: resource, reduceMotion: false)
        stalled.start()
        wait(5) { (stalled.player?.currentTime().seconds ?? 0) > 0.1 }
        stalled.player?.pause()
        wait(14) { !stalled.blocksLibrary }
        require(stalled.player == nil, "Watchdog must release stalled playback")
        print("Real AVPlayer playback, native window attachment, cleanup, invalid media, Reduce Motion and stall watchdog passed")
    }
}
