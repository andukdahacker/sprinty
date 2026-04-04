import Foundation
import GRDB

final class ConversationExportService: ConversationExportServiceProtocol, Sendable {
    private let dbPool: DatabasePool

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func hasConversations() async throws -> Bool {
        try await dbPool.read { db in
            try ConversationSession.fetchCount(db) > 0
        }
    }

    func exportConversations() async throws -> URL {
        let sessions = try await dbPool.read { db in
            try ConversationSession.order(Column("startedAt").asc).fetchAll(db)
        }

        var output = "# My Coaching Conversations\n"
        var lastDateString: String?

        for session in sessions {
            let messages = try await dbPool.read { db in
                try Message.forSession(id: session.id).fetchAll(db)
            }

            for message in messages {
                guard message.role != .system else { continue }

                let dateString = Self.dateFormatter.string(from: message.timestamp)
                if dateString != lastDateString {
                    output += "\n## \(dateString)\n"
                    lastDateString = dateString
                }

                switch message.role {
                case .user:
                    output += "\n> \(message.content)\n"
                case .assistant:
                    output += "\n\(message.content)\n"
                case .system:
                    break
                }
            }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sprinty-conversations.md")
        try output.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
