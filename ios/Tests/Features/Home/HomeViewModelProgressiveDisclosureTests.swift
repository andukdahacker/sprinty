import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("HomeViewModel Progressive Disclosure")
struct HomeViewModelProgressiveDisclosureTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createCompletedSession(in db: DatabaseManager) async throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSinceNow: -3600),
            endedAt: Date(),
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

    private func createOpenSession(in db: DatabaseManager) async throws -> ConversationSession {
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

    private func createSummary(in db: DatabaseManager, sessionId: UUID, summary: String = "Great session insight") async throws {
        let conversationSummary = ConversationSummary(
            id: UUID(),
            sessionId: sessionId,
            summary: summary,
            keyMoments: "[]",
            domainTags: "[]",
            createdAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try conversationSummary.save(dbConn)
        }
    }

    // MARK: - Data Loading

    @Test("Load with no data stays at welcome stage")
    @MainActor
    func test_load_noData_welcomeStage() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.homeStage == .welcome)
        #expect(vm.completedConversationCount == 0)
        #expect(vm.latestInsight == nil)
        #expect(vm.insightDisplayText == nil)
    }

    @Test("Load with completed conversation and summary unlocks insight")
    @MainActor
    func test_load_completedWithSummary_insightUnlocked() async throws {
        let db = try makeTestDB()
        let session = try await createCompletedSession(in: db)
        try await createSummary(in: db, sessionId: session.id, summary: "You showed courage today")

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.homeStage == .insightUnlocked)
        #expect(vm.completedConversationCount == 1)
        #expect(vm.latestInsight == "You showed courage today")
        #expect(vm.insightDisplayText == "You showed courage today")
    }

    @Test("Load with completed conversation but no summary shows fallback")
    @MainActor
    func test_load_completedNoSummary_fallback() async throws {
        let db = try makeTestDB()
        _ = try await createCompletedSession(in: db)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.homeStage == .insightUnlocked)
        #expect(vm.completedConversationCount == 1)
        #expect(vm.latestInsight == nil)
        #expect(vm.insightDisplayText == "Your coach is getting to know you...")
    }

    @Test("Open session does not count as completed")
    @MainActor
    func test_load_openSession_notCounted() async throws {
        let db = try makeTestDB()
        _ = try await createOpenSession(in: db)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.completedConversationCount == 0)
        #expect(vm.homeStage == .welcome)
    }

    @Test("Multiple completed sessions counted correctly")
    @MainActor
    func test_load_multipleCompleted_correctCount() async throws {
        let db = try makeTestDB()
        let s1 = try await createCompletedSession(in: db)
        _ = try await createCompletedSession(in: db)
        _ = try await createOpenSession(in: db)
        try await createSummary(in: db, sessionId: s1.id, summary: "Latest insight")

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.completedConversationCount == 2)
        #expect(vm.latestInsight == "Latest insight")
    }

    @Test("Paused state overrides insight display text")
    @MainActor
    func test_load_paused_overridesInsight() async throws {
        let db = try makeTestDB()
        let session = try await createCompletedSession(in: db)
        try await createSummary(in: db, sessionId: session.id, summary: "Some insight")

        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.homeStage == .paused)
        #expect(vm.insightDisplayText == "Your coach is here when you're ready.")
    }

    @Test("Sprint loading gracefully handles missing table")
    @MainActor
    func test_load_noSprintTable_graceful() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.hasActiveSprint == false)
        #expect(vm.sprintProgress == 0)
    }

    @Test("Check-in is nil when not yet implemented")
    @MainActor
    func test_load_checkIn_nil() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.latestCheckIn == nil)
    }
}
