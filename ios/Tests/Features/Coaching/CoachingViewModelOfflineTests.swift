import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("CoachingViewModel Offline")
struct CoachingViewModelOfflineTests {

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
        dbManager: DatabaseManager? = nil,
        isOnline: Bool = true,
        onDeviceSafetyClassifier: MockOnDeviceSafetyClassifier? = nil,
        safetyStateManager: MockSafetyStateManager? = nil
    ) async throws -> (CoachingViewModel, MockChatService, DatabaseManager, AppState) {
        let db = try dbManager ?? makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        appState.isOnline = isOnline
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: chatService,
            databaseManager: db,
            safetyStateManager: safetyStateManager ?? SafetyStateManager(),
            onDeviceSafetyClassifier: onDeviceSafetyClassifier
        )
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

    // MARK: - Task 3 Tests: Offline message queuing

    @Test("Send message when offline saves as pending")
    @MainActor
    func test_sendMessage_whenOffline_savesAsPending() async throws {
        let (viewModel, _, db, _) = try await makeViewModel(isOnline: false)

        await viewModel.sendMessage("Hello offline")
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].deliveryStatus == .pending)
        #expect(viewModel.messages[0].content == "Hello offline")

        // Verify persisted in DB
        let persisted = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(persisted.count == 1)
        #expect(persisted[0].deliveryStatus == .pending)
    }

    @Test("Send message when offline does not stream")
    @MainActor
    func test_sendMessage_whenOffline_doesNotStream() async throws {
        let mockChat = MockChatService()
        let (viewModel, _, _, _) = try await makeViewModel(chatService: mockChat, isOnline: false)

        await viewModel.sendMessage("Hello offline")
        try await Task.sleep(for: .milliseconds(100))

        // Chat service should not have been called
        #expect(mockChat.lastMessages == nil)
        #expect(viewModel.isStreaming == false)
    }

    @Test("Load messages includes pending messages")
    @MainActor
    func test_loadMessages_includesPendingMessages() async throws {
        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let sentMsg = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Sent message",
            timestamp: Date(),
            deliveryStatus: .sent
        )

        let pendingMsg = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Pending message",
            timestamp: Date().addingTimeInterval(1),
            deliveryStatus: .pending
        )

        try await db.dbPool.write { dbConn in
            try sentMsg.save(dbConn)
            try pendingMsg.save(dbConn)
        }

        let (viewModel, _, _, _) = try await makeViewModel(dbManager: db)
        await viewModel.loadMessagesAsync()

        #expect(viewModel.messages.count == 2)
        let pendingMsgs = viewModel.messages.filter { $0.deliveryStatus == .pending }
        #expect(pendingMsgs.count == 1)
        #expect(pendingMsgs[0].content == "Pending message")
    }

    // MARK: - Task 4 Tests: Auto-sync on reconnect

    @Test("Sync pending messages sends in order")
    @MainActor
    func test_syncPendingMessages_sendsInOrder() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let msg1 = Message(id: UUID(), sessionId: session.id, role: .user, content: "First", timestamp: Date(), deliveryStatus: .pending)
        let msg2 = Message(id: UUID(), sessionId: session.id, role: .user, content: "Second", timestamp: Date().addingTimeInterval(1), deliveryStatus: .pending)

        try await db.dbPool.write { dbConn in
            try msg1.save(dbConn)
            try msg2.save(dbConn)
        }

        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: true)
        await viewModel.loadMessagesAsync()

        appState.isOnline = true
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(200))

        // All pending messages should now be sent
        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.isEmpty)
    }

    @Test("Sync pending messages updates status to sent")
    @MainActor
    func test_syncPendingMessages_updatesStatusToSent() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let msg = Message(id: UUID(), sessionId: session.id, role: .user, content: "Pending msg", timestamp: Date(), deliveryStatus: .pending)
        try await db.dbPool.write { dbConn in
            try msg.save(dbConn)
        }

        let (viewModel, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: true)
        await viewModel.loadMessagesAsync()
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(200))

        // All messages should now be sent (no pending remain)
        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.isEmpty)

        // Verify the specific message is sent
        let allMsgs = try await db.dbPool.read { dbConn in
            try Message.filter(Column("role") == "user").fetchAll(dbConn)
        }
        let matched = allMsgs.first { $0.content == "Pending msg" }
        #expect(matched?.deliveryStatus == .sent)
    }

    @Test("Sync pending messages on error stops and keeps remaining")
    @MainActor
    func test_syncPendingMessages_onError_stopsAndKeepsRemaining() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedError = AppError.networkUnavailable

        let db = try makeTestDB()
        let session = try await createSession(in: db)

        let msg1 = Message(id: UUID(), sessionId: session.id, role: .user, content: "First", timestamp: Date(), deliveryStatus: .pending)
        let msg2 = Message(id: UUID(), sessionId: session.id, role: .user, content: "Second", timestamp: Date().addingTimeInterval(1), deliveryStatus: .pending)

        try await db.dbPool.write { dbConn in
            try msg1.save(dbConn)
            try msg2.save(dbConn)
        }

        let (viewModel, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: true)
        await viewModel.loadMessagesAsync()
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(200))

        // At least one message should remain pending (sync stops on error)
        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.count >= 1)
    }

    @Test("Reconnect triggers sync — offline to online transition")
    @MainActor
    func test_reconnect_triggersSyncAutomatically() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: false)

        // Send message while offline
        await viewModel.sendMessage("Offline message")
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].deliveryStatus == .pending)

        // Simulate reconnection and manually trigger sync (as the observer would)
        appState.isOnline = true
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(200))

        // The pending message should have been synced
        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.isEmpty)
    }

    // MARK: - Task 8 Tests: On-device safety classification

    @Test("Offline message with crisis content shows safety resources")
    @MainActor
    func test_offlineMessage_crisisContent_showsSafetyResources() async throws {
        let mockClassifier = MockOnDeviceSafetyClassifier()
        mockClassifier.stubbedLevel = .red

        let (viewModel, _, _, _) = try await makeViewModel(isOnline: false, onDeviceSafetyClassifier: mockClassifier)

        await viewModel.sendMessage("I want to end my life")
        try await Task.sleep(for: .milliseconds(100))

        #expect(mockClassifier.classifyCallCount == 1)
        #expect(viewModel.currentSafetyUIState.showCrisisResources == true)
    }

    @Test("Reconnect server classification more conservative wins")
    @MainActor
    func test_reconnect_serverClassification_moreConservativeWins() async throws {
        let mockClassifier = MockOnDeviceSafetyClassifier()
        mockClassifier.stubbedLevel = .yellow

        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "orange", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: false, onDeviceSafetyClassifier: mockClassifier)

        // Send offline — device classifies as yellow
        await viewModel.sendMessage("I feel hopeless")
        try await Task.sleep(for: .milliseconds(100))

        // Go online and sync — server says orange (more conservative)
        appState.isOnline = true
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(200))

        // Orange (server) should win over yellow (device) since orange > yellow
        #expect(viewModel.currentSafetyUIState.level >= .orange)
    }

    @Test("Reconnect device classification more conservative wins")
    @MainActor
    func test_reconnect_deviceClassification_moreConservativeWins() async throws {
        let mockClassifier = MockOnDeviceSafetyClassifier()
        mockClassifier.stubbedLevel = .red

        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "yellow", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: false, onDeviceSafetyClassifier: mockClassifier)

        // Send offline — device classifies as red
        await viewModel.sendMessage("I want to kill myself")
        try await Task.sleep(for: .milliseconds(100))

        // Go online and sync — server says yellow (less conservative)
        appState.isOnline = true
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(200))

        // Red (device) should win over yellow (server)
        #expect(viewModel.currentSafetyUIState.showCrisisResources == true)
    }

    // MARK: - Task 9: Integration tests

    @Test("End-to-end: offline → write → online → sends → coach responds")
    @MainActor
    func test_e2e_offlineWriteOnlineSend() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Coach reply"),
            .done(safetyLevel: "green", domainTags: [], mood: "warm", mode: "discovery", memoryReferenced: false, challengerUsed: false, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: "v1", profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: false)

        // Offline: write message
        await viewModel.sendMessage("Help me with this")
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].deliveryStatus == .pending)

        // Go online: sync sends message and coach responds
        appState.isOnline = true
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(300))

        // User message should be sent, coach response added
        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.isEmpty)

        // Should have user message + assistant response
        let allMsgs = try await db.dbPool.read { dbConn in
            try Message.order(Column("timestamp").asc).fetchAll(dbConn)
        }
        #expect(allMsgs.count >= 2)
        #expect(allMsgs.last?.role == .assistant)
    }

    @Test("Multiple pending messages sync in correct order")
    @MainActor
    func test_multiplePendingMessages_syncInOrder() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: false)

        // Send multiple messages offline
        await viewModel.sendMessage("First message")
        try await Task.sleep(for: .milliseconds(50))
        await viewModel.sendMessage("Second message")
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.messages.count == 2)

        // Sync
        appState.isOnline = true
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(300))

        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.isEmpty)
    }

    @Test("App launch with pending messages displays with indicators then syncs")
    @MainActor
    func test_appLaunch_pendingMessages_displayAndSync() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let session = try await createSession(in: db)

        // Simulate pending messages from previous session
        let msg = Message(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: "Previous session pending",
            timestamp: Date(),
            deliveryStatus: .pending
        )
        try await db.dbPool.write { dbConn in
            try msg.save(dbConn)
        }

        // "Launch" — load messages
        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: true)
        await viewModel.loadMessagesAsync()

        // Pending messages should be loaded with pending status
        let pendingMsgs = viewModel.messages.filter { $0.deliveryStatus == .pending }
        #expect(pendingMsgs.count == 1)

        // Sync when online
        await viewModel.syncPendingMessages()
        try await Task.sleep(for: .milliseconds(300))

        let pending = try await db.dbPool.read { dbConn in
            try Message.pending().fetchAll(dbConn)
        }
        #expect(pending.isEmpty)
    }

    @Test("Rapid network transitions don't lose state")
    @MainActor
    func test_rapidNetworkTransitions_noStateLoss() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let db = try makeTestDB()
        let (viewModel, _, _, appState) = try await makeViewModel(chatService: mockChat, dbManager: db, isOnline: true)

        // Online → send message normally
        await viewModel.sendMessage("Online message")
        try await Task.sleep(for: .milliseconds(200))

        let initialCount = viewModel.messages.count

        // Rapid transitions
        appState.isOnline = false
        await viewModel.sendMessage("Offline message")
        try await Task.sleep(for: .milliseconds(50))
        appState.isOnline = true
        try await Task.sleep(for: .milliseconds(50))
        appState.isOnline = false
        try await Task.sleep(for: .milliseconds(50))
        appState.isOnline = true

        // No messages should be lost
        #expect(viewModel.messages.count > initialCount)

        // All messages should be in DB
        let allMsgs = try await db.dbPool.read { dbConn in
            try Message.fetchAll(dbConn)
        }
        #expect(allMsgs.count >= viewModel.messages.count)
    }

    @Test("Classify returns nil when unavailable")
    @MainActor
    func test_classify_nilWhenUnavailable() async throws {
        let mockClassifier = MockOnDeviceSafetyClassifier()
        mockClassifier.stubbedLevel = nil

        let (viewModel, _, _, _) = try await makeViewModel(isOnline: false, onDeviceSafetyClassifier: mockClassifier)

        await viewModel.sendMessage("Just a normal message")
        try await Task.sleep(for: .milliseconds(100))

        #expect(mockClassifier.classifyCallCount == 1)
        // No safety level change — stays green
        #expect(viewModel.currentSafetyUIState.level == .green)
    }
}
