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
        print("Status icon resource, state, caching, library-close and rebind checks passed")
    }
}
