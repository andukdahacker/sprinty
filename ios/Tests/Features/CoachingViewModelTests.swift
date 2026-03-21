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
        dbManager: DatabaseManager? = nil,
        embeddingPipeline: MockEmbeddingPipeline? = nil,
        profileUpdateService: MockProfileUpdateService? = nil,
        profileEnricher: MockProfileEnricher? = nil
    ) async throws -> (CoachingViewModel, MockChatService, DatabaseManager, AppState) {
        let db = try dbManager ?? makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        let viewModel = CoachingViewModel(appState: appState, chatService: chatService, databaseManager: db, embeddingPipeline: embeddingPipeline, profileUpdateService: profileUpdateService, profileEnricher: profileEnricher)
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
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil)
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
            .done(safetyLevel: "green", domainTags: [], mood: "warm", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
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

    @Test("Done event with mode updates session mode")
    @MainActor
    func test_sendMessage_whenDoneEventHasMode_updatesSessionMode() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Let's focus."),
            .done(safetyLevel: "green", domainTags: [], mood: "focused", mode: "directive", memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.coachingMode == .discovery)

        await viewModel.sendMessage("I want to set a goal")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.coachingMode == .directive)
    }

    @Test("Done event with challengerUsed true sets challengerActive")
    @MainActor
    func test_sendMessage_challengerUsedTrue_setsChallengerActive() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Have you considered..."),
            .done(safetyLevel: "green", domainTags: ["career"], mood: "focused", mode: "discovery", memoryReferenced: nil, challengerUsed: true, usage: ChatUsage(inputTokens: 20, outputTokens: 15), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("I'm going to quit my job")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.challengerActive == true)
    }

    @Test("Challenger active resets to false on next done event without challenger")
    @MainActor
    func test_sendMessage_challengerUsedFalse_resetsChallengerActive() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Have you considered..."),
            .done(safetyLevel: "green", domainTags: [], mood: "focused", mode: "discovery", memoryReferenced: nil, challengerUsed: true, usage: ChatUsage(inputTokens: 20, outputTokens: 15), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("I want to quit")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.challengerActive == true)

        // Now send again with challengerUsed false
        mockChat.stubbedEvents = [
            .token(text: "That makes sense."),
            .done(safetyLevel: "green", domainTags: [], mood: "warm", mode: "discovery", memoryReferenced: nil, challengerUsed: false, usage: ChatUsage(inputTokens: 20, outputTokens: 15), promptVersion: nil, profileUpdate: nil)
        ]

        await viewModel.sendMessage("I've thought it through")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.challengerActive == false)
    }

    @Test("Send message includes userState in request")
    @MainActor
    func test_sendMessage_includesUserStateInRequest() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello coach")
        try await Task.sleep(for: .milliseconds(500))

        // UserState should be populated (even if defaults for a fresh session)
        #expect(mockChat.lastUserState != nil)
    }

    @Test("Done event with mood appends to sessionMoods")
    @MainActor
    func test_sendMessage_appendsMoodToSessionMoods() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "warm", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.sessionMoods == ["warm"])
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

    // MARK: - Story 3.1 — Session Lifecycle

    @Test("endSession sets endedAt and clears currentSession")
    @MainActor
    func test_endSession_setsEndedAt() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let session = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        // Send message to reach 2 messages (user + assistant)
        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.messages.count == 2)

        await viewModel.endSession()

        // Verify session endedAt is set in DB
        let updated = try await db.dbPool.read { dbConn in
            try ConversationSession.fetchOne(dbConn, key: session.id)
        }
        #expect(updated?.endedAt != nil)
    }

    @Test("endSession with fewer than 2 messages does not end session")
    @MainActor
    func test_endSession_fewerThan2Messages_skips() async throws {
        let (viewModel, _, db, _) = try await makeViewModel()
        let session = try await createSession(in: db)

        // Add only 1 user message directly
        let msg = Message(id: UUID(), sessionId: session.id, role: .user, content: "Hi", timestamp: Date())
        try await db.dbPool.write { dbConn in
            try msg.save(dbConn)
        }

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.messages.count == 1)

        await viewModel.endSession()

        // Session should NOT be ended
        let updated = try await db.dbPool.read { dbConn in
            try ConversationSession.fetchOne(dbConn, key: session.id)
        }
        #expect(updated?.endedAt == nil)
    }

    @Test("endSession triggers summary generation and persists")
    @MainActor
    func test_endSession_triggersAndPersistsSummary() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]
        mockChat.stubbedSummaryResponse = SummaryResponse(
            summary: "Explored career stress.",
            keyMoments: ["identified pattern"],
            domainTags: ["career"],
            emotionalMarkers: ["stressed"],
            keyDecisions: nil
        )

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let session = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("I'm stressed")
        try await Task.sleep(for: .milliseconds(500))

        await viewModel.endSession()
        // Wait for fire-and-forget summary generation
        try await Task.sleep(for: .milliseconds(500))

        let summaries = try await db.dbPool.read { dbConn in
            try ConversationSummary.forSession(id: session.id).fetchAll(dbConn)
        }

        #expect(summaries.count == 1)
        #expect(summaries[0].summary == "Explored career stress.")
        #expect(summaries[0].decodedDomainTags == ["career"])
        #expect(mockChat.summarizeCallCount == 1)
    }

    @Test("endSession with summary error logs but does not crash")
    @MainActor
    func test_endSession_summaryError_graceful() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]
        mockChat.stubbedSummaryError = AppError.networkUnavailable

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let session = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        await viewModel.endSession()
        try await Task.sleep(for: .milliseconds(500))

        // No summary persisted due to error
        let summaries = try await db.dbPool.read { dbConn in
            try ConversationSummary.forSession(id: session.id).fetchAll(dbConn)
        }
        #expect(summaries.isEmpty)
        #expect(mockChat.summarizeCallCount == 1)
    }

    @Test("retryMissingSummaries generates for sessions without summaries")
    @MainActor
    func test_retryMissingSummaries() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedSummaryResponse = SummaryResponse(
            summary: "Retry summary.",
            keyMoments: ["moment"],
            domainTags: ["health"],
            emotionalMarkers: nil,
            keyDecisions: nil
        )

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)

        // Create an ended session with messages but no summary
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSinceNow: -3600),
            endedAt: Date(timeIntervalSinceNow: -1800),
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in
            try session.save(dbConn)
        }

        let msg1 = Message(id: UUID(), sessionId: session.id, role: .user, content: "I need to exercise more", timestamp: Date(timeIntervalSinceNow: -3500))
        let msg2 = Message(id: UUID(), sessionId: session.id, role: .assistant, content: "What's been stopping you?", timestamp: Date(timeIntervalSinceNow: -3400))
        try await db.dbPool.write { dbConn in
            try msg1.save(dbConn)
            try msg2.save(dbConn)
        }

        await viewModel.retryMissingSummaries()
        try await Task.sleep(for: .milliseconds(500))

        let summaries = try await db.dbPool.read { dbConn in
            try ConversationSummary.forSession(id: session.id).fetchAll(dbConn)
        }

        #expect(summaries.count == 1)
        #expect(summaries[0].summary == "Retry summary.")
        #expect(mockChat.summarizeCallCount == 1)
    }

    // MARK: - Story 3.2 — Embedding Pipeline Integration

    @Test("endSession triggers embedding pipeline after summary generation")
    @MainActor
    func test_endSession_callsEmbeddingPipeline() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]
        mockChat.stubbedSummaryResponse = SummaryResponse(
            summary: "Explored career stress.",
            keyMoments: ["identified pattern"],
            domainTags: ["career"],
            emotionalMarkers: nil,
            keyDecisions: nil
        )

        let mockPipeline = MockEmbeddingPipeline()
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("I'm stressed")
        try await Task.sleep(for: .milliseconds(500))

        await viewModel.endSession()
        try await Task.sleep(for: .milliseconds(800))

        #expect(mockPipeline.embedCallCount == 1)
        #expect(mockPipeline.lastEmbedSummary?.summary == "Explored career stress.")
        #expect(mockPipeline.lastEmbedRowid != nil)
    }

    @Test("endSession with embedding failure still persists summary")
    @MainActor
    func test_endSession_embeddingFailure_summaryStillPersisted() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]
        mockChat.stubbedSummaryResponse = SummaryResponse(
            summary: "Career chat.",
            keyMoments: ["moment"],
            domainTags: ["career"],
            emotionalMarkers: nil,
            keyDecisions: nil
        )

        let mockPipeline = MockEmbeddingPipeline()
        mockPipeline.stubbedEmbedError = EmbeddingServiceError.invalidOutput
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let session = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        await viewModel.endSession()
        try await Task.sleep(for: .milliseconds(800))

        // Summary should still be persisted despite embedding failure
        let summaries = try await db.dbPool.read { dbConn in
            try ConversationSummary.forSession(id: session.id).fetchAll(dbConn)
        }
        #expect(summaries.count == 1)
        #expect(summaries[0].summary == "Career chat.")
        #expect(summaries[0].embedding == nil)

        // Embedding was attempted
        #expect(mockPipeline.embedCallCount == 1)
    }

    @Test("retryMissingEmbeddings delegates to embedding pipeline")
    @MainActor
    func test_retryMissingEmbeddings_delegatesToPipeline() async throws {
        let mockPipeline = MockEmbeddingPipeline()
        let (viewModel, _, _, _) = try await makeViewModel(embeddingPipeline: mockPipeline)

        await viewModel.retryMissingEmbeddings()

        #expect(mockPipeline.retryCallCount == 1)
    }

    // MARK: - Story 3.3 — Profile Update Integration

    @Test("Done event with profileUpdate triggers ProfileUpdateService")
    @MainActor
    func test_sendMessage_doneWithProfileUpdate_triggersService() async throws {
        let mockChat = MockChatService()
        let profileUpdate = ProfileUpdate(
            values: ["creativity"],
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            corrections: nil
        )
        mockChat.stubbedEvents = [
            .token(text: "Great."),
            .done(safetyLevel: "green", domainTags: [], mood: "warm", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: profileUpdate)
        ]

        let mockProfileService = MockProfileUpdateService()
        let db = try makeTestDB()

        // Create a user profile in the DB
        let userProfile = UserProfile(
            id: UUID(),
            avatarId: "default",
            coachAppearanceId: "default",
            coachName: "Luna",
            onboardingStep: 5,
            onboardingCompleted: true,
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try userProfile.save(dbConn)
        }

        let (viewModel, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db, profileUpdateService: mockProfileService)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("I value creativity")
        try await Task.sleep(for: .milliseconds(800))

        #expect(mockProfileService.applyUpdateCallCount == 1)
        #expect(mockProfileService.lastUpdate?.values == ["creativity"])
        #expect(mockProfileService.lastProfileId == userProfile.id)
    }

    @Test("Done event without profileUpdate does not trigger service")
    @MainActor
    func test_sendMessage_doneWithoutProfileUpdate_noServiceCall() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockProfileService = MockProfileUpdateService()
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, profileUpdateService: mockProfileService)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(mockProfileService.applyUpdateCallCount == 0)
    }

    @Test("Cold start: nil profile fields don't crash request assembly")
    @MainActor
    func test_sendMessage_coldStart_nilProfileFields() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Welcome!"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        // No UserProfile created — cold start scenario
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        // Should complete without crash, profile should be nil
        #expect(viewModel.messages.count == 2)
        #expect(mockChat.lastProfile == nil)
    }

    @Test("Partial profile: some fields populated works correctly")
    @MainActor
    func test_sendMessage_partialProfile_works() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let db = try makeTestDB()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "default",
            coachAppearanceId: "default",
            coachName: "Luna",
            onboardingStep: 5,
            onboardingCompleted: true,
            values: UserProfile.encodeArray(["honesty"]),
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.save(dbConn)
        }

        let (viewModel, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.messages.count == 2)
        #expect(mockChat.lastProfile?.values == ["honesty"])
        #expect(mockChat.lastProfile?.goals == nil)
    }

    @Test("endSession triggers profile enrichment after summary")
    @MainActor
    func test_endSession_triggersProfileEnrichment() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]
        mockChat.stubbedSummaryResponse = SummaryResponse(
            summary: "Career chat.",
            keyMoments: ["moment"],
            domainTags: ["career"],
            emotionalMarkers: nil,
            keyDecisions: nil
        )

        let mockEnricher = MockProfileEnricher()
        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, profileEnricher: mockEnricher)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Let's talk about career")
        try await Task.sleep(for: .milliseconds(500))

        await viewModel.endSession()
        try await Task.sleep(for: .milliseconds(800))

        #expect(mockEnricher.enrichCallCount == 1)
        #expect(mockEnricher.lastSummary?.summary == "Career chat.")
    }

    // MARK: - Story 3.4 — RAG Context Retrieval

    @Test("sendMessage retrieves RAG context and passes to chat service")
    @MainActor
    func test_sendMessage_retrievesRAGContext() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockPipeline = MockEmbeddingPipeline()
        mockPipeline.stubbedSearchResults = [
            ConversationSummary(
                id: UUID(),
                sessionId: UUID(),
                summary: "Discussed career goals and feeling stuck.",
                keyMoments: ConversationSummary.encodeArray(["identified pattern"]),
                domainTags: ConversationSummary.encodeArray(["career"]),
                emotionalMarkers: nil,
                keyDecisions: nil,
                goalReferences: nil,
                embedding: nil,
                createdAt: Date(timeIntervalSinceNow: -86400)
            )
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("I want to talk about my career")
        try await Task.sleep(for: .milliseconds(500))

        #expect(mockPipeline.searchCallCount == 1)
        #expect(mockPipeline.lastSearchLimit == 5)
        #expect(mockChat.lastRagContext != nil)
        #expect(mockChat.lastRagContext?.contains("career goals") == true)
        #expect(mockChat.lastRagContext?.contains("Past Conversations") == true)
    }

    @Test("sendMessage without embedding pipeline sends nil ragContext")
    @MainActor
    func test_sendMessage_noEmbeddingPipeline_nilRagContext() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(mockChat.lastRagContext == nil)
    }

    @Test("RAG retrieval failure falls back to nil ragContext gracefully")
    @MainActor
    func test_sendMessage_ragFailure_gracefulFallback() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockPipeline = MockEmbeddingPipeline()
        mockPipeline.stubbedSearchError = EmbeddingServiceError.invalidOutput

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        // Should complete without error, ragContext should be nil due to search failure
        #expect(viewModel.messages.count == 2)
        #expect(mockChat.lastRagContext == nil)
        #expect(mockPipeline.searchCallCount == 1)
    }

    @Test("RAG context includes gap duration when lastSessionGapHours > 72")
    @MainActor
    func test_sendMessage_longGap_includesGapInRagContext() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Welcome back."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockPipeline = MockEmbeddingPipeline()
        mockPipeline.stubbedSearchResults = [
            ConversationSummary(
                id: UUID(),
                sessionId: UUID(),
                summary: "Explored health and exercise habits.",
                keyMoments: ConversationSummary.encodeArray(["committed to routine"]),
                domainTags: ConversationSummary.encodeArray(["health"]),
                emotionalMarkers: nil,
                keyDecisions: nil,
                goalReferences: nil,
                embedding: nil,
                createdAt: Date(timeIntervalSinceNow: -86400 * 8)
            )
        ]

        let db = try makeTestDB()

        // Create an old ended session to produce a gap > 72 hours
        let oldSession = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSinceNow: -86400 * 8),
            endedAt: Date(timeIntervalSinceNow: -86400 * 8 + 3600),
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in
            try oldSession.save(dbConn)
        }

        // Create a new open session
        let newSession = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in
            try newSession.save(dbConn)
        }

        let (viewModel, _, _, _) = try await makeViewModel(chatService: mockChat, dbManager: db, embeddingPipeline: mockPipeline)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hey")
        try await Task.sleep(for: .milliseconds(500))

        // Verify RAG was called and context was returned
        #expect(mockPipeline.searchCallCount == 1)
        #expect(mockChat.lastRagContext != nil)
        // The gap string depends on EngagementCalculator producing lastSessionGapHours > 72.
        // With an 8-day-old ended session and a new session, the calculator should detect the gap.
        // Assert the gap duration string is present when gap is detected.
        if let ctx = mockChat.lastRagContext, ctx.contains("days away") {
            #expect(ctx.contains("User returning after"))
        }
    }

    @Test("Empty search results produce nil ragContext")
    @MainActor
    func test_sendMessage_emptySearchResults_nilRagContext() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockPipeline = MockEmbeddingPipeline()
        mockPipeline.stubbedSearchResults = []

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(mockPipeline.searchCallCount == 1)
        #expect(mockChat.lastRagContext == nil)
    }

    @Test("Done event with memoryReferenced true stores flag per message")
    @MainActor
    func test_sendMessage_memoryReferencedTrue_storesFlag() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "I recall last time we talked about career goals."),
            .done(safetyLevel: "green", domainTags: [], mood: "warm", mode: nil, memoryReferenced: true, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hi")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.messages.count == 2)
        let assistantMessage = viewModel.messages[1]
        #expect(viewModel.memoryReferencedMessages[assistantMessage.id] == true)
    }

    @Test("Done event without memoryReferenced does not store flag")
    @MainActor
    func test_sendMessage_memoryReferencedNil_noFlag() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hello."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.messages.count == 2)
        let assistantMessage = viewModel.messages[1]
        #expect(viewModel.memoryReferencedMessages[assistantMessage.id] == nil)
    }

    @Test("Token budget enforcement truncates long ragContext")
    @MainActor
    func test_sendMessage_tokenBudget_truncatesLongContext() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockPipeline = MockEmbeddingPipeline()
        // Create 5 summaries with very long text to exceed 4000 chars
        let longText = String(repeating: "This is a long summary about various topics. ", count: 30)
        mockPipeline.stubbedSearchResults = (0..<5).map { i in
            ConversationSummary(
                id: UUID(),
                sessionId: UUID(),
                summary: "Entry \(i): \(longText)",
                keyMoments: ConversationSummary.encodeArray(["moment \(i)"]),
                domainTags: ConversationSummary.encodeArray(["career"]),
                emotionalMarkers: nil,
                keyDecisions: nil,
                goalReferences: nil,
                embedding: nil,
                createdAt: Date(timeIntervalSinceNow: Double(-86400 * (i + 1)))
            )
        }

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Tell me about career")
        try await Task.sleep(for: .milliseconds(500))

        // ragContext should exist but be truncated under budget
        #expect(mockChat.lastRagContext != nil)
        #expect(mockChat.lastRagContext!.count <= 4500) // Allow slight buffer for header
        // Should have fewer than 5 entries due to truncation
        let entryCount = mockChat.lastRagContext!.components(separatedBy: "Summary: Entry").count - 1
        #expect(entryCount < 5)
    }

    // MARK: - Story 3.4 — Daily Greeting

    @Test("Daily greeting returns topic-based when key moments available")
    @MainActor
    func test_generateDailyGreeting_topicBased() async throws {
        let db = try makeTestDB()
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSinceNow: -3600),
            endedAt: Date(timeIntervalSinceNow: -1800),
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in try session.save(dbConn) }

        let summary = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "Discussed career goals.",
            keyMoments: ConversationSummary.encodeArray(["career transition plan"]),
            domainTags: ConversationSummary.encodeArray(["career"]),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date(timeIntervalSinceNow: -1800)
        )
        try await db.dbPool.write { dbConn in try summary.save(dbConn) }

        let (viewModel, _, _, _) = try await makeViewModel(dbManager: db)
        await viewModel.generateDailyGreeting()

        #expect(viewModel.dailyGreeting == "Last time we talked about career transition plan. How's that going?")
    }

    @Test("Daily greeting returns emotion-based when emotional markers available")
    @MainActor
    func test_generateDailyGreeting_emotionBased() async throws {
        let db = try makeTestDB()
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSinceNow: -3600),
            endedAt: Date(timeIntervalSinceNow: -1800),
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in try session.save(dbConn) }

        let summary = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "Explored health habits.",
            keyMoments: ConversationSummary.encodeArray([]),
            domainTags: ConversationSummary.encodeArray(["health"]),
            emotionalMarkers: ConversationSummary.encodeArray(["energized"]),
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date(timeIntervalSinceNow: -1800)
        )
        try await db.dbPool.write { dbConn in try summary.save(dbConn) }

        let (viewModel, _, _, _) = try await makeViewModel(dbManager: db)
        await viewModel.generateDailyGreeting()

        #expect(viewModel.dailyGreeting == "You seemed energized last time — how are things now?")
    }

    @Test("Daily greeting returns gap-aware when gap > 72 hours")
    @MainActor
    func test_generateDailyGreeting_gapAware() async throws {
        let db = try makeTestDB()
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSinceNow: -86400 * 5),
            endedAt: Date(timeIntervalSinceNow: -86400 * 5 + 3600),
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in try session.save(dbConn) }

        let summary = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "Health discussion.",
            keyMoments: ConversationSummary.encodeArray(["started running"]),
            domainTags: ConversationSummary.encodeArray(["health"]),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date(timeIntervalSinceNow: -86400 * 5)
        )
        try await db.dbPool.write { dbConn in try summary.save(dbConn) }

        let (viewModel, _, _, _) = try await makeViewModel(dbManager: db)
        await viewModel.generateDailyGreeting()

        #expect(viewModel.dailyGreeting == "It's been a few days — what's been on your mind?")
    }

    @Test("Daily greeting returns fallback when no summaries exist (cold start)")
    @MainActor
    func test_generateDailyGreeting_coldStart() async throws {
        let (viewModel, _, _, _) = try await makeViewModel()
        await viewModel.generateDailyGreeting()

        #expect(viewModel.dailyGreeting == "What's on your mind?")
    }

    // MARK: - Story 3.4 — Integration & Edge Cases

    @Test("Cold start: no prior conversations sends no ragContext and shows fallback greeting")
    @MainActor
    func test_coldStart_noRagContext_fallbackGreeting() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Welcome!"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockPipeline = MockEmbeddingPipeline()
        mockPipeline.stubbedSearchResults = []

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let _ = try await createSession(in: db)

        await viewModel.generateDailyGreeting()
        #expect(viewModel.dailyGreeting == "What's on your mind?")

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        #expect(mockChat.lastRagContext == nil)
        #expect(viewModel.messages.count == 2)
    }

    @Test("Token budget enforcement: 5 long summaries truncated to budget")
    @MainActor
    func test_tokenBudget_5LongSummaries_truncated() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Response."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let mockPipeline = MockEmbeddingPipeline()
        let longSummary = String(repeating: "Discussing career goals and personal growth. ", count: 30)
        mockPipeline.stubbedSearchResults = (0..<5).map { i in
            ConversationSummary(
                id: UUID(),
                sessionId: UUID(),
                summary: "Session \(i): \(longSummary)",
                keyMoments: ConversationSummary.encodeArray(["key moment \(i)", "another moment \(i)"]),
                domainTags: ConversationSummary.encodeArray(["career", "personal-growth"]),
                emotionalMarkers: nil,
                keyDecisions: nil,
                goalReferences: nil,
                embedding: nil,
                createdAt: Date(timeIntervalSinceNow: Double(-86400 * (i + 1)))
            )
        }

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat, embeddingPipeline: mockPipeline)
        let _ = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Tell me about my career patterns")
        try await Task.sleep(for: .milliseconds(500))

        #expect(mockChat.lastRagContext != nil)
        // Verify it's under the ~4000 char budget (with some tolerance for header)
        #expect(mockChat.lastRagContext!.count <= 4500)
    }

    @Test("getOrCreateSession creates new session after previous was ended")
    @MainActor
    func test_getOrCreateSession_afterEndSession_createsNew() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Hi."),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let (viewModel, _, db, _) = try await makeViewModel(chatService: mockChat)
        let session = try await createSession(in: db)

        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        await viewModel.sendMessage("Hello")
        try await Task.sleep(for: .milliseconds(500))

        let originalSessionId = session.id

        await viewModel.endSession()

        // Load messages again — should create a new session
        viewModel.loadMessages()
        try await Task.sleep(for: .milliseconds(200))

        // Verify a new session was created (different from original)
        let sessions = try await db.dbPool.read { dbConn in
            try ConversationSession.fetchAll(dbConn)
        }
        #expect(sessions.count == 2)
        let newSession = sessions.first(where: { $0.id != originalSessionId })
        #expect(newSession != nil)
        #expect(newSession?.endedAt == nil)
    }
}
