import AppKit
import CoreAudio
import AudioToolbox
import Darwin

/// Shared by the frontend and its hosted engine. No shell commands, synthetic
/// media keys, global preferences, or changes to the stream playback gain.
enum NativeMacControls {
    static func outputVolume(_ value: Float? = nil) -> Float? {
        var device = AudioDeviceID(0), bytes = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &bytes, &device) == noErr,
              device != kAudioObjectUnknown else { return nil }
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyVolumeScalar] {
            address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: 0)
            var writable = DarwinBoolean(false)
            guard AudioObjectHasProperty(device, &address),
                  AudioObjectIsPropertySettable(device, &address, &writable) == noErr, writable.boolValue else { continue }
            var current = Float(0); bytes = UInt32(MemoryLayout<Float>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &bytes, &current) == noErr,
                  current.isFinite else { continue }
            if let value {
                guard value.isFinite else { return nil }
                current = min(1, max(0, value))
                guard AudioObjectSetPropertyData(device, &address, 0, nil, bytes, &current) == noErr else { return nil }
            }
            return current
        }
        return nil
    }
    private static let displayServices = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL)
    static func brightness(_ value: Float? = nil) -> Float? {
        typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32
        guard let handle = displayServices,
              let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
              let setSymbol = dlsym(handle, "DisplayServicesSetBrightness"),
              let display = NSScreen.screens.compactMap({ screen -> CGDirectDisplayID? in
                  guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
                  let id = CGDirectDisplayID(number.uint32Value)
                  return CGDisplayIsBuiltin(id) != 0 ? id : nil
              }).first else { return nil }
        let get = unsafeBitCast(getSymbol, to: Get.self), set = unsafeBitCast(setSymbol, to: Set.self)
        var current = Float(0)
        guard get(display, &current) == 0, current.isFinite else { return nil }
        if let value {
            guard value.isFinite, set(display, min(1, max(0, value))) == 0,
                  get(display, &current) == 0, current.isFinite else { return nil }
        }
        return min(1, max(0, current))
    }
}

/// The owner retains this delegate only for its own full-width presentation.
/// Slider items remain hosted by AppKit, including its touch tracking support.
@objc(MLTouchBarSystemControls)
final class NativeTouchBarSystemControls: NSObject, NSTouchBarDelegate {
    var volume: (Float?) -> Float? = NativeMacControls.outputVolume
    var brightness: (Float?) -> Float? = NativeMacControls.brightness
    private var active = false
    private var sliders: [String: NSSliderTouchBarItem] = [:]
    private var timer: Timer?
    private var popover: NSPopoverTouchBarItem?
    @objc func makeItem() -> NSTouchBarItem {
        if let popover { return popover }
        let item = NSPopoverTouchBarItem(identifier: .init("touch.system"))
        item.collapsedRepresentationLabel = "Mac"
        item.collapsedRepresentationImage = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Mac volume and display brightness")
        item.showsCloseButton = true
        let bar = NSTouchBar(); bar.delegate = self
        bar.defaultItemIdentifiers = [.init("system.volume"), .init("system.brightness"), .init("system.restore")]
        item.popoverTouchBar = bar; popover = item
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        return item
    }
    @objc func setActive(_ value: Bool) {
        active = value
        if !value { popover?.dismissPopover(nil) }
        refresh()
    }
    private var eligible: Bool { active && NSApp.isActive && NSApp.keyWindow != nil }
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier.rawValue == "system.restore" {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "System Strip", target: self, action: #selector(restore))
            button.setAccessibilityLabel("Restore system Control Strip")
            item.view = button; return item
        }
        let item = NSSliderTouchBarItem(identifier: identifier)
        item.label = identifier.rawValue == "system.volume" ? "Mac Volume" : "Brightness"
        item.slider.minValue = 0; item.slider.maxValue = 1; item.slider.isContinuous = true
        item.slider.trackFillColor = NSColor(srgbRed: 0.95, green: 0.19, blue: 0.32, alpha: 1)
        item.slider.setAccessibilityLabel(item.label)
        item.target = self; item.action = #selector(adjust(_:)); sliders[identifier.rawValue] = item
        refresh(); return item
    }
    private func refresh() {
        for (key, item) in sliders {
            let result = eligible ? (key == "system.volume" ? volume(nil) : brightness(nil)) : nil
            item.slider.isEnabled = result != nil
            item.label = (key == "system.volume" ? "Mac Volume" : "Brightness") + (result == nil ? " · Unavailable" : "")
            if let result, item.slider.cell?.isHighlighted != true { item.slider.floatValue = result }
            item.slider.setAccessibilityLabel(item.label)
        }
    }
    @objc private func adjust(_ sender: NSSliderTouchBarItem) {
        guard eligible, sender.slider.isEnabled else { return }
        let result = sender.identifier.rawValue == "system.volume" ? volume(sender.slider.floatValue) : brightness(sender.slider.floatValue)
        if let result { sender.slider.floatValue = result } else { sender.slider.isEnabled = false }
    }
    @objc private func restore() {
        guard eligible, let prefs = UserDefaults(suiteName: "com.moonlight-stream.NativeGlass") else { return }
        prefs.set(false, forKey: "touchBarFullWidth"); prefs.synchronize()
        DistributedNotificationCenter.default().postNotificationName(.init("com.moonlight-stream.NativeGlass.touchBarPresentationChanged"), object: nil, userInfo: nil, deliverImmediately: true)
    }
    @objc func invalidate() {
        active = false; timer?.invalidate(); timer = nil
        popover?.dismissPopover(nil); popover?.popoverTouchBar.delegate = nil
        for item in sliders.values { item.target = nil; item.action = nil }
        sliders.removeAll(); popover = nil
    }
    deinit { timer?.invalidate() }
}

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
