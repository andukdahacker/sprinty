import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("ProfileEnricher")
struct ProfileEnricherTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager, domainStates: [String: DomainState]? = nil) async throws -> UserProfile {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "default",
            coachAppearanceId: "default",
            coachName: "Luna",
            onboardingStep: 5,
            onboardingCompleted: true,
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: domainStates.map { UserProfile.encodeDomainStates($0) },
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.save(dbConn)
        }
        return profile
    }

    private func createSummary(sessionId: UUID = UUID(), domainTags: [String]) -> ConversationSummary {
        ConversationSummary(
            id: UUID(),
            sessionId: sessionId,
            summary: "Test summary",
            keyMoments: ConversationSummary.encodeArray(["moment"]),
            domainTags: ConversationSummary.encodeArray(domainTags),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date()
        )
    }

    // MARK: - Task 7.4: Domain enrichment tests

    @Test("Enrichment creates new domain state entries")
    func test_enrich_createsDomainEntries() async throws {
        let db = try makeTestDB()
        let _ = try await createProfile(in: db)
        let enricher = ProfileEnricher(databaseManager: db)

        let summary = createSummary(domainTags: ["career", "health"])
        try await enricher.enrich(from: summary)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        let states = profile?.decodedDomainStates ?? [:]
        #expect(states["career"]?.conversationCount == 1)
        #expect(states["health"]?.conversationCount == 1)
        #expect(states["career"]?.lastUpdated != nil)
    }

    @Test("Enrichment increments existing domain conversation count")
    func test_enrich_incrementsConversationCount() async throws {
        let db = try makeTestDB()
        let existing: [String: DomainState] = [
            "career": DomainState(status: "active", conversationCount: 3, lastUpdated: "2026-03-20")
        ]
        let _ = try await createProfile(in: db, domainStates: existing)
        let enricher = ProfileEnricher(databaseManager: db)

        let summary = createSummary(domainTags: ["career"])
        try await enricher.enrich(from: summary)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        let states = profile?.decodedDomainStates ?? [:]
        #expect(states["career"]?.conversationCount == 4)
        #expect(states["career"]?.status == "active")
    }

    // MARK: - Task 7.10: Empty domainTags is a no-op

    @Test("Summary with empty domainTags is a no-op")
    func test_enrich_emptyDomainTags_noOp() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db)
        let enricher = ProfileEnricher(databaseManager: db)

        let summary = createSummary(domainTags: [])
        try await enricher.enrich(from: summary)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.decodedDomainStates == nil)
    }

    @Test("Enrichment preserves existing domain state status")
    func test_enrich_preservesExistingStatus() async throws {
        let db = try makeTestDB()
        let existing: [String: DomainState] = [
            "health": DomainState(status: "improving", conversationCount: 2, lastUpdated: "2026-03-19")
        ]
        let _ = try await createProfile(in: db, domainStates: existing)
        let enricher = ProfileEnricher(databaseManager: db)

        let summary = createSummary(domainTags: ["health"])
        try await enricher.enrich(from: summary)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        let states = profile?.decodedDomainStates ?? [:]
        #expect(states["health"]?.status == "improving")
        #expect(states["health"]?.conversationCount == 3)
    }
}
