import Foundation
import Testing
import GRDB
@testable import ai_life_coach

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
}
