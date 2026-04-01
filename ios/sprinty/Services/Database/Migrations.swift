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

        migrator.registerMigration("v5") { db in
            try db.create(table: "ConversationSummary") { t in
                t.primaryKey("id", .text).notNull()
                t.column("sessionId", .text).notNull()
                    .references("ConversationSession", onDelete: .cascade)
                t.column("summary", .text).notNull()
                t.column("keyMoments", .text).notNull()      // JSON array
                t.column("domainTags", .text).notNull()       // JSON array
                t.column("emotionalMarkers", .text)           // Phase 2, nullable
                t.column("keyDecisions", .text)               // Phase 2, nullable
                t.column("goalReferences", .text)             // Phase 2, nullable
                t.column("embedding", .blob)                  // 384-dim, nullable until 3.2
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "ConversationSummary_sessionId",
                          on: "ConversationSummary", columns: ["sessionId"])
        }

        migrator.registerMigration("v6") { db in
            // Timestamp index for cross-session ORDER BY performance
            try db.create(
                index: "idx_message_timestamp",
                on: "Message",
                columns: ["timestamp"]
            )

            // FTS5 virtual table for Message content (prepares for Story 3.6 search)
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS MessageFTS USING fts5(
                    content,
                    content='Message',
                    content_rowid='rowid'
                )
                """)

            // Populate FTS from existing messages
            try db.execute(sql: """
                INSERT INTO MessageFTS(rowid, content)
                SELECT rowid, content FROM Message
                """)

            // Keep FTS in sync on INSERT
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS message_fts_insert AFTER INSERT ON Message BEGIN
                    INSERT INTO MessageFTS(rowid, content) VALUES (new.rowid, new.content);
                END
                """)

            // Keep FTS in sync on UPDATE
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS message_fts_update AFTER UPDATE OF content ON Message BEGIN
                    INSERT INTO MessageFTS(MessageFTS, rowid, content) VALUES('delete', old.rowid, old.content);
                    INSERT INTO MessageFTS(rowid, content) VALUES (new.rowid, new.content);
                END
                """)

            // Keep FTS in sync on DELETE
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS message_fts_delete AFTER DELETE ON Message BEGIN
                    INSERT INTO MessageFTS(MessageFTS, rowid, content) VALUES('delete', old.rowid, old.content);
                END
                """)
        }

        migrator.registerMigration("v7") { db in
            // Avatar column: SF Symbol → asset catalog name
            try db.execute(sql: "UPDATE UserProfile SET avatarId = 'avatar_classic' WHERE avatarId IN ('person.circle.fill', '')")
            try db.execute(sql: "UPDATE UserProfile SET avatarId = 'avatar_minimal' WHERE avatarId = 'person.circle'")
            try db.execute(sql: "UPDATE UserProfile SET avatarId = 'avatar_zen' WHERE avatarId = 'figure.mind.and.body'")
            // Coach column: SF Symbol → asset catalog name
            try db.execute(sql: "UPDATE UserProfile SET coachAppearanceId = 'coach_sage' WHERE coachAppearanceId IN ('person.circle.fill', '')")
            try db.execute(sql: "UPDATE UserProfile SET coachAppearanceId = 'coach_mentor' WHERE coachAppearanceId = 'brain.head.profile'")
            try db.execute(sql: "UPDATE UserProfile SET coachAppearanceId = 'coach_guide' WHERE coachAppearanceId = 'leaf.circle.fill'")
        }

        migrator.registerMigration("v8") { db in
            try db.create(table: "Sprint") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("name", .text).notNull()
                t.column("startDate", .text).notNull()
                t.column("endDate", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "active")
            }

            try db.create(table: "SprintStep") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sprintId", .text).notNull()
                    .references("Sprint", onDelete: .cascade)
                t.column("description", .text).notNull()
                t.column("completed", .boolean).notNull().defaults(to: false)
                t.column("completedAt", .text)
                t.column("order", .integer).notNull()
            }

            try db.create(
                index: "idx_sprintstep_sprintId",
                on: "SprintStep",
                columns: ["sprintId"]
            )
        }

        migrator.registerMigration("v9") { db in
            try db.alter(table: "SprintStep") { t in
                t.add(column: "coachContext", .text)
            }
        }

        migrator.registerMigration("v10_sprintRetroAndMilestone") { db in
            try db.alter(table: "Sprint") { t in
                t.add(column: "narrativeRetro", .text)
                t.add(column: "lastStepCompletedAt", .text)
            }
        }

        migrator.registerMigration("v11_checkIn") { db in
            try db.create(table: "CheckIn") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sessionId", .text).notNull()
                    .references("ConversationSession", onDelete: .cascade)
                t.column("sprintId", .text).notNull()
                    .references("Sprint", onDelete: .cascade)
                t.column("summary", .text).notNull()
                t.column("createdAt", .text).notNull()
            }

            try db.create(
                index: "idx_checkin_sprintId",
                on: "CheckIn",
                columns: ["sprintId"]
            )

            try db.create(
                index: "idx_checkin_createdAt",
                on: "CheckIn",
                columns: ["createdAt"]
            )

            try db.alter(table: "UserProfile") { t in
                t.add(column: "checkInCadence", .text).notNull().defaults(to: "daily")
                t.add(column: "checkInTimeHour", .integer).notNull().defaults(to: 9)
                t.add(column: "checkInWeekday", .integer)
            }
        }

        migrator.registerMigration("v12_safetyBoundary") { db in
            try db.alter(table: "UserProfile") { t in
                t.add(column: "lastSafetyBoundaryAt", .text)
            }
        }

        migrator.registerMigration("v13_complianceLog") { db in
            try db.create(table: "SafetyComplianceLog") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sessionId", .text).notNull()
                t.column("timestamp", .text).notNull()
                t.column("safetyLevel", .text).notNull()
                t.column("classificationSource", .text).notNull()
                t.column("eventType", .text).notNull()
                t.column("previousLevel", .text)
            }
            try db.create(index: "idx_complianceLog_timestamp", on: "SafetyComplianceLog", columns: ["timestamp"])
            try db.create(index: "idx_complianceLog_safetyLevel", on: "SafetyComplianceLog", columns: ["safetyLevel"])
        }

        migrator.registerMigration("v14_pauseMode") { db in
            try db.alter(table: "UserProfile") { t in
                t.add(column: "isPaused", .boolean).notNull().defaults(to: false)
                t.add(column: "pausedAt", .text)
            }
        }

        migrator.registerMigration("v15_engagementSource") { db in
            try db.alter(table: "ConversationSession") { t in
                t.add(column: "engagementSource", .text).notNull().defaults(to: "organic")
            }
        }
    }
}
