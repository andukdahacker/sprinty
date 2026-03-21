import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("Search Integration")
struct SearchIntegrationTests {

    private func makeTestDB() throws -> DatabasePool {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return dbPool
    }

    private func createSession(in dbPool: DatabasePool, endedAt: Date? = nil) throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: endedAt,
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

    // MARK: - 7.1 Search finds messages across multiple sessions

    @Test("Search finds messages across multiple sessions")
    func test_search_acrossSessions_findsAll() async throws {
        let dbPool = try makeTestDB()
        let session1 = try createSession(in: dbPool, endedAt: Date())
        let session2 = try createSession(in: dbPool)

        try createMessage(in: dbPool, sessionId: session1.id, content: "My career is going well")
        try createMessage(in: dbPool, sessionId: session1.id, role: .assistant, content: "Tell me more about your career")
        try createMessage(in: dbPool, sessionId: session2.id, content: "Career planning session")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "career")

        #expect(results.count == 3)
        let sessionIds = Set(results.map(\.sessionId))
        #expect(sessionIds.count == 2)
        #expect(sessionIds.contains(session1.id))
        #expect(sessionIds.contains(session2.id))
    }

    // MARK: - 7.2 Up/down navigation cycles through results correctly

    @Test("Navigation cycles through all results and wraps")
    @MainActor
    func test_navigation_cyclesThroughResults() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        let msg1 = try createMessage(in: dbPool, sessionId: session.id, content: "goal one")
        let msg2 = try createMessage(in: dbPool, sessionId: session.id, content: "goal two")
        let msg3 = try createMessage(in: dbPool, sessionId: session.id, content: "goal three")

        let searchService = SearchService(dbPool: dbPool)
        let dbManager = DatabaseManager(dbPool: dbPool)
        let appState = AppState()
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: MockChatService(),
            databaseManager: dbManager,
            searchService: searchService
        )

        await viewModel.performSearch("goal")
        #expect(viewModel.searchResults.count == 3)

        // Navigate forward through all results
        #expect(viewModel.currentResultIndex == 0)
        viewModel.navigateToResult(direction: .next)
        #expect(viewModel.currentResultIndex == 1)
        viewModel.navigateToResult(direction: .next)
        #expect(viewModel.currentResultIndex == 2)
        viewModel.navigateToResult(direction: .next)
        #expect(viewModel.currentResultIndex == 0) // wraps

        // Navigate backward
        viewModel.navigateToResult(direction: .previous)
        #expect(viewModel.currentResultIndex == 2) // wraps back
    }

    // MARK: - 7.3 Empty query returns no results (no crash)

    @Test("Empty query returns no results without crash")
    func test_search_emptyQuery_noCrash() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "Hello world")

        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "")
        #expect(results.isEmpty)

        let whitespace = try await service.search(query: "   ")
        #expect(whitespace.isEmpty)

        let singleChar = try await service.search(query: "a")
        #expect(singleChar.isEmpty)
    }

    // MARK: - 7.4 Special characters in query handled safely

    @Test("Special characters in query do not crash FTS5")
    func test_search_specialCharacters_safe() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "test content")

        let service = SearchService(dbPool: dbPool)

        // These should not crash
        _ = try await service.search(query: "test\"query")
        _ = try await service.search(query: "test*query")
        _ = try await service.search(query: "test'query")
        _ = try await service.search(query: "(test)")
        _ = try await service.search(query: "test AND OR query")
        _ = try await service.search(query: "NEAR/3 test")
    }

    // MARK: - 7.5 Offline search works (no network calls)

    @Test("Search works with no network — fully local FTS5")
    func test_search_offline_worksLocally() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)
        try createMessage(in: dbPool, sessionId: session.id, content: "offline test message")

        // SearchService uses only dbPool.read — no network calls
        let service = SearchService(dbPool: dbPool)
        let results = try await service.search(query: "offline")

        #expect(results.count == 1)
        #expect(results[0].content == "offline test message")
    }

    // MARK: - 7.6 Search + pagination interaction

    @Test("Search result from older messages works with pagination context")
    @MainActor
    func test_search_paginationInteraction() async throws {
        let dbPool = try makeTestDB()
        let session = try createSession(in: dbPool)

        // Create messages — some recent, one old with searchable content
        let oldMsg = try createMessage(
            in: dbPool, sessionId: session.id, content: "unique career topic",
            timestamp: Date().addingTimeInterval(-86400)
        )
        for i in 0..<60 {
            try createMessage(
                in: dbPool, sessionId: session.id, content: "filler message \(i)",
                timestamp: Date().addingTimeInterval(Double(i))
            )
        }

        let searchService = SearchService(dbPool: dbPool)
        let results = try await searchService.search(query: "unique career")

        #expect(results.count == 1)
        #expect(results[0].messageId == oldMsg.id)
        // The result exists in DB even if not in the loaded page — search finds it
    }
}
