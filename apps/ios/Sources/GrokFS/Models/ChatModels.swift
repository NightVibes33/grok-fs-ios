import Foundation

struct ChatThread: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var updatedAt = Date()
    var cwd = "/root"
    var messages: [ChatMessage]
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: ChatRole
    var text: String
    var createdAt = Date()
    var isStreaming = false
}

enum ChatRole: String, Codable {
    case user
    case assistant
    case tool
    case system
}

enum ChatThreadStore {
    private static let fileName = "threads.json"

    static func load() -> [ChatThread] {
        guard let data = try? Data(contentsOf: storeURL()) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ChatThread].self, from: data)) ?? []
    }

    static func save(_ threads: [ChatThread]) {
        guard let data = try? JSONEncoder.pretty.encode(threads) else { return }
        try? FileManager.default.createDirectory(at: storeURL().deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storeURL(), options: .atomic)
    }

    private static func storeURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appending(path: "GrokFS").appending(path: fileName)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
