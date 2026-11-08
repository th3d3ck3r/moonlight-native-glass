import AppKit
import Foundation
import Darwin

func nativeArgument(_ name: String) -> String? { nil }

// Real EngineStore and EngineChannel processes, with a deliberately slow helper:
// the old SIGTERM shutdown deterministically lost a queued final numeric edit.
@main struct SettingsPersistenceTests {
    @MainActor static func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        fatalError("Timed out waiting for persisted settings")
    }
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--parent-exit-child" {
            let helper = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("settings-engine")
            let store = EngineStore(executable: helper)
            store.start()
            try await wait { store.ready && store.values["bitrateKbps"] != nil }
            // Several valid edits queue separate acknowledgments. Close the
            // real frontend process immediately after its termination path;
            // keeping this parent alive previously hid stdout/EPIPE data loss.
            store.set("bitrateKbps", 61000)
            store.set("fps", 90)
            store.set("bitrateKbps", 128000)
            store.shutdown(waitForDiscovery: true)
            exit(0)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MoonlightLG-Settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("settings-engine")
        try """
        #!/usr/bin/env python3
        import json, pathlib, sys, time
        root = pathlib.Path(__file__).parent
        saved = root / 'settings.json'
        values = json.loads(saved.read_text()) if saved.exists() else {'bitrateKbps': 20000, 'fps': 60, 'width': 1920, 'height': 1080, 'autoAdjustBitrate': False, 'enableVsync': True}
        def emit(value): print(json.dumps(value), flush=True)
        def emit_hosts(): emit({'event': 'hosts', 'hosts': json.loads((root / 'hosts.json').read_text())})
        if len(sys.argv) > 2 and sys.argv[2] == 'stream':
            (root / 'next-stream.json').write_text(json.dumps(values))
            emit({'event': 'connected'})
            for line in sys.stdin:
                if json.loads(line).get('command') in ('shutdown', 'cancelStream'): break
        else:
            emit({'event': 'ready', 'protocol': 1})
            emit_hosts()
            emit({'event': 'settings', 'schema': [], 'values': values})
            for line in sys.stdin:
                command = json.loads(line)
                if command['command'] == 'settings':
                    time.sleep(0.2)
                    values.update(command['values'])
                    temporary = saved.with_suffix('.tmp')
                    temporary.write_text(json.dumps(values)); temporary.replace(saved)
                    emit({'event': 'settings', 'schema': [], 'values': values})
                elif command['command'] == 'snapshot':
                    emit_hosts()
                elif command['command'] == 'pause':
                    emit({'event': 'paused', 'requestID': command['requestID']})
                elif command['command'] == 'shutdown':
                    (root / 'discovery-stopped').write_text('clean')
                    break
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        func host(_ id: String, _ name: String) -> Computer {
            Computer(id: id, name: name, online: true, unknown: false, paired: true,
                     runningApp: 0, address: "127.0.0.1", localAddress: "127.0.0.1",
                     serverVersion: "test", gpu: "", supported: true, apps: [])
        }
        func writeHosts(_ hosts: [Computer], to directory: URL) throws {
            try JSONEncoder().encode(hosts).write(to: directory.appendingPathComponent("hosts.json"), options: .atomic)
        }
        let a = host("a", "Alpha"), b = host("b", "Bravo"), c = host("c", "Charlie"), d = host("d", "Delta")
        try writeHosts([b, c, a], to: directory)
        let defaultsName = "MoonlightLG-HostOrder-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let first = EngineStore(executable: executable, defaults: defaults)
        first.start()
        try await wait { first.ready && first.values["bitrateKbps"] != nil }
        try await wait { first.computers.count == 3 }
        precondition(first.computers.map(\.id) == ["a", "b", "c"])
        first.selectedID = "b"
        first.moveComputer("c", by: -1)
        first.moveComputer("a", by: 1)
        first.moveComputer("c", by: -1) // Already first.
        precondition(first.computers.map(\.id) == ["c", "a", "b"] && first.selectedID == "b")
        try writeHosts([d, b, c], to: directory)
        first.refresh()
        try await wait { first.computers.map(\.id) == ["c", "b", "d"] }
        first.moveComputer("d", by: -1)
        precondition(first.computers.map(\.id) == ["c", "d", "b"])
        try writeHosts([host("b", "Aardvark"), a, d, c], to: directory)
        first.refresh()
        try await wait { first.computers.map(\.id) == ["c", "a", "d", "b"] }
        precondition(first.selectedID == "b" && first.selected?.name == "Aardvark")
        first.set("bitrateKbps", 64000)
        first.shutdown() // No acknowledgment wait and no focus/Return event.
        let stopped = directory.appendingPathComponent("discovery-stopped")
        try await wait { FileManager.default.fileExists(atPath: stopped.path) }
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("settings.json"))) as! [String: Any]
        precondition(saved["bitrateKbps"] as? Int == 64000, "Quit discarded the final queued bitrate")
        precondition(saved["enableVsync"] as? Bool == true && saved["fps"] as? Int == 60, "Editing bitrate changed unrelated settings")
        try FileManager.default.removeItem(at: stopped)

        let second = EngineStore(executable: executable, defaults: UserDefaults(suiteName: defaultsName)!)
        second.start()
        try await wait { second.ready && second.values["bitrateKbps"] != nil }
        try await wait { second.computers.count == 4 }
        precondition(second.computers.map(\.id) == ["c", "a", "d", "b"], "Custom host order did not survive a fresh store")
        precondition(second.values["bitrateKbps"] as? Int == 64000, "A fresh store/helper did not reload bitrate")
        let game = Game(id: 1, name: "Desktop", hdr: false, hidden: false, artwork: "")
        let computer = Computer(id: "settings-test", name: "Test", online: true, unknown: false, paired: true,
                                runningApp: 0, address: "127.0.0.1", localAddress: "127.0.0.1", serverVersion: "test", gpu: "", supported: true, apps: [game])
        second.startStream(computer, game: game)
        let streamValues = directory.appendingPathComponent("next-stream.json")
        try await wait { FileManager.default.fileExists(atPath: streamValues.path) }
        let loaded = try JSONSerialization.jsonObject(with: Data(contentsOf: streamValues)) as! [String: Any]
        precondition(loaded["bitrateKbps"] as? Int == 64000, "The next stream process did not load the saved bandwidth")
        second.shutdown()
        try await wait { FileManager.default.fileExists(atPath: stopped.path) }
        let exitDirectory = directory.appendingPathComponent("parent-exit")
        try FileManager.default.createDirectory(at: exitDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: executable, to: exitDirectory.appendingPathComponent("settings-engine"))
        try writeHosts([], to: exitDirectory)
        let parent = Process()
        parent.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        parent.arguments = ["--parent-exit-child", exitDirectory.path]
        try parent.run()
        parent.waitUntilExit()
        precondition(parent.terminationStatus == 0, "Frontend termination fixture failed")
        let final = try JSONSerialization.jsonObject(with: Data(contentsOf: exitDirectory.appendingPathComponent("settings.json"))) as! [String: Any]
        precondition(final["bitrateKbps"] as? Int == 128000 && final["fps"] as? Int == 90,
                     "Closing the frontend stdout reader discarded the final queued settings")
        precondition(FileManager.default.fileExists(atPath: exitDirectory.appendingPathComponent("discovery-stopped").path),
                     "Actual frontend exit must let discovery finish ordered shutdown")
        print("PASS: queued settings survive immediate frontend process exit, fresh store/helper and next stream; unrelated values preserved")
    }
}
