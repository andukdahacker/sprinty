import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 7.3 Tests ---

@Suite("EngagementSource Tests")
struct EngagementSourceTests {

    // MARK: - Test 6.1: Encoding/decoding and database round-trip

    @Test func test_engagementSource_encodingDecoding() throws {
        let sources: [EngagementSource] = [.organic, .checkInNotification, .reEngagementNudge, .milestoneNotification, .pauseSuggestionNotification]
        for source in sources {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(EngagementSource.self, from: data)
            #expect(decoded == source)
        }
    }

    @Test func test_engagementSource_rawValues() {
        #expect(EngagementSource.organic.rawValue == "organic")
        #expect(EngagementSource.checkInNotification.rawValue == "checkInNotification")
        #expect(EngagementSource.reEngagementNudge.rawValue == "reEngagementNudge")
        #expect(EngagementSource.milestoneNotification.rawValue == "milestoneNotification")
        #expect(EngagementSource.pauseSuggestionNotification.rawValue == "pauseSuggestionNotification")
    }

    @Test func test_engagementSource_databaseRoundTrip() throws {
        let dbPool = try makeTestDB()
        let dbManager = DatabaseManager(dbPool: dbPool)

        let sources: [EngagementSource] = [.organic, .checkInNotification, .reEngagementNudge, .milestoneNotification, .pauseSuggestionNotification]

        for source in sources {
            let session = ConversationSession(
                id: UUID(),
                startedAt: Date(),
                endedAt: nil,
                type: .coaching,
                mode: .discovery,
                safetyLevel: .green,
                engagementSource: source
            )

            try dbPool.write { db in
                try session.save(db)
            }

            let fetched = try dbPool.read { db in
                try ConversationSession.fetchOne(db, id: session.id)
            }

            #expect(fetched?.engagementSource == source)
        }
    }

    // MARK: - Test 6.2: ConversationSession creation with engagement source persists correctly

    @Test func test_conversationSession_defaultEngagementSource() throws {
        let dbPool = try makeTestDB()

        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green
        )

        try dbPool.write { db in
            try session.save(db)
        }

        let fetched = try dbPool.read { db in
            try ConversationSession.fetchOne(db, id: session.id)
        }

        #expect(fetched?.engagementSource == .organic)
    }

    @Test func test_conversationSession_explicitEngagementSource() throws {
        let dbPool = try makeTestDB()

        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            engagementSource: .checkInNotification
        )

        try dbPool.write { db in
            try session.save(db)
        }

        let fetched = try dbPool.read { db in
            try ConversationSession.fetchOne(db, id: session.id)
        }

        #expect(fetched?.engagementSource == .checkInNotification)
    }

    // MARK: - Helpers

    private func makeTestDB() throws -> DatabasePool {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return dbPool
    }
}
