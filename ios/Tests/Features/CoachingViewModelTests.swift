import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("CoachingViewModel")
struct CoachingViewModelTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    @MainActor
    private func makeViewModel(
        chatService: MockChatService = MockChatService(),
        dbManager: DatabaseManager? = nil
    ) async throws -> (CoachingViewModel, MockChatService, DatabaseManager, AppState) {
        let db = try dbManager ?? makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        let viewModel = CoachingViewModel(appState: appState, chatService: chatService, databaseManager: db)
        return (viewModel, chatService, db, appState)
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

    @Test("Loads messages from database for current session")
    @MainActor
    func test_loadMessages_loadsFromDB() async throws {
        let (viewModel, _, db, _) = try await makeViewModel()

        let session = try await createSession(in: db)
        let msg = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Hello coach",
            timestamp: Date()
        )
        try await db.dbPool.write { dbConn in
            try msg.save(dbConn)
        }

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].content == "Hello coach")
    }

    @Test("Send message saves user message to DB and starts streaming")
    @MainActor
    func test_sendMessage_savesUserMessage() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response "),
            .token(text: "text."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "Hello")
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].content == "Response text.")
    }

    @Test("Expression transitions from thinking to mood on done event")
    @MainActor
    func test_sendMessage_expressionTransitions() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "warm", usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.coachExpression == .welcoming)

        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.coachExpression == .warm)
        #expect(viewModel.isStreaming == false)
    }

    @Test("Auth error routes to appState.needsReauth")
    @MainActor
    func test_sendMessage_authError_routesToAppState() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedError = AppError.authExpired

        let (viewModel, _, db, appState) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        #expect(appState.needsReauth == true)
    }

    @Test("Provider error routes to localError")
    @MainActor
    func test_sendMessage_providerError_routesToLocalError() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedError = AppError.providerError(message: "Coach needs a moment.", retryAfter: nil)

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.localError != nil)
    }

    @Test("Creates new session if none exists")
    @MainActor
    func test_loadMessages_createsSessionIfNoneExists() async throws {
        let (viewModel, _, _, _) = try await makeViewModel()

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.messages.isEmpty)
    }

    @Test("Empty message is not sent")
    @MainActor
    func test_sendMessage_emptyText_doesNothing() async throws {
        let mockChat = MockChatService()
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("   ")

        #expect(viewModel.messages.isEmpty)
        #expect(mockChat.lastMessages == nil)
    }

    @Test("Cancel streaming stops the task")
    @MainActor
    func test_cancelStreaming_stopsTask() async throws {
        let (viewModel, _, _, _) = try await makeViewModel()

        viewModel.isStreaming = true
        viewModel.streamingText = "partial..."

        viewModel.cancelStreaming()

        #expect(viewModel.isStreaming == false)
        #expect(viewModel.streamingText.isEmpty)
    }
}
