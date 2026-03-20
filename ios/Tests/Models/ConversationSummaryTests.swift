import Foundation
import Testing
import GRDB
@testable import sprinty

@Suite("ConversationSummary Tests")
struct ConversationSummaryTests {

    private func createInMemoryDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        return dbQueue
    }

    private func createSession(in db: DatabaseQueue) throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
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

    private func makeSummary(
        sessionId: UUID,
        summary: String = "Test summary",
        keyMoments: [String] = ["breakthrough moment"],
        domainTags: [String] = ["career"],
        emotionalMarkers: [String]? = nil,
        keyDecisions: [String]? = nil
    ) -> ConversationSummary {
        ConversationSummary(
            id: UUID(),
            sessionId: sessionId,
            summary: summary,
            keyMoments: ConversationSummary.encodeArray(keyMoments),
            domainTags: ConversationSummary.encodeArray(domainTags),
            emotionalMarkers: emotionalMarkers.map { ConversationSummary.encodeArray($0) },
            keyDecisions: keyDecisions.map { ConversationSummary.encodeArray($0) },
            goalReferences: nil,
            embedding: nil,
            createdAt: Date()
        )
    }

    // MARK: - Table Structure

    @Test("v5 migration creates ConversationSummary table with correct columns")
    func tableCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let columns = try db.columns(in: "ConversationSummary")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("id"))
            #expect(columnNames.contains("sessionId"))
            #expect(columnNames.contains("summary"))
            #expect(columnNames.contains("keyMoments"))
            #expect(columnNames.contains("domainTags"))
            #expect(columnNames.contains("emotionalMarkers"))
            #expect(columnNames.contains("keyDecisions"))
            #expect(columnNames.contains("goalReferences"))
            #expect(columnNames.contains("embedding"))
            #expect(columnNames.contains("createdAt"))
        }
    }

    @Test("v5 migration creates sessionId index")
    func indexCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let indexes = try db.indexes(on: "ConversationSummary")
            let indexNames = indexes.map(\.name)
            #expect(indexNames.contains("ConversationSummary_sessionId"))
        }
    }

    @Test("v5 migration is idempotent")
    func migrationIdempotent() throws {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        try migrator.migrate(dbQueue)
    }

    // MARK: - CRUD

    @Test("Can insert and fetch ConversationSummary")
    func insertAndFetch() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let summary = makeSummary(sessionId: session.id)

        try db.write { dbConn in
            try summary.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }

        #expect(fetched != nil)
        #expect(fetched?.summary == "Test summary")
        #expect(fetched?.sessionId == session.id)
    }

    @Test("Cascade delete removes summary when session deleted")
    func cascadeDelete() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let summary = makeSummary(sessionId: session.id)

        try db.write { dbConn in
            try summary.insert(dbConn)
        }

        try db.write { dbConn in
            _ = try ConversationSession.deleteOne(dbConn, key: session.id)
        }

        let fetched = try db.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }

        #expect(fetched == nil)
    }

    // MARK: - JSON Round-Trip

    @Test("JSON round-trip for keyMoments")
    func jsonRoundTrip_keyMoments() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let moments = ["realized pattern", "made commitment", "had breakthrough"]
        let summary = makeSummary(sessionId: session.id, keyMoments: moments)

        try db.write { dbConn in
            try summary.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }

        #expect(fetched?.decodedKeyMoments == moments)
    }

    @Test("JSON round-trip for domainTags")
    func jsonRoundTrip_domainTags() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let tags = ["career", "personal-growth"]
        let summary = makeSummary(sessionId: session.id, domainTags: tags)

        try db.write { dbConn in
            try summary.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }

        #expect(fetched?.decodedDomainTags == tags)
    }

    @Test("JSON round-trip for optional emotionalMarkers")
    func jsonRoundTrip_emotionalMarkers() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let markers = ["frustrated", "hopeful", "relieved"]
        let summary = makeSummary(sessionId: session.id, emotionalMarkers: markers)

        try db.write { dbConn in
            try summary.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }

        #expect(fetched?.decodedEmotionalMarkers == markers)
    }

    @Test("Nil emotionalMarkers decoded as nil")
    func jsonRoundTrip_nilEmotionalMarkers() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let summary = makeSummary(sessionId: session.id)

        try db.write { dbConn in
            try summary.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }

        #expect(fetched?.decodedEmotionalMarkers == nil)
    }

    @Test("JSON round-trip for optional keyDecisions")
    func jsonRoundTrip_keyDecisions() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let decisions = ["will apply for the role", "scheduled gym sessions"]
        let summary = makeSummary(sessionId: session.id, keyDecisions: decisions)

        try db.write { dbConn in
            try summary.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }

        #expect(fetched?.decodedKeyDecisions == decisions)
    }

    @Test("encodeArray handles empty array")
    func encodeArray_empty() {
        let encoded = ConversationSummary.encodeArray([])
        #expect(encoded == "[]")
    }

    // MARK: - Query Extensions

    @Test("forSession returns summaries for specific session")
    func forSessionQuery() throws {
        let db = try createInMemoryDatabase()
        let session1 = try createSession(in: db)
        let session2 = try createSession(in: db)

        let summary1 = makeSummary(sessionId: session1.id)
        let summary2 = makeSummary(sessionId: session2.id)

        try db.write { dbConn in
            try summary1.insert(dbConn)
            try summary2.insert(dbConn)
        }

        let results = try db.read { dbConn in
            try ConversationSummary.forSession(id: session1.id).fetchAll(dbConn)
        }

        #expect(results.count == 1)
        #expect(results[0].sessionId == session1.id)
    }

    @Test("recent returns summaries ordered by createdAt descending")
    func recentQuery() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)

        let older = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "older",
            keyMoments: "[]",
            domainTags: "[]",
            createdAt: Date(timeIntervalSinceNow: -3600)
        )
        let newer = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "newer",
            keyMoments: "[]",
            domainTags: "[]",
            createdAt: Date()
        )

        try db.write { dbConn in
            try older.insert(dbConn)
            try newer.insert(dbConn)
        }

        let results = try db.read { dbConn in
            try ConversationSummary.recent(limit: 10).fetchAll(dbConn)
        }

        #expect(results.count == 2)
        #expect(results[0].summary == "newer")
        #expect(results[1].summary == "older")
    }

    @Test("recent respects limit parameter")
    func recentQuery_limit() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)

        for i in 0..<5 {
            let s = ConversationSummary(
                id: UUID(),
                sessionId: session.id,
                summary: "summary \(i)",
                keyMoments: "[]",
                domainTags: "[]",
                createdAt: Date(timeIntervalSinceNow: Double(-i * 60))
            )
            try db.write { dbConn in
                try s.insert(dbConn)
            }
        }

        let results = try db.read { dbConn in
            try ConversationSummary.recent(limit: 2).fetchAll(dbConn)
        }

        #expect(results.count == 2)
    }

    @Test("forDomainTag filters by domain tag")
    func forDomainTagQuery() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)

        let careerSummary = makeSummary(sessionId: session.id, domainTags: ["career", "finance"])
        let healthSummary = makeSummary(sessionId: session.id, domainTags: ["health"])

        try db.write { dbConn in
            try careerSummary.insert(dbConn)
            try healthSummary.insert(dbConn)
        }

        let careerResults = try db.read { dbConn in
            try ConversationSummary.forDomainTag("career").fetchAll(dbConn)
        }

        #expect(careerResults.count == 1)
        #expect(careerResults[0].id == careerSummary.id)

        let healthResults = try db.read { dbConn in
            try ConversationSummary.forDomainTag("health").fetchAll(dbConn)
        }

        #expect(healthResults.count == 1)
        #expect(healthResults[0].id == healthSummary.id)
    }

    // MARK: - Performance

    @Test("Query performance with 100+ summaries")
    func queryPerformance_bulkInserts() throws {
        let db = try createInMemoryDatabase()
        let domains = ["career", "health", "finance", "relationships", "personal-growth", "creativity", "education", "family"]

        // Insert 150 summaries across 30 sessions
        var sessionIds: [UUID] = []
        for _ in 0..<30 {
            let session = try createSession(in: db)
            sessionIds.append(session.id)
        }

        try db.write { dbConn in
            for i in 0..<150 {
                let sessionId = sessionIds[i % sessionIds.count]
                let tag = domains[i % domains.count]
                let summary = ConversationSummary(
                    id: UUID(),
                    sessionId: sessionId,
                    summary: "Summary \(i)",
                    keyMoments: ConversationSummary.encodeArray(["moment \(i)"]),
                    domainTags: ConversationSummary.encodeArray([tag]),
                    createdAt: Date(timeIntervalSinceNow: Double(-i * 60))
                )
                try summary.insert(dbConn)
            }
        }

        // Verify queries return correct results at scale
        let recentResults = try db.read { dbConn in
            try ConversationSummary.recent(limit: 10).fetchAll(dbConn)
        }
        #expect(recentResults.count == 10)

        let careerResults = try db.read { dbConn in
            try ConversationSummary.forDomainTag("career").fetchAll(dbConn)
        }
        #expect(!careerResults.isEmpty)

        let sessionResults = try db.read { dbConn in
            try ConversationSummary.forSession(id: sessionIds[0]).fetchAll(dbConn)
        }
        #expect(!sessionResults.isEmpty)

        // Verify total count
        let totalCount = try db.read { dbConn in
            try ConversationSummary.fetchCount(dbConn)
        }
        #expect(totalCount == 150)
    }
}
