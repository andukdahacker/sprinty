import Foundation
import GRDB

struct ConversationSummary: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sessionId: UUID
    var summary: String
    var keyMoments: String            // JSON-encoded [String]
    var domainTags: String            // JSON-encoded [String]
    var emotionalMarkers: String?     // Phase 2, JSON-encoded [String]?
    var keyDecisions: String?         // Phase 2, JSON-encoded [String]?
    var goalReferences: String?       // Phase 2, JSON-encoded [String]?
    var embedding: Data?              // 384-dim float array, nullable until Story 3.2
    var createdAt: Date

    static let databaseTableName = "ConversationSummary"
}

// MARK: - JSON Array Helpers

extension ConversationSummary {
    var decodedKeyMoments: [String] {
        guard let data = keyMoments.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return decoded
    }

    var decodedDomainTags: [String] {
        guard let data = domainTags.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return decoded
    }

    var decodedEmotionalMarkers: [String]? {
        guard let raw = emotionalMarkers,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        return decoded
    }

    var decodedKeyDecisions: [String]? {
        guard let raw = keyDecisions,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        return decoded
    }

    static func encodeArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: - Query Extensions

extension ConversationSummary {
    static func forSession(id: UUID) -> QueryInterfaceRequest<ConversationSummary> {
        filter(Column("sessionId") == id)
    }

    static func recent(limit: Int = 10) -> QueryInterfaceRequest<ConversationSummary> {
        order(Column("createdAt").desc).limit(limit)
    }

    static func forDomainTag(_ tag: String) -> QueryInterfaceRequest<ConversationSummary> {
        let escaped = tag
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return filter(Column("domainTags").like("%\"\(escaped)\"%"))
    }
}
