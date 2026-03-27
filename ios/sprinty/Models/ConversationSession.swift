import Foundation
import GRDB

enum SessionType: String, Codable, Sendable, DatabaseValueConvertible {
    case coaching
    case checkIn
}

enum CoachingMode: String, Codable, Sendable, DatabaseValueConvertible {
    case discovery
    case directive
}

enum SafetyLevel: String, Codable, Sendable, DatabaseValueConvertible {
    case green
    case yellow
    case red
}

struct ModeSegment: Codable, Sendable {
    let mode: CoachingMode
    let messageIndex: Int
}

struct ConversationSession: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var type: SessionType
    var mode: CoachingMode
    var safetyLevel: SafetyLevel
    var promptVersion: String?
    var modeHistory: String?
    var moodHistory: String?

    static let databaseTableName = "ConversationSession"
}

extension ConversationSession {
    static func recent(limit: Int = 10) -> QueryInterfaceRequest<ConversationSession> {
        order(Column("startedAt").desc).limit(limit)
    }

    static func completedCount(_ db: Database) throws -> Int {
        try filter(Column("endedAt") != nil).fetchCount(db)
    }
}
