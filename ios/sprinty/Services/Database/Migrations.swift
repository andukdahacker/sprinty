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

        migrator.registerMigration("v2") { db in
            try db.create(table: "UserProfile") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("avatarId", .text).notNull().defaults(to: "")
                t.column("coachAppearanceId", .text).notNull().defaults(to: "")
                t.column("coachName", .text).notNull().defaults(to: "")
                t.column("onboardingStep", .integer).notNull().defaults(to: 0)
                t.column("onboardingCompleted", .boolean).notNull().defaults(to: false)
                t.column("values", .text)
                t.column("goals", .text)
                t.column("personalityTraits", .text)
                t.column("domainStates", .text)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }

        migrator.registerMigration("v3") { db in
            try db.alter(table: "ConversationSession") { t in
                t.add(column: "modeHistory", .text)
            }
        }

        migrator.registerMigration("v4") { db in
            try db.alter(table: "ConversationSession") { t in
                t.add(column: "moodHistory", .text)
            }
        }
    }
}
