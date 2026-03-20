import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("EmbeddingPipeline")
struct EmbeddingPipelineTests {

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
            endedAt: Date(),
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

    private func createSummary(sessionId: UUID, embedding: Data? = nil, in db: DatabaseManager) async throws -> (ConversationSummary, Int64) {
        let summary = ConversationSummary(
            id: UUID(),
            sessionId: sessionId,
            summary: "Test conversation about career goals",
            keyMoments: ConversationSummary.encodeArray(["identified goal"]),
            domainTags: ConversationSummary.encodeArray(["career"]),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: embedding,
            createdAt: Date()
        )
        let rowid = try await db.dbPool.write { dbConn in
            try summary.insert(dbConn)
            return dbConn.lastInsertedRowID
        }
        return (summary, rowid)
    }

    // MARK: - Task 1: embed stores embedding in GRDB and sqlite-vec

    @Test("embed stores embedding in GRDB and sqlite-vec")
    func test_embed_storesEmbeddingInBothStores() async throws {
        let db = try makeTestDB()
        let mockEmbedding = MockEmbeddingService()
        let mockVector = MockVectorSearch()
        let pipeline = EmbeddingPipeline(embeddingService: mockEmbedding, vectorSearch: mockVector, databaseManager: db)

        let session = try await createSession(in: db)
        let (summary, rowid) = try await createSummary(sessionId: session.id, in: db)

        try await pipeline.embed(summary: summary, rowid: rowid)

        // Verify GRDB has embedding
        let updated = try await db.dbPool.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }
        #expect(updated?.embedding != nil)

        // Verify embedding data round-trips correctly
        let decoded = updated?.decodedEmbedding
        #expect(decoded?.count == 384)
        #expect(decoded?[0] == 0.1)

        // Verify sqlite-vec received insert
        #expect(mockVector.insertedItems.count == 1)
        #expect(mockVector.insertedItems[0].rowid == rowid)
        #expect(mockVector.insertedItems[0].embedding.count == 384)

