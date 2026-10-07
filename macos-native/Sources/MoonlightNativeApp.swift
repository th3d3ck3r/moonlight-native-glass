import AppKit
import SwiftUI

final class NativeAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: EngineStore?
    var statusMenu: NativeStatusMenu?
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
            if CommandLine.arguments.contains("--design-preview"), nativeArgument("--preview-screen") == "about" {
                showNativeAboutPanel()
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
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
                .background(NativeStatusActions(store: store, delegate: delegate))
                .onAppear { delegate.store = store; store.start() }
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Moonlight Native Glass") {
                    showNativeAboutPanel()
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

// Keep window routing in SwiftUI; the AppKit status button provides a direct
// primary click and a secondary-click menu without changing app activation policy.
private struct NativeStatusActions: View {
    let store: EngineStore
    let delegate: NativeAppDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Color.clear.frame(width: 0, height: 0).onAppear {
            if delegate.statusMenu == nil { delegate.statusMenu = NativeStatusMenu() }
            delegate.statusMenu?.bind(to: store.$streamWindowExists)
            delegate.statusMenu?.open = {
                if store.streamWindowExists { store.restoreStreamWindow() }
                else { openWindow(id: "library"); NSApp.activate(ignoringOtherApps: true) }
            }
            delegate.statusMenu?.settings = {
                openSettings(); NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// Keep these credits fixed across builds. AppKit reads the build number from
// CFBundleVersion for the preview number; release notes belong on GitHub.
func showNativeAboutPanel() {
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "3"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let credits = NSMutableAttributedString(
        string: "SwiftUI/AppKit interface\nMoonlight Qt 6.2.0 streaming engine\nManual updates · GPL-3.0\n\nNative Glass created and maintained by Th3D3ck3r\n\nGitHub Repository",
        attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                     .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
    credits.addAttributes([.link: URL(string: "https://github.com/th3d3ck3r/moonlight-native-glass")!,
                           .foregroundColor: NSColor.linkColor,
                           .underlineStyle: NSUnderlineStyle.single.rawValue],
                          range: (credits.string as NSString).range(of: "GitHub Repository"))
    NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: "Moonlight Native Glass",
        .applicationVersion: "Native UI Preview \(build) - Moonlight 6.2",
        .version: "",
        .credits: credits])
    NSApp.keyWindow?.setAccessibilityIdentifier("native-about")
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
