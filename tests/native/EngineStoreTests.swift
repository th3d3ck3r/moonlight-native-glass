import AppKit
import Foundation

// Production argument lookup is in the app entry point, excluded from this test.
func nativeArgument(_ name: String) -> String? { nil }

@main struct EngineStoreTests {
    @MainActor static func wait(seconds: Int = 5, _ condition: () -> Bool) async throws {
        for _ in 0..<(seconds * 40) {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        fatalError("Timed out waiting for engine lifecycle")
    }
    @MainActor static func main() async throws {
        _ = NSApplication.shared
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
        // Missing transport must not leave a modal sheet or busy operation.
        let disconnected = EngineStore(executable: helper)
        disconnected.add("127.0.0.1")
        precondition(!disconnected.addingHost && disconnected.message != nil)
        disconnected.pair(computer)
        precondition(disconnected.pairing == nil)
        disconnected.testConnection()
        precondition(!disconnected.testingConnection)

        func fixture(_ mode: String) throws -> URL {
            let directory = folder.appendingPathComponent(mode)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let executable = directory.appendingPathComponent("engine-fixture")
            try """
            #!/usr/bin/env python3
            import json, os, pathlib, sys, time
            def emit(value):
                print(json.dumps(value), flush=True)
            if '\(mode)' == 'broken-pipe':
                os.close(0)
                emit({'event': 'ready', 'protocol': 1})
                time.sleep(5)
            elif len(sys.argv) > 2 and sys.argv[2] == 'stream':
                pathlib.Path('stream-started').write_text('started')
                emit({'event': 'quitRequired', 'app': 'Previous game'})
                for line in sys.stdin:
                    request = json.loads(line)
                    if request['command'] == 'confirmQuit':
                        emit({'event': 'streaming'})
                        emit({'event': 'windowOpened'})
                    elif request['command'] == 'menuAction':
                        if '\(mode)' != 'menu-no-ack':
                            emit({'event': 'menuActionAcknowledged', 'action': request['action'], 'requestID': request['requestID']})
                        pathlib.Path('menu-actions').open('a').write(str(request['action']) + '\\n')
            else:
                pauses = []
                emit({'event': 'ready', 'protocol': 1})
                for line in sys.stdin:
                    request = json.loads(line)
                    command = request['command']
                    if command == 'pause':
                        pauses.append(request['requestID'])
                        if '\(mode)' == 'reject':
                            emit({'event': 'error', 'message': 'Launch rejected'})
                    elif command == 'release':
                        emit({'event': 'paused', 'requestID': pauses[request['index']]})
                    elif command == 'malformed':
                        emit({'event': 'hosts', 'hosts': [{'id': 'incomplete'}]})
                    elif command == 'finishTest':
                        emit({'event': 'connectionTest', 'result': 0})
                    emit({'event': 'settings', 'values': {'fixtureStep': command, 'windowMode': request.get('values', {}).get('windowMode', 0)}, 'schema': []})
            """.write(to: executable, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
            return executable
        }
        let missingAck = EngineStore(executable: try fixture("menu-no-ack"))
        missingAck.start(); try await wait { missingAck.ready }
        missingAck.startStream(computer, game: game)
        try await wait { missingAck.values["fixtureStep"] as? String == "pause" }
        missingAck.send("release", ["index": 0])
        try await wait { missingAck.quitRequired != nil }
        missingAck.confirmQuit()
        try await wait { missingAck.streamWindowExists }
        missingAck.menuAction(209)
        try await wait { missingAck.message?.detail.contains("did not acknowledge") == true }
        missingAck.shutdown()
        let brokenHelper = try fixture("broken-pipe")
        for operation in 0..<3 {
            let broken = EngineStore(executable: brokenHelper)
            broken.start()
            try await wait { broken.ready }
            switch operation {
            case 0: broken.add("127.0.0.1")
            case 1: broken.pair(computer)
            default: broken.testConnection()
            }
            precondition(!broken.ready && broken.message != nil && !broken.addingHost && broken.pairing == nil && !broken.testingConnection,
                         "Broken pipe terminated the frontend or stranded an operation")
            try await wait { if !broken.ready { broken.refresh() }; return broken.ready }
            broken.shutdown()
        }
        let rejected = EngineStore(executable: try fixture("reject"))
        rejected.start()
        try await wait { rejected.ready }
        rejected.startStream(computer, game: game)
        try await wait { rejected.message?.detail == "Launch rejected" }
        precondition(rejected.ready && !rejected.streamActive, "Rejected launch stayed busy despite a live helper")
        try await wait { rejected.values["fixtureStep"] as? String == "resume" }
        rejected.shutdown()

        let delayedHelper = try fixture("delayed")
        let delayed = EngineStore(executable: delayedHelper)
        delayed.start()
        try await wait { delayed.ready }
        delayed.testConnection()
        try await wait { delayed.values["fixtureStep"] as? String == "testConnection" }
        delayed.startStream(computer, game: game)
        precondition(!delayed.streamActive, "Launch bypassed an outstanding connection test")
        delayed.send("finishTest")
        try await wait { !delayed.testingConnection }
        delayed.startStream(computer, game: game)
        try await wait { delayed.values["fixtureStep"] as? String == "pause" }
        delayed.cancelLaunch()
        try await wait { delayed.values["fixtureStep"] as? String == "resume" }
        delayed.startStream(computer, game: game)
        try await wait { delayed.values["fixtureStep"] as? String == "pause" }
        delayed.send("release", ["index": 0])
        try await wait { delayed.values["fixtureStep"] as? String == "release" }
        let marker = delayedHelper.deletingLastPathComponent().appendingPathComponent("stream-started")
        precondition(!FileManager.default.fileExists(atPath: marker.path), "Cancelled launch reply started the replacement stream")
        delayed.send("release", ["index": 1])
        try await wait { delayed.quitRequired != nil }
        precondition(FileManager.default.fileExists(atPath: marker.path), "Current launch reply did not start a stream")
        // Dismissal is queued; selecting Confirm in the same turn must win.
        delayed.dismissQuitConfirmation()
        delayed.confirmQuit()
        try await wait { delayed.streamStarted }
        precondition(delayed.streamActive, "Confirmation dismissal cancelled an accepted launch")
        delayed.streamWindowExists = true
        for (action, expected) in [(204, 2), (205, 0), (206, 1)] {
            delayed.menuAction(action)
            try await wait { (delayed.values["windowMode"] as? NSNumber)?.intValue == expected && delayed.values["fixtureStep"] as? String == "settings" }
            precondition(delayed.streamActive && delayed.streamStarted, "Selecting next window mode ended the active stream")
        }
        try await wait { delayed.streamWindowExists }
        for action in [213, 214, 212, 209] { delayed.menuAction(action) }
        let actionFile = delayedHelper.deletingLastPathComponent().appendingPathComponent("menu-actions")
        try await wait { (try? String(contentsOf: actionFile, encoding: .utf8))?.contains("209") == true }
        try await Task.sleep(for: .seconds(4))
        precondition(delayed.message == nil,"Acknowledged menu commands must not trigger a timeout")
        delayed.message = nil
        delayed.quitRequired = "Previous game"
        delayed.dismissQuitConfirmation()
        try await wait { !delayed.streamActive }
        precondition(delayed.quitRequired == nil && !delayed.streamStarted, "Outside dismissal stranded the launch helper")
        precondition(delayed.message == nil, "Intentional launch cancellation was reported as a crash")
        delayed.shutdown()

        for (online, unknown, paired, supported) in [(false,false,true,true),(true,true,true,true),(true,false,false,true),(true,false,true,false)] {
            let unavailable = Computer(id: computer.id, name: computer.name, online: online, unknown: unknown, paired: paired,
                runningApp: 0, address: "", localAddress: "", serverVersion: "", gpu: "", supported: supported, apps: [game])
            let guarded = EngineStore(executable: helper)
            guarded.start()
            try await wait { guarded.ready }
            guarded.startStream(unavailable, game: game)
            precondition(!guarded.streamActive && guarded.message == nil,"Controller or stale UI must reject an unavailable or unpaired host before sending pause")
            guarded.shutdown()
        }
        let silent = EngineStore(executable: try fixture("silent"))
        silent.start()
        try await wait { silent.ready }
        silent.startStream(computer, game: game)
        try await wait(seconds: 12) { !silent.streamActive }
        precondition(silent.ready && silent.message?.detail.contains("did not prepare") == true,
                     "A silent, live helper left launch stuck indefinitely")
        silent.shutdown()
        let malformed = EngineStore(executable: try fixture("malformed"))
        malformed.start()
        try await wait { malformed.ready }
        malformed.pair(computer)
        malformed.send("malformed")
        try await wait { !malformed.ready && malformed.pairing == nil }
        precondition(malformed.message != nil, "Invalid typed event retained an unusable ready engine")
        malformed.shutdown()
        for (command, expected) in [("exit 11", "exit 11"), ("kill -TERM $$", "signal 15")] {
            let diagnostic = folder.appendingPathComponent("diagnostic-fixture")
            try "#!/bin/sh\necho 'helper diagnostic marker' >&2\n\(command)\n".write(to: diagnostic, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: diagnostic.path)
            let channel = EngineChannel(executable: diagnostic, arguments: [])
            var ended = false
            channel.onExit = { _ in ended = true }
            try channel.start()
            try await wait { ended }
            precondition(channel.terminationDescription == expected,"Signals and exit codes must not be conflated")
            let log = try String(contentsOf: channel.diagnosticURL!, encoding: .utf8)
            precondition(log.contains("helper diagnostic marker"),"Helper stderr must survive process exit")
            try? FileManager.default.removeItem(at: channel.diagnosticURL!)
        }
        print("PASS: helper exit, missing/broken-pipe sends, busy guard, live rejection, cancelled/replacement replies, confirmation dismissal, quiet cancellation, launch deadline, malformed events")
    }
}
