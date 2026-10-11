import AppKit
import Security
import ServiceManagement
import SwiftUI

@objc(NativeAWDLControl) protocol NativeAWDLControl {
    @objc(renewLeaseWithReply:) func renewLease(withReply reply: @escaping (Bool, String) -> Void)
    @objc(releaseLeaseWithReply:) func releaseLease(withReply reply: @escaping (Bool, String) -> Void)
    @objc(prepareRemovalWithReply:) func prepareRemoval(withReply reply: @escaping (Bool, String) -> Void)
}

@MainActor final class NativeAWDL: ObservableObject {
    static let serviceName = "com.moonlight-stream.NativeGlass.AWDLHelper"
    private static let enabledKey = "native.awdl.enabled"
    @Published var enabled: Bool {
        didSet {
            guard !preview else { return }
            UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
            if enabled { reconcile() } else { disconnect(); status = "Off" }
        }
    }
    @Published private(set) var status = "Off"
    @Published private(set) var installed = false
    @Published private(set) var approvalRequired = false
    @Published private(set) var busy = false
    @Published private(set) var streamInProgress = false
    @Published private(set) var manualInstallation = false
    private let preview: Bool
    private var sessions = Set<String>()
    private var connection: NSXPCConnection?
    private var heartbeat: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var awaitingReply = false
    private var removalConnection: NSXPCConnection?
    private var removalDeadline: Task<Void, Never>?
    private var service: SMAppService { .daemon(plistName: Self.serviceName + ".plist") }
    private var bundledHelperURL: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Helpers/MoonlightAWDLHelper") }
    private var installedHelperURL: URL { URL(fileURLWithPath: "/Library/PrivilegedHelperTools/" + Self.serviceName) }
    private var helperURL: URL { manualInstallation ? installedHelperURL : bundledHelperURL }

