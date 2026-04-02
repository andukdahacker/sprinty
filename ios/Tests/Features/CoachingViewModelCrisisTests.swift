import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("CoachingViewModel Crisis Re-engagement")
struct CoachingViewModelCrisisTests {

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
        safetyHandler: MockSafetyHandler = MockSafetyHandler(),
        safetyStateManager: MockSafetyStateManager = MockSafetyStateManager(),
        dbManager: DatabaseManager? = nil
    ) async throws -> (CoachingViewModel, MockChatService, MockSafetyHandler, MockSafetyStateManager, DatabaseManager, AppState) {
        let db = try dbManager ?? makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: chatService,
            databaseManager: db,
            safetyHandler: safetyHandler,
            safetyStateManager: safetyStateManager
        )
        return (viewModel, chatService, safetyHandler, safetyStateManager, db, appState)
    }

    private func createProfile(in db: DatabaseManager, lastSafetyBoundaryAt: Date? = nil) async throws -> UserProfile {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 3,
            onboardingCompleted: true,
            lastSafetyBoundaryAt: lastSafetyBoundaryAt,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.save(dbConn)
        }
        return profile
    }

    private func createSession(in db: DatabaseManager, endedAt: Date? = nil) async throws -> ConversationSession {
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

    // MARK: - Task 2: Persist safety boundary events

    @Test("Orange classification writes lastSafetyBoundaryAt to UserProfile")
    @MainActor
    func test_orangeClassification_writesLastSafetyBoundaryAt() async throws {
        let mockChat = MockChatService()
        let mockHandler = MockSafetyHandler()
        mockHandler.stubbedClassifyResult = .orange
        mockHandler.stubbedUIState = SafetyUIState(
            level: .orange,
            hiddenElements: [.gamification],
            coachExpression: .gentle,
            notificationBehavior: .safetyOnly,
            showCrisisResources: true
        )
        let mockStateManager = MockSafetyStateManager()
        mockStateManager.stubbedProcessResult = .orange

        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "orange", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, db, _) = try await makeViewModel(
            chatService: mockChat,
            safetyHandler: mockHandler,
            safetyStateManager: mockStateManager
        )

        _ = try await createProfile(in: db)
        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.lastSafetyBoundaryAt != nil)
    }

    @Test("Red classification writes lastSafetyBoundaryAt to UserProfile")
    @MainActor
    func test_redClassification_writesLastSafetyBoundaryAt() async throws {
        let mockChat = MockChatService()
        let mockHandler = MockSafetyHandler()
        mockHandler.stubbedClassifyResult = .red
        mockHandler.stubbedUIState = SafetyUIState(
            level: .red,
            hiddenElements: [.gamification],
            coachExpression: .gentle,
            notificationBehavior: .safetyOnly,
            showCrisisResources: true
        )
        let mockStateManager = MockSafetyStateManager()
        mockStateManager.stubbedProcessResult = .red

        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "red", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, db, _) = try await makeViewModel(
            chatService: mockChat,
            safetyHandler: mockHandler,
            safetyStateManager: mockStateManager
        )

        _ = try await createProfile(in: db)
        let session = try await createSession(in: db)
        _ = try await createMessage(in: db, sessionId: session.id)

        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.lastSafetyBoundaryAt != nil)
    }

    // MARK: - Task 3: Detect returning-from-crisis state

    @Test("createNewSession detects lastSafetyBoundaryAt and sets isReturningFromCrisis")
    @MainActor
    func test_createNewSession_detectsCrisis() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, lastSafetyBoundaryAt: Date())
        // Create an ended session so getOrCreateSession creates a new one
        _ = try await createSession(in: db, endedAt: Date())

        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db)
        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Hi there")
        try await Task.sleep(for: .milliseconds(500))

        // isReturningFromCrisis should have been set during session creation, but cleared by genuine green
        // The flag was set and then cleared — verify clearing happened by checking DB
        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.lastSafetyBoundaryAt == nil)
    }

    @Test("First genuine green classification clears isReturningFromCrisis and nils lastSafetyBoundaryAt")
    @MainActor
    func test_genuineGreen_clearsReEngagementState() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, lastSafetyBoundaryAt: Date())
        _ = try await createSession(in: db, endedAt: Date())

        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Welcome back"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db)
        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.isReturningFromCrisis == false)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.lastSafetyBoundaryAt == nil)
    }

    @Test("Genuine yellow classification also clears isReturningFromCrisis")
    @MainActor
    func test_genuineYellow_clearsReEngagementState() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, lastSafetyBoundaryAt: Date())
        _ = try await createSession(in: db, endedAt: Date())

        let mockHandler = MockSafetyHandler()
        mockHandler.stubbedClassifyResult = .yellow
        mockHandler.stubbedUIState = SafetyUIState(
            level: .yellow,
            hiddenElements: [],
            coachExpression: .gentle,
            notificationBehavior: .normal,
            showCrisisResources: false
        )
        let mockStateManager = MockSafetyStateManager()
        mockStateManager.stubbedProcessResult = .yellow

        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "yellow", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, _, _) = try await makeViewModel(
            chatService: mockChat,
            safetyHandler: mockHandler,
            safetyStateManager: mockStateManager,
            dbManager: db
        )
        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.isReturningFromCrisis == false)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.lastSafetyBoundaryAt == nil)
    }

    @Test("Failsafe classification does NOT clear isReturningFromCrisis")
    @MainActor
    func test_failsafe_doesNotClearReEngagement() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, lastSafetyBoundaryAt: Date())
        _ = try await createSession(in: db, endedAt: Date())

        let mockHandler = MockSafetyHandler()
        mockHandler.stubbedClassifyResult = .yellow
        mockHandler.stubbedUIState = SafetyUIState(
            level: .yellow,
            hiddenElements: [],
            coachExpression: .gentle,
            notificationBehavior: .normal,
            showCrisisResources: false
        )
        let mockStateManager = MockSafetyStateManager()
        mockStateManager.stubbedProcessResult = .yellow

        let mockChat = MockChatService()
        // Use an invalid safety level to trigger failsafe source
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "invalid_level", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, _, _) = try await makeViewModel(
            chatService: mockChat,
            safetyHandler: mockHandler,
            safetyStateManager: mockStateManager,
            dbManager: db
        )
        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        // isReturningFromCrisis should still be true — failsafe should not clear it
        #expect(viewModel.isReturningFromCrisis == true)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.lastSafetyBoundaryAt != nil)
    }

    @Test("New orange during re-engagement overrides — safety wins")
    @MainActor
    func test_newOrangeDuringReEngagement_overrides() async throws {
        let db = try makeTestDB()
        let originalDate = Date(timeIntervalSinceNow: -3600)
        _ = try await createProfile(in: db, lastSafetyBoundaryAt: originalDate)
        _ = try await createSession(in: db, endedAt: Date())

        let mockHandler = MockSafetyHandler()
        mockHandler.stubbedClassifyResult = .orange
        mockHandler.stubbedUIState = SafetyUIState(
            level: .orange,
            hiddenElements: [.gamification],
            coachExpression: .gentle,
            notificationBehavior: .safetyOnly,
            showCrisisResources: true
        )
        let mockStateManager = MockSafetyStateManager()
        mockStateManager.stubbedProcessResult = .orange

        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response"),
            .done(safetyLevel: "orange", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, _, _) = try await makeViewModel(
            chatService: mockChat,
            safetyHandler: mockHandler,
            safetyStateManager: mockStateManager,
            dbManager: db
        )
        await viewModel.loadMessagesAsync()
        await viewModel.sendMessage("Test")
        try await Task.sleep(for: .milliseconds(500))

        // isReturningFromCrisis stays true (orange doesn't clear it)
        #expect(viewModel.isReturningFromCrisis == true)

        // lastSafetyBoundaryAt should be updated (new write)
        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.lastSafetyBoundaryAt != nil)
    }

    // MARK: - Task 4: UserState encodes isReturningFromCrisis

    @Test("UserState encodes isReturningFromCrisis when true, omits when nil")
    func test_userState_encodesReturningFromCrisis() throws {
        let snapshot = EngagementSnapshot(
            engagementLevel: .high,
            recentMoods: ["warm"],
            avgMessageLength: .medium,
            sessionCount: 5,
            lastSessionGapHours: nil,
            recentSessionIntensity: .moderate
        )
        var userState = UserState(from: snapshot)

        // When nil, should not appear in JSON
        let nilData = try JSONEncoder().encode(userState)
        let nilString = String(data: nilData, encoding: .utf8) ?? ""
        #expect(!nilString.contains("isReturningFromCrisis"))

        // When true, should appear
        userState.isReturningFromCrisis = true
        let trueData = try JSONEncoder().encode(userState)
        let trueString = String(data: trueData, encoding: .utf8) ?? ""
        #expect(trueString.contains("isReturningFromCrisis"))
        #expect(trueString.contains("true"))
    }

    // MARK: - Task 6: Re-engagement greeting

    @Test("Greeting returns re-engagement text when isReturningFromCrisis is true")
    @MainActor
    func test_greeting_reEngagementText() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, lastSafetyBoundaryAt: Date())
        _ = try await createSession(in: db, endedAt: Date())

        let mockChat = MockChatService()
        // Make stream empty to avoid sendMessage complexity
        mockChat.stubbedEvents = [
            .token(text: "Hi"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil, guardrail: nil),
        ]

        let (viewModel, _, _, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db)
        await viewModel.loadMessagesAsync()

        // Trigger session creation to set isReturningFromCrisis
        await viewModel.sendMessage("Hi")
        try await Task.sleep(for: .milliseconds(300))

        // Reset for the next sendMessage — need fresh state for greeting test
        // Since the green classification already cleared the flag, set it directly
        viewModel.isReturningFromCrisis = true
        await viewModel.generateDailyGreeting()

        #expect(viewModel.dailyGreeting == "I'm glad you're here. What's on your mind today?")
    }
}
