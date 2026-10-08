import AppKit
import Foundation

// Production argument lookup is in the app entry point, excluded from this test.
func nativeArgument(_ name: String) -> String? { nil }

@main struct EngineStoreTests {
    @MainActor static func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        fatalError("Timed out waiting for engine lifecycle")
    }
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let helper = folder.appendingPathComponent("engine-fixture")
        // Real pipe/process transport; simulate the engine dying before replying.
        try """
        #!/bin/sh
        printf '%s\\n' '{"event":"ready","protocol":1}'
        IFS= read -r command
        exit 0
        """.write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        let computer = Computer(id: "test", name: "Test", online: true, unknown: false, paired: true,
            runningApp: 0, address: "127.0.0.1", localAddress: "127.0.0.1", serverVersion: "test", gpu: "", supported: true, apps: [])
        let game = Game(id: 1, name: "Test", hdr: false, hidden: false, artwork: "")
        for operation in 0..<4 {
            let store = EngineStore(executable: helper)
            store.start()
            try await wait { store.ready }
            switch operation {
            case 0: store.startStream(computer, game: game)
            case 1: store.pair(computer)
            case 2: store.add("127.0.0.1")
            default: store.testConnection()
            }
            try await wait { !store.ready && store.message != nil }
            precondition(!store.streamActive && !store.streamStarted, "Launch remained busy after engine exit")
            precondition(store.pairing == nil && !store.addingHost && !store.testingConnection, "Pending operation remained busy")
            store.shutdown()
        }
        print("PASS: helper exit clears pending stream, pairing, host-add and connection-test state")
    }
}
