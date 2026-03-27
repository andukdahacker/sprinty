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

enum SafetyLevel: String, Codable, Sendable, DatabaseValueConvertible, Comparable {
    case green
    case yellow
    case orange
    case red

    // MARK: - Comparable

    private var severityOrder: Int {
        switch self {
        case .green: 0
        case .yellow: 1
        case .orange: 2
        case .red: 3
        }
    }

    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.severityOrder < rhs.severityOrder
    }
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
