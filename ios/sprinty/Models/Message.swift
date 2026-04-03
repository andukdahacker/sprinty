import Foundation
import GRDB

enum MessageRole: String, Codable, Sendable, DatabaseValueConvertible {
    case user
    case assistant
    case system
}

enum MessageDeliveryStatus: String, Codable, Sendable, DatabaseValueConvertible {
    case sent
    case pending
}

struct Message: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sessionId: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var deliveryStatus: MessageDeliveryStatus = .sent

    static let databaseTableName = "Message"
}

extension Message {
    static func forSession(id: UUID) -> QueryInterfaceRequest<Message> {
        filter(Column("sessionId") == id).order(Column("timestamp").asc)
    }

    static func allConversations(limit: Int, offset: Int) -> QueryInterfaceRequest<Message> {
        order(Column("timestamp").desc).limit(limit, offset: offset)
    }

    static func pending() -> QueryInterfaceRequest<Message> {
        filter(Column("deliveryStatus") == "pending").order(Column("timestamp").asc)
    }
}
