import AppKit

/// Runtime bridge used by the Qt/SDL owner. Controls and stream actions remain
/// native; this view owns only the decorative renderer and its visibility clock.
@objc(MLTouchBarAnimationBridge)
final class NativeTouchBarAnimationBridge: NSView {
    private let strip = MoonlightLGTouchBarStripView(frame: .zero)
    override init(frame: NSRect) {
        super.init(frame: frame)
        strip.frame = bounds; strip.autoresizingMask = [.width, .height]
        addSubview(strip)
        strip.setStreaming(true)
    }
    required init?(coder: NSCoder) { return nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    @objc func setPresentationActive(_ active: Bool) { strip.setPresentationActive(active) }
    @objc func setStreaming(_ streaming: Bool) { strip.setStreaming(streaming) }
    @objc func showConnectionState(_ state: Int) {
        switch state {
        case 1: strip.show(.connecting)
        case 2, 3: strip.show(.connected)
        case 4: strip.show(.failed)
        default: strip.show(.idle)
        }
    }
}
