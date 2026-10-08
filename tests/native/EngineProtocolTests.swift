import Foundation

@main struct EngineProtocolTests {
    static func main() throws {
        var decoder = EngineLineDecoder()
        let event = Data("{\"event\":\"stage\",\"message\":\"Starting 🎮…\"}\n{\"event\":\"finished\"}\n".utf8)
        var received = [[String: Any]]()
        for byte in event { received += try decoder.append(Data([byte])) }
        precondition(received.count == 2)
        precondition(received[0]["message"] as? String == "Starting 🎮…")
        precondition(received[1]["event"] as? String == "finished")
        var bad = EngineLineDecoder()
        do { _ = try bad.append(Data("[]\n".utf8)); fatalError("Non-object event accepted") } catch EngineProtocolError.invalidEvent {}
        var large = EngineLineDecoder()
        do { _ = try large.append(Data(repeating: 0x20, count: 1_048_577)); fatalError("Oversized event accepted") } catch EngineProtocolError.oversizedFrame {}
        var terminatedLarge = EngineLineDecoder()
        do { _ = try terminatedLarge.append(Data(repeating: 0x20, count: 1_048_577) + Data([0x0A])); fatalError("Oversized complete frame accepted") } catch EngineProtocolError.oversizedFrame {}
        var batch = EngineLineDecoder()
        let frame = Data(("{\"event\":\"stage\",\"message\":\"" + String(repeating: "x", count: 600_000) + "\"}\n").utf8)
        let batchEvents = try batch.append(frame + frame)
        precondition(batchEvents.count == 2, "Valid frames were rejected because their batched read exceeds one frame's limit")
        print("PASS: fragmented UTF-8, batched JSON lines, invalid events, per-frame size limit")
    }
}
