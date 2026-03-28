import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("Compliance Logging Integration")
struct ComplianceLoggingIntegrationTests {

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
        complianceLogger: MockComplianceLogger = MockComplianceLogger(),
        dbManager: DatabaseManager? = nil
    ) async throws -> (CoachingViewModel, MockChatService, MockComplianceLogger, DatabaseManager) {
        let db = try dbManager ?? makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: chatService,
            databaseManager: db,
            complianceLogger: complianceLogger
        )
        return (viewModel, chatService, complianceLogger, db)
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

    private func createMessage(in db: DatabaseManager, sessionId: UUID) async throws -> Message {
        let msg = Message(
            id: UUID(),
            sessionId: sessionId,
            role: .user,
            content: "Hello",
            timestamp: Date()
        )
        try await db.dbPool.write { dbConn in
            try msg.save(dbConn)
        }
        return msg
    }

    // MARK: - Compliance logging triggers

    @Test("Yellow safety level triggers compliance logging")
    @MainActor
    func test_yellowLevel_triggersComplianceLog() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "yellow", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, mockLogger, db) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(mockLogger.logCallCount == 1)
        #expect(mockLogger.lastLevel == .yellow)
        #expect(mockLogger.lastSource == .genuine)
    }

    @Test("Orange safety level triggers compliance logging")
    @MainActor
    func test_orangeLevel_triggersComplianceLog() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "orange", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, mockLogger, db) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(mockLogger.logCallCount == 1)
        #expect(mockLogger.lastLevel == .orange)
    }

    @Test("Red safety level triggers compliance logging")
    @MainActor
    func test_redLevel_triggersComplianceLog() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "red", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, mockLogger, db) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(mockLogger.logCallCount == 1)
        #expect(mockLogger.lastLevel == .red)
    }

    @Test("Green safety level does NOT trigger compliance logging")
    @MainActor
    func test_greenLevel_doesNotTriggerComplianceLog() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, mockLogger, db) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(mockLogger.logCallCount == 0)
    }

    @Test("Failsafe classification triggers compliance logging with failsafe source")
    @MainActor
    func test_failsafeClassification_logsWithFailsafeSource() async throws {
        let mockChat = MockChatService()
        // Unknown safetyLevel → nil → failsafe classification to yellow
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "unknown_value", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil),
        ]
        let (viewModel, _, mockLogger, db) = try await makeViewModel(chatService: mockChat)

        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")

        try await Task.sleep(for: .milliseconds(300))

        #expect(mockLogger.logCallCount == 1)
        #expect(mockLogger.lastSource == .failsafe)
    }
}
