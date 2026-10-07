import AppKit
import SwiftUI

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
            if !(nativeArgument("--preview-screen") ?? "").hasPrefix("settings-") {
                NSApp.windows.first(where: { $0.contentView != nil })?.makeKeyAndOrderFront(nil)
            }
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
