import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("EngagementCalculator")
struct EngagementCalculatorTests {

    private func makeTestDB() throws -> DatabasePool {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return dbPool
    }

    private func createSession(
        in dbPool: DatabasePool,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        moodHistory: String? = nil
    ) async throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0",
            moodHistory: moodHistory
        )
        try await dbPool.write { db in
            try session.save(db)
        }
        return session
    }

    private func createMessage(
        in dbPool: DatabasePool,
        sessionId: UUID,
        role: MessageRole = .user,
        content: String = "test message"
    ) async throws {
        let msg = Message(
            id: UUID(),
            sessionId: sessionId,
            role: role,
            content: content,
            timestamp: Date()
        )
        try await dbPool.write { db in
            try msg.save(db)
        }
    }

    @Test("Recent activity returns high engagement")
    func test_engagementCalculator_recentActivity_returnsHighEngagement() async throws {
        let dbPool = try makeTestDB()
        let calculator = EngagementCalculator(dbPool: dbPool)

        // Create a session from 2 hours ago with medium-length messages
        let session = try await createSession(in: dbPool, startedAt: Date().addingTimeInterval(-2 * 3600))
        for _ in 0..<5 {
            try await createMessage(in: dbPool, sessionId: session.id, content: String(repeating: "word ", count: 20))
        }

        let snapshot = try await calculator.compute()
        #expect(snapshot.engagementLevel == .high)
    }

    @Test("Long gap returns low engagement")
    func test_engagementCalculator_longGap_returnsLowEngagement() async throws {
        let dbPool = try makeTestDB()
        let calculator = EngagementCalculator(dbPool: dbPool)

        // Create a session from 4 days ago
        let session = try await createSession(in: dbPool, startedAt: Date().addingTimeInterval(-96 * 3600))
        try await createMessage(in: dbPool, sessionId: session.id, content: "hi")

        let snapshot = try await calculator.compute()
        #expect(snapshot.engagementLevel == .low)
    }

    @Test("No sessions returns defaults")
    func test_engagementCalculator_noSessions_returnsDefaults() async throws {
        let dbPool = try makeTestDB()
        let calculator = EngagementCalculator(dbPool: dbPool)

        let snapshot = try await calculator.compute()
        #expect(snapshot.engagementLevel == .low)
        #expect(snapshot.recentMoods.isEmpty)
        #expect(snapshot.avgMessageLength == .short)
        #expect(snapshot.sessionCount == 0)
        #expect(snapshot.lastSessionGapHours == nil)
        #expect(snapshot.recentSessionIntensity == .light)
    }

    @Test("Mood history collected from recent sessions")
    func test_engagementCalculator_collectsMoodHistory() async throws {
        let dbPool = try makeTestDB()
        let calculator = EngagementCalculator(dbPool: dbPool)

        let moods = try JSONEncoder().encode(["warm", "focused", "gentle"])
        let moodJSON = String(data: moods, encoding: .utf8)!
        let session = try await createSession(in: dbPool, startedAt: Date().addingTimeInterval(-1 * 3600), moodHistory: moodJSON)
        try await createMessage(in: dbPool, sessionId: session.id, content: "test message content here")

        let snapshot = try await calculator.compute()
        #expect(snapshot.recentMoods == ["warm", "focused", "gentle"])
    }

    @Test("Session intensity deep for many messages")
    func test_engagementCalculator_deepIntensity() async throws {
        let dbPool = try makeTestDB()
        let calculator = EngagementCalculator(dbPool: dbPool)

        let session = try await createSession(in: dbPool, startedAt: Date().addingTimeInterval(-1 * 3600))
        for _ in 0..<20 {
            try await createMessage(in: dbPool, sessionId: session.id, content: String(repeating: "word ", count: 15))
        }

        let snapshot = try await calculator.compute()
        #expect(snapshot.recentSessionIntensity == .deep)
    }
}
