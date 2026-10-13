import AppKit
import SwiftUI
import IOKit

private enum SettingsPane: String, CaseIterable, Identifiable {
    case appearance = "Appearance", video = "Video", audio = "Audio", recording = "Recording", input = "Input", network = "Network", advanced = "Advanced", overlay = "Overlay", shortcuts = "Shortcuts"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .appearance: "paintpalette"; case .video: "display"; case .audio: "speaker.wave.2"; case .recording: "record.circle"; case .input: "gamecontroller"; case .network: "network"; case .advanced: "slider.horizontal.3"; case .overlay: "rectangle.on.rectangle"; case .shortcuts: "keyboard" }
    }
    var keys: [String] {
        switch self {
        case .video: [ "fps", "bitrateKbps", "autoAdjustBitrate", "videoCodecConfig", "videoDecoderSelection", "rendererSelection", "enableHdr", "enableYUV444", "windowMode", "framePacing", "enableVsync"]
        case .audio: ["audioConfig", "playAudioOnHost", "muteOnFocusLoss"]
        case .input: ["multiController", "gamepadMouse", "backgroundGamepad", "swapFaceButtons", "absoluteMouseMode", "absoluteTouchMode", "swapMouseButtons", "reverseScrollDirection", "captureSysKeysMode"]
        case .network: ["enableMdns", "detectNetworkBlocking", "connectionWarnings"]
        case .appearance, .overlay, .shortcuts, .recording: []
        case .advanced: ["gameOptimizations", "quitAppAfter", "configurationWarnings", "showPerformanceOverlay", "keepAwake", "unlockBitrate", "richPresence"]
        }
    }
}

