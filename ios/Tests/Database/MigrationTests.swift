import Foundation
import Testing
import GRDB
@testable import sprinty

@Suite("Database Migration Tests")
struct MigrationTests {
    private func createInMemoryDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        return dbQueue
    }

    @Test("ConversationSession table is created with correct columns")
    func conversationSessionTableCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let columns = try db.columns(in: "ConversationSession")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("id"))
            #expect(columnNames.contains("startedAt"))
            #expect(columnNames.contains("endedAt"))
            #expect(columnNames.contains("type"))
            #expect(columnNames.contains("mode"))
            #expect(columnNames.contains("safetyLevel"))
            #expect(columnNames.contains("promptVersion"))
        }
    }

    @Test("Message table is created with correct columns")
    func messageTableCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let columns = try db.columns(in: "Message")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("id"))
            #expect(columnNames.contains("sessionId"))
            #expect(columnNames.contains("role"))
            #expect(columnNames.contains("content"))
            #expect(columnNames.contains("timestamp"))
        }
    }

    @Test("Message sessionId index exists")
    func messageSessionIdIndexExists() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let indexes = try db.indexes(on: "Message")
            let indexNames = indexes.map(\.name)
            #expect(indexNames.contains("idx_message_sessionId"))
        }
    }

    @Test("Migrations are idempotent — running twice succeeds")
    func migrationsIdempotent() throws {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        try migrator.migrate(dbQueue)
    }

    @Test("Can insert and fetch ConversationSession")
    func insertAndFetchSession() throws {
        let db = try createInMemoryDatabase()
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil
        )
        try db.write { db in
            try session.insert(db)
        }
        let fetched = try db.read { db in
            try ConversationSession.fetchOne(db, key: session.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.id == session.id)
    }

    @Test("Can insert and fetch Message")
    func insertAndFetchMessage() throws {
        let db = try createInMemoryDatabase()
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil
        )
        let message = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Hello",
            timestamp: Date()
        )
        try db.write { db in
            try session.insert(db)
            try message.insert(db)
        }
        let fetched = try db.read { db in
            try Message.fetchOne(db, key: message.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.sessionId == session.id)
    }

    @Test("Message foreign key enforced — cascade delete")
    func messageCascadeDelete() throws {
        let db = try createInMemoryDatabase()
        let sessionId = UUID()
        let session = ConversationSession(
            id: sessionId,
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil
        )
        let message = Message(
            id: UUID(),
            sessionId: sessionId,
            role: .assistant,
            content: "Hi there",
            timestamp: Date()
        )
        try db.write { db in
            try session.insert(db)
            try message.insert(db)
            try session.delete(db)
        }
        let remainingMessages = try db.read { db in
            try Message.filter(Column("sessionId") == sessionId).fetchCount(db)
        }
        #expect(remainingMessages == 0)
    }

    @Test("ConversationSession.recent query returns ordered results")
    func recentSessionsQuery() throws {
        let db = try createInMemoryDatabase()
        let older = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSinceNow: -3600),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil
        )
        let newer = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .directive,
            safetyLevel: .green,
            promptVersion: nil
        )
        try db.write { db in
            try older.insert(db)
            try newer.insert(db)
        }
        let results = try db.read { db in
            try ConversationSession.recent(limit: 10).fetchAll(db)
        }
        #expect(results.count == 2)
        #expect(results.first?.id == newer.id)
    }

    // --- Story 3.5 Tests ---

    @Test("v6 migration creates timestamp index on Message")
    func v6TimestampIndexExists() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let indexes = try db.indexes(on: "Message")
            let indexNames = indexes.map(\.name)
            #expect(indexNames.contains("idx_message_timestamp"))
        }
    }

    @Test("v6 migration creates FTS5 virtual table")
    func v6FTS5TableCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='MessageFTS'")
            #expect(tables.contains("MessageFTS"))
        }
    }

    @Test("v6 FTS5 populated from existing messages")
    func v6FTS5PopulatedFromExistingData() throws {
        // Create DB with v1-v5 only, insert data, then run v6
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var partialMigrator = DatabaseMigrator()

        // Register only v1-v5
        partialMigrator.registerMigration("v1") { db in
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
            try db.create(index: "idx_message_sessionId", on: "Message", columns: ["sessionId"])
        }
        try partialMigrator.migrate(dbQueue)

        // Insert test data
        let sessionId = UUID()
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO ConversationSession (id, startedAt, type, mode, safetyLevel) VALUES (?, ?, 'coaching', 'discovery', 'green')",
                           arguments: [sessionId.uuidString, Date().databaseValue])
            try db.execute(sql: "INSERT INTO Message (id, sessionId, role, content, timestamp) VALUES (?, ?, 'user', 'Hello world', ?)",
                           arguments: [UUID().uuidString, sessionId.uuidString, Date().databaseValue])
        }

        // Now run full migrations (v6 will run on top)
        var fullMigrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&fullMigrator)
        try fullMigrator.migrate(dbQueue)

        // Verify FTS is populated
        let ftsCount = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM MessageFTS WHERE content MATCH 'Hello'")
        }
        #expect(ftsCount == 1)
    }

    @Test("v6 FTS5 INSERT trigger keeps sync")
    func v6FTS5InsertTrigger() throws {
        let db = try createInMemoryDatabase()
        let sessionId = UUID()
        try db.write { db in
            try db.execute(sql: "INSERT INTO ConversationSession (id, startedAt, type, mode, safetyLevel) VALUES (?, ?, 'coaching', 'discovery', 'green')",
                           arguments: [sessionId.uuidString, Date().databaseValue])
            try db.execute(sql: "INSERT INTO Message (id, sessionId, role, content, timestamp) VALUES (?, ?, 'user', 'New message for search', ?)",
                           arguments: [UUID().uuidString, sessionId.uuidString, Date().databaseValue])
        }
        let ftsCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM MessageFTS WHERE content MATCH 'search'")
        }
        #expect(ftsCount == 1)
    }

    @Test("v6 FTS5 DELETE trigger keeps sync")
    func v6FTS5DeleteTrigger() throws {
        let db = try createInMemoryDatabase()
        let sessionId = UUID()
        let messageId = UUID()
        try db.write { db in
            try db.execute(sql: "INSERT INTO ConversationSession (id, startedAt, type, mode, safetyLevel) VALUES (?, ?, 'coaching', 'discovery', 'green')",
                           arguments: [sessionId.uuidString, Date().databaseValue])
            try db.execute(sql: "INSERT INTO Message (id, sessionId, role, content, timestamp) VALUES (?, ?, 'user', 'Deletable content', ?)",
                           arguments: [messageId.uuidString, sessionId.uuidString, Date().databaseValue])
        }
        // Verify exists
        let beforeCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM MessageFTS WHERE content MATCH 'Deletable'")
        }
        #expect(beforeCount == 1)

        // Delete the message
        try db.write { db in
            try db.execute(sql: "DELETE FROM Message WHERE id = ?", arguments: [messageId.uuidString])
        }
        let afterCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM MessageFTS WHERE content MATCH 'Deletable'")
        }
        #expect(afterCount == 0)
    }

    @Test("v6 FTS5 UPDATE trigger keeps sync")
    func v6FTS5UpdateTrigger() throws {
        let db = try createInMemoryDatabase()
        let sessionId = UUID()
        let messageId = UUID()
        try db.write { db in
            try db.execute(sql: "INSERT INTO ConversationSession (id, startedAt, type, mode, safetyLevel) VALUES (?, ?, 'coaching', 'discovery', 'green')",
                           arguments: [sessionId.uuidString, Date().databaseValue])
            try db.execute(sql: "INSERT INTO Message (id, sessionId, role, content, timestamp) VALUES (?, ?, 'user', 'Original content', ?)",
                           arguments: [messageId.uuidString, sessionId.uuidString, Date().databaseValue])
        }
        // Verify original content searchable
        let beforeCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM MessageFTS WHERE content MATCH 'Original'")
        }
        #expect(beforeCount == 1)

        // Update the message content
        try db.write { db in
            try db.execute(sql: "UPDATE Message SET content = 'Updated content' WHERE id = ?", arguments: [messageId.uuidString])
        }

        // Old content should no longer match
        let oldCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM MessageFTS WHERE content MATCH 'Original'")
        }
        #expect(oldCount == 0)

        // New content should be searchable
        let newCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM MessageFTS WHERE content MATCH 'Updated'")
        }
        #expect(newCount == 1)
    }

    @Test("Message.allConversations returns messages across sessions with pagination")
    func allConversationsPagination() throws {
        let db = try createInMemoryDatabase()
        let session1 = ConversationSession(id: UUID(), startedAt: Date(timeIntervalSinceNow: -7200), endedAt: Date(timeIntervalSinceNow: -3600), type: .coaching, mode: .discovery, safetyLevel: .green, promptVersion: nil)
        let session2 = ConversationSession(id: UUID(), startedAt: Date(timeIntervalSinceNow: -3600), endedAt: nil, type: .coaching, mode: .discovery, safetyLevel: .green, promptVersion: nil)

        try db.write { db in
            try session1.insert(db)
            try session2.insert(db)
        }

        let msg1 = Message(id: UUID(), sessionId: session1.id, role: .user, content: "First", timestamp: Date(timeIntervalSinceNow: -7000))
        let msg2 = Message(id: UUID(), sessionId: session1.id, role: .assistant, content: "Second", timestamp: Date(timeIntervalSinceNow: -6900))
        let msg3 = Message(id: UUID(), sessionId: session2.id, role: .user, content: "Third", timestamp: Date(timeIntervalSinceNow: -3500))

        try db.write { db in
            try msg1.insert(db)
            try msg2.insert(db)
            try msg3.insert(db)
        }

        // First page (newest first)
        let page1 = try db.read { db in
            try Message.allConversations(limit: 2, offset: 0).fetchAll(db)
        }
        #expect(page1.count == 2)
        #expect(page1[0].content == "Third") // newest
        #expect(page1[1].content == "Second")

        // Second page
        let page2 = try db.read { db in
            try Message.allConversations(limit: 2, offset: 2).fetchAll(db)
        }
        #expect(page2.count == 1)
        #expect(page2[0].content == "First") // oldest

        // Empty page at end
        let page3 = try db.read { db in
            try Message.allConversations(limit: 2, offset: 3).fetchAll(db)
        }
        #expect(page3.isEmpty)
    }

    @Test("Message.forSession query filters correctly")
    func messagesForSessionQuery() throws {
        let db = try createInMemoryDatabase()
        let sessionA = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil
        )
        let sessionB = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil
        )
        let msgA = Message(id: UUID(), sessionId: sessionA.id, role: .user, content: "A", timestamp: Date())
        let msgB = Message(id: UUID(), sessionId: sessionB.id, role: .user, content: "B", timestamp: Date())
        try db.write { db in
            try sessionA.insert(db)
            try sessionB.insert(db)
            try msgA.insert(db)
            try msgB.insert(db)
        }
        let results = try db.read { db in
            try Message.forSession(id: sessionA.id).fetchAll(db)
        }
        #expect(results.count == 1)
        #expect(results.first?.content == "A")
    }

    // --- Story 5.1 Tests ---

    @Test("v8 migration creates Sprint table with correct columns")
    func v8SprintTableCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let columns = try db.columns(in: "Sprint")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("id"))
            #expect(columnNames.contains("name"))
            #expect(columnNames.contains("startDate"))
            #expect(columnNames.contains("endDate"))
            #expect(columnNames.contains("status"))
        }
    }

    @Test("v8 migration creates SprintStep table with correct columns")
    func v8SprintStepTableCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let columns = try db.columns(in: "SprintStep")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("id"))
            #expect(columnNames.contains("sprintId"))
            #expect(columnNames.contains("description"))
            #expect(columnNames.contains("completed"))
            #expect(columnNames.contains("completedAt"))
            #expect(columnNames.contains("order"))
        }
    }

    @Test("v8 SprintStep sprintId index exists")
    func v8SprintStepIndexExists() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let indexes = try db.indexes(on: "SprintStep")
            let indexNames = indexes.map(\.name)
            #expect(indexNames.contains("idx_sprintstep_sprintId"))
        }
    }

    @Test("Can insert and fetch Sprint")
    func insertAndFetchSprint() throws {
        let db = try createInMemoryDatabase()
        let sprint = Sprint(
            id: UUID(),
            name: "Career Growth",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 14 * 86400),
            status: .active
        )
        try db.write { db in
            try sprint.insert(db)
        }
        let fetched = try db.read { db in
            try Sprint.fetchOne(db, key: sprint.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.name == "Career Growth")
        #expect(fetched?.status == .active)
    }

    @Test("Can insert and fetch SprintStep")
    func insertAndFetchSprintStep() throws {
        let db = try createInMemoryDatabase()
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 7 * 86400),
            status: .active
        )
        let step = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Research PM roles",
            completed: false,
            completedAt: nil,
            order: 1
        )
        try db.write { db in
            try sprint.insert(db)
            try step.insert(db)
        }
        let fetched = try db.read { db in
            try SprintStep.fetchOne(db, key: step.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.description == "Research PM roles")
        #expect(fetched?.sprintId == sprint.id)
    }

    @Test("SprintStep cascade delete when Sprint deleted")
    func sprintStepCascadeDelete() throws {
        let db = try createInMemoryDatabase()
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 7 * 86400),
            status: .active
        )
        let step = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Step 1",
            completed: false,
            completedAt: nil,
            order: 1
        )
        try db.write { db in
            try sprint.insert(db)
            try step.insert(db)
            try sprint.delete(db)
        }
        let remainingSteps = try db.read { db in
            try SprintStep.filter(Column("sprintId") == sprint.id).fetchCount(db)
        }
        #expect(remainingSteps == 0)
    }

    @Test("Sprint.active() query returns only active sprints")
    func sprintActiveQuery() throws {
        let db = try createInMemoryDatabase()
        let activeSprint = Sprint(id: UUID(), name: "Active", startDate: Date(), endDate: Date(timeIntervalSinceNow: 7 * 86400), status: .active)
        let completeSprint = Sprint(id: UUID(), name: "Complete", startDate: Date(timeIntervalSinceNow: -14 * 86400), endDate: Date(timeIntervalSinceNow: -7 * 86400), status: .complete)
        try db.write { db in
            try activeSprint.insert(db)
            try completeSprint.insert(db)
        }
        let result = try db.read { db in
            try Sprint.active().fetchOne(db)
        }
        #expect(result != nil)
        #expect(result?.name == "Active")
    }

    @Test("SprintStep.forSprint returns ordered steps")
    func sprintStepForSprintQuery() throws {
        let db = try createInMemoryDatabase()
        let sprint = Sprint(id: UUID(), name: "Test", startDate: Date(), endDate: Date(timeIntervalSinceNow: 7 * 86400), status: .active)
        let step3 = SprintStep(id: UUID(), sprintId: sprint.id, description: "Third", completed: false, completedAt: nil, order: 3)
        let step1 = SprintStep(id: UUID(), sprintId: sprint.id, description: "First", completed: false, completedAt: nil, order: 1)
        let step2 = SprintStep(id: UUID(), sprintId: sprint.id, description: "Second", completed: true, completedAt: Date(), order: 2)
        try db.write { db in
            try sprint.insert(db)
            try step3.insert(db)
            try step1.insert(db)
            try step2.insert(db)
        }
        let results = try db.read { db in
            try SprintStep.forSprint(id: sprint.id).fetchAll(db)
        }
        #expect(results.count == 3)
        #expect(results[0].description == "First")
        #expect(results[1].description == "Second")
        #expect(results[2].description == "Third")
        #expect(results[1].completed == true)
    }
}
