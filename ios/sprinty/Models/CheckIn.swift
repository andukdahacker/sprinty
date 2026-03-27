import Foundation
import GRDB

struct CheckIn: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sessionId: UUID
    var sprintId: UUID
    var summary: String
    var createdAt: Date

    static let databaseTableName = "CheckIn"
}

// MARK: - Query Extensions

extension CheckIn {
    static func latest() -> QueryInterfaceRequest<CheckIn> {
        order(Column("createdAt").desc).limit(1)
    }

    static func latestToday(referenceDate: Date = Date()) -> QueryInterfaceRequest<CheckIn> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return filter(Column("createdAt") >= startOfDay && Column("createdAt") < endOfDay)
            .order(Column("createdAt").desc)
            .limit(1)
    }

    static func latestThisWeek(referenceDate: Date = Date()) -> QueryInterfaceRequest<CheckIn> {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return none()
        }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        return filter(Column("createdAt") >= weekStart && Column("createdAt") < weekEnd)
            .order(Column("createdAt").desc)
            .limit(1)
    }

    static func forSprint(id: UUID) -> QueryInterfaceRequest<CheckIn> {
        filter(Column("sprintId") == id)
            .order(Column("createdAt").desc)
    }
}
