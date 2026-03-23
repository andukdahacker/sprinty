import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("ConversationSession Query Tests")
struct ConversationSessionQueryTests {

    private func createInMemoryDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        return dbQueue
    }

    private func createSession(
        in db: DatabaseQueue,
        endedAt: Date? = nil
    ) throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: endedAt,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try db.write { dbConn in
            try session.save(dbConn)
        }
        return session
    }

    // MARK: - completedCount

    @Test("completedCount returns 0 with no sessions")
    func test_completedCount_empty_zero() throws {
        let db = try createInMemoryDatabase()
        let count = try db.read { dbConn in
            try ConversationSession.completedCount(dbConn)
        }
        #expect(count == 0)
    }

    @Test("completedCount counts only sessions with non-nil endedAt")
    func test_completedCount_mixedSessions_countsCompleted() throws {
        let db = try createInMemoryDatabase()
        _ = try createSession(in: db, endedAt: Date()) // completed
        _ = try createSession(in: db, endedAt: Date()) // completed
        _ = try createSession(in: db, endedAt: nil)    // open

        let count = try db.read { dbConn in
            try ConversationSession.completedCount(dbConn)
        }
        #expect(count == 2)
    }

    @Test("completedCount returns 0 when all sessions are open")
    func test_completedCount_allOpen_zero() throws {
        let db = try createInMemoryDatabase()
        _ = try createSession(in: db, endedAt: nil)
        _ = try createSession(in: db, endedAt: nil)

        let count = try db.read { dbConn in
            try ConversationSession.completedCount(dbConn)
        }
        #expect(count == 0)
    }
}
