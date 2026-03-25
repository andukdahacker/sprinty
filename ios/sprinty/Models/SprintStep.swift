import Foundation
import GRDB

struct SprintStep: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sprintId: UUID
    var description: String
    var completed: Bool
    var completedAt: Date?
    var order: Int
    var coachContext: String?

    static let databaseTableName = "SprintStep"
}

extension SprintStep {
    static func forSprint(id: UUID) -> QueryInterfaceRequest<SprintStep> {
        filter(Column("sprintId") == id).order(Column("order").asc)
    }
}
