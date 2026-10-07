import AppKit
import SwiftUI
import QuartzCore

final class NativeAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: EngineStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--design-preview") {
            if CommandLine.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
            if CommandLine.arguments.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first(where: { $0.contentView != nil })?.makeKeyAndOrderFront(nil)
            captureDesignPreviewIfRequested()
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if store?.streamActive == true {
            let alert = NSAlert()
            alert.messageText = "Quit while streaming?"
            alert.informativeText = "This disconnects the client. The game may continue running on your computer."
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return .terminateCancel }
        }
        store?.shutdown()
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) { store?.shutdown() }
}

@main struct MoonlightNativeApp: App {
    @NSApplicationDelegateAdaptor(NativeAppDelegate.self) private var delegate
    @StateObject private var store = EngineStore(preview: CommandLine.arguments.contains("--design-preview"))
    var body: some Scene {
        Window("Moonlight Native Glass", id: "library") {
            LibraryView(store: store)
                .frame(minWidth: 680, minHeight: 460)
                .onAppear { delegate.store = store; store.start() }
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Moonlight Native Glass") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Moonlight Native Glass",
                        .applicationVersion: "Native UI Preview 1 · Moonlight Qt 6.2.0",
                        .credits: NSAttributedString(string: "SwiftUI/AppKit interface\nMoonlight Qt 6.2.0 streaming engine\nManual updates · GPL-3.0\n\nThis preview requires physical Mac streaming validation.")])
                }
            }
            CommandGroup(after: .newItem) {
                Button("Add Computer…") { NotificationCenter.default.post(name: .nativeAddComputer, object: nil) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Refresh Computers") { store.refresh() }.keyboardShortcut("r")
            }
            CommandGroup(after: .appSettings) {
                Button("Open Engine Logs") { NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp", isDirectory: true)) }
                Button("View Preview Releases…") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/th3d3ck3r/moonlight-native-glass/releases")!)
                }
            }
        }
        Settings {
            NativeSettingsView(store: store)
                .frame(width: 640, height: 540)
        }
    }
}

extension Notification.Name { static let nativeAddComputer = Notification.Name("MoonlightNativeAddComputer") }

// Actual app-window capture using sample content. This is deliberately gated
// behind --design-preview and never runs in a normal app launch.
@MainActor func captureDesignPreviewIfRequested() {
    let args = CommandLine.arguments
    guard args.contains("--design-preview"), let destination = nativeArgument("--capture-preview") else { return }
    let logURL = URL(fileURLWithPath: destination + ".log")
    func record(_ message: String) { try? (message + "\n").data(using: .utf8)?.write(to: logURL) }
    record("Capture launched; windows=\(NSApp.windows.map { $0.title })")
    if args.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
    if args.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
    func prepare(attempt: Int) {
        let screen = nativeArgument("--preview-screen") ?? "main"
        let identifier = screen.hasPrefix("settings-") ? "native-settings" : "native-library"
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == identifier && $0.isVisible }) else {
            guard attempt < 40 else { record("No visible \(identifier) window: \(NSApp.windows.map { $0.title })"); exit(2) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { prepare(attempt: attempt + 1) }
            return
        }
        if !screen.hasPrefix("settings-") {
            window.setContentSize(NSSize(width: args.contains("--compact") ? 680 : 1080, height: args.contains("--compact") ? 460 : 720))
        }
        window.makeKeyAndOrderFront(nil)
        // Let the WindowServer composite SwiftUI layers and native glass across
        // real display cycles. NSView bitmap caching omits composited layers.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            record("Capturing window \(window.title), number=\(window.windowNumber), frame=\(window.frame)")
            let captureWindow = window.attachedSheet ?? window
            let number = captureWindow.windowNumber
            DispatchQueue.global(qos: .userInitiated).async {
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(number), destination]
                let errors = Pipe()
                capture.standardError = errors
                do {
                    try capture.run(); capture.waitUntilExit()
                    let status = capture.terminationStatus
                    let diagnostic = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    try? "screencapture status=\(status) \(diagnostic)".write(toFile: destination + ".capture-log", atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        if status == 0 { NSApp.terminate(nil) }
                        else {
                            // CI may create windows without permitting WindowServer
                            // screenshots. Render only our own UI for layout review;
                            // this does not reproduce composited glass materials.
                            captureNativeLayout(window: captureWindow, destination: destination)
                        }
                    }
                } catch { print("Window capture failed: \(error)"); exit(3) }
            }
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { prepare(attempt: 0) }
}

struct NativeWindowAccessor: NSViewRepresentable {
    let report: (NSWindow?) -> Void
    final class ObserverView: NSView {
        var report: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); report?(window) }
    }
    func makeNSView(context: Context) -> ObserverView { let view = ObserverView(); view.report = report; return view }
    func updateNSView(_ view: ObserverView, context: Context) { view.report = report }
}

func nativeArgument(_ name: String) -> String? {
    let args = CommandLine.arguments
    if let argument = args.first(where: { $0.hasPrefix(name + "=") }) { return String(argument.dropFirst(name.count + 1)) }
    if let i = args.firstIndex(of: name), args.indices.contains(i + 1) { return args[i + 1] }
    return nil
}

@MainActor private func captureNativeLayout(window: NSWindow, destination: String) {
    guard let view = window.contentView?.superview ?? window.contentView else { exit(4) }
    view.wantsLayer = true
    view.displayIfNeeded()
    let scale: CGFloat = 2
    let width = Int(view.bounds.width * scale), height = Int(view.bounds.height * scale)
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext,
        let layer = view.layer else { exit(5) }
    context.scaleBy(x: scale, y: scale)
    window.effectiveAppearance.performAsCurrentDrawingAppearance {
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(view.bounds)
        layer.render(in: context)
    }
    guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(6) }
    do {
        try data.write(to: URL(fileURLWithPath: destination))
        try "App-layer layout capture with sample content. WindowServer glass appearance requires a physical Mac screenshot.".write(toFile: destination + ".capture-method.txt", atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    } catch { exit(7) }
}