        // Verify embedding service was called with summary text
        #expect(mockEmbedding.generateCallCount == 1)
        #expect(mockEmbedding.lastText == "Test conversation about career goals")
    }

    @Test("embed failure logs error and leaves embedding nil")
    func test_embed_failure_leavesEmbeddingNil() async throws {
        let db = try makeTestDB()
        let mockEmbedding = MockEmbeddingService()
        mockEmbedding.stubbedError = EmbeddingServiceError.invalidOutput
        let mockVector = MockVectorSearch()
        let pipeline = EmbeddingPipeline(embeddingService: mockEmbedding, vectorSearch: mockVector, databaseManager: db)

        let session = try await createSession(in: db)
        let (summary, rowid) = try await createSummary(sessionId: session.id, in: db)

        do {
            try await pipeline.embed(summary: summary, rowid: rowid)
            Issue.record("Expected embed to throw")
        } catch {
            // Expected
        }

        // Verify embedding remains nil
        let stored = try await db.dbPool.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }
        #expect(stored?.embedding == nil)

        // Verify vector search was NOT called
        #expect(mockVector.insertedItems.isEmpty)
    }

    // MARK: - Task 4: search returns ranked results

    @Test("search returns ranked ConversationSummary results")
    func test_search_returnsRankedResults() async throws {
        let db = try makeTestDB()
        let mockEmbedding = MockEmbeddingService()
        let mockVector = MockVectorSearch()
        let pipeline = EmbeddingPipeline(embeddingService: mockEmbedding, vectorSearch: mockVector, databaseManager: db)

        let session = try await createSession(in: db)

        // Create two summaries
        let summary1 = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "Career goals discussion",
            keyMoments: "[]",
            domainTags: "[\"career\"]",
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: ConversationSummary.encodeEmbedding(Array(repeating: Float(0.1), count: 384)),
            createdAt: Date(timeIntervalSinceNow: -3600)
        )

        let summary2 = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "Health and fitness talk",
            keyMoments: "[]",
            domainTags: "[\"health\"]",
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: ConversationSummary.encodeEmbedding(Array(repeating: Float(0.2), count: 384)),
            createdAt: Date()
        )

        let rowid1 = try await db.dbPool.write { dbConn in
            try summary1.insert(dbConn)
            return dbConn.lastInsertedRowID
        }
        let rowid2 = try await db.dbPool.write { dbConn in
            try summary2.insert(dbConn)
            return dbConn.lastInsertedRowID
        }

        // Mock vector search returns results in distance order (summary2 closer)
        mockVector.stubbedQueryResults = [
            VectorSearchResult(rowid: rowid2, distance: 0.1),
            VectorSearchResult(rowid: rowid1, distance: 0.5),
        ]

        let results = try await pipeline.search(query: "fitness goals", limit: 5)

        #expect(results.count == 2)
        #expect(results[0].id == summary2.id)  // Closer match first
        #expect(results[1].id == summary1.id)

        // Verify embedding was generated for query
        #expect(mockEmbedding.generateCallCount == 1)
        #expect(mockEmbedding.lastText == "fitness goals")
    }

    @Test("search returns empty array when no matches")
    func test_search_noMatches_returnsEmpty() async throws {
        let db = try makeTestDB()
        let mockEmbedding = MockEmbeddingService()
        let mockVector = MockVectorSearch()
        mockVector.stubbedQueryResults = []
        let pipeline = EmbeddingPipeline(embeddingService: mockEmbedding, vectorSearch: mockVector, databaseManager: db)

        let results = try await pipeline.search(query: "anything", limit: 5)
        #expect(results.isEmpty)
    }

    // MARK: - Task 5: retryMissingEmbeddings

    @Test("retryMissingEmbeddings processes only summaries with nil embedding")
    func test_retryMissingEmbeddings_processesOnlyNilEmbeddings() async throws {
        let db = try makeTestDB()
        let mockEmbedding = MockEmbeddingService()
        let mockVector = MockVectorSearch()
        let pipeline = EmbeddingPipeline(embeddingService: mockEmbedding, vectorSearch: mockVector, databaseManager: db)

        let session = try await createSession(in: db)

        // Summary WITH embedding (should be skipped)
        let embeddingData = ConversationSummary.encodeEmbedding(Array(repeating: Float(0.5), count: 384))
        let _ = try await createSummary(sessionId: session.id, embedding: embeddingData, in: db)

        // Summary WITHOUT embedding (should be processed)
        let _ = try await createSummary(sessionId: session.id, embedding: nil, in: db)

        await pipeline.retryMissingEmbeddings()

        // Only the nil-embedding summary should have been processed
        #expect(mockEmbedding.generateCallCount == 1)
        #expect(mockVector.insertedItems.count == 1)
    }

    @Test("retryMissingEmbeddings continues after individual failure")
    func test_retryMissingEmbeddings_continuesAfterFailure() async throws {
        let db = try makeTestDB()
        let mockEmbedding = MockEmbeddingService()
        let mockVector = MockVectorSearch()
        let pipeline = EmbeddingPipeline(embeddingService: mockEmbedding, vectorSearch: mockVector, databaseManager: db)

        let session = try await createSession(in: db)

        // Create two summaries without embeddings
        let _ = try await createSummary(sessionId: session.id, embedding: nil, in: db)
        let _ = try await createSummary(sessionId: session.id, embedding: nil, in: db)

        // Fail on first vectorSearch insert, succeed on second
        mockVector.insertFailOnce = true

        await pipeline.retryMissingEmbeddings()

        // Both summaries should have been attempted despite first failure
        #expect(mockEmbedding.generateCallCount == 2)
        // Only the second insert should have succeeded
        #expect(mockVector.insertedItems.count == 1)
    }

    // MARK: - Task 6: ConversationSummary embedding helpers

    @Test("encodeEmbedding and decodedEmbedding round-trip correctly")
    func test_embeddingRoundTrip() {
        let original: [Float] = [0.1, 0.2, 0.3, -0.5, 1.0]
        let data = ConversationSummary.encodeEmbedding(original)

        let summary = ConversationSummary(
            id: UUID(),
            sessionId: UUID(),
            summary: "test",
            keyMoments: "[]",
            domainTags: "[]",
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: data,
            createdAt: Date()
        )

        let decoded = summary.decodedEmbedding
        #expect(decoded != nil)
        #expect(decoded?.count == 5)
        #expect(decoded?[0] == 0.1)
        #expect(decoded?[3] == -0.5)
        #expect(decoded?[4] == 1.0)
    }

    @Test("decodedEmbedding returns nil when embedding is nil")
    func test_decodedEmbedding_nilData_returnsNil() {
        let summary = ConversationSummary(
            id: UUID(),
            sessionId: UUID(),
            summary: "test",
            keyMoments: "[]",
            domainTags: "[]",
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date()
        )

        #expect(summary.decodedEmbedding == nil)
    }

    @Test("withoutEmbedding query filters correctly")
    func test_withoutEmbedding_filtersCorrectly() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)

        // One with embedding, one without
        let embeddingData = ConversationSummary.encodeEmbedding(Array(repeating: Float(0.1), count: 384))
        let _ = try await createSummary(sessionId: session.id, embedding: embeddingData, in: db)
        let (summaryWithout, _) = try await createSummary(sessionId: session.id, embedding: nil, in: db)

        let results = try await db.dbPool.read { dbConn in
            try ConversationSummary.withoutEmbedding().fetchAll(dbConn)
        }

        #expect(results.count == 1)
        #expect(results[0].id == summaryWithout.id)
    }
}
