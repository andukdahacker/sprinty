import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SearchService")
struct SearchServiceTests {

    private func makeTestDB() throws -> DatabasePool {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return dbPool
    }

    private func createSession(in dbPool: DatabasePool) throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try dbPool.write { db in
            try session.save(db)
        }
        return session
    }

    private func createMessage(in dbPool: DatabasePool, sessionId: UUID, role: MessageRole = .user, content: String, timestamp: Date = Date()) throws -> Message {
        let message = Message(
            id: UUID(),
            sessionId: sessionId,
            role: role,
            content: content,
            timestamp: timestamp
        )
        try dbPool.write { db in
            try message.save(db)
        }
        return message
    }

    // MARK: - Search with matches

    @Test("Search returns matching messages")
    func test_search_withMatches_returnsResults() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        let msg = try createMessage(in: dbPool, sessionId: session.id, content: "I got a job offer today")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "job offer")

        #expect(results.count == 1)
        #expect(results[0].messageId == msg.id)
        #expect(results[0].sessionId == session.id)
        #expect(results[0].content == "I got a job offer today")
    }

    @Test("Search returns results across multiple sessions")
    func test_search_acrossSessions_returnsAll() async throws {
        let dbPool = try makeTestDB()
        let session1 = try createSession(in: dbPool)
        let session2 = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session1.id, content: "My career goals are important")
        try createMessage(in: dbPool, sessionId: session2.id, content: "Career growth is exciting")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "career")

        #expect(results.count == 2)
    }

    @Test("Search orders by FTS5 rank")
    func test_search_orderedByRelevance() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "The weather is nice today")
        try createMessage(in: dbPool, sessionId: session.id, content: "career career career goals")
        try createMessage(in: dbPool, sessionId: session.id, content: "My career plan")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "career")

        #expect(results.count == 2)
        // FTS5 rank orders by relevance — more occurrences rank higher
        #expect(results[0].content.contains("career career career"))
    }

    // MARK: - No matches

    @Test("Search with no matches returns empty array")
    func test_search_noMatches_returnsEmpty() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "Hello world")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "quantum")

        #expect(results.isEmpty)
    }

    // MARK: - Special characters

    @Test("Search handles double quotes safely")
    func test_search_doubleQuotes_nocrash() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "She said \"hello\" to me")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "\"hello\"")

        #expect(results.count == 1)
    }

    @Test("Search handles asterisks safely")
    func test_search_asterisks_noCrash() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "Important note here")

        let service = SearchService(dbPool: dbPool)
        // Should not crash — asterisks are wrapped in quotes by sanitizer
        let results = try await service.search(query: "important*")
        #expect(results.count >= 0)
    }

    // MARK: - Empty query

    @Test("Empty query returns empty results")
    func test_search_emptyQuery_returnsEmpty() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "Hello world")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "")

        #expect(results.isEmpty)
    }

    @Test("Whitespace-only query returns empty results")
    func test_search_whitespaceQuery_returnsEmpty() async throws {
        let dbPool = try makeTestDB()
        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "   ")

        #expect(results.isEmpty)
    }

    @Test("Single character query returns empty results")
    func test_search_singleChar_returnsEmpty() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "Hello a world")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "a")

        #expect(results.isEmpty)
    }

    // MARK: - FTS operators stripped

    @Test("FTS operators in query are stripped")
    func test_search_ftsOperators_stripped() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "career goals")

        let service = SearchService(dbPool: dbPool)
        // "AND" should be stripped, leaving just "career goals"
        let results = try await service.search(query: "career AND goals")

        #expect(results.count == 1)
    }

    @Test("Query with only FTS operators returns empty")
    func test_search_onlyOperators_returnsEmpty() async throws {
        let dbPool = try makeTestDB()
        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "AND OR NOT")

        #expect(results.isEmpty)
    }

    // MARK: - Limit

    @Test("Search respects limit parameter")
    func test_search_limit_respected() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        for i in 0..<10 {
            try createMessage(in: dbPool, sessionId: session.id, content: "career message \(i)")
        }

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "career", limit: 3)

        #expect(results.count == 3)
    }

    // MARK: - Sanitizer unit tests

    @Test("sanitizeFTSQuery returns nil for empty string")
    func test_sanitize_empty() {
        #expect(SearchService.sanitizeFTSQuery("") == nil)
    }

    @Test("sanitizeFTSQuery returns nil for single character")
    func test_sanitize_singleChar() {
        #expect(SearchService.sanitizeFTSQuery("a") == nil)
    }

    @Test("sanitizeFTSQuery wraps words in quotes")
    func test_sanitize_wrapsInQuotes() {
        let result = SearchService.sanitizeFTSQuery("job offer")
        #expect(result == "\"job\" \"offer\"")
    }

    @Test("sanitizeFTSQuery strips FTS operators")
    func test_sanitize_stripsOperators() {
        let result = SearchService.sanitizeFTSQuery("career AND goals")
        #expect(result == "\"career\" \"goals\"")
    }

    @Test("sanitizeFTSQuery escapes double quotes")
    func test_sanitize_escapesQuotes() {
        let result = SearchService.sanitizeFTSQuery("say \"hello\"")
        #expect(result == "\"say\" \"\"\"hello\"\"\"")
    }
}
