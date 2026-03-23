import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("HomeDisclosureStage")
struct HomeDisclosureStageTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    // MARK: - Stage Derivation

    @Test("New user with no conversations returns .welcome")
    @MainActor
    func test_homeStage_noConversations_welcome() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        #expect(vm.homeStage == .welcome)
    }

    @Test("User with completed conversation returns .insightUnlocked")
    @MainActor
    func test_homeStage_hasConversation_insightUnlocked() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 1

        #expect(vm.homeStage == .insightUnlocked)
    }

    @Test("User with active sprint returns .sprintActive")
    @MainActor
    func test_homeStage_hasActiveSprint_sprintActive() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 3
        vm.hasActiveSprint = true

        #expect(vm.homeStage == .sprintActive)
    }

    @Test("Paused overrides all other stages")
    @MainActor
    func test_homeStage_paused_overridesAll() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 5
        vm.hasActiveSprint = true

        #expect(vm.homeStage == .paused)
    }

    @Test("Sprint active without conversations still shows .sprintActive")
    @MainActor
    func test_homeStage_sprintNoConversations_sprintActive() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.hasActiveSprint = true

        #expect(vm.homeStage == .sprintActive)
    }

    @Test("Unpausing returns to appropriate stage")
    @MainActor
    func test_homeStage_unpause_returnsToCorrectStage() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 2

        #expect(vm.homeStage == .paused)

        appState.isPaused = false
        #expect(vm.homeStage == .insightUnlocked)
    }

    // MARK: - InsightDisplayText

    @Test("Paused returns pause message regardless of other state")
    @MainActor
    func test_insightDisplayText_paused_pauseMessage() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.latestInsight = "Some insight"

        #expect(vm.insightDisplayText == "Your coach is here when you're ready.")
    }

    @Test("Has insight returns insight text")
    @MainActor
    func test_insightDisplayText_hasInsight_returnsInsight() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.latestInsight = "You've been making great progress on career goals."
        vm.completedConversationCount = 1

        #expect(vm.insightDisplayText == "You've been making great progress on career goals.")
    }

    @Test("Has conversations but no insight returns fallback")
    @MainActor
    func test_insightDisplayText_noInsight_fallback() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 1

        #expect(vm.insightDisplayText == "Your coach is getting to know you...")
    }

    @Test("No conversations returns nil")
    @MainActor
    func test_insightDisplayText_noConversations_nil() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        #expect(vm.insightDisplayText == nil)
    }

    // MARK: - Enum cases

    @Test("All four cases exist")
    func test_allCases() {
        #expect(HomeDisclosureStage.allCases.count == 4)
        #expect(HomeDisclosureStage.allCases.contains(.welcome))
        #expect(HomeDisclosureStage.allCases.contains(.insightUnlocked))
        #expect(HomeDisclosureStage.allCases.contains(.sprintActive))
        #expect(HomeDisclosureStage.allCases.contains(.paused))
    }
}
