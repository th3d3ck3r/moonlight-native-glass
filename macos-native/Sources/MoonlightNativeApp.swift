import AppKit
import SwiftUI

final class NativeAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: EngineStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(store.preview ? .disabled : .automatic)
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
    guard args.contains("--design-preview"), let index = args.firstIndex(of: "--capture-preview"), args.count > index + 1 else { return }
    if args.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
    if args.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
    func prepare(attempt: Int) {
        let screen = args.firstIndex(of: "--preview-screen").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "main"
        let identifier = screen.hasPrefix("settings-") ? "native-settings" : "native-library"
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == identifier && $0.isVisible }) else {
            guard attempt < 40 else { print("No visible \(identifier) window: \(NSApp.windows.map { $0.title })"); exit(2) }
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
            let number = window.windowNumber
            DispatchQueue.global(qos: .userInitiated).async {
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(number), args[index + 1]]
                do {
                    try capture.run(); capture.waitUntilExit()
                    let status = capture.terminationStatus
                    DispatchQueue.main.async { if status == 0 { NSApp.terminate(nil) } else { exit(status) } }
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
