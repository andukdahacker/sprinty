import Foundation
import GRDB

enum DatabaseMigrations {
    static func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1") { db in
            try db.create(table: "ConversationSession") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("startedAt", .text).notNull()
                t.column("endedAt", .text)
                t.column("type", .text).notNull().defaults(to: "coaching")
                t.column("mode", .text).notNull().defaults(to: "discovery")
                t.column("safetyLevel", .text).notNull().defaults(to: "green")
                t.column("promptVersion", .text)
            }

            try db.create(table: "Message") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sessionId", .text).notNull()
                    .references("ConversationSession", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .text).notNull()
            }

            try db.create(
                index: "idx_message_sessionId",
                on: "Message",
                columns: ["sessionId"]
            )
        }
    }
}
