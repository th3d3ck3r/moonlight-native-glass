import AppKit
import SwiftUI

// Presentation-only preferences; the engine reads the same suite for its native
// glass panels. No streaming preferences or input/window geometry are changed.
enum NativeCrimsonTheme {
    static let key = "crimsonGlass"
    static let suite = "com.moonlight-stream.NativeGlass.Overlay"
    static let changed = Notification.Name("com.moonlight-stream.NativeGlass.overlaySettingsChanged")
    static var enabled: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    static let accent = Color(red: 0.95, green: 0.19, blue: 0.32)
    static let ruby = Color(red: 0.57, green: 0.025, blue: 0.15)
    static let highlight = Color(red: 1, green: 0.46, blue: 0.57)
    static let surface = Color(red: 0.045, green: 0.025, blue: 0.035)
    static let card = Color(red: 0.10, green: 0.055, blue: 0.07)
    static let windowColor = NSColor(srgbRed: 0.045, green: 0.025, blue: 0.035, alpha: 1)
    static var bootResource: URL? {
        Bundle.main.url(forResource: enabled ? "crimson-moon" : "boot-moon", withExtension: "png")
    }
    @MainActor static func apply(_ enabled: Bool) {
        // Canvas previews must not restyle Xcode's own process or Dock icon.
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        NSApp.appearance = enabled ? NSAppearance(named: .darkAqua) : nil
        let name = enabled ? "crimson" : "moonlight"
        if let url = Bundle.main.url(forResource: name, withExtension: "icns"), let image = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = image
        }
        if let defaults = UserDefaults(suiteName: suite), defaults.object(forKey: key) as? Bool != enabled {
            defaults.set(enabled, forKey: key); defaults.synchronize()
            DistributedNotificationCenter.default().postNotificationName(changed, object: nil, userInfo: nil, deliverImmediately: true)
        }
    }
}

private struct CrimsonEnvironmentKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var crimsonGlassEnabled: Bool {
        get { self[CrimsonEnvironmentKey.self] }
        set { self[CrimsonEnvironmentKey.self] = newValue }
    }
}

private struct CrimsonWindowAppearance: NSViewRepresentable {
    let enabled: Bool
    final class WindowView: NSView {
        var enabled = true
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            guard let window else { return }
            window.appearance = enabled ? NSAppearance(named: .darkAqua) : nil
            window.backgroundColor = enabled ? NativeCrimsonTheme.windowColor : .windowBackgroundColor
            // Extend the same background beneath the real native toolbar.
            // Keep the toolbar, traffic lights and glass controls intact.
            if enabled || window.titleVisibility != .hidden { window.titlebarAppearsTransparent = enabled }
        }
    }
    func makeNSView(context: Context) -> WindowView { let v = WindowView(); v.enabled = enabled; return v }
    func updateNSView(_ view: WindowView, context: Context) { view.enabled = enabled; view.apply() }
}

private struct CrimsonThemeModifier: ViewModifier {
    @AppStorage(NativeCrimsonTheme.key) private var enabled = true
    func body(content: Content) -> some View {
        content
            .environment(\.crimsonGlassEnabled, enabled)
            .accentColor(enabled ? NativeCrimsonTheme.accent : nil)
            .tint(enabled ? NativeCrimsonTheme.accent : Color.accentColor)
            .preferredColorScheme(enabled ? .dark : nil)
            .containerBackground(enabled ? NativeCrimsonTheme.surface : Color(nsColor: .windowBackgroundColor), for: .window)
            .background(CrimsonWindowAppearance(enabled: enabled).frame(width: 0, height: 0))
            .onAppear { NativeCrimsonTheme.apply(enabled) }
            .onChange(of: enabled) { _, value in NativeCrimsonTheme.apply(value) }
    }
}

extension View {
    func crimsonGlassTheme() -> some View { modifier(CrimsonThemeModifier()) }
}
