import AppKit
import SwiftUI

/// One serialized read queue per helper; only complete events cross to the UI.
final class EngineChannel {
    let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var decoder = EngineLineDecoder()
    private let readQueue = DispatchQueue(label: "moonlight.native.events")
    var onEvent: (([String: Any]) -> Void)?
    var onExit: ((Int32) -> Void)?
    private var closed = false

    init(executable: URL, arguments: [String]) {
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = executable.deletingLastPathComponent()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

    }
    func start() throws {
        // A blocking pipe reader runs off the UI thread; EOF drains all events
        // before reporting termination. No per-frame polling or UI animation.
        try process.run()
        input.fileHandleForReading.closeFile()
        output.fileHandleForWriting.closeFile()
        readQueue.async { [weak self] in
            guard let self else { return }
            while true {
                let data = self.output.fileHandleForReading.availableData
                if data.isEmpty { break }
                do {
                    for event in try self.decoder.append(data) {
                        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.onEvent?(["event": "error", "message": "The streaming engine returned an invalid response."])
                        self?.stop()
                    }
                    break
                }
            }
            self.process.waitUntilExit()
            let code = self.process.terminationStatus
            DispatchQueue.main.async { [weak self] in self?.onExit?(code) }
        }
    }
    func send(_ request: [String: Any]) throws {
        guard process.isRunning, !closed else { throw CocoaError(.fileWriteUnknown) }
        var data = try JSONSerialization.data(withJSONObject: request)
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    func stop() {
        guard !closed else { return }
        closed = true
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
    }
}

struct NativeMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    var settingsScene = false
}
struct PairingRequest: Identifiable {
    let id = UUID()
    let computer: Computer
    let pin: String
}

@MainActor final class EngineStore: ObservableObject {
    @Published var computers: [Computer] = []
    @Published var values: [String: Any] = [:]
    @Published var fields: [PreferenceField] = []
    @Published var ready = false
    @Published var status = "Starting streaming engine…"
    @Published var message: NativeMessage?
    @Published var pairing: PairingRequest?
    @Published var testingConnection = false
    @Published var addingHost = false
    @Published var streamWindowExists = false
    private var streamWindowToken: String?
    @Published var streamActive = false
    @Published var streamStarted = false
    @Published var quitRequired: String?
    @Published var warnings: [String] = []
    @Published var selectedID: String?
    weak var settingsWindow: NSWindow?
    weak var libraryWindow: NSWindow?
    let preview: Bool
    private var channel: EngineChannel?
    private var stream: EngineChannel?
    private var shuttingDown = false
    private var pendingStream: (Computer, Game)?
    private var hostDeadline: Task<Void, Never>?

    var selected: Computer? { computers.first { $0.id == selectedID } }
    var executable: URL? {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MoonlightEngine.app/Contents/MacOS/Moonlight")
    }

    init(preview: Bool = false) {
        self.preview = preview
        if preview {
            computers = [Computer(id: "preview-computer", name: "Gaming PC", online: true, unknown: false,
                paired: true, runningApp: 0, address: "192.168.1.20", localAddress: "192.168.1.20",
                serverVersion: "Sunshine", gpu: "Gaming GPU", supported: true,
                apps: [Game(id: 1, name: "Desktop", hdr: false, hidden: false, artwork: ""),
                       Game(id: 2, name: "Steam", hdr: true, hidden: false, artwork: "")])]
            let args = CommandLine.arguments
            if let screen = nativeArgument("--preview-screen") {
                if screen == "empty" { computers = [] }
                else if ["offline", "unpaired", "loading"].contains(screen), let host = computers.first {
                    computers = [Computer(id: host.id, name: host.name, online: screen != "offline" && screen != "loading", unknown: screen == "loading",
                        paired: screen != "unpaired", runningApp: 0, address: host.address, localAddress: host.localAddress,
                        serverVersion: host.serverVersion, gpu: host.gpu, supported: true, apps: [])]
                }
            }
            if let path = nativeArgument("--settings-fixture"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                values = event["values"] as? [String: Any] ?? [:]
                fields = (try? decodeEngineValue(event["schema"] ?? [], as: [PreferenceField].self)) ?? []
            }
            selectedID = computers.first?.id
            ready = true
            status = "Design preview — sample computers and games"
        }
    }

