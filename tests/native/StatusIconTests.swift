import AppKit
import Combine

@MainActor private final class WindowState {
    @Published var exists = false
}

@main struct StatusIconTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let savedTheme = UserDefaults.standard.object(forKey: NativeCrimsonTheme.key)
        UserDefaults.standard.set(false, forKey: NativeCrimsonTheme.key)
        defer {
            if let savedTheme { UserDefaults.standard.set(savedTheme, forKey: NativeCrimsonTheme.key) }
            else { UserDefaults.standard.removeObject(forKey: NativeCrimsonTheme.key) }
        }
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
        precondition(fullMoon === crescent && fullMoon.isTemplate, "Idle and active states must reuse the new system-tinted menu glyph")
        precondition(fullMoon.size == crescent.size)
        precondition(button.accessibilityLabel()?.contains("stream window open") == true)
        // Verify the supplied template glyph at physical and Retina sizes.
        // State remains in accessibility and menu actions, not manual tinting.
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
                var visible = 0
                for y in 0..<pixels { for x in 0..<pixels {
                    if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.1 { visible += 1 }
                } }
                precondition(visible > pixels && visible < pixels * pixels,
                             "Template glyph must preserve visible strokes and transparent space")
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
        for tag in [200, 100, 201, 203, 207, 209, 212, 217, 219] {
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
        var actions = [Int](), restores = 0, libraries = 0
        menu.perform = { actions.append($0) }; menu.open = { restores += 1 }; menu.library = { libraries += 1 }
        menu.menuAction(connectedMenu.items.first { $0.title == "Release Input" }!)
        menu.menuAction(connectedMenu.items.first { $0.title == "Hide Statistics" }!)
        menu.menuAction(connectedMenu.items.first { $0.title == "Open Library" }!)
        menu.menuAction(connectedMenu.items.first { $0.title == "Disconnect" }!)
        precondition(actions == [202, 208, 212] && libraries == 1)
        let recording = UserDefaults(suiteName: "com.moonlight-stream.NativeGlass.Recording")!
        let previousEnabled = recording.object(forKey: "enabled"), previousReplay = recording.object(forKey: "replay")
        defer { recording.set(previousEnabled, forKey: "enabled"); recording.set(previousReplay, forKey: "replay") }
        recording.set(true, forKey: "enabled"); recording.set(true, forKey: "replay")
        let recordMenu = menu.makeMenu()
        for tag in [217, 219] {
            let command = recordMenu.items.first { $0.tag == tag }!; precondition(command.isEnabled)
            menu.menuAction(command)
        }
        precondition(Array(actions.suffix(2)) == [217, 219], "Recording commands remain available without a titlebar")
        let exitItem = connectedMenu.items.first { $0.tag == 209 }!
        let beforeExit = actions.count
        menu.menuAction(exitItem)
        precondition(Array(actions.dropFirst(beforeExit)) == [216], "Host-exit confirmation must be delegated to the stream owner, never shown by the frontend")
        menu.state.token = "first-stream"
        precondition(!button.trackingAreas.contains { ($0.owner as AnyObject?) === menu }, "Status item must install no hover tracking")
        precondition(!menu.responds(to: NSSelectorFromString("mouseEnteredWithEvent:")), "Status menu must have no hover handler")
        precondition(connectedMenu.items.allSatisfy { $0.tag != -5 }, "Removed thumbnails must leave no Screen Recording permission action")
        button.performClick(nil)
        precondition(restores == 1, "Primary status-item click must still restore/open the main window")
        menu.state.visible = false
        let hiddenMenu = menu.makeMenu()
        menu.menuAction(hiddenMenu.items.first { $0.title == "Restore Stream Window" }!)
        precondition(restores == 2, "Hidden stream must still restore from its menu item")
        let windowCount = NSApp.windows.count
        for _ in 0..<20 { flush() }
        precondition(NSApp.windows.count == windowCount, "Idle status item must not create a preview window")
        menu.state = NativeMenuState()
        let finalMenu = menu.makeMenu()
        for tag in [200, 100, 201, 203, 207, 209, 212, 217, 219] {
            precondition(finalMenu.items.first { $0.tag == tag }?.isEnabled == false)
        }
        precondition(finalMenu.items.first { $0.title == "Settings…" }?.isEnabled == true)
        precondition(finalMenu.items.first { $0.title == "Open Engine Logs" }?.isEnabled == true)
        // Template artwork follows the system appearance in either app theme.
        UserDefaults.standard.set(true, forKey: NativeCrimsonTheme.key)
        flush()
        for exists in [false, true] {
            state.exists = exists; flush()
            precondition(button.image === crescent && button.image!.isTemplate,
                         "Crimson Glass must retain the same system-tinted template glyph")
            precondition(button.accessibilityLabel()?.contains(exists ? "stream window open" : "no stream window") == true)
        }
        UserDefaults.standard.set(false, forKey: NativeCrimsonTheme.key); flush()
        precondition(button.image === crescent, "Theme changes must not reload the menu artwork")
        print("Status icon states, menu confirmations/input handoff, click/hidden restore and hover removal checks passed")
    }
}
