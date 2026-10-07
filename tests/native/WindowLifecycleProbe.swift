// CI-only lifecycle probe: separate SwiftUI scene failure from WindowServer failure.
import AppKit
import SwiftUI

final class ProbeDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        #if APPKIT_PROBE
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 600, height: 400), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window?.title = "AppKit Window Probe"
        window?.contentView = NSHostingView(rootView: Text("Native window lifecycle probe").padding(40))
        window?.makeKeyAndOrderFront(nil)
        #endif
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            #if APPKIT_PROBE
            let name = "appkit"
            #else
            let name = "swiftui"
            #endif
            let report = NSApp.windows.map { "\($0.title) visible=\($0.isVisible) id=\($0.windowNumber)" }.joined(separator: "\n")
            try? ("windows=\(NSApp.windows.count)\n" + report).write(toFile: "/tmp/moonlight-probe-\(name).log", atomically: true, encoding: .utf8)
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                let number = window.windowNumber
                DispatchQueue.global().async {
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    p.arguments = ["-x", "-l", String(number), "/tmp/moonlight-probe-\(name).png"]
                    let errors = Pipe(); p.standardError = errors
                    try? p.run(); p.waitUntilExit()
                    let diagnostic = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    try? "status=\(p.terminationStatus) \(diagnostic)".write(toFile: "/tmp/moonlight-probe-\(name)-capture.log", atomically: true, encoding: .utf8)
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                }
            } else { NSApp.terminate(nil) }
        }
    }
}
#if APPKIT_PROBE
@main enum AppKitProbe {
    static func main() {
        let app = NSApplication.shared
        let delegate = ProbeDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
#else
@main struct SwiftUIProbe: App {
    @NSApplicationDelegateAdaptor(ProbeDelegate.self) var delegate
    var body: some Scene { WindowGroup("SwiftUI Window Probe") { Text("Native window lifecycle probe").padding(40).frame(width: 600, height: 400) } }
}
#endif