    init(preview: Bool = false) {
        self.preview = preview
        enabled = !preview && UserDefaults.standard.bool(forKey: Self.enabledKey)
        if preview { status = "Design preview — helper installation is disabled" }
    }
    func refresh() {
        guard !preview else { return }
        manualInstallation = Self.rootOwnedFile(installedHelperURL.path)
        installed = manualInstallation || service.status == .enabled
        approvalRequired = !manualInstallation && service.status == .requiresApproval
        if approvalRequired { status = "Approve the helper in Login Items & Extensions" }
        else if !installed { status = "Helper not installed or approved" }
        else if !enabled { status = "Off" }
        else if sessions.isEmpty { status = "Ready — waiting for a stream" }
    }
    func install() {
        guard !preview, !busy, !streamInProgress else { return }
        if manualInstallation || !supportsServiceSigning() {
            runInstaller(removing: false)
            return
        }
        busy = true
        defer { busy = false }
        do {
            if service.status == .notRegistered || service.status == .notFound { try service.register() }
            refresh()
            if approvalRequired { SMAppService.openSystemSettingsLoginItems() }
        } catch { refresh(); status = "Installation failed: \(error.localizedDescription)" }
    }
    func openApprovalSettings() {
        guard !preview else { return }
        SMAppService.openSystemSettingsLoginItems()
    }
    func remove() {
        guard !preview, !busy, !streamInProgress else { return }
        enabled = false
        busy = true
        // A pending approval has never run the daemon, so there is no state to
        // restore. An approved daemon must acknowledge recovery before removal.
        guard installed else { unregister(); return }
        guard let requirement = helperRequirement() else {
            busy = false; status = "Cannot verify the helper. Restore AWDL before removing it."; return
        }
        let client = NSXPCConnection(machServiceName: Self.serviceName, options: .privileged)
        client.remoteObjectInterface = NSXPCInterface(with: NativeAWDLControl.self)
        client.setCodeSigningRequirement(requirement)
        removalConnection = client
        client.resume()
        removalDeadline = Task { [weak self, weak client] in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            self?.removalResult(client, false, "Could not confirm AWDL restoration. Helper removal cancelled.")
        }
        let proxy = client.remoteObjectProxyWithErrorHandler { [weak self, weak client] error in
            Task { @MainActor in self?.removalResult(client, false, error.localizedDescription) }
        } as? NativeAWDLControl
        guard let proxy else { removalResult(client, false, "Helper unavailable"); return }
        proxy.prepareRemoval { [weak self, weak client] success, message in
            Task { @MainActor in self?.removalResult(client, success, message) }
        }
    }
    private func removalResult(_ client: NSXPCConnection?, _ success: Bool, _ message: String) {
        guard let client, removalConnection === client else { return }
        removalDeadline?.cancel(); removalDeadline = nil
        removalConnection = nil; client.invalidate()
        if success { unregister() } else { busy = false; status = message }
    }
    private func unregister() {
        if manualInstallation { runInstaller(removing: true); return }
        service.unregister { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.busy = false; self.refresh()
                if let error { self.status = "Removal failed: \(error.localizedDescription)" }
            }
        }
    }
    func beginSession(_ token: String) {
        guard !preview else { return }
        sessions.insert(token)
        streamInProgress = true
        reconcile()
    }
    func endSession(_ token: String) {
        sessions.remove(token)
        streamInProgress = !sessions.isEmpty
        if sessions.isEmpty { disconnect(); if !preview { refresh() } }
    }
    func shutdown() {
        sessions.removeAll(); streamInProgress = false; disconnect()
        removalDeadline?.cancel(); removalDeadline = nil
        removalConnection?.invalidate(); removalConnection = nil
    }
    private func reconcile() {
        guard !preview, enabled, !sessions.isEmpty else { return }
        refresh()
        guard installed else { return } // Never install or prompt during a stream.
        renew()
        if heartbeat == nil {
            heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    guard let self else { return }
                    self.renew()
                }
            }
        }
    }
    private func renew() {
        guard enabled, !sessions.isEmpty, !awaitingReply else { return }
        guard manualInstallation || service.status == .enabled else {
            disconnect(); refresh(); return
        }
        if connection == nil {
            guard let requirement = helperRequirement() else {
                status = "Helper signature is invalid; streaming is unaffected"
                return
            }
            let client = NSXPCConnection(machServiceName: Self.serviceName, options: .privileged)
            client.remoteObjectInterface = NSXPCInterface(with: NativeAWDLControl.self)
            client.setCodeSigningRequirement(requirement)
            client.invalidationHandler = { [weak self, weak client] in
                Task { @MainActor in self?.connectionFailed(client, "AWDL helper disconnected; streaming is unaffected") }
            }
            client.interruptionHandler = client.invalidationHandler
            connection = client
            client.resume()
        }
        guard let client = connection else { return }
        awaitingReply = true
        deadline = Task { [weak self, weak client] in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            self?.connectionFailed(client, "AWDL helper timed out; streaming is unaffected")
        }
        let proxy = client.remoteObjectProxyWithErrorHandler { [weak self, weak client] error in
            Task { @MainActor in self?.connectionFailed(client, "AWDL helper unavailable: \(error.localizedDescription)") }
        } as? NativeAWDLControl
        guard let proxy else { connectionFailed(client, "AWDL helper unavailable"); return }
        proxy.renewLease { [weak self, weak client] success, message in
            Task { @MainActor in
                guard let self, let client, self.connection === client else { return }
                self.deadline?.cancel(); self.deadline = nil; self.awaitingReply = false
                self.status = success ? "Active — AWDL suppressed during streaming" : message
            }
        }
    }
    private func connectionFailed(_ failed: NSXPCConnection?, _ message: String) {
        guard let failed, connection === failed else { return }
        connection = nil; failed.invalidate()
        deadline?.cancel(); deadline = nil; awaitingReply = false
        status = message
    }
    private func disconnect() {
        heartbeat?.cancel(); heartbeat = nil
        deadline?.cancel(); deadline = nil; awaitingReply = false
        let old = connection; connection = nil
        // Daemon drops this connection's lease on invalidation, or after the
        // 15-second heartbeat timeout if the process vanishes unexpectedly.
        old?.invalidate()
    }
    private func helperRequirement() -> String? { Self.designatedRequirement(helperURL) }
    nonisolated private static func designatedRequirement(_ url: URL) -> String? {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        var text: CFString?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess,
              SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess,
              let requirement,
              SecRequirementCopyString(requirement, [], &text) == errSecSuccess else { return nil }
        return text as String?
    }
    private func supportsServiceSigning() -> Bool {
        func team(_ url: URL) -> String? {
            var code: SecStaticCode?
            var info: CFDictionary?
            guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
                  SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
                  let info else { return nil }
            return (info as NSDictionary)[kSecCodeInfoTeamIdentifier] as? String
        }
        guard let appTeam = team(Bundle.main.bundleURL), !appTeam.isEmpty else { return false }
        return team(bundledHelperURL) == appTeam
    }
    nonisolated private static func rootOwnedFile(_ path: String) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.ownerAccountID] as? NSNumber)?.intValue == 0,
              let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue else { return false }
        return mode & 0o022 == 0
    }
    private func runInstaller(removing: Bool) {
        let tool = removing ? installedHelperURL : bundledHelperURL
        guard Self.designatedRequirement(tool) != nil else {
            busy = false; status = "Installer signature is invalid"; return
        }
        busy = true
        status = removing ? "Waiting for administrator approval to remove the helper…" : "Waiting for administrator approval to install the helper…"
        Task { [weak self] in
            let result = await Task.detached { Self.administratorCommand(tool, removing: removing) }.value
            guard let self else { return }
            self.busy = false; self.refresh()
            if let result { self.status = result }
            else if !removing && self.enabled { self.reconcile() }
        }
    }
    nonisolated private static func administratorCommand(_ tool: URL, removing: Bool) -> String? {
        // The root executable implements fixed --install/--remove operations.
        // No generated shell scripts or caller-supplied destinations are used.
        let quotedTool = "'" + tool.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = quotedTool + (removing ? " --remove" : " --install")
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        process.standardOutput = output; process.standardError = output
        do { try process.run() } catch { return "Administrator authorization failed: \(error.localizedDescription)" }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return nil }
        let message = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "Helper installation or removal failed" : message
    }
}

