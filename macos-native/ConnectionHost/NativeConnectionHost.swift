import AppKit
import SwiftUI

private typealias ConnectionAction = @convention(c) (Int32) -> Void
@MainActor private final class ConnectionHostModel: ObservableObject {
    @Published var journey: ConnectionJourney
    @Published var canRetry = false
    let action: ConnectionAction
    init(host: String, game: String, action: @escaping ConnectionAction) {
        self.action = action
        journey = ConnectionJourney(computer: Computer(id: host, name: host, online: true, unknown: false,
            paired: true, runningApp: 0, address: "", localAddress: "", serverVersion: "", gpu: "", supported: true, apps: []),
            game: Game(id: 1, name: game, hdr: false, hidden: false, artwork: ""))
    }
}
@MainActor private struct ConnectionHostRoot: View {
    @ObservedObject var model: ConnectionHostModel
    var body: some View {
        NativeConnectionView(journey: model.journey, canRetry: model.canRetry,
            cancel: { model.action(2) }, proceed: {
                guard model.journey.phase == .connected else { return }
                model.journey.phase = .entering; model.journey.detail = "Opening stream…"
                model.action(1)
            }, retry: { model.action(3) })
            .environment(\.crimsonGlassEnabled, UserDefaults(suiteName: NativeCrimsonTheme.suite)?.object(forKey: NativeCrimsonTheme.key) as? Bool ?? true)
    }
}
// Keep SDL's native content view and delegate intact. The hosting view is an
// ordinary temporary subview, removed before decoder/input/fullscreen entry.
private final class ConnectionCloseDelegate: NSObject, NSWindowDelegate {
    var original: NSWindowDelegate?
    let action: ConnectionAction
    init(original: NSWindowDelegate?, action: @escaping ConnectionAction) { self.original = original; self.action = action }
    func windowShouldClose(_ sender: NSWindow) -> Bool { action(2); return false }
    override func responds(to selector: Selector!) -> Bool { super.responds(to: selector) || (original?.responds(to: selector) ?? false) }
    override func forwardingTarget(for selector: Selector!) -> Any? { original }
}
@MainActor private var connectionHost: (window: NSWindow, view: NSView, model: ConnectionHostModel, delegate: ConnectionCloseDelegate, zoomEnabled: Bool)?

@MainActor @_cdecl("MLConnectionAttach")
public func connectionAttach(_ raw: UnsafeMutableRawPointer, _ host: UnsafePointer<CChar>, _ game: UnsafePointer<CChar>, _ action: @escaping @convention(c) (Int32) -> Void) {
    connectionDetach()
    let window = Unmanaged<NSWindow>.fromOpaque(raw).takeUnretainedValue()
    guard let content = window.contentView else { return }
    let model = ConnectionHostModel(host: String(cString: host), game: String(cString: game), action: action)
    let view = NSHostingView(rootView: ConnectionHostRoot(model: model))
    view.frame = content.bounds; view.autoresizingMask = [.width, .height]
    view.identifier = NSUserInterfaceItemIdentifier("stream-connection-host")
    content.addSubview(view, positioned: .above, relativeTo: nil)
    let delegate = ConnectionCloseDelegate(original: window.delegate, action: action)
    window.delegate = delegate
    let zoom = window.standardWindowButton(.zoomButton)?.isEnabled ?? true
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    connectionHost = (window, view, model, delegate, zoom)
}
@MainActor @_cdecl("MLConnectionUpdate")
public func connectionUpdate(_ message: UnsafePointer<CChar>, _ phase: Int32) {
    guard let model = connectionHost?.model else { return }
    let text = String(cString: message)
    if phase == 1 {
        model.journey.phase = .connected; model.journey.connectedAt = Date()
        model.journey.detail = "Connected · Awaiting Continue"
    } else if phase == 2 {
        model.journey.phase = .failed; model.journey.error = text; model.journey.detail = "Connection failed"
        model.canRetry = false
    } else if phase == 3 { model.canRetry = true }
    else if model.journey.phase == .connecting { model.journey.detail = text }
}
@MainActor @_cdecl("MLConnectionDetach")
public func connectionDetach() {
    guard let host = connectionHost else { return }
    if host.window.delegate === host.delegate { host.window.delegate = host.delegate.original }
    host.window.standardWindowButton(.zoomButton)?.isEnabled = host.zoomEnabled
    host.view.removeFromSuperview()
    connectionHost = nil
}
