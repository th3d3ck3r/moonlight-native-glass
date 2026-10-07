import AppKit
import SwiftUI
import IOKit

private enum SettingsPane: String, CaseIterable, Identifiable {
    case video = "Video", audio = "Audio", input = "Input", network = "Network", advanced = "Advanced"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .video: "display"; case .audio: "speaker.wave.2"; case .input: "gamecontroller"; case .network: "network"; case .advanced: "slider.horizontal.3" }
    }
    var keys: [String] {
        switch self {
        case .video: [ "fps", "bitrateKbps", "autoAdjustBitrate", "videoCodecConfig", "videoDecoderSelection", "rendererSelection", "enableHdr", "enableYUV444", "windowMode", "framePacing", "enableVsync"]
        case .audio: ["audioConfig", "playAudioOnHost", "muteOnFocusLoss"]
        case .input: ["multiController", "gamepadMouse", "backgroundGamepad", "swapFaceButtons", "absoluteMouseMode", "absoluteTouchMode", "swapMouseButtons", "reverseScrollDirection", "captureSysKeysMode"]
        case .network: ["enableMdns", "detectNetworkBlocking", "connectionWarnings"]
        case .advanced: ["gameOptimizations", "quitAppAfter", "configurationWarnings", "showPerformanceOverlay", "keepAwake", "unlockBitrate", "richPresence"]
        }
    }
}

struct NativeSettingsView: View {
    @ObservedObject var store: EngineStore
    @State private var pane = SettingsPane.video
    @State private var nativeSize: VideoResolution?
    @State private var choseNative = false
    var body: some View {
        VStack(spacing: 0) {
            if store.preview { Label("Design preview · Sample settings", systemImage: "photo").font(.caption).foregroundStyle(.secondary).padding(.top, 10) }
            Picker("Settings", selection: $pane) { ForEach(SettingsPane.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) } }
                .pickerStyle(.segmented).padding(20)
            if store.fields.isEmpty {
                ContentUnavailableView("Settings Unavailable", systemImage: "gearshape", description: Text("Open the main window and connect to the streaming engine first."))
            } else {
                Form {
                    Section(pane.rawValue) {
                        if pane == .video { resolutionPicker }
                        ForEach(pane.keys.compactMap { key in store.fields.first { $0.id == key } }) { field in preference(field) }
                    }
                    if pane == .video {
                        Section {
                            Text("Automatic selections use Moonlight Qt's normal capability checks. HDR and codecs depend on your Mac, display and host.").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    if pane == .input {
                        Section { Text("Disconnect a stream with Control–Option–Shift–Q or Start + Select + L1 + R1. In the library, use the D-pad to select games, A to launch, and shoulder buttons to switch computers.").foregroundStyle(.secondary) }
                    }
                    if pane == .network {
                        Section {
                            Button(store.testingConnection ? "Testing Internet Streaming Ports…" : "Test Internet Streaming Ports") { store.testConnection() }
                                .disabled(store.testingConnection)
                            Button("Open Local Network Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork") { NSWorkspace.shared.open(url) }
                            }
                            Text("Allow Moonlight Native Glass to access your local network. Host networking and pairing are handled by the Moonlight Qt engine.").foregroundStyle(.secondary)
                        }
                    }
                }.formStyle(.grouped)
                    .disabled(!store.ready || store.streamActive || store.pairing != nil)
            }
            Divider()
            Text(store.streamActive ? "Settings are unavailable while streaming." : "Changes save automatically. App updates are manual.")
                .font(.caption).foregroundStyle(.secondary).padding(12)
        }
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
            pane = SettingsPane(rawValue: name) ?? .video
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
