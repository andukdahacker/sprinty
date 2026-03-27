import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("CoachingViewModel Safety")
struct CoachingViewModelSafetyTests {

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
        safetyHandler: SafetyHandlerProtocol = SafetyHandler(),
        dbManager: DatabaseManager? = nil
    ) async throws -> (CoachingViewModel, MockChatService, DatabaseManager, AppState) {
        let db = try dbManager ?? makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: chatService,
            databaseManager: db,
            safetyHandler: safetyHandler
        )
        return (viewModel, chatService, db, appState)
    }

    private func createSession(in db: DatabaseManager, safetyLevel: SafetyLevel = .green) async throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: safetyLevel,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in
            try session.save(dbConn)
        }
        return session
    }

    private func createMessage(in db: DatabaseManager, sessionId: UUID, role: MessageRole = .user, content: String = "Hello") async throws -> Message {
        let msg = Message(
            id: UUID(),
            sessionId: sessionId,
            role: role,
            content: content,
            timestamp: Date()
        )
        try await db.dbPool.write { dbConn in
            try msg.save(dbConn)
        }
        return msg
    }

    // MARK: - Done event triggers classification

    @Test("Done event triggers safety classification and updates UI state")
    @MainActor
    func test_doneEvent_triggersClassification() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "yellow", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)

        // Pre-create session and user message so sendMessage works
        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test message")

        // Wait for async processing
        try await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.currentSafetyUIState.level == .yellow)
        #expect(viewModel.currentSafetyUIState.coachExpression == .gentle)
    }

    @Test("Done event with missing safetyLevel fails safe to yellow")
    @MainActor
    func test_doneEvent_missingSafetyLevel_failsafeYellow() async throws {
        let mockChat = MockChatService()
        // Server returns unknown safety level (simulates parse failure)
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "unknown_level", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test message")

        try await Task.sleep(for: .milliseconds(300))

        // Unknown rawValue → SafetyLevel(rawValue:) returns nil → classify(serverLevel: nil) → .yellow
        #expect(viewModel.currentSafetyUIState.level == .yellow)
    }

    @Test("CoachExpression set to gentle on yellow safety level")
    @MainActor
    func test_yellowLevel_setsGentleExpression() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "yellow", domainTags: [], mood: "warm", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        // Safety override should set expression to gentle for yellow+
        #expect(viewModel.coachExpression == .gentle)
    }

    @Test("Orange safety level correctly classified")
    @MainActor
    func test_orangeLevel_correctlyClassified() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "orange", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.currentSafetyUIState.level == .orange)
        #expect(viewModel.currentSafetyUIState.showCrisisResources == true)
        #expect(viewModel.currentSafetyUIState.hiddenElements.contains(.gamification))
    }

    @Test("Session safety level persisted to database")
    @MainActor
    func test_safetyLevel_persistedToDB() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "red", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        // Verify safety level was persisted to database
        let updatedSession: ConversationSession? = try await db.dbPool.read { dbConn in
            try ConversationSession.fetchOne(dbConn, key: session.id)
        }
        #expect(updatedSession?.safetyLevel == .red)
    }

    @Test("Mock safety handler receives correct arguments")
    @MainActor
    func test_mockSafetyHandler_receivesArgs() async throws {
        let mockHandler = MockSafetyHandler()
        mockHandler.stubbedClassifyResult = .orange
        mockHandler.stubbedUIState = SafetyUIState(
            level: .orange,
            hiddenElements: [.gamification],
            coachExpression: .gentle,
            notificationBehavior: .safetyOnly,
            showCrisisResources: true
        )

        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "orange", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, safetyHandler: mockHandler)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(mockHandler.classifyCallCount == 1)
        #expect(mockHandler.lastClassifyServerLevel == .orange)
        #expect(mockHandler.uiStateCallCount == 1)
        #expect(viewModel.currentSafetyUIState.level == .orange)
    }

    @Test("Green safety level keeps normal state")
    @MainActor
    func test_greenLevel_normalState() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.currentSafetyUIState.level == .green)
        #expect(viewModel.currentSafetyUIState.hiddenElements.isEmpty)
        #expect(viewModel.currentSafetyUIState.showCrisisResources == false)
    }
}
