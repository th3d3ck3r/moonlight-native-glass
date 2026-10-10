import AppKit
import Combine

@MainActor private final class WindowState {
    @Published var exists = false
}

@main struct StatusIconTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let state = WindowState()
        let menu = NativeStatusMenu(resourceURL: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))
        menu.bind(to: state.$exists)
        func flush() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        flush()
        let button = menu.item.button!
        let crescent = button.image!
        precondition(crescent.size == NSSize(width: 18, height: 18))
        precondition(button.accessibilityLabel()?.contains("no stream window") == true)
        state.exists = true
        flush()
        let fullMoon = button.image!
        precondition(fullMoon !== crescent, "Full moon resource must load")
        precondition(fullMoon.size == crescent.size)
        precondition(button.accessibilityLabel()?.contains("stream window open") == true)
        // Verify the actual rendered images, including Retina-sized backing.
        // The blue artwork and opaque edge centers must survive the corner mask.
        for (name, image) in [("crescent", crescent), ("full-moon", fullMoon)] {
            for scale in [1, 2] {
                let pixels = 18 * scale
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                NSGraphicsContext.restoreGraphicsState()
                for (x, y) in [(0, 0), (pixels-1, 0), (0, pixels-1), (pixels-1, pixels-1)] {
                    precondition(bitmap.colorAt(x: x, y: y)!.alphaComponent < 0.05, "Both icon states must have transparent rounded corners")
                }
                precondition(bitmap.colorAt(x: pixels/2, y: 0)!.alphaComponent > 0.95, "Mask must preserve the icon's straight edge")
                let center = bitmap.colorAt(x: pixels/2, y: pixels/2)!.usingColorSpace(.sRGB)!
                precondition(center.alphaComponent > 0.95 && center.blueComponent > center.redComponent, "Mask must preserve the original full-color artwork")
                if CommandLine.arguments.count > 2 {
                    let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
                    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try! bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(name)-\(scale)x.png"))
                }
            }
        }
        // Closing the library must not cancel the app-owned observation.
        let library = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: .titled, backing: .buffered, defer: false)
        library.isReleasedWhenClosed = false
        library.close()
        state.exists = true
        flush()
        precondition(button.image === fullMoon, "Repeated state must reuse cached image")
        state.exists = false
        flush()
        precondition(button.image === crescent, "Window destruction must restore crescent")
        menu.bind(to: state.$exists)
        state.exists = true
        flush()
        precondition(button.image === fullMoon, "Rebinding must preserve state observation")
        // No stream: app actions stay available, all stream actions are disabled.
        let idleMenu = menu.makeMenu()
        for tag in [200, 100, 201, 203, 207, 209, 212] {
            precondition(idleMenu.items.first { $0.tag == tag }?.isEnabled == false)
        }
        precondition(idleMenu.items.first { $0.title == "Open Library" }?.isEnabled == true)
        menu.state = NativeMenuState(exists: true, token: "first-stream", windowNumber: 99, visible: true,
            captured: true, statistics: true, controls: true, muted: true, nextMode: 2)
        let connectedMenu = menu.makeMenu()
        for title in ["Hide Stream Window", "Hide Stream Controls", "Release Input", "Hide Statistics", "Unmute Stream Audio"] {
            precondition(connectedMenu.items.first { $0.title == title }?.isEnabled == true)
        }
        let modes = connectedMenu.items.first { $0.title == "Window Mode (Next Stream)" }!.submenu!
        precondition(modes.items[2].state == .on && modes.items[0].state == .off)
        var actions = [Int](), restores = 0, libraries = 0, captures = 0
        menu.perform = { actions.append($0) }; menu.open = { restores += 1 }; menu.library = { libraries += 1 }
        menu.menuAction(connectedMenu.items.first { $0.title == "Release Input" }!)
        menu.menuAction(connectedMenu.items.first { $0.title == "Hide Statistics" }!)
        menu.menuAction(connectedMenu.items.first { $0.title == "Open Library" }!)
        menu.menuAction(connectedMenu.items.first { $0.title == "Disconnect" }!)
        precondition(actions == [202, 208, 212] && libraries == 1)
        let exitItem = connectedMenu.items.first { $0.tag == 209 }!
        for (reply, replaceStream) in [(NSApplication.ModalResponse.alertFirstButtonReturn,false),(.alertSecondButtonReturn,false),(.alertSecondButtonReturn,true)] {
            let before = actions.count
            DispatchQueue.main.async {
                if replaceStream { menu.state.token = "replaced-during-confirmation" }
                NSApp.stopModal(withCode: reply)
            }
            menu.menuAction(exitItem)
            let expected = replaceStream ? [213] : [213, reply == .alertSecondButtonReturn ? 209 : 214]
            precondition(Array(actions.dropFirst(before)) == expected,"Confirmation must suspend input, restore on Cancel, and exit only the same stream")
        }
        menu.state.token = "first-stream"
        let thumbnail = NSImage(size: NSSize(width: 320, height: 180), flipped: false) { rect in
            NSColor.systemBlue.setFill(); rect.fill(); return true
        }
        menu.thumbnailProvider = { id in precondition(id == 99); captures += 1; return thumbnail }
        menu.hoverDelay = .milliseconds(40)
        menu.beginHover(); menu.endHover(); flush(); flush()
        precondition(captures == 0 && menu.previewPanel == nil, "Leaving before delay must cancel capture")
        let keyWindow = NSApp.keyWindow
        menu.beginHover()
        for _ in 0..<5 { flush() }
        precondition(captures == 1 && menu.previewPanel?.isVisible == true, "Delayed hover must show thumbnail")
        precondition(menu.previewPanel!.canBecomeKey == false && NSApp.keyWindow === keyWindow, "Thumbnail must not steal focus")
        precondition(menu.previewPanel!.contentView!.accessibilityPerformPress(), "Thumbnail must be accessible and clickable")
        precondition(restores == 1 && menu.previewPanel == nil)
        // A window missing from shareable content reuses only this stream's last frame.
        menu.thumbnailProvider = { _ in nil }
        menu.state.visible = false
        menu.beginHover(); for _ in 0..<5 { flush() }
        precondition(menu.previewPanel?.isVisible == true, "Hidden stream should retain cached thumbnail")
        menu.state = NativeMenuState(exists: true, token: "replacement", windowNumber: 100)
        precondition(menu.previewPanel == nil, "Replacement must dismiss the old stream thumbnail")
        menu.beginHover(); for _ in 0..<5 { flush() }
        precondition(menu.previewPanel?.isVisible == true && menu.previewUnavailable, "Replacement without an image must show a restore fallback, never the previous stream image")
        menu.captureAllowed = { false }
        menu.dismissPreview(); menu.beginHover(); for _ in 0..<5 { flush() }
        precondition(menu.previewPanel?.isVisible == true && menu.previewUnavailable, "Missing permission must still show a clickable restore fallback")
        menu.dismissPreview()
        menu.thumbnailProvider = { _ in try? await Task.sleep(for: .milliseconds(120)); return thumbnail }
        menu.beginHover(); flush()
        menu.state = NativeMenuState()
        for _ in 0..<5 { flush() }
        precondition(menu.previewPanel == nil, "A completed stale capture must not resurrect an ended stream")
        print("Status icon, complete menu routing/state, hover delay/cancellation, focus, cached fallback, restore and stream replacement checks passed")
    }
}
