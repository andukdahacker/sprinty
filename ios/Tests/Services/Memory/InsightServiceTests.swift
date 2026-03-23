import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("InsightService")
struct InsightServiceTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createSession(in db: DatabaseManager, endedAt: Date? = Date()) async throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: endedAt,
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

    private func createSummary(
        sessionId: UUID,
        summary: String = "Test conversation about career goals",
        keyMoments: [String] = ["identified goal"],
        in db: DatabaseManager
    ) async throws {
        let summaryRecord = ConversationSummary(
            id: UUID(),
            sessionId: sessionId,
            summary: summary,
            keyMoments: ConversationSummary.encodeArray(keyMoments),
            domainTags: ConversationSummary.encodeArray(["career"]),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try summaryRecord.save(dbConn)
        }
    }

    // MARK: - Empty database

    @Test("Returns nil when no conversations exist")
    func test_generateDailyInsight_emptyDB_returnsNil() async throws {
        let db = try makeTestDB()
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let insight = await service.generateDailyInsight()

        #expect(insight == nil)
    }

    // MARK: - Key moment fallback

    @Test("Returns key moment from most recent summary")
    func test_generateDailyInsight_withKeyMoment_returnsKeyMoment() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            keyMoments: ["You showed great resilience today"],
            in: db
        )
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let insight = await service.generateDailyInsight()

        #expect(insight == "You showed great resilience today")
    }

    // MARK: - Summary text fallback

    @Test("Returns summary text when no key moments exist")
    func test_generateDailyInsight_noKeyMoments_returnsSummaryText() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            summary: "Discussed career transition strategies",
            keyMoments: [],
            in: db
        )
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let insight = await service.generateDailyInsight()

        #expect(insight == "Discussed career transition strategies")
    }

    // MARK: - Getting-to-know-you fallback

    @Test("Returns fallback when summary has no usable content")
    func test_generateDailyInsight_emptySummaryContent_returnsFallback() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            summary: "",
            keyMoments: [],
            in: db
        )
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let insight = await service.generateDailyInsight()

        #expect(insight == "Your coach is getting to know you...")
    }

    // MARK: - Caching

    @Test("Returns cached value on repeated calls with same session")
    func test_generateDailyInsight_cachingHit_skipsDatabaseQuery() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            keyMoments: ["First insight"],
            in: db
        )
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let first = await service.generateDailyInsight()
        let second = await service.generateDailyInsight()

        #expect(first == "First insight")
        #expect(second == "First insight")
    }

    // MARK: - Cache invalidation

    @Test("Regenerates insight when new session completes")
    func test_generateDailyInsight_newSession_invalidatesCache() async throws {
        let db = try makeTestDB()
        let session1 = try await createSession(in: db)
        try await createSummary(
            sessionId: session1.id,
            keyMoments: ["Old insight"],
            in: db
        )
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let first = await service.generateDailyInsight()
        #expect(first == "Old insight")

        // Complete a new session with different insight
        let session2 = try await createSession(in: db)
        try await createSummary(
            sessionId: session2.id,
            keyMoments: ["New insight"],
            in: db
        )

        let second = await service.generateDailyInsight()
        #expect(second == "New insight")
    }

    // MARK: - Nil embedding pipeline

    @Test("Works correctly with nil embedding pipeline")
    func test_generateDailyInsight_nilEmbeddingPipeline_usesLocalFallback() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            keyMoments: ["Local insight"],
            in: db
        )
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let insight = await service.generateDailyInsight()

        #expect(insight == "Local insight")
    }

    // MARK: - Embedding pipeline integration

    @Test("Uses semantic search result when embedding pipeline available")
    func test_generateDailyInsight_withEmbeddingPipeline_usesSemanticResult() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            summary: "Career goals discussion",
            keyMoments: ["Direct key moment"],
            in: db
        )

        let mockPipeline = MockEmbeddingPipeline()
        // Return a different summary via semantic search
        let semanticSummary = ConversationSummary(
            id: UUID(), // Different ID than the most recent
            sessionId: UUID(),
            summary: "Older related conversation",
            keyMoments: ConversationSummary.encodeArray(["Semantic key moment"]),
            domainTags: ConversationSummary.encodeArray(["career"]),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date().addingTimeInterval(-86400)
        )
        mockPipeline.stubbedSearchResults = [semanticSummary]

        let service = InsightService(databaseManager: db, embeddingPipeline: mockPipeline)

        let insight = await service.generateDailyInsight()

        #expect(insight == "Semantic key moment")
        #expect(mockPipeline.searchCallCount == 1)
    }

    // MARK: - Embedding pipeline error handling

    @Test("Falls back to local data when embedding pipeline errors")
    func test_generateDailyInsight_embeddingPipelineError_fallsBackToLocal() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            keyMoments: ["Local fallback moment"],
            in: db
        )

        let mockPipeline = MockEmbeddingPipeline()
        mockPipeline.stubbedSearchError = NSError(domain: "test", code: 1)

        let service = InsightService(databaseManager: db, embeddingPipeline: mockPipeline)

        let insight = await service.generateDailyInsight()

        #expect(insight == "Local fallback moment")
    }

    // MARK: - Multiple summaries

    @Test("Uses most recent summary's key moment")
    func test_generateDailyInsight_multipleSummaries_usesMostRecent() async throws {
        let db = try makeTestDB()

        let session1 = try await createSession(in: db)
        try await createSummary(
            sessionId: session1.id,
            keyMoments: ["Older moment"],
            in: db
        )

        // Small delay to ensure ordering
        try await Task.sleep(for: .milliseconds(10))

        let session2 = try await createSession(in: db)
        try await createSummary(
            sessionId: session2.id,
            keyMoments: ["Newest moment"],
            in: db
        )

        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let insight = await service.generateDailyInsight()

        #expect(insight == "Newest moment")
    }

    // MARK: - Empty key moments array

    @Test("Falls back to summary when key moments array has empty string")
    func test_generateDailyInsight_emptyKeyMomentString_fallsToSummary() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)
        try await createSummary(
            sessionId: session.id,
            summary: "Good discussion about goals",
            keyMoments: [""],
            in: db
        )
        let service = InsightService(databaseManager: db, embeddingPipeline: nil)

        let insight = await service.generateDailyInsight()

        #expect(insight == "Good discussion about goals")
    }
}
