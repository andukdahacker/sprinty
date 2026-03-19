import Foundation
import GRDB
import Testing
@testable import sprinty

@Suite("Embedding Pipeline Integration Tests")
struct EmbeddingPipelineIntegrationTests {
    @Test("Full pipeline: embed text → insert into sqlite-vec → query by similarity → verify correct result")
    func fullPipelineSmokeTest() throws {
        // Set up services
        let embeddingService = try EmbeddingService(
            modelURL: EmbeddingTestHelpers.modelURL(),
            vocabURL: EmbeddingTestHelpers.vocabURL()
        )
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("integration_\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        let vectorSearch = try VectorSearch(path: tempPath)
        try vectorSearch.createTable()

        // Generate embeddings for sample texts
        let texts = [
            "I want to set better goals for my career",
            "The stock market crashed today",
            "I need help with time management and productivity",
        ]

        var embeddings: [[Float]] = []
        for text in texts {
            let emb = try embeddingService.generateEmbedding(for: text)
            #expect(emb.count == 384)
            #expect(emb.filter { $0.isNaN }.isEmpty, "Embedding contains NaN for: \(text)")
            embeddings.append(emb)
        }

        // Insert embeddings into sqlite-vec
        for (i, emb) in embeddings.enumerated() {
            try vectorSearch.insert(rowid: Int64(i + 1), embedding: emb)
        }

        #expect(try vectorSearch.count() == 3)

        // Query with a text similar to the first one (career/goals)
        let queryEmb = try embeddingService.generateEmbedding(for: "How can I advance in my career?")
        let results = try vectorSearch.query(embedding: queryEmb, limit: 3)

        #expect(results.count == 3)
        // The closest match should be the career/goals text (rowid 1)
        #expect(results.first?.rowid == 1, "Expected career-related text (rowid 1) to be the top match, got rowid \(results.first?.rowid ?? -1)")

        // Query with text similar to productivity (third text)
        let queryEmb2 = try embeddingService.generateEmbedding(for: "Tips for being more productive at work")
        let results2 = try vectorSearch.query(embedding: queryEmb2, limit: 3)

        #expect(results2.count == 3)
        // Productivity text (rowid 3) should be closer than stock market text (rowid 2)
        let productivityRank: Int = results2.firstIndex { $0.rowid == 3 } ?? Int.max
        let stockRank: Int = results2.firstIndex { $0.rowid == 2 } ?? Int.max
        #expect(productivityRank < stockRank,
            "Productivity text should rank higher than stock market text for productivity query")
    }

    @Test("sqlite-vec and GRDB coexist on the same database file without WAL locking issues")
    func grdbAndSqliteVecCoexistence() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("coexist_\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: dbPath) }

        // Open with GRDB (simulates DatabaseManager's DatabasePool)
        let dbPool = try DatabasePool(path: dbPath)
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS conversation_summaries (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
                """)
        }

        // Open the same file with sqlite-vec (separate connection)
        let vectorSearch = try VectorSearch(path: dbPath)
        try vectorSearch.createTable()

        // Write metadata via GRDB
        let summaryId = UUID().uuidString
        try dbPool.write { db in
            try db.execute(
                sql: "INSERT INTO conversation_summaries (id, session_id, summary, created_at) VALUES (?, ?, ?, ?)",
                arguments: [summaryId, "session-1", "User discussed career goals", "2026-03-18"]
            )
        }

        // Write vector via sqlite-vec
        let embedding = (0..<384).map { Float($0) * 0.001 }
        try vectorSearch.insert(rowid: 1, embedding: embedding)

        // Read back via GRDB — verify no corruption
        let count = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM conversation_summaries")
        }
        #expect(count == 1)

        // Read back via sqlite-vec — verify vector is intact
        let vecCount = try vectorSearch.count()
        #expect(vecCount == 1)

        // Query vector while GRDB connection is open
        let results = try vectorSearch.query(embedding: embedding, limit: 1)
        #expect(results.count == 1)
        #expect(results.first?.rowid == 1)

        // Concurrent read from both — GRDB read + sqlite-vec query
        let grdbSummary = try dbPool.read { db in
            try String.fetchOne(db, sql: "SELECT summary FROM conversation_summaries WHERE id = ?", arguments: [summaryId])
        }
        #expect(grdbSummary == "User discussed career goals")

        let vecResults = try vectorSearch.query(embedding: embedding, limit: 1)
        #expect(vecResults.first?.rowid == 1)
    }
}
