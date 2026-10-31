import AppKit
import Foundation

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
        if len(sys.argv) > 2 and sys.argv[2] == 'stream':
            (root / 'next-stream.json').write_text(json.dumps(values))
            emit({'event': 'connected'})
            for line in sys.stdin:
                if json.loads(line).get('command') in ('shutdown', 'cancelStream'): break
        else:
            emit({'event': 'ready', 'protocol': 1})
            emit({'event': 'settings', 'schema': [], 'values': values})
            for line in sys.stdin:
                command = json.loads(line)
                if command['command'] == 'settings':
                    time.sleep(0.2)
                    values.update(command['values'])
                    temporary = saved.with_suffix('.tmp')
                    temporary.write_text(json.dumps(values)); temporary.replace(saved)
                    emit({'event': 'settings', 'schema': [], 'values': values})
                elif command['command'] == 'pause':
                    emit({'event': 'paused', 'requestID': command['requestID']})
                elif command['command'] == 'shutdown':
                    (root / 'discovery-stopped').write_text('clean')
                    break
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let first = EngineStore(executable: executable)
        first.start()
        try await wait { first.ready && first.values["bitrateKbps"] != nil }
        first.set("bitrateKbps", 64000)
        first.shutdown() // No acknowledgment wait and no focus/Return event.
        let stopped = directory.appendingPathComponent("discovery-stopped")
        try await wait { FileManager.default.fileExists(atPath: stopped.path) }
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("settings.json"))) as! [String: Any]
        precondition(saved["bitrateKbps"] as? Int == 64000, "Quit discarded the final queued bitrate")
        precondition(saved["enableVsync"] as? Bool == true && saved["fps"] as? Int == 60, "Editing bitrate changed unrelated settings")
        try FileManager.default.removeItem(at: stopped)

        let second = EngineStore(executable: executable)
        second.start()
        try await wait { second.ready && second.values["bitrateKbps"] != nil }
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
        print("PASS: last numeric setting drains on quit, survives fresh store/helper, preserves unrelated values and reaches the next stream process")
    }
}
