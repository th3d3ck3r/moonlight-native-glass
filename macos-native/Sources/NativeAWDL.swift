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
    private let preview: Bool
    private var sessions = Set<String>()
    private var connection: NSXPCConnection?
    private var heartbeat: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var awaitingReply = false
    private var removalConnection: NSXPCConnection?
    private var removalDeadline: Task<Void, Never>?
    private var service: SMAppService { .daemon(plistName: Self.serviceName + ".plist") }
    private var helperURL: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Helpers/MoonlightAWDLHelper") }
    var streamInProgress: Bool { !sessions.isEmpty }

    init(preview: Bool = false) {
        self.preview = preview
        enabled = !preview && UserDefaults.standard.bool(forKey: Self.enabledKey)
        if preview { status = "Design preview — helper installation is disabled" }
    }
    func refresh() {
        guard !preview else { return }
        installed = service.status == .enabled
        approvalRequired = service.status == .requiresApproval
        if approvalRequired { status = "Approve the helper in Login Items & Extensions" }
        else if !installed { status = "Helper not installed or approved" }
        else if !enabled { status = "Off" }
        else if sessions.isEmpty { status = "Ready — waiting for a stream" }
    }
    func install() {
        guard !preview, !busy, !streamInProgress else { return }
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
        guard service.status == .enabled else { unregister(); return }
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
        reconcile()
    }
    func endSession(_ token: String) {
        sessions.remove(token)
        if sessions.isEmpty { disconnect(); if !preview { refresh() } }
    }
    func shutdown() {
        sessions.removeAll(); disconnect()
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
        guard service.status == .enabled else {
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
    private func helperRequirement() -> String? {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        var text: CFString?
        guard SecStaticCodeCreateWithPath(helperURL as CFURL, [], &code) == errSecSuccess,
              let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess,
              SecCodeCopyDesignatedRequirement(unsafeBitCast(code, to: SecCode.self), [], &requirement) == errSecSuccess,
              let requirement,
              SecRequirementCopyString(requirement, [], &text) == errSecSuccess else { return nil }
        return text as String?
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
                Button("Refresh Helper Status") { awdl.refresh() }
                if awdl.installed || awdl.approvalRequired { Button("Remove Helper") { awdl.remove() } }
            }.disabled(preview || awdl.busy || awdl.streamInProgress)
            Text("Optional and off by default. Requires administrator approval. Temporarily affects AirDrop and AWDL-based AirPlay/Continuity features. Ordinary Wi-Fi remains available. The helper restores AWDL when the last session ends; crash recovery may take up to 15 seconds plus a check interval.")
                .font(.caption).foregroundStyle(.secondary)
        }.onAppear { awdl.refresh() }
    }
}
