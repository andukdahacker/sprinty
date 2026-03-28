import Foundation
import GRDB

struct SafetyComplianceLog: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sessionId: UUID
    var timestamp: Date
    var safetyLevel: SafetyLevel
    var classificationSource: String
    var eventType: String
    var previousLevel: String?

    static let databaseTableName = "SafetyComplianceLog"
}

// MARK: - Query Extensions

extension SafetyComplianceLog {
    static func timeline(limit: Int = 100) -> QueryInterfaceRequest<SafetyComplianceLog> {
        order(Column("timestamp").desc).limit(limit)
    }

    static func forSession(id: UUID) -> QueryInterfaceRequest<SafetyComplianceLog> {
        filter(Column("sessionId") == id).order(Column("timestamp").asc)
    }

    static func forLevel(_ level: SafetyLevel) -> QueryInterfaceRequest<SafetyComplianceLog> {
        filter(Column("safetyLevel") == level.rawValue).order(Column("timestamp").desc)
    }
}
