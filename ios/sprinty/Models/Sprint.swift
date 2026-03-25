import Foundation
import GRDB

enum SprintStatus: String, Codable, Sendable, DatabaseValueConvertible {
    case active
    case complete
    case cancelled
}

struct Sprint: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var status: SprintStatus

    static let databaseTableName = "Sprint"
}

extension Sprint {
    static func active() -> QueryInterfaceRequest<Sprint> {
        filter(Column("status") == SprintStatus.active.rawValue).limit(1)
    }
}