    func start() {
        guard !preview, channel == nil, let executable else { return }
        shuttingDown = false
        ready = false
        let helper = EngineChannel(executable: executable, arguments: ["native"])
        helper.onEvent = { [weak self] event in self?.receive(event) }
        helper.onExit = { [weak self, weak helper] code in
            guard let self, self.channel === helper else { return }
            self.ready = false
            self.channel = nil
            if !self.shuttingDown { self.fail("The streaming engine stopped (exit \(code)). Use Refresh to restart it.") }
        }
        channel = helper
        do { try helper.start() } catch { channel = nil; fail("Could not start the bundled streaming engine: \(error.localizedDescription)") }
    }

    private func receive(_ event: [String: Any]) {
        do {
            switch event["event"] as? String {
            case "ready":
                guard event["protocol"] as? Int == 1 else { fail("This app and streaming engine use incompatible protocols."); channel?.stop(); return }
                ready = true; status = "Discovering computers on your local network…"
            case "hosts":
                computers = try decodeEngineValue(event["hosts"] ?? [], as: [Computer].self).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                if selectedID == nil { selectedID = computers.first?.id }
                status = computers.isEmpty ? "Looking for computers…" : "\(computers.count) computer\(computers.count == 1 ? "" : "s")"
            case "settings":
                values = event["values"] as? [String: Any] ?? [:]
                fields = try decodeEngineValue(event["schema"] ?? [], as: [PreferenceField].self)
            case "artwork":
                if let host = event["host"] as? String, let app = event["app"] as? Int, let url = event["url"] as? String,
                   let h = computers.firstIndex(where: { $0.id == host }), let a = computers[h].apps.firstIndex(where: { $0.id == app }) {
                    computers[h].apps[a].artwork = url
                }
            case "hostAdded": addingHost = false; hostDeadline?.cancel()
            case "paired": pairing = nil
            case "connectionTest":
                testingConnection = false
                let result = event["result"] as? Int ?? -1
                let detail = result == 0 ? "Internet streaming ports are reachable. This test does not check your local host or its firewall." : result == -1 ? "The Internet streaming port test was inconclusive. Check your network connection and try again." : "These Internet streaming ports appear blocked: \(event["ports"] as? String ?? "Not reported")."
                message = NativeMessage(title: "Connection Test", detail: detail, settingsScene: settingsWindow?.isKeyWindow == true)
            case "paused":
                if let request = pendingStream { pendingStream = nil; runStream(request.0, game: request.1) }
            case "error": testingConnection = false; addingHost = false; hostDeadline?.cancel(); pairing = nil; fail(event["message"] as? String ?? "The engine could not complete this request.")
            default: break
            }
        } catch { fail("Could not read the engine response: \(error.localizedDescription)") }
    }

