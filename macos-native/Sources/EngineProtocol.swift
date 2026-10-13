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

struct MoonlightLGVersion {
    let redesign: Int
    let major: Int
    let minor: Int
    let hotfix: Int
    let channel: String
    init?(numeric: String, channel: String) {
        let parts = numeric.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({
            !$0.isEmpty && ($0.count == 1 || $0.first != "0") && $0.allSatisfy({ $0.isASCII && $0.isNumber })
        }), let redesign = Int(parts[0]), let major = Int(parts[1]),
            let minor = Int(parts[2]), let hotfix = Int(parts[3]),
            ["U", "E", "stable"].contains(channel) else { return nil }
        self.redesign = redesign; self.major = major; self.minor = minor; self.hotfix = hotfix; self.channel = channel
    }
    var display: String { "\(redesign).\(major).\(minor).\(hotfix)" + (channel == "stable" ? "" : channel) }
    static var current: MoonlightLGVersion {
        MoonlightLGVersion(numeric: Bundle.main.object(forInfoDictionaryKey: "MoonlightLGVersion") as? String ?? "1.2.1.0",
                           channel: Bundle.main.object(forInfoDictionaryKey: "MoonlightLGReleaseChannel") as? String ?? "U")
            ?? MoonlightLGVersion(numeric: "1.2.1.0", channel: "U")!
    }
}

func nativeEngineLogDirectory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    let manager = FileManager.default
    let current = home.appendingPathComponent("Library/Logs/MoonlightLG", isDirectory: true)
    let legacy = home.appendingPathComponent("Library/Logs/MoonlightNativeGlass", isDirectory: true)
    if manager.fileExists(atPath: legacy.path), !manager.fileExists(atPath: current.path) {
        do { try manager.moveItem(at: legacy, to: current) }
        catch {
            // A concurrent first launch may have completed the same move.
            if !manager.fileExists(atPath: current.path) { return legacy }
        }
    }
    return current
}


// One launch identity owns flight, rendezvous and handoff. It is never inferred
// from UI timers: only real helper events can mark the connection ready.
struct ConnectionJourney: Identifiable {
    enum Phase: Equatable { case connecting, connected, entering, failed }
    let id = UUID()
    let computer: Computer
    let game: Game
    var phase: Phase = .connecting
    var detail: String = "Preparing stream…"
    var connectedAt: Date?
    var continueRequested = false
    var error: String?
}
