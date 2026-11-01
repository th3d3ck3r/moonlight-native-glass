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
        // Large Retina startup windows must not silently return to shading
        // four times as many pixels. Native-size text sits outside this effect.
        for size in [CGSize(width: 1100, height: 720), CGSize(width: 2560, height: 1600), CGSize(width: 600, height: 1200)] {
            let factor = SmokeAccretionRenderBudget.factor(size: size, displayScale: 2)
            precondition(size.width * 2 / factor <= 1280.001 && size.height * 2 / factor <= 800.001)
        }
        precondition(SmokeAccretionRenderBudget.factor(size: CGSize(width: 640, height: 400), displayScale: 2) == 1,
                     "Small surfaces keep their full native resolution")
        var images: [String: NSBitmapImageRep] = [:]
        let frames: [(String, SmokeAccretionState, Bool)] = [
            ("boot-early", .init(time: 0.6, bootProgress: 0.6 / 3.8, isBoot: true), false),
            ("boot-arrival", .init(time: 3.6, bootProgress: 3.6 / 3.8, isBoot: true), false),
            ("boot-retina", .init(time: 3.6, bootProgress: 3.6 / 3.8, isBoot: true), false),
            ("connecting", .init(time: 3, progressFill: 0.9), false),
            ("connected", .init(time: 5, connected: 1, sinceConnect: 1.5, progressFill: 1), false),
            ("strip-connecting", .init(time: 3, progressFill: 0.9), true),
            ("strip-connected", .init(time: 5, connected: 1, sinceConnect: 1.5, progressFill: 1), true),
            ("tile-connecting", .init(time: 3, progressFill: 0.9), true),
            ("tile-connected", .init(time: 5, connected: 1, sinceConnect: 1.5, progressFill: 1), true)
        ]
        for (name, state, strip) in frames {
            let size = strip ? NSSize(width: name.hasPrefix("tile-") ? 72 : 685, height: 30) : NSSize(width: name == "boot-retina" ? 1100 : 640, height: name == "boot-retina" ? 720 : 400)
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
        // Exercise the production composition, not just the shader in an
        // isolated view: the moon must occupy the centre of the app's available
        // bar while the original status/actions remain visible above it.
        for width in [CGFloat(685), 1085] {
            for boot in [true, false] {
                let size = NSSize(width: width, height: 30)
                let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: 70, y: 100), size: size),
                                      styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.backgroundColor = .black
                let status = NativeTouchBarButton(title: boot ? "MoonlightLG\nStarting…" : "Th3D3ck3r-R7\nReady to stream", target: nil, action: nil)
                status.statusOnly = true; status.isEnabled = false
                status.templateGlyph = MoonlightLGTouchBarArt.appGlyph
                status.image = status.templateGlyph
                let primary = NativeTouchBarButton(title: boot ? "Skip to Library" : "Continue to Stream", target: nil, action: nil)
                primary.image = NSImage(systemSymbolName: boot ? "forward.end.fill" : "play.fill", accessibilityDescription: nil)
                let cancel = NativeTouchBarButton(title: "Cancel", target: nil, action: nil)
                cancel.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
                let retry = NativeTouchBarButton(title: "Retry", target: nil, action: nil)
                retry.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
                retry.isEnabled = false
                var buttons: [(NSButton, CGFloat)] = [(status, 200), (primary, 150)]
                if !boot { buttons += [(retry, 65), (cancel, 80)] }
                for (button, _) in buttons {
                    button.bezelColor = NSColor(srgbRed: 0.12, green: 0.035, blue: 0.055, alpha: 1)
                    button.contentTintColor = NSColor(srgbRed: 0.95, green: 0.19, blue: 0.32, alpha: 1)
                }
                let row = NativeTouchBarRow(buttons: buttons, pinnedStatus: true)
                var now: CFTimeInterval = 100
                let strip = MoonlightLGTouchBarStripView(frame: NSRect(origin: .zero, size: size),
                    clock: { now }, reduceMotion: { false })
                row.installStrip(strip)
                row.frame = NSRect(origin: .zero, size: size)
                window.contentView = row
                window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
                strip.setPresentationActive(true)
                if boot { strip.playBoot(duration: 3.8); now += 3.2 }
                else { strip.show(.connected, animated: false); now += 1.6 }
                RunLoop.main.run(until: Date().addingTimeInterval(0.8))
                precondition(row.strip === strip && strip.frame == row.bounds,
                             "Production artwork must fill the complete row, never a status tile")
                precondition(strip.bounds.width == width && strip.bounds.height == 30 && strip.isAnimating)
                precondition(row.status!.frame.maxX < width / 2 && row.scroll.frame.minX > width / 2,
                             "Foreground status/actions must leave the central moon readable")
                precondition(buttons.allSatisfy { $0.0.frame.height == 30 }, "Controls retain physical Touch Bar height")
                let path = directory.appendingPathComponent("smoke-row-\(boot ? "boot" : "connected")-\(Int(width)).png")
                let capture = Process(); capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path.path]
                try! capture.run(); capture.waitUntilExit()
                precondition(capture.terminationStatus == 0, "Composited production-row capture must succeed")
                let bitmap = NSBitmapImageRep(data: try! Data(contentsOf: path))!
                // Neither status nor action occupies this region. Bright lunar
                // pixels prove the GPU image is centred across the whole row;
                // the old 72-point status decoration cannot satisfy this check.
                let scale = CGFloat(bitmap.pixelsWide) / width
                let center = bitmap.pixelsWide / 2
                let radius = Int(15 * scale)
                var lunarPixels = 0
                for y in 0..<bitmap.pixelsHigh {
                    for x in max(0, center - radius)..<min(bitmap.pixelsWide, center + radius) {
                        guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                        if c.redComponent > 0.25 && c.greenComponent > 0.2 && c.blueComponent > 0.2 { lunarPixels += 1 }
                    }
                }
                precondition(lunarPixels > 10, "\(path.lastPathComponent): central moon must render through the actual composed control row")
                row.removeStrip()
                precondition(!strip.isAnimating && strip.superview == nil,
                             "Removing the row artwork must tear down its renderer and timer")
                window.orderOut(nil); window.close()
            }
        }
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
        print("PASS: packaged screen/Touch Bar Metal functions, live state frames, integrated 685/1085-point rows and visible system-tinted glyph")
    }
}
