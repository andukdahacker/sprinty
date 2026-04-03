import Foundation
import GRDB

enum SprintStepSyncStatus: String, Codable, Sendable, DatabaseValueConvertible {
    case synced
    case pendingSync
}

struct SprintStep: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sprintId: UUID
    var description: String
    var completed: Bool
    var completedAt: Date?
    var order: Int
    var coachContext: String?
    var syncStatus: SprintStepSyncStatus = .synced

    static let databaseTableName = "SprintStep"
}

extension SprintStep {
    static func forSprint(id: UUID) -> QueryInterfaceRequest<SprintStep> {
        filter(Column("sprintId") == id).order(Column("order").asc)
    }

    static func pendingSync() -> QueryInterfaceRequest<SprintStep> {
        filter(Column("syncStatus") == SprintStepSyncStatus.pendingSync.rawValue)
            .order(Column("completedAt").asc)
    }
}