struct NativeSettingsView: View {
    @ObservedObject var store: EngineStore
    @AppStorage(NativeCrimsonTheme.key) private var crimson = true
    @State private var pane = SettingsPane.video
    @State private var nativeSize: VideoResolution?
    @State private var choseNative = false
    var body: some View {
        VStack(spacing: 0) {
            if store.preview { Label("Design preview · Sample settings", systemImage: "photo").font(.caption).foregroundStyle(.secondary).padding(.top, 10) }
            Picker("Settings", selection: $pane) { ForEach(SettingsPane.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().padding(20)
            if store.fields.isEmpty && pane != .overlay && pane != .shortcuts && pane != .appearance && pane != .recording {
                ContentUnavailableView("Settings Unavailable", systemImage: "gearshape", description: Text("Open the main window and connect to the streaming engine first."))
            } else {
                Form {
                    if pane != .overlay && pane != .shortcuts && pane != .appearance && pane != .recording {
                        Section(pane.rawValue) {
                            if pane == .video { resolutionPicker }
                            ForEach(pane.keys.compactMap { key in store.fields.first { $0.id == key } }) { field in preference(field) }
                        }
                        .disabled(!store.ready || store.streamActive || store.pairing != nil)
                    }
                    if pane == .appearance {
                        Section("Appearance") {
                            Toggle("Crimson Glass", isOn: $crimson).accessibilityIdentifier("crimson-glass-toggle")
                            Text("Near-black surfaces, crimson accents and matching moon artwork. Native Liquid Glass remains active on supported macOS versions. Turn off to use the original appearance.").foregroundStyle(.secondary)
                        }
                    }
                    if pane == .recording { RecordingSettings().disabled(store.streamActive) }
                    if pane == .overlay { OverlaySettings() }
                    if pane == .shortcuts { ShortcutSettings() }
                    if pane == .video {
                        Section {
                            Text("Automatic selections use Moonlight Qt's normal capability checks. HDR and codecs depend on your Mac, display and host.").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    if pane == .input {
                        Section { Text("Hide the stream window with Close Stream Window (Control–Option–Shift–Q by default). End the stream with Disconnect or Start + Select + L1 + R1. Disconnect and Exit also quits the host game. In the library, use the D-pad to select games, A to launch, and shoulder buttons to switch computers.").foregroundStyle(.secondary) }
                    }
                    if pane == .network {
                        Section {
                            Button(store.testingConnection ? "Testing Internet Streaming Ports…" : "Test Internet Streaming Ports") { store.testConnection() }
                                .disabled(store.testingConnection)
                            Button("Open Local Network Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork") { NSWorkspace.shared.open(url) }
                            }
                            Text("Allow MoonlightLG to access your local network. Host networking and pairing are handled by the Moonlight Qt engine.").foregroundStyle(.secondary)
                        }
                        .disabled(!store.ready || store.streamActive || store.pairing != nil)
                    }
                }.formStyle(.grouped)
                    .scrollContentBackground(crimson ? .hidden : .automatic)
            }
            Divider()
            Text(store.streamActive ? "Stream settings are locked while streaming. Overlay controls remain available." : "Changes save automatically. App updates are manual.")
                .font(.caption).foregroundStyle(.secondary).padding(12)
        }
        .crimsonGlassTheme()
        .background(NativeWindowAccessor { store.settingsWindow = $0; $0?.identifier = NSUserInterfaceItemIdentifier("native-settings"); $0?.setAccessibilityIdentifier("native-settings")
            if store.preview, let window = $0 { DispatchQueue.main.async { window.makeKeyAndOrderFront(nil) } } }.frame(width: 0, height: 0))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification)) { notification in
            if let window = notification.object as? NSWindow, window === store.settingsWindow { refreshNativeResolution() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in refreshNativeResolution() }
        .onAppear {
            refreshNativeResolution()
            guard store.preview, let screen = nativeArgument("--preview-screen") else { return }
            let name = screen.replacingOccurrences(of: "settings-", with: "").capitalized
            pane = screen == "settings-overlay" ? .overlay : (SettingsPane(rawValue: name) ?? .video)
        }
        .alert(item: Binding(get: { store.message?.settingsScene == true ? store.message : nil }, set: { store.message = $0 })) { message in
            Alert(title: Text(message.title), message: Text(message.detail), dismissButton: .default(Text("OK")))
        }
    }
    private struct VideoResolution: Equatable {
        let width: Int
        let height: Int
        var id: String { "\(width)x\(height)" }
    }
    private var savedResolution: VideoResolution {
        VideoResolution(width: (store.values["width"] as? NSNumber)?.intValue ?? 1920,
                        height: (store.values["height"] as? NSNumber)?.intValue ?? 1080)
    }
    private var presets: [(String, VideoResolution)] {
        [("720p", VideoResolution(width: 1280, height: 720)),
         ("1080p", VideoResolution(width: 1920, height: 1080)),
         ("1440p", VideoResolution(width: 2560, height: 1440)),
         ("4K", VideoResolution(width: 3840, height: 2160))]
    }
    private var selectedResolution: String {
        if let nativeSize, nativeSize == savedResolution,
           choseNative || !presets.contains(where: { $0.1 == savedResolution }) { return "native" }
        return savedResolution.id
    }
    private var resolutionPicker: some View {
        Picker("Resolution", selection: Binding(get: { selectedResolution }, set: { choice in
            let size = choice == "native" ? nativeSize : presets.first(where: { $0.1.id == choice })?.1
            guard let size else { return }
            choseNative = choice == "native"
            if size != savedResolution { store.setResolution(width: size.width, height: size.height) }
        })) {
            ForEach(presets, id: \.0) { name, size in Text(name).tag(size.id) }
            Text(nativeSize.map { "Native (\($0.width) × \($0.height))" } ?? "Native (Unavailable)")
                .tag("native").disabled(nativeSize == nil)
            if !presets.contains(where: { $0.1 == savedResolution }), nativeSize != savedResolution {
                Text("Custom (\(savedResolution.width) × \(savedResolution.height))").tag(savedResolution.id)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("resolution-picker")
        .help("Native uses the monitor containing this Settings window. The selected dimensions are saved for future streams.")
    }
    private func refreshNativeResolution() {
        let screen = store.settingsWindow?.screen ?? NSScreen.main
        let displayID = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        // Match stock Moonlight's native-mode detection, rather than logical
        // points or a scaled Retina framebuffer that can exceed panel resolution.
        let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] ?? []
        guard let mode = modes.first(where: { ($0.ioFlags & UInt32(kDisplayModeNativeFlag)) != 0 }),
              (320...16384).contains(mode.width), (240...16384).contains(mode.height) else {
            nativeSize = nil
            return
        }
        nativeSize = VideoResolution(width: mode.width, height: mode.height)
    }
    @ViewBuilder private func preference(_ field: PreferenceField) -> some View {
        if field.boolean {
            Toggle(label(field.id), isOn: Binding(get: { store.values[field.id] as? Bool ?? false }, set: { store.set(field.id, $0) }))
        } else if !field.choices.isEmpty {
            Picker(label(field.id), selection: Binding(get: { (store.values[field.id] as? NSNumber)?.intValue ?? 0 }, set: { store.set(field.id, $0) })) {
                ForEach(field.choices) { Text(choiceLabel($0.name)).tag($0.value) }
            }
        } else {
            let bounds = range(field.id)
            LabeledContent(label(field.id)) {
                TextField("Value", value: Binding(get: { (store.values[field.id] as? NSNumber)?.intValue ?? bounds.lowerBound }, set: { value in if bounds.contains(value) { store.set(field.id, value) } }), format: .number.grouping(.never))
                    .labelsHidden().textFieldStyle(.roundedBorder).frame(width: 100).multilineTextAlignment(.trailing)
            }
        }
    }
    private func range(_ key: String) -> ClosedRange<Int> {
        switch key { case "width": 320...16384; case "height": 240...16384; case "fps": 10...480; case "bitrateKbps": 500...((store.values["unlockBitrate"] as? Bool ?? false) ? 500000 : 150000); default: 0...500000 }
    }
    private func label(_ key: String) -> String {
        let names = ["width": "Resolution Width (pixels)", "height": "Resolution Height (pixels)", "fps": "Frame Rate (FPS)", "bitrateKbps": "Bitrate (Kbps)",
            "autoAdjustBitrate": "Adjust Bitrate with Resolution", "videoCodecConfig": "Video Codec", "videoDecoderSelection": "Video Decoder", "rendererSelection": "Video Renderer", "enableHdr": "HDR", "enableYUV444": "4:4:4 Chroma", "windowMode": "Stream Display Mode", "framePacing": "Frame Pacing", "enableVsync": "Vertical Sync",
            "audioConfig": "Audio Channels", "playAudioOnHost": "Play Audio on Host", "muteOnFocusLoss": "Mute When App Is Inactive", "multiController": "Multiple Controllers", "gamepadMouse": "Controller Mouse Emulation", "backgroundGamepad": "Controller Input in Background", "swapFaceButtons": "Swap Controller Face Buttons", "absoluteMouseMode": "Absolute Mouse Position", "absoluteTouchMode": "Absolute Touch Position", "swapMouseButtons": "Swap Mouse Buttons", "reverseScrollDirection": "Reverse Scroll Direction", "captureSysKeysMode": "Capture System Shortcuts", "enableMdns": "Discover Computers Automatically", "detectNetworkBlocking": "Detect Blocked Network Ports", "connectionWarnings": "Connection Warnings", "gameOptimizations": "Optimize Game Settings on Host", "quitAppAfter": "Quit Host App After Disconnecting", "configurationWarnings": "Configuration Warnings", "showPerformanceOverlay": "Performance Overlay", "keepAwake": "Keep Mac Awake While Streaming", "unlockBitrate": "Allow Higher Bitrates", "richPresence": "Discord Activity"]
        return names[key] ?? key
    }
    private func choiceLabel(_ key: String) -> String {
        let labels = ["VCC_AUTO": "Automatic", "VCC_FORCE_H264": "H.264", "VCC_FORCE_HEVC": "HEVC", "VCC_FORCE_AV1": "AV1",
            "VDS_AUTO": "Automatic", "VDS_FORCE_HARDWARE": "Hardware", "VDS_FORCE_SOFTWARE": "Software",
            "RS_AUTO": "Automatic", "RS_VULKAN": "Vulkan", "RS_METAL": "Metal", "RS_AVSBDL": "AVSampleBufferDisplayLayer",
            "WM_FULLSCREEN": "Full Screen", "WM_FULLSCREEN_DESKTOP": "Borderless Full Screen", "WM_WINDOWED": "Windowed",
            "AC_STEREO": "Stereo", "AC_51_SURROUND": "5.1 Surround", "AC_71_SURROUND": "7.1 Surround", "CSK_OFF": "Never", "CSK_FULLSCREEN": "Full Screen Only", "CSK_ALWAYS": "Always"]
        return labels[key] ?? key
    }
}

private struct OverlaySettings: View {
    private static let defaults = UserDefaults(suiteName: "com.moonlight-stream.NativeGlass.Overlay")!
    @AppStorage("streamStatsGraphs", store: Self.defaults) private var streamStatsGraphs = true
    @AppStorage("scale", store: Self.defaults) private var scale = 1.0
    @AppStorage("position", store: Self.defaults) private var position = "topLeft"
    @State private var buttons = Self.savedButtons()
    private static func savedButtons() -> [Int] {
        guard let saved = defaults.array(forKey: "buttons") as? [Int] else { return [2,3,1,6,7] }
        var result: [Int] = []
        for id in saved where (0..<11).contains(id) && !result.contains(id) { result.append(id) }
        return result
    }
    private let names = ["Close Stream Window", "Release / Capture Input", "Full Screen", "Statistics", "Mouse Mode", "Cursor Visibility", "Minimize", "Paste Clipboard", "Pointer Region Lock", "Disconnect and Exit", "Keyboard Capture", "Show / Hide Controls"]
    var body: some View {
        Section("Statistics Overlay") {
            Toggle("Show Graphs", isOn: $streamStatsGraphs).accessibilityIdentifier("stream-statistics-graphs")
            HStack { Text("Size"); Slider(value: $scale, in: 0.8...1.5, step: 0.05); Text("\(Int(scale * 100))%").monospacedDigit().frame(width: 46) }
            Picker("Position", selection: $position) {
                Text("Top Left").tag("topLeft"); Text("Top Right").tag("topRight")
                Text("Bottom Left").tag("bottomLeft"); Text("Bottom Right").tag("bottomRight")
            }
            Text("Statistics use Crimson Glass cards. Graphs show the last minute. During captured gameplay the panel passes clicks through; release input to use its Graphs toggle or scroll.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Stream Controls") {
            Text("Set its show/hide binding in Shortcuts, or use the Moonlight menu bar menu. The visible pointer stays inside the stream window while controls are open. Done restores input; Disconnect ends the stream.").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Choose and Order Buttons") {
                ForEach(buttons, id: \.self) { id in
                    HStack {
                        Text(names[id]); Spacer()
                        Button { move(id, by: -1) } label: { Image(systemName: "arrow.up") }.disabled(buttons.first == id).help("Move \(names[id]) earlier")
                        Button { move(id, by: 1) } label: { Image(systemName: "arrow.down") }.disabled(buttons.last == id).help("Move \(names[id]) later")
                        Button { buttons.removeAll { $0 == id }; saveButtons() } label: { Image(systemName: "minus.circle") }.help("Remove \(names[id])")
                    }
                }
                Menu("Add Button") { ForEach((0..<11).filter { !buttons.contains($0) }, id: \.self) { id in Button(names[id]) { buttons.append(id); saveButtons() } } }
            }
            .accessibilityIdentifier("overlay-button-customization")
            Button("Restore Overlay Defaults") {
                scale = 1; position = "topLeft"; streamStatsGraphs = true; buttons = [2,3,1,6,7]
                saveButtons(); notify()
            }
        }
        .onChange(of: streamStatsGraphs) { _, _ in notify() }
        .onChange(of: scale) { _, _ in notify() }
        .onChange(of: position) { _, _ in notify() }
    }
    private func move(_ id: Int, by delta: Int) {
        guard let index = buttons.firstIndex(of: id), buttons.indices.contains(index + delta) else { return }
        buttons.swapAt(index, index + delta); saveButtons()
    }
    private func saveButtons() { Self.defaults.set(buttons, forKey: "buttons"); notify() }
    private func notify() {
        Self.defaults.synchronize()
        DistributedNotificationCenter.default().postNotificationName(Notification.Name("com.moonlight-stream.NativeGlass.overlaySettingsChanged"), object: nil, userInfo: nil, deliverImmediately: true)
    }
}

private struct ShortcutSettings: View {
    private static let defaults = UserDefaults(suiteName: "com.moonlight-stream.NativeGlass.Overlay")!
    @State private var shortcuts = (Self.defaults.dictionary(forKey: "shortcuts") as? [String: [String: Any]]) ?? [:]
    @State private var shortcutError: String?
    private let names = ["Close Stream Window", "Release / Capture Input", "Full Screen", "Statistics", "Mouse Mode", "Cursor Visibility", "Minimize", "Paste Clipboard", "Pointer Region Lock", "Disconnect and Exit", "Keyboard Capture", "Show / Hide Controls", "Disconnect"]
    private let defaultKeys = Array("qzxsmcdvlekob").map(String.init)
    var body: some View {
        Section("Stream Shortcuts") {
            ForEach(0..<names.count, id: \.self) { id in
                VStack(alignment: .leading) {
                    Text(names[id])
                    HStack {
                        Picker("Modifiers", selection: Binding(get: { modifiers(id) }, set: { update(id, key: key(id), modifiers: $0) })) {
                            Text("⌃⌥⇧").tag(7); Text("⌘⌥⇧").tag(14); Text("⌃⌥").tag(3); Text("⌘⌥").tag(10)
                        }.labelsHidden()
                        Picker("Key", selection: Binding(get: { key(id) }, set: { update(id, key: $0, modifiers: modifiers(id)) })) {
                            ForEach(Array("abcdefghijklmnopqrstuvwxyz").map(String.init), id: \.self) { Text($0.uppercased()).tag($0) }
                        }.labelsHidden()
                    }
                }
            }
            if let shortcutError { Text(shortcutError).foregroundStyle(.red) }
            Text("These shortcuts control Moonlight locally. Ordinary keys still go to your host. Duplicate bindings are rejected.").font(.caption).foregroundStyle(.secondary)
        }
        Section {
            Button("Restore Shortcut Defaults") {
                shortcuts = [:]; shortcutError = nil
                Self.defaults.removeObject(forKey: "shortcuts"); notify()
            }
        }
    }
    private func key(_ id: Int) -> String { shortcuts[String(id)]?["key"] as? String ?? defaultKeys[id] }
    private func modifiers(_ id: Int) -> Int { shortcuts[String(id)]?["modifiers"] as? Int ?? 7 }
    private func update(_ id: Int, key: String, modifiers: Int) {
        guard !(0..<names.count).contains(where: { $0 != id && self.key($0) == key && self.modifiers($0) == modifiers }) else { shortcutError = "This shortcut is already assigned to another stream action."; return }
        shortcuts[String(id)] = ["key": key, "modifiers": modifiers]
        Self.defaults.set(shortcuts, forKey: "shortcuts"); shortcutError = nil; notify()
    }
    private func notify() {
        Self.defaults.synchronize()
        DistributedNotificationCenter.default().postNotificationName(Notification.Name("com.moonlight-stream.NativeGlass.overlaySettingsChanged"), object: nil, userInfo: nil, deliverImmediately: true)
    }
}

private struct RecordingSettings: View {
    private static let defaults = UserDefaults(suiteName: "com.moonlight-stream.NativeGlass.Recording")!
    @AppStorage("enabled", store: defaults) private var enabled = false
    @AppStorage("mode", store: defaults) private var mode = 0
    @AppStorage("codec", store: defaults) private var codec = 1
    @AppStorage("resolution", store: defaults) private var resolution = 0
    @AppStorage("fps", store: defaults) private var fps = 0
    @AppStorage("bitrate", store: defaults) private var bitrate = 30
    @AppStorage("replay", store: defaults) private var replay = false
    @AppStorage("replaySeconds", store: defaults) private var seconds = 60
    @AppStorage("directory", store: defaults) private var directory = ""
    var body: some View {
        Section("Recording") {
            Toggle("Enable Recording Controls", isOn: $enabled).accessibilityIdentifier("recording-enabled")
            Text("Use Record / Stop and Save Instant Replay in the stream title bar. Changes apply to the next stream.").foregroundStyle(.secondary)
        }
        Section("Video Encoding") {
            Picker("Mode", selection: $mode) {
                Text("Original Stream Quality").tag(0)
                Text("Custom Hardware Encoding").tag(1)
            }
            if mode == 0 {
                Text("Copies H.264 or HEVC video without a second video encode. Resolution, frame rate and bitrate follow the host stream. Recording and replay request a host keyframe when needed, with limited retries. A keyframe can briefly increase bandwidth; no second video encode is performed.").foregroundStyle(.secondary)
            } else {
                Picker("Codec", selection: $codec) { Text("H.264").tag(1); Text("HEVC").tag(2) }
                Picker("Resolution", selection: $resolution) {
                    Text("Stream Resolution").tag(0); Text("720p").tag(720); Text("1080p").tag(1080); Text("1440p").tag(1440); Text("4K").tag(2160)
                }
                Picker("Frame Rate", selection: $fps) { Text("Stream Frame Rate").tag(0); Text("30 fps").tag(30); Text("60 fps").tag(60); Text("120 fps").tag(120) }
                Stepper("Bitrate: \(bitrate) Mbps", value: $bitrate, in: 5...150, step: 5)
                Text("Requires the VideoToolbox decoder and an available hardware encoder. Support is checked when recording starts. SDR only in this U build; use Original Stream Quality for HDR. The app reports unsupported settings and does not fall back to software encoding.").foregroundStyle(.secondary)
            }
        }.disabled(!enabled)
        Section("Instant Replay") {
            Toggle("Buffer Instant Replay", isOn: $replay)
            Picker("Replay Length", selection: $seconds) { Text("30 seconds").tag(30); Text("60 seconds").tag(60); Text("5 minutes").tag(300) }
                .disabled(!replay)
            Text("30/60 seconds use up to 256 MB of memory. Five minutes uses a disk cache capped at 2 GB. A save can temporarily retain another buffer. Clips begin at a complete keyframe, so the available duration can be shorter than requested.").foregroundStyle(.secondary)
        }.disabled(!enabled)
        Section("Save Location") {
            LabeledContent("Folder", value: directory.isEmpty ? "Movies/MoonlightLG" : directory)
            Button("Choose Folder…") {
                let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
                if panel.runModal() == .OK, let url = panel.url { directory = url.path }
            }
            Button("Show Recordings") {
                let url = directory.isEmpty ? FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].appendingPathComponent("MoonlightLG") : URL(fileURLWithPath: directory)
                NSWorkspace.shared.open(url)
            }
            Text("Audio is captured independently of local mute. Movies are written in fragments so a partial file may remain playable after an interruption. Disk limits and writer errors stop recording while the stream continues.").foregroundStyle(.secondary)
        }
    }
}
