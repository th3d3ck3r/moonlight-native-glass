import SwiftUI

struct AddComputerSheet: View {
    @ObservedObject var store: EngineStore
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var submitted = false
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Add Computer", systemImage: "desktopcomputer").font(.title2).fontWeight(.semibold)
            Text("Enter the hostname or IP address of your Sunshine or GameStream-compatible computer.").foregroundStyle(.secondary)
            TextField("Hostname or IP address", text: $address).textFieldStyle(.roundedBorder).focused($focused)
                .onSubmit { add() }.disabled(store.addingHost)
            Text("For a custom port, use host:port. Enclose IPv6 addresses in square brackets.").font(.caption).foregroundStyle(.secondary)
            HStack {
                if store.addingHost { ProgressView().controlSize(.small); Text("Connecting…").font(.callout) }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(store.addingHost)
                Button("Add Computer") { add() }.keyboardShortcut(.defaultAction).disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.addingHost)
            }
        }.padding(24).frame(width: 420)
            .onAppear { focused = true }
            .onChange(of: store.addingHost) { _, busy in if submitted && !busy { dismiss() } }
    }
    private func add() {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !store.addingHost else { return }
        submitted = true; store.add(address)
    }
}

struct PairingSheet: View {
    let request: PairingRequest
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "link").font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
            Text("Pair with \(request.computer.name)").font(.title2).fontWeight(.semibold).multilineTextAlignment(.center)
            Text("Enter this PIN in your host's pairing page.").foregroundStyle(.secondary)
            Text(request.pin).font(.system(size: 44, weight: .medium, design: .monospaced))
                .textSelection(.enabled).accessibilityLabel("Pairing PIN \(request.pin.map(String.init).joined(separator: " "))")
            HStack { ProgressView().controlSize(.small); Text("Waiting for the host…").font(.callout).foregroundStyle(.secondary) }
            Text("Keep this window open until pairing completes.").font(.caption).foregroundStyle(.secondary)
        }.padding(32).frame(width: 420)
    }
}

struct ComputerDetailsSheet: View {
    let computer: Computer
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(computer.name, systemImage: "desktopcomputer").font(.title2).fontWeight(.semibold)
            Form {
                LabeledContent("Status", value: computer.status)
                LabeledContent("Connection", value: computer.address.isEmpty ? "Unavailable" : computer.address)
                LabeledContent("Local Address", value: computer.localAddress.isEmpty ? "Unavailable" : computer.localAddress)
                LabeledContent("Host Version", value: computer.serverVersion.isEmpty ? "Unavailable" : computer.serverVersion)
                LabeledContent("Graphics", value: computer.gpu.isEmpty ? "Not reported" : computer.gpu)
                LabeledContent("Host Support", value: computer.supported ? "Supported" : "Unsupported or not yet checked")
            }.formStyle(.grouped).textSelection(.enabled)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 490)
    }
}

struct RenameComputerSheet: View {
    @ObservedObject var store: EngineStore
    let computer: Computer
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Rename Computer").font(.title2).fontWeight(.semibold)
            TextField("Computer name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Rename") { store.send("rename", ["host": computer.id, "name": name]); dismiss() }
                    .keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 100)
            }
        }.padding(24).frame(width: 380).onAppear { name = computer.name }
    }
}
