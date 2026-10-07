import AppKit
import SwiftUI

final class NativeAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: EngineStore?
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
                .onAppear { delegate.store = store; store.start(); captureDesignPreviewIfRequested() }
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
    guard args.contains("--design-preview"), let index = args.firstIndex(of: "--capture-preview"), args.count > index + 1 else { return }
    if args.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
    if args.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }), let view = window.contentView else { exit(2) }
        for size in [NSSize(width: 1080, height: 720), NSSize(width: 680, height: 460), NSSize(width: 1280, height: 800)] {
            window.setContentSize(size)
            for _ in 0..<50 { view.needsLayout = true; view.layoutSubtreeIfNeeded() }
        }
        window.setContentSize(NSSize(width: args.contains("--compact") ? 680 : 1080, height: args.contains("--compact") ? 460 : 720))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(3) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(4) }
        do { try data.write(to: URL(fileURLWithPath: args[index + 1])); NSApp.terminate(nil) } catch { exit(5) }
    }
}
