import AppKit
import SwiftUI

final class NativeAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: EngineStore?
    weak var boot: NativeBootPresentation?
    var statusMenu: NativeStatusMenu?
    var openPrimaryWindow: (() -> Void)?
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
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Keep SwiftUI's launch/restoration behavior when there is no stream.
        // Intercept only an existing stream, so the library cannot cover it.
        guard store?.streamWindowExists == true || store?.connectionJourney != nil, let openPrimaryWindow else { return true }
        openPrimaryWindow()
        return false
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
        boot?.finishImmediately()
        store?.shutdown()
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) { boot?.finishImmediately(); store?.shutdown() }
}

@main struct MoonlightLGApp: App {
    @NSApplicationDelegateAdaptor(NativeAppDelegate.self) private var delegate
    @StateObject private var store = EngineStore(preview: CommandLine.arguments.contains("--design-preview"))
    @StateObject private var boot = NativeBootPresentation(
        enabled: !CommandLine.arguments.contains("--design-preview") || CommandLine.arguments.contains("--boot-preview"),
        resource: CommandLine.arguments.contains("--design-preview") && CommandLine.arguments.contains("--boot-missing-resource")
            ? nil : CommandLine.arguments.contains("--design-preview") && CommandLine.arguments.contains("--boot-invalid-resource")
                ? Bundle.main.url(forResource: "boot-animation", withExtension: "mp4")
                : NativeCrimsonTheme.bootResource,
        // An explicit design playback probe must work even on CI machines
        // configured to reduce system animation. Normal launches respect it.
        reduceMotion: CommandLine.arguments.contains("--design-preview") && CommandLine.arguments.contains("--boot-preview")
            ? CommandLine.arguments.contains("--boot-reduce-motion")
            : NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    var body: some Scene {
        Window("MoonlightLG", id: "library") {
            ZStack {
                NativeBootView.background.ignoresSafeArea()
                if boot.blocksLibrary {
                    NativeWarpBootView(presentation: boot, previewTime: store.preview ? Double(nativeArgument("--boot-frame") ?? "") : nil)
                        .toolbarBackground(.hidden, for: .windowToolbar)
                        .background(NativeWindowAccessor { window in
                            store.libraryWindow = window
                            window?.identifier = NSUserInterfaceItemIdentifier("native-library")
                            window?.setAccessibilityIdentifier("native-library")
                            boot.watchWindow(window)
                        }.frame(width: 0, height: 0))
                } else {
                    LibraryView(store: store, sizesPreviewWindow: boot.startedAt == nil)
                        .transition(.opacity)
                }
            }
            .containerBackground(boot.blocksLibrary ? NativeBootView.background : Color(nsColor: .windowBackgroundColor), for: .window)
            .crimsonGlassTheme()
            .frame(minWidth: 680, minHeight: 460)
            .animation(.easeInOut(duration: 0.4), value: boot.phase)
            .background(NativeStatusActions(store: store, delegate: delegate))
            .onAppear { delegate.store = store; delegate.boot = boot; store.start() }
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MoonlightLG") {
                    showNativeAboutPanel()
                }
                Button("Licenses & Notices") { NSWorkspace.shared.open(nativeLegalNoticesURL()) }
            }
            CommandGroup(after: .newItem) {
                Button("Add Computer…") { NotificationCenter.default.post(name: .nativeAddComputer, object: nil) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(boot.blocksLibrary)
                Button("Refresh Computers") { store.refresh() }.keyboardShortcut("r")
            }
            CommandGroup(after: .appSettings) {
                Button("Open Engine Logs") {
                    try? FileManager.default.createDirectory(at: nativeEngineLogDirectory(), withIntermediateDirectories: true)
                    NSWorkspace.shared.open(nativeEngineLogDirectory())
                }
                Button("View Preview Releases…") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/th3d3ck3r/moonlight-native-glass/releases")!)
                }
            }
        }
        Settings {
            NativeSettingsView(store: store)
                .frame(width: 860, height: 600)
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
            delegate.statusMenu?.bindState(to: store.$menuState)
            let openLibrary: () -> Void = {
                    openWindow(id: "library")
                    if let window = store.libraryWindow {
                        if window.isMiniaturized { window.deminiaturize(nil) }
                        window.makeKeyAndOrderFront(nil)
                    }
                    NSApp.activate(ignoringOtherApps: true)
            }
            let openPrimaryWindow: () -> Void = {
                if store.streamWindowExists || store.connectionJourney != nil { store.restoreStreamWindow() } else { openLibrary() }
            }
            delegate.statusMenu?.library = openLibrary
            delegate.statusMenu?.perform = { store.menuAction($0) }
            delegate.statusMenu?.about = { showNativeAboutPanel() }
            delegate.openPrimaryWindow = openPrimaryWindow
            delegate.statusMenu?.open = openPrimaryWindow
            delegate.statusMenu?.controls = { store.showStreamControls() }
            delegate.statusMenu?.settings = {
                openSettings(); NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@MainActor func nativeLegalNoticesURL() -> URL {
    let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MoonlightLGEngine.app/Contents/Resources/Legal/index.html")
    return FileManager.default.fileExists(atPath: bundled.path) ? bundled
        : URL(string: "https://github.com/th3d3ck3r/moonlight-native-glass/blob/moonlightlg-v1.3.2.0/docs/THIRD_PARTY_NOTICES.md")!
}

// Keep author and engine attribution across builds. About displays the app
// version/channel from bundle metadata, separately from the engine version.
@MainActor func showNativeAboutPanel() {
    NativeCrimsonTheme.apply(NativeCrimsonTheme.enabled)
    let engineBundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MoonlightLGEngine.app"))
    let engineVersion = engineBundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "6.2.0"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let credits = NSMutableAttributedString(
        string: "Moonlight Qt \(engineVersion) streaming engine\nGPL-3.0 · WITHOUT ANY WARRANTY\nLicenses & Notices\n\nMoonlightLG created and maintained by Th3D3ck3r\nSwiftUI/AppKit interface\n\nBased on Moonlight Qt and moonlight-common-c by the Moonlight developers and contributors.\n\nUses Qt, SDL, FFmpeg, Opus, OpenSSL, libplacebo, MoltenVK and other open-source components.\nQt © The Qt Company Ltd. and contributors.\nOriginal copyright and license notices are preserved.\n\nFree software under GNU GPL version 3. You may redistribute and modify it under those terms.\nProvided WITHOUT ANY WARRANTY.\n\nCorresponding Source\nGitHub Repository",
        attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                     .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
    for (label, url) in [("GitHub Repository", URL(string: "https://github.com/th3d3ck3r/moonlight-native-glass")!),
                         ("Licenses & Notices", nativeLegalNoticesURL()),
                         ("Corresponding Source", URL(string: "https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/moonlightlg-v1.3.2.0/MoonlightLG-1.3.2.0-source.tar.gz")!)] {
        credits.addAttributes([.link: url,
                           .foregroundColor: NativeCrimsonTheme.enabled ? NSColor(srgbRed: 0.95, green: 0.19, blue: 0.32, alpha: 1) : NSColor.linkColor,
                           .underlineStyle: NSUnderlineStyle.single.rawValue],
                          range: (credits.string as NSString).range(of: label))
    }
    NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: "MoonlightLG",
        .applicationVersion: MoonlightLGVersion.current.display,
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

