import Foundation
import GRDB

struct NotificationDelivery: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var type: String
    var scheduledAt: Date
    var deliveredAt: Date?
    var priority: Int

    static let databaseTableName = "notificationDelivery"
}

extension NotificationDelivery {
    static func todayCount(in db: Database) throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try NotificationDelivery
            .filter(Column("scheduledAt") >= startOfDay)
            .fetchCount(db)
    }

    static func todayByPriority(in db: Database) throws -> [NotificationDelivery] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try NotificationDelivery
            .filter(Column("scheduledAt") >= startOfDay)
            .order(Column("priority").asc)
            .fetchAll(db)
    }

    static func cleanupOldEntries(in db: Database) throws {
        let cutoff = Date().addingTimeInterval(-48 * 3600)
        try NotificationDelivery
            .filter(Column("scheduledAt") < cutoff)
            .deleteAll(db)
    }
}
