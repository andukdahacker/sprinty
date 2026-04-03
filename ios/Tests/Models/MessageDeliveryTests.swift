import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("Message Delivery Status")
struct MessageDeliveryTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createSession(in db: DatabaseManager) async throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in
            try session.save(dbConn)
        }
        return session
    }

    @Test("Default delivery status is sent")
    func test_message_defaultDeliveryStatus_isSent() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let message = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Hello",
            timestamp: Date()
        )

        try await db.dbPool.write { dbConn in
            try message.save(dbConn)
        }

        let fetched = try await db.dbPool.read { dbConn in
            try Message.fetchOne(dbConn)
        }

        #expect(fetched?.deliveryStatus == .sent)
    }

    @Test("Pending query returns only pending messages")
    func test_message_pendingQuery_returnsPendingOnly() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let sentMsg = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Sent message",
            timestamp: Date(),
            deliveryStatus: .sent
        )

        let pendingMsg = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Pending message",
            timestamp: Date().addingTimeInterval(1),
            deliveryStatus: .pending
        )

        try await db.dbPool.write { dbConn in
            try sentMsg.save(dbConn)
            try pendingMsg.save(dbConn)
        }

        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }

        #expect(pending.count == 1)
        #expect(pending[0].content == "Pending message")
        #expect(pending[0].deliveryStatus == .pending)
    }

    @Test("Migration sets existing messages to sent status")
    func test_migration_existingMessages_haveSentStatus() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let message = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Pre-migration message",
            timestamp: Date()
        )

        try await db.dbPool.write { dbConn in
            try message.save(dbConn)
        }

        let fetched = try await db.dbPool.read { dbConn in
            try Message.fetchOne(dbConn)
        }

        #expect(fetched?.deliveryStatus == .sent)
    }

    @Test("Pending messages returned in chronological order")
    func test_message_pendingQuery_returnsInChronologicalOrder() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let first = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "First",
            timestamp: Date(),
            deliveryStatus: .pending
        )

        let second = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Second",
            timestamp: Date().addingTimeInterval(5),
            deliveryStatus: .pending
        )

        try await db.dbPool.write { dbConn in
            try second.save(dbConn)
            try first.save(dbConn)
        }

        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }

        #expect(pending.count == 2)
        #expect(pending[0].content == "First")
        #expect(pending[1].content == "Second")
    }

    @Test("Delivery status can be updated from pending to sent")
    func test_message_updateDeliveryStatus_pendingToSent() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let message = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Will be sent",
            timestamp: Date(),
            deliveryStatus: .pending
        )

        try await db.dbPool.write { dbConn in
            try message.save(dbConn)
        }

        var toUpdate = message
        toUpdate.deliveryStatus = .sent
        let updated = toUpdate
        try await db.dbPool.write { dbConn in
            try updated.update(dbConn)
        }

        let fetched = try await db.dbPool.read { dbConn in
            try Message.fetchOne(dbConn)
        }

        #expect(fetched?.deliveryStatus == .sent)

        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.isEmpty)
    }
}
