import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 5.4 Tests ---

@Suite("CheckInViewModel Tests")
struct CheckInViewModelTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager) async throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }
    }

    private func createActiveSprint(in db: DatabaseManager) async throws -> Sprint {
        let sprint = Sprint(
            id: UUID(),
            name: "Growth Sprint",
            startDate: Date(timeIntervalSinceNow: -3 * 86400),
            endDate: Date(timeIntervalSinceNow: 4 * 86400),
            status: .active
        )
        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            for i in 1...3 {
                let step = SprintStep(
                    id: UUID(),
                    sprintId: sprint.id,
                    description: "Step \(i)",
                    completed: i <= 1,
                    completedAt: i <= 1 ? Date() : nil,
                    order: i
                )
                try step.insert(dbConn)
            }
        }
        return sprint
    }

    // MARK: - startCheckIn

    @Test("startCheckIn streams tokens and sets coachResponse")
    @MainActor
    func test_startCheckIn_streamsResponse() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let sprint = try await createActiveSprint(in: db)

        let chatService = MockChatService()
        chatService.stubbedEvents = [
            .token(text: "You're doing great. "),
            .token(text: "Keep going."),
            .done(safetyLevel: "green", domainTags: [], mood: "supportive", mode: "check_in", memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: nil, profileUpdate: nil)
        ]

        let sprintService = MockSprintService()
        sprintService.activeSprintResult = (sprint: sprint, steps: [
            SprintStep(id: UUID(), sprintId: sprint.id, description: "Step 1", completed: true, completedAt: Date(), order: 1),
            SprintStep(id: UUID(), sprintId: sprint.id, description: "Step 2", completed: false, completedAt: nil, order: 2)
        ])

        let appState = AppState()
        let vm = CheckInViewModel(appState: appState, databaseManager: db, chatService: chatService, sprintService: sprintService)

        vm.startCheckIn()

        // Wait for streaming to complete
        try await Task.sleep(for: .milliseconds(200))

        #expect(vm.coachResponse == "You're doing great. Keep going.")
        #expect(vm.isComplete == true)
        #expect(vm.isStreaming == false)
        #expect(chatService.lastMode == "check_in")
    }

    @Test("startCheckIn creates session with checkIn type")
    @MainActor
    func test_startCheckIn_createsSession() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let sprint = try await createActiveSprint(in: db)

        let chatService = MockChatService()
        chatService.stubbedEvents = [
            .token(text: "Hello."),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: "check_in", memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let sprintService = MockSprintService()
        sprintService.activeSprintResult = (sprint: sprint, steps: [])

        let appState = AppState()
        let vm = CheckInViewModel(appState: appState, databaseManager: db, chatService: chatService, sprintService: sprintService)

        vm.startCheckIn()
        try await Task.sleep(for: .milliseconds(200))

        let sessions = try await db.dbPool.read { dbConn in
            try ConversationSession.fetchAll(dbConn)
        }
        #expect(sessions.count == 1)
        #expect(sessions.first?.type == .checkIn)
    }

    // MARK: - saveCheckIn

    @Test("saveCheckIn persists CheckIn record")
    @MainActor
    func test_saveCheckIn_persistsRecord() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let sprint = try await createActiveSprint(in: db)

        let chatService = MockChatService()
        chatService.stubbedEvents = [
            .token(text: "Great progress!"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: "check_in", memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil)
        ]

        let sprintService = MockSprintService()
        sprintService.activeSprintResult = (sprint: sprint, steps: [])

        let appState = AppState()
        let vm = CheckInViewModel(appState: appState, databaseManager: db, chatService: chatService, sprintService: sprintService)

        vm.startCheckIn()
        try await Task.sleep(for: .milliseconds(200))

        await vm.saveCheckIn()

        let checkIns = try await db.dbPool.read { dbConn in
            try CheckIn.fetchAll(dbConn)
        }
        #expect(checkIns.count == 1)
        #expect(checkIns.first?.summary == "Great progress!")
        #expect(checkIns.first?.sprintId == sprint.id)
    }

    // MARK: - latestCheckInSummary

    @Test("latestCheckInSummary returns today's check-in for daily cadence")
    @MainActor
    func test_latestCheckInSummary_dailyCadence() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let sprint = try await createActiveSprint(in: db)

        // Create a session for FK
        let session = ConversationSession(
            id: UUID(), startedAt: Date(), endedAt: Date(),
            type: .checkIn, mode: .discovery, safetyLevel: .green,
            promptVersion: nil, modeHistory: nil, moodHistory: nil
        )
        try await db.dbPool.write { dbConn in
            try session.insert(dbConn)
        }

        let checkIn = CheckIn(id: UUID(), sessionId: session.id, sprintId: sprint.id, summary: "Feeling focused today", createdAt: Date())
        try await db.dbPool.write { dbConn in
            try checkIn.insert(dbConn)
        }

        let appState = AppState()
        let chatService = MockChatService()
        let sprintService = MockSprintService()
        let vm = CheckInViewModel(appState: appState, databaseManager: db, chatService: chatService, sprintService: sprintService)

        let summary = await vm.latestCheckInSummary()
        #expect(summary == "Feeling focused today")
    }

    @Test("latestCheckInSummary returns nil when no check-in today")
    @MainActor
    func test_latestCheckInSummary_nilWhenNone() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let appState = AppState()
        let chatService = MockChatService()
        let sprintService = MockSprintService()
        let vm = CheckInViewModel(appState: appState, databaseManager: db, chatService: chatService, sprintService: sprintService)

        let summary = await vm.latestCheckInSummary()
        #expect(summary == nil)
    }

    // MARK: - Error handling

    @Test("startCheckIn sets localError on chat failure")
    @MainActor
    func test_startCheckIn_handlesError() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let sprint = try await createActiveSprint(in: db)

        let chatService = MockChatService()
        chatService.stubbedError = AppError.networkUnavailable

        let sprintService = MockSprintService()
        sprintService.activeSprintResult = (sprint: sprint, steps: [])

        let appState = AppState()
        let vm = CheckInViewModel(appState: appState, databaseManager: db, chatService: chatService, sprintService: sprintService)

        vm.startCheckIn()
        try await Task.sleep(for: .milliseconds(200))

        #expect(vm.localError != nil)
        #expect(vm.isStreaming == false)
        #expect(vm.isComplete == false)
    }
}
