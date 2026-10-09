import Foundation

enum EngineProtocolError: Error { case oversizedFrame, invalidEvent }

/// Pipe reads may split a UTF-8 character or contain several events at once.
/// Frame bytes first; decode JSON only after a complete newline arrives.
struct EngineLineDecoder {
    private var buffer = Data()
    mutating func append(_ data: Data) throws -> [[String: Any]] {
        buffer.append(data)
        var events = [[String: Any]]()
        while let end = buffer.firstIndex(of: 0x0A) {
            guard buffer.distance(from: buffer.startIndex, to: end) <= 1_048_576 else { throw EngineProtocolError.oversizedFrame }
            let line = Data(buffer[..<end])
            buffer.removeSubrange(...end)
            guard let event = try JSONSerialization.jsonObject(with: line) as? [String: Any],
                  event["event"] is String else { throw EngineProtocolError.invalidEvent }
            events.append(event)
        }
        guard buffer.count <= 1_048_576 else { throw EngineProtocolError.oversizedFrame }
        return events
    }
}

struct Game: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let hdr: Bool
    let hidden: Bool
    var artwork: String
}

struct Computer: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let online: Bool
    let unknown: Bool
    let paired: Bool
    let runningApp: Int
    let address: String
    let localAddress: String
    let serverVersion: String
    let gpu: String
    let supported: Bool
    var apps: [Game]
    var status: String {
        if unknown { return "Checking connection…" }
        if !online { return "Offline" }
        if !paired { return "Not paired" }
        return runningApp == 0 ? "Ready to stream" : "App running"
    }
}

struct PreferenceChoice: Identifiable, Codable {
    let value: Int
    let name: String
    var id: Int { value }
}
struct PreferenceField: Identifiable, Codable {
    let id: String
    let boolean: Bool
    let choices: [PreferenceChoice]
}

func decodeEngineValue<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
    try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
}

struct NativeMenuState: Equatable {
    var exists = false
    var token: String?
    var windowNumber: UInt32 = 0
    var visible = false
    var captured = false
    var statistics = false
    var controls = false
    var muted = false
    var mode = 0
    var nextMode = 0
}
