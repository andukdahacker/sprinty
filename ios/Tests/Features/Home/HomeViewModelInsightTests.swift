import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("HomeViewModel Insight Integration")
struct HomeViewModelInsightTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    // MARK: - InsightService integration

    @Test("Load uses InsightService when provided")
    @MainActor
    func test_loadLatestInsight_withInsightService_usesService() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockService = MockInsightService()
        mockService.stubbedInsight = "Service-provided insight"
        let vm = HomeViewModel(appState: appState, databaseManager: db, insightService: mockService)

        await vm.load()

        #expect(vm.latestInsight == "Service-provided insight")
        #expect(mockService.generateCallCount == 1)
    }

    @Test("Load returns nil from InsightService when no data")
    @MainActor
    func test_loadLatestInsight_insightServiceReturnsNil_setsNil() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockService = MockInsightService()
        mockService.stubbedInsight = nil
        let vm = HomeViewModel(appState: appState, databaseManager: db, insightService: mockService)

        await vm.load()

        #expect(vm.latestInsight == nil)
    }

    @Test("Load falls back to direct DB query when no InsightService")
    @MainActor
    func test_loadLatestInsight_noInsightService_queriesDBDirectly() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        // Create a session and summary directly
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: Date(),
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try await db.dbPool.write { dbConn in
            try session.save(dbConn)
        }
        let summary = ConversationSummary(
            id: UUID(),
            sessionId: session.id,
            summary: "Direct DB insight",
            keyMoments: ConversationSummary.encodeArray(["moment"]),
            domainTags: ConversationSummary.encodeArray(["career"]),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try summary.save(dbConn)
        }

        await vm.load()

        #expect(vm.latestInsight == "Direct DB insight")
    }

    // MARK: - insightDisplayText computed property

    @Test("insightDisplayText returns pause message when paused")
    @MainActor
    func test_insightDisplayText_paused_returnsPauseMessage() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        let mockService = MockInsightService()
        mockService.stubbedInsight = "Should not show this"
        let vm = HomeViewModel(appState: appState, databaseManager: db, insightService: mockService)
        vm.latestInsight = "Should not show this"

        #expect(vm.insightDisplayText == "Your coach is here when you're ready.")
    }

    @Test("insightDisplayText returns insight when available")
    @MainActor
    func test_insightDisplayText_withInsight_returnsInsight() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.latestInsight = "Great progress on goals"

        #expect(vm.insightDisplayText == "Great progress on goals")
    }

    @Test("insightDisplayText returns getting-to-know fallback when conversations exist but no insight")
    @MainActor
    func test_insightDisplayText_noInsightWithConversations_returnsFallback() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 1
        vm.latestInsight = nil

        #expect(vm.insightDisplayText == "Your coach is getting to know you...")
    }

    @Test("insightDisplayText returns nil when no conversations (Stage 1)")
    @MainActor
    func test_insightDisplayText_noConversations_returnsNil() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        #expect(vm.insightDisplayText == nil)
    }
}
