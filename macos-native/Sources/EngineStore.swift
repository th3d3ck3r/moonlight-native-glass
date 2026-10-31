import AppKit
import SwiftUI
import Darwin

/// One serialized read queue per helper; only complete events cross to the UI.
final class EngineChannel {
    let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var decoder = EngineLineDecoder()
    private let readQueue = DispatchQueue(label: "moonlight.native.events")
    private let exited = DispatchSemaphore(value: 0)
    var onEvent: (([String: Any]) -> Void)?
    var onExit: ((Int32) -> Void)?
    private(set) var diagnosticURL: URL?
    private var diagnosticHandle: FileHandle?
    private var closed = false
    var stopRequested: Bool { closed }

    init(executable: URL, arguments: [String]) {
        // A helper can close stdin before exiting. Let FileHandle surface EPIPE
        // as a send error instead of allowing SIGPIPE to terminate the frontend.
        signal(SIGPIPE, SIG_IGN)
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = executable.deletingLastPathComponent()
        process.standardInput = input
        process.standardOutput = output
        // Keep real helper diagnostics instead of discarding the only evidence
        // of a streaming teardown fault. Logging never enters the JSON pipe.
        let directory = nativeEngineLogDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let role = arguments.contains("stream") ? "stream" : "discovery"
        let log = directory.appendingPathComponent("\(role)-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).log")
        if FileManager.default.createFile(atPath: log.path, contents: nil), let handle = try? FileHandle(forWritingTo: log) {
            diagnosticURL = log; diagnosticHandle = handle; process.standardError = handle
        } else { process.standardError = FileHandle.standardError }

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
            self.exited.signal() // Independent of MainActor/UI callbacks during app termination.
            try? self.diagnosticHandle?.close()
            self.diagnosticHandle = nil
            let code = self.process.terminationStatus
            DispatchQueue.main.async { [weak self] in self?.onExit?(code) }
        }
    }
    var terminationDescription: String {
        process.terminationReason == .uncaughtSignal ? "signal \(process.terminationStatus)" : "exit \(process.terminationStatus)"
    }
    func send(_ request: [String: Any]) throws {
        guard process.isRunning, !closed else { throw CocoaError(.fileWriteUnknown) }
        var data = try JSONSerialization.data(withJSONObject: request)
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    func stopGracefully(_ request: [String: Any]) throws {
        try send(request)
        closed = true // Ignore late messages and classify the eventual exit as intentional.
        try? input.fileHandleForWriting.close()
    }
    func waitForExit(timeout: TimeInterval) -> Bool {
        if !process.isRunning { return true }
        return exited.wait(timeout: .now() + timeout) == .success
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
    @Published var menuState = NativeMenuState()
    @Published var streamWindowExists = false
    private var streamWindowToken: String?
    private var menuRequestID: UInt32 = 0
    private var menuDeadlines: [UInt32: Task<Void, Never>] = [:]
    private var menuActions: [UInt32: Int] = [:]
    @Published var streamActive = false
    @Published var streamStarted = false
    @Published var connectionJourney: ConnectionJourney?
    private var retryAfterExit = false
    private var connectionDeadline: Task<Void, Never>?
    @Published var quitRequired: String?
    @Published var warnings: [String] = []
    @Published var selectedID: String?
    weak var settingsWindow: NSWindow?
    weak var libraryWindow: NSWindow?
    let preview: Bool
    private var channel: EngineChannel?
    private var stream: EngineChannel?
    private var shuttingDown = false
    private var pendingStream: (id: String, computer: Computer, game: Game)?
    private var hostDeadline: Task<Void, Never>?
    private var launchDeadline: Task<Void, Never>?
    private let executableOverride: URL?
    private let streamHandoffTimeout: Duration

    var selected: Computer? { computers.first { $0.id == selectedID } }
    var executable: URL? {
        executableOverride ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MoonlightLGEngine.app/Contents/MacOS/Moonlight")
    }

    init(preview: Bool = false, executable: URL? = nil, streamHandoffTimeout: Duration = .seconds(15)) {
        self.preview = preview
        executableOverride = executable
        self.streamHandoffTimeout = streamHandoffTimeout
        if preview {
            computers = [Computer(id: "preview-computer", name: "Gaming PC", online: true, unknown: false,
                paired: true, runningApp: 0, address: "192.168.1.20", localAddress: "192.168.1.20",
                serverVersion: "Sunshine", gpu: "Gaming GPU", supported: true,
                apps: [Game(id: 1, name: "Desktop", hdr: false, hidden: false, artwork: ""),
                       Game(id: 2, name: "Steam", hdr: true, hidden: false, artwork: "")])]
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
            if let screen = nativeArgument("--preview-screen"), screen.hasPrefix("connection-"),
               let host = computers.first, let game = host.apps.first {
                var journey = ConnectionJourney(computer: host, game: game)
                journey.detail = "Starting video stream…"
                if screen == "connection-orbit" { journey.phase = .connected; journey.connectedAt = Date().addingTimeInterval(-3); journey.detail = "Connected · Awaiting Continue" }
                if screen == "connection-error" { journey.phase = .failed; journey.error = "Could not connect to Gaming PC. Check the host and try again." }
                connectionJourney = journey
            }
        }
    }

    func start() {
        guard !preview, channel == nil, let executable else { return }
        shuttingDown = false
        ready = false
        let helper = EngineChannel(executable: executable, arguments: ["native"])
        helper.onEvent = { [weak self, weak helper] event in
            guard let self, !self.shuttingDown, self.channel === helper else { return }
            self.receive(event)
        }
        helper.onExit = { [weak self, weak helper] code in
            guard let self, let helper, self.channel === helper else { return }
            self.ready = false
            self.channel = nil
            self.pairing = nil; self.addingHost = false; self.testingConnection = false
            self.hostDeadline?.cancel()
            let launchWasPending = self.pendingStream != nil
            if launchWasPending {
                self.launchDeadline?.cancel()
                self.pendingStream = nil; self.streamActive = false; self.streamStarted = false
            }
            if !self.shuttingDown {
                let detail = "The streaming engine stopped (\(helper.terminationDescription)). Use Refresh to restart it."
                if launchWasPending { self.connectionFailed(detail) }
                else if self.connectionJourney?.phase != .failed { self.fail(detail) }
            }
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
                if !computers.contains(where: { $0.id == selectedID }) { selectedID = computers.first?.id }
                status = computers.isEmpty ? "Looking for computers…" : "\(computers.count) computer\(computers.count == 1 ? "" : "s")"
            case "settings":
                let schema = try decodeEngineValue(event["schema"] ?? [], as: [PreferenceField].self)
                values = event["values"] as? [String: Any] ?? [:]
                fields = schema
                menuState.nextMode = [1: 2, 0: 1, 2: 0][(values["windowMode"] as? NSNumber)?.intValue ?? 0] ?? 1
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
                if let request = pendingStream, event["requestID"] as? String == request.id {
                    launchDeadline?.cancel(); pendingStream = nil
                    runStream(request.computer, game: request.game)
                }
            case "error":
                testingConnection = false; addingHost = false; hostDeadline?.cancel(); pairing = nil
                let launchWasPending = pendingStream != nil
                if launchWasPending { let journey = connectionJourney; cancelLaunch(); connectionJourney = journey }
                let detail = event["message"] as? String ?? "The engine could not complete this request."
                if launchWasPending { connectionFailed(detail) } else { fail(detail) }
            default: break
            }
        } catch {
            let launchWasPending = pendingStream != nil
            if launchWasPending { let journey = connectionJourney; cancelLaunch(); connectionJourney = journey }
            let detail = "Could not read the engine response: \(error.localizedDescription)"
            if launchWasPending { connectionFailed(detail) } else { fail(detail) }
            channel?.stop()
        }
    }

    @discardableResult func send(_ action: String, _ data: [String: Any] = [:]) -> Bool {
        guard !preview else { return false }
        var request = data; request["command"] = action
        do { guard let channel else { throw CocoaError(.fileWriteUnknown) }; try channel.send(request); return true }
        catch {
            ready = false; channel?.stop()
            fail("Could not send the request to the engine. Use Refresh to reconnect.")
            return false
        }
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
        guard !addingHost else { return }
        hostDeadline?.cancel()
        addingHost = true
        guard send("addHost", ["address": address]) else { addingHost = false; return }
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
        if !send("pair", ["host": computer.id, "pin": pin]) { pairing = nil }
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
        guard ready, !streamActive, pairing == nil, !addingHost, !testingConnection, !preview,
              computer.online, !computer.unknown, computer.paired, computer.supported else { return }
        streamActive = true; streamStarted = false; warnings = []
        connectionJourney = ConnectionJourney(computer: computer, game: game)
        status = "Preparing \(game.name)…"
        let requestID = UUID().uuidString
        pendingStream = (requestID, computer, game)
        guard send("pause", ["requestID": requestID]) else {
            pendingStream = nil; streamActive = false
            connectionFailed(message?.detail ?? "Could not prepare the connection."); message = nil
            return
        }
        launchDeadline?.cancel()
        launchDeadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.pendingStream?.id == requestID else { return }
            let journey = self.connectionJourney
            self.cancelLaunch(); self.connectionJourney = journey
            self.connectionFailed("The streaming engine did not prepare the launch. Use Refresh and try again.")
        }
    }
    private func runStream(_ computer: Computer, game: Game) {
        guard let executable else { streamActive = false; connectionFailed("The bundled streaming engine is missing."); return }
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        let displayID = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        let bounds = CGDisplayBounds(displayID)
        let x = Int(bounds.midX), y = Int(bounds.midY)
        let token = UUID().uuidString
        streamWindowToken = token
        menuState = NativeMenuState(token: token, nextMode: [1: 2, 0: 1, 2: 0][(values["windowMode"] as? NSNumber)?.intValue ?? 0] ?? 1)
        streamWindowExists = false
        let helper = EngineChannel(executable: executable, arguments: ["native", "stream", computer.id, String(game.id), String(x), String(y), token, "await-continue", computer.name, game.name])
        helper.onEvent = { [weak self, weak helper] event in
            guard let self, !self.shuttingDown, self.stream === helper, helper?.stopRequested == false else { return }
            switch event["event"] as? String {
            case "stage":
                self.status = event["message"] as? String ?? "Starting stream…"
                if self.connectionJourney?.phase == .connecting { self.connectionJourney?.detail = self.status }
            case "connectionWindowOpened": self.libraryWindow?.orderOut(nil)
            case "connectionCancelled":
                self.connectionJourney = nil
                try? helper?.stopGracefully(["command":"cancelStream"])
                self.libraryWindow?.makeKeyAndOrderFront(nil)
            case "connectionRetry": self.retryAfterExit = true
            case "connected":
                guard self.connectionJourney?.phase == .connecting else { return }
                self.connectionJourney?.phase = .connected
                self.connectionJourney?.connectedAt = Date()
                self.connectionJourney?.detail = "Connected · Awaiting Continue"
                self.status = "Connected to \(computer.name)"
            case "windowOpened":
                self.streamWindowExists = true
                self.streamStarted = true; self.status = "Streaming \(game.name)"
                self.menuState.exists = true
                self.menuAction(210)
                if self.connectionJourney?.phase == .entering {
                    self.connectionDeadline?.cancel()
                    self.connectionJourney = nil
                    self.libraryWindow?.orderOut(nil)
                }
            case "windowHidden": self.menuState.visible = false
            case "windowClosed":
                self.clearMenuRequests()
                self.streamWindowExists = false; self.menuState = NativeMenuState()
            case "menuActionAcknowledged":
                if let number = event["requestID"] as? NSNumber, let action = event["action"] as? Int {
                    let id = number.uint32Value
                    if self.menuActions[id] == action {
                        self.menuDeadlines.removeValue(forKey: id)?.cancel()
                        self.menuActions.removeValue(forKey: id)
                    }
                }
            case "menuState":
                self.menuState.windowNumber = (event["windowNumber"] as? NSNumber)?.uint32Value ?? 0
                self.menuState.visible = event["visible"] as? Bool ?? false
                self.menuState.captured = event["captured"] as? Bool ?? false
                self.menuState.statistics = event["statistics"] as? Bool ?? false
                self.menuState.controls = event["controls"] as? Bool ?? false
                self.menuState.muted = event["muted"] as? Bool ?? false
                self.menuState.mode = event["mode"] as? Int ?? 0
            case "enteringStream", "streaming":
                self.beginStreamHandoff()
            case "warning": self.warnings.append(event["message"] as? String ?? "")
            case "quitRequired": self.quitRequired = event["app"] as? String
            case "error": self.connectionFailed(event["message"] as? String ?? "Streaming failed.")
            default: break
            }
        }
        helper.onExit = { [weak self, weak helper] code in
            guard let self, let helper, self.stream === helper else { return }
            self.clearMenuRequests()
            self.streamWindowExists = false; self.streamWindowToken = nil; self.menuState = NativeMenuState()
            self.stream = nil; self.streamActive = false; self.streamStarted = false; self.quitRequired = nil
            self.connectionDeadline?.cancel()
            if self.connectionJourney != nil {
                self.connectionJourney?.phase = .failed
                self.connectionJourney?.error = self.connectionJourney?.error ?? "The connection ended before entering the stream."
                self.connectionJourney?.detail = "Connection ended"
            }
            self.status = "Stream ended"
            if self.retryAfterExit {
                self.retryAfterExit = false
                self.send("resume"); self.retryConnection(); return
            }
            if let journey = self.connectionJourney {
                self.connectionJourney = nil
                if !self.shuttingDown { self.fail(journey.error ?? "The connection ended before entering the stream.") }
                self.libraryWindow?.makeKeyAndOrderFront(nil)
            }
            if !self.shuttingDown { self.send("resume") }
            if !self.shuttingDown && !helper.stopRequested && code != 0 && self.message == nil && self.connectionJourney == nil { self.fail("The streaming engine stopped unexpectedly (\(helper.terminationDescription)). Open Engine Logs from the menu bar and save the stream log and macOS crash report.") }
            if !self.shuttingDown && self.message != nil { self.libraryWindow?.makeKeyAndOrderFront(nil) }
        }
        stream = helper
        do { try helper.start() } catch {
            stream = nil; streamWindowToken = nil; streamActive = false
            send("resume"); connectionFailed(error.localizedDescription)
        }
    }
    private func clearMenuRequests() {
        for task in menuDeadlines.values { task.cancel() }
        menuDeadlines.removeAll(); menuActions.removeAll()
    }
    func menuAction(_ action: Int) {
        if (204...206).contains(action) {
            guard streamWindowExists else { return }
            menuState.nextMode = action - 204
            // Discovery remains responsive while polling is paused. Save through
            // its normal validated transaction; the streaming helper has its own
            // preference snapshot, so this takes effect only on the next launch.
            set("windowMode", [2, 0, 1][action - 204])
            return
        }
        guard streamWindowExists, let token = streamWindowToken, let stream else { return }
        guard [100, 200, 201, 202, 203, 207, 208, 209, 210, 212, 213, 214, 215, 216, 217, 219].contains(action) else { return }
        menuRequestID = menuRequestID == .max ? 1 : menuRequestID + 1
        let id = menuRequestID
        do {
            try stream.send(["command": "menuAction", "token": token, "action": action, "requestID": id])
            menuActions[id] = action
            menuDeadlines[id] = Task { [weak self, weak stream] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self, self.stream === stream, self.streamWindowToken == token,
                      self.menuActions.removeValue(forKey: id) != nil else { return }
                self.menuDeadlines.removeValue(forKey: id)
                self.fail("The streaming engine did not acknowledge menu action \(action). Open Engine Logs to inspect the stream log.")
            }
        } catch { fail("Could not send the stream menu command. \(error.localizedDescription)") }
    }
    func restoreStreamWindow() {
        guard connectionJourney == nil else {
            if let stream { try? stream.send(["command":"showConnectionWindow"]) }
            else { libraryWindow?.makeKeyAndOrderFront(nil) }
            return
        }
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
        do { try stream?.send(["command": "confirmQuit"]) } catch { connectionFailed(error.localizedDescription) }
    }
    func continueToStream() {
        if preview { connectionJourney = nil; return }
        guard connectionJourney?.phase == .connected, let stream else { return }
        do {
            try stream.send(["command": "continueStream"])
            beginStreamHandoff()
        } catch { connectionFailed(error.localizedDescription) }
    }
    private func beginStreamHandoff() {
        // Both the hosted connection button and frontend commands reach here.
        // Duplicate acknowledgements must not extend the deadline.
        guard connectionJourney?.phase == .connected, let stream else { return }
        connectionJourney?.phase = .entering
        connectionJourney?.continueRequested = true
        connectionJourney?.detail = "Opening stream window…"
        connectionDeadline?.cancel()
        connectionDeadline = Task { [weak self, weak stream] in
            guard let timeout = self?.streamHandoffTimeout else { return }
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, self.stream === stream,
                  self.connectionJourney?.phase == .entering, !self.streamWindowExists else { return }
            // The library is hidden while the helper owns Apollo. Restore it
            // and cancel the stuck helper so the user can actually see/retry.
            self.cancelLaunch()
            self.fail("The stream window did not open. The connection was cancelled; try again.")
            self.libraryWindow?.makeKeyAndOrderFront(nil)
        }
    }
    func retryConnection() {
        guard !streamActive, let journey = connectionJourney, journey.phase == .failed else { return }
        connectionJourney = nil
        message = nil
        startStream(journey.computer, game: journey.game)
    }
    func cancelLaunch() {
        connectionDeadline?.cancel()
        let waiting = connectionJourney?.connectedAt != nil && connectionJourney?.continueRequested == false && !streamWindowExists
        connectionJourney = nil
        quitRequired = nil; launchDeadline?.cancel(); pendingStream = nil
        if waiting, let stream {
            do { try stream.stopGracefully(["command": "cancelStream"]) }
            catch { stream.stop() }
        } else { stream?.stop() }
        if stream == nil { streamActive = false; status = "Launch cancelled"; send("resume") }
    }
    func dismissQuitConfirmation() {
        // SwiftUI may dismiss before invoking a selected button. Defer until
        // its action has cleared quitRequired; outside-click/Escape still cancels.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.quitRequired != nil else { return }
            self.cancelLaunch()
        }
    }
    func fail(_ detail: String) {
        message = NativeMessage(title: "MoonlightLG", detail: detail, settingsScene: settingsWindow?.isKeyWindow == true)
    }
    private func connectionFailed(_ detail: String) {
        if connectionJourney != nil {
            connectionJourney?.phase = .failed; connectionJourney?.error = detail
            connectionJourney?.detail = "Connection failed"
        } else { fail(detail) }
    }
    func shutdown(waitForDiscovery: Bool = false) {
        clearMenuRequests()
        connectionDeadline?.cancel(); connectionJourney = nil
        shuttingDown = true; hostDeadline?.cancel(); launchDeadline?.cancel(); pendingStream = nil
        // Preserve FIFO ordering: a valid settings edit may already be in the
        // helper's stdin when Quit arrives. SIGTERM could discard it before Qt
        // reads/saves it. Close discovery only after its queued requests drain.
        if let channel, !channel.stopRequested {
            do { try channel.stopGracefully(["command": "shutdown"]) }
            catch { channel.stop() }
        }
        stream?.stop()
        // Only applicationWillTerminate requests this bounded wait. Keep the
        // stdout reader alive until discovery finishes queued saves: closing it
        // first makes the real Qt helper stop on EPIPE after an earlier reply.
        // The reader signals directly from its queue, never through MainActor.
        if waitForDiscovery, let channel, !channel.waitForExit(timeout: 2), channel.process.isRunning {
            channel.process.terminate()
        }
    }
}