struct NativeAWDLSettings: View {
    @ObservedObject var awdl: NativeAWDL
    let preview: Bool
    var body: some View {
        Section("Wi-Fi Streaming Stability") {
            Toggle("Suppress AWDL while streaming", isOn: $awdl.enabled)
                .disabled(preview || !awdl.installed || awdl.busy)
                .accessibilityIdentifier("native-awdl-toggle")
            Text(awdl.status).font(.callout).foregroundStyle(.secondary)
                .accessibilityIdentifier("native-awdl-status")
            HStack {
                if !awdl.installed && !awdl.approvalRequired {
                    Button("Install Helper…") { awdl.install() }.accessibilityIdentifier("native-awdl-install")
                }
                if awdl.approvalRequired {
                    Button("Open Approval Settings…") { awdl.openApprovalSettings() }
                }
                if awdl.manualInstallation {
                    Button("Reinstall Helper…") { awdl.install() }
                }
                Button("Refresh Helper Status") { awdl.refresh() }
                if awdl.installed || awdl.approvalRequired { Button("Remove Helper") { awdl.remove() } }
            }.disabled(preview || awdl.busy || awdl.streamInProgress)
            Text("Optional and off by default. Requires administrator approval. Temporarily affects AirDrop and AWDL-based AirPlay/Continuity features. Ordinary Wi-Fi remains available. The helper restores AWDL when the last session ends; crash recovery may take up to 15 seconds plus a check interval.")
                .font(.caption).foregroundStyle(.secondary)
        }.onAppear { awdl.refresh() }
    }
}
