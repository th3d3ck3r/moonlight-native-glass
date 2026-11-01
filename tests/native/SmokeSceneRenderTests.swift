import AppKit
import Metal
import QuartzCore
import SwiftUI

// Render through the actual SwiftUI shader path and capture the window's
// composited pixels. cacheDisplay/ImageRenderer can omit GPU-backed content.
@main struct SmokeSceneRenderTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.finishLaunching()
        NSApp.appearance = NSAppearance(named: .darkAqua)
        guard let device = MTLCreateSystemDefaultDevice(),
              let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let library = try? device.makeLibrary(URL: url) else {
            preconditionFailure("Packaged default Metal library must load on the runner's GPU")
        }
        precondition(library.functionNames.contains("smokeAccretion") && library.functionNames.contains("smokeAccretionStrip"),
                     "Both packaged stitchable functions must be available")
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var images: [String: NSBitmapImageRep] = [:]
        let frames: [(String, SmokeAccretionState, Bool)] = [
            ("boot-early", .init(time: 0.6, bootProgress: 0.6 / 3.8, isBoot: true), false),
            ("boot-arrival", .init(time: 3.6, bootProgress: 3.6 / 3.8, isBoot: true), false),
            ("connecting", .init(time: 3, progressFill: 0.9), false),
            ("connected", .init(time: 5, connected: 1, sinceConnect: 1.5, progressFill: 1), false),
            ("strip-connecting", .init(time: 3, progressFill: 0.9), true),
            ("strip-connected", .init(time: 5, connected: 1, sinceConnect: 1.5, progressFill: 1), true),
            ("tile-connecting", .init(time: 3, progressFill: 0.9), true),
            ("tile-connected", .init(time: 5, connected: 1, sinceConnect: 1.5, progressFill: 1), true)
        ]
        for (name, state, strip) in frames {
            let size = strip ? NSSize(width: name.hasPrefix("tile-") ? 72 : 685, height: 30) : NSSize(width: 640, height: 400)
            let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: 70, y: 100), size: size),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            var liveStrip: MoonlightLGTouchBarStripView?
            if strip {
                let view = MoonlightLGTouchBarStripView(frame: NSRect(origin: .zero, size: size),
                    clock: CACurrentMediaTime, reduceMotion: { false })
                window.contentView = view
                liveStrip = view
            } else {
                let host = NSHostingView(rootView: SmokeAccretionScene(state: state))
                host.frame = NSRect(origin: .zero, size: size)
                window.contentView = host
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            liveStrip?.setPresentationActive(true)
            liveStrip?.show(name.hasSuffix("-connected") ? .connected : .connecting, animated: false)
            RunLoop.main.run(until: Date().addingTimeInterval(0.8))
            if let liveStrip { precondition(liveStrip.isAnimating, "The actual strip hosting view must schedule live GPU content") }
            let path = directory.appendingPathComponent("smoke-\(name).png")
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path.path]
            try! capture.run(); capture.waitUntilExit()
            precondition(capture.terminationStatus == 0, "Composited shader capture must succeed")
            let bitmap = NSBitmapImageRep(data: try! Data(contentsOf: path))!
            images[name] = bitmap
            // The earliest boot intentionally begins nearly dark. Later screen
            // and strip frames must contain the authored red smoke and moon.
            if name != "boot-early" {
                var lit = 0, red = 0
                for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
                    for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
                        guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                        if max(c.redComponent, c.greenComponent, c.blueComponent) > 0.08 { lit += 1 }
                        if c.redComponent > c.greenComponent * 1.4 && c.redComponent > c.blueComponent * 1.2 && c.redComponent > 0.05 { red += 1 }
                    }
                }
                precondition(lit > 30 && red > 10, "\(name): shader must render visible crimson artwork, not a blank/black fallback")
            }
            liveStrip?.setPresentationActive(false)
            if let liveStrip { precondition(!liveStrip.isAnimating, "Hidden strip must stop live scheduling") }
            window.orderOut(nil); window.close()
        }
        precondition(images["connecting"]!.tiffRepresentation != images["connected"]!.tiffRepresentation,
                     "Connecting and connected shader states must render distinct frames")
        precondition(images["strip-connecting"]!.tiffRepresentation != images["strip-connected"]!.tiffRepresentation,
                     "The Touch Bar shader must respond to connected state, not display a fixed image")
        precondition(images["tile-connecting"]!.tiffRepresentation != images["tile-connected"]!.tiffRepresentation,
                     "The actual 72-point status tile must retain live state changes")
        // Template PNGs need AppKit's image-view rendering; raw NSImage.draw
        // would leave the black mask invisible on the dark Touch Bar surface.
        let glyphWindow = NSWindow(contentRect: NSRect(x: 70, y: 100, width: 72, height: 30),
                                   styleMask: .borderless, backing: .buffered, defer: false)
        glyphWindow.isReleasedWhenClosed = false; glyphWindow.backgroundColor = .black
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 72, height: 30))
        let glyph = NSImageView(frame: NSRect(x: 27, y: 6, width: 18, height: 18))
        glyph.image = MoonlightLGTouchBarArt.streamGlyph
        precondition(glyph.image?.isTemplate == true, "Provided glyph must remain a template")
        glyph.imageScaling = .scaleProportionallyDown
        container.addSubview(glyph); glyphWindow.contentView = container
        glyphWindow.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let glyphPath = directory.appendingPathComponent("smoke-template-glyph.png")
        let glyphCapture = Process(); glyphCapture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        glyphCapture.arguments = ["-x", "-o", "-l", String(glyphWindow.windowNumber), glyphPath.path]
        try! glyphCapture.run(); glyphCapture.waitUntilExit()
        precondition(glyphCapture.terminationStatus == 0)
        let glyphBitmap = NSBitmapImageRep(data: try! Data(contentsOf: glyphPath))!
        var lightPixels = 0
        for y in 0..<glyphBitmap.pixelsHigh { for x in 0..<glyphBitmap.pixelsWide {
            guard let c = glyphBitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            if c.redComponent > 0.5 && c.greenComponent > 0.5 && c.blueComponent > 0.5 { lightPixels += 1 }
        } }
        precondition(lightPixels > 10, "System-tinted template glyph must remain visible on the dark surface")
        glyphWindow.orderOut(nil); glyphWindow.close()
        print("PASS: packaged screen/Touch Bar Metal functions, 72-point tile, live state frames and visible system-tinted glyph")
    }
}