    @discardableResult func send(_ action: String, _ data: [String: Any] = [:]) -> Bool {
        guard !preview else { return false }
        var request = data; request["command"] = action
        do { guard let channel else { throw CocoaError(.fileWriteUnknown) }; try channel.send(request); return true }
        catch { fail("Could not send the request to the engine. Use Refresh to reconnect."); return false }
    }
    func requestArtwork(_ computer: Computer, game: Game) {
        guard !streamActive, !preview, game.artwork.isEmpty else { return }
        send("artwork", ["host": computer.id, "app": game.id])
    }
    func testConnection() {
        guard !testingConnection else { return }
        testingConnection = true
        if !send("testConnection") { testingConnection = false }
    }
    func refresh() { if channel == nil { start() } else { send("snapshot") } }
    func add(_ address: String) {
        addingHost = true
        send("addHost", ["address": address])
        hostDeadline?.cancel()
        hostDeadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(35))
            guard !Task.isCancelled, let self, self.addingHost else { return }
            self.addingHost = false
            self.fail("The computer has not responded yet. Check Local Network permission and its address.")
        }
    }
    func pair(_ computer: Computer) {
        guard pairing == nil else { return }
        let pin = String(format: "%04d", Int.random(in: 0...9999))
        pairing = PairingRequest(computer: computer, pin: pin)
        send("pair", ["host": computer.id, "pin": pin])
    }
    func set(_ key: String, _ value: Any) {
        var changes: [String: Any] = [key: value]
        // Match the stock UI: turning off higher bitrates also clamps the value.
        if key == "unlockBitrate", value as? Bool == false {
            changes["bitrateKbps"] = min((values["bitrateKbps"] as? NSNumber)?.intValue ?? 150000, 150000)
        }
        send("settings", ["values": changes])
    }
    func setResolution(width: Int, height: Int) {
        // One transaction preserves the engine's stock automatic bitrate update.
        if preview { values["width"] = width; values["height"] = height; return }
        send("settings", ["values": ["width": width, "height": height]])
    }
    func startStream(_ computer: Computer, game: Game) {
        guard ready, !streamActive, pairing == nil, !addingHost, !preview else { return }
        streamActive = true; streamStarted = false; warnings = []
        status = "Preparing \(game.name)…"
        pendingStream = (computer, game)
        if !send("pause") { pendingStream = nil; streamActive = false }
    }
    private func runStream(_ computer: Computer, game: Game) {
        guard let executable else { streamActive = false; return }
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        let displayID = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        let bounds = CGDisplayBounds(displayID)
        let x = Int(bounds.midX), y = Int(bounds.midY)
        let token = UUID().uuidString
        streamWindowToken = token
        streamWindowExists = false
        let helper = EngineChannel(executable: executable, arguments: ["native", "stream", computer.id, String(game.id), String(x), String(y), token])
        helper.onEvent = { [weak self] event in
            guard let self else { return }
            switch event["event"] as? String {
            case "stage": self.status = event["message"] as? String ?? "Starting stream…"
            case "windowOpened": self.streamWindowExists = true
            case "windowClosed": self.streamWindowExists = false
            case "streaming": self.streamStarted = true; self.status = "Streaming \(game.name)"
            case "warning": self.warnings.append(event["message"] as? String ?? "")
            case "quitRequired": self.quitRequired = event["app"] as? String
            case "error": self.fail(event["message"] as? String ?? "Streaming failed.")
            default: break
            }
        }
        helper.onExit = { [weak self, weak helper] code in
            guard let self, self.stream === helper else { return }
            self.streamWindowExists = false; self.streamWindowToken = nil
            self.stream = nil; self.streamActive = false; self.streamStarted = false; self.quitRequired = nil
            self.status = "Stream ended"
            self.send("resume")
            if code != 0 && self.message == nil { self.fail("The streaming engine exited unexpectedly (\(code)). Please save its crash report and engine log.") }
        }
        stream = helper
        do { try helper.start() } catch { stream = nil; streamActive = false; send("resume"); fail(error.localizedDescription) }
    }
    func restoreStreamWindow() {
        guard streamWindowExists, let token = streamWindowToken else { return }
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.moonlight-stream.NativeGlass.restoreStreamWindow"),
            object: token, userInfo: nil, deliverImmediately: true)
    }
    func showStreamControls() {
        guard streamWindowExists, let token = streamWindowToken else { return }
        restoreStreamWindow()
        DistributedNotificationCenter.default().postNotificationName(Notification.Name("com.moonlight-stream.NativeGlass.toggleStreamControls"), object: token, userInfo: nil, deliverImmediately: true)
    }
    func confirmQuit() {
        quitRequired = nil
        do { try stream?.send(["command": "confirmQuit"]) } catch { fail(error.localizedDescription) }
    }
    func cancelLaunch() { quitRequired = nil; pendingStream = nil; stream?.stop(); if stream == nil { streamActive = false; send("resume") } }
    func fail(_ detail: String) { message = NativeMessage(title: "Moonlight Native Glass", detail: detail, settingsScene: settingsWindow?.isKeyWindow == true) }
    func shutdown() {
        shuttingDown = true; hostDeadline?.cancel(); channel?.stop(); stream?.stop()
    }
}
