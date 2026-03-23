import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("HomeViewModel Avatar")
struct HomeViewModelAvatarTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    // MARK: - Avatar state exposure

    @Test("avatarState reflects appState")
    @MainActor
    func test_avatarState_reflectsAppState() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        #expect(viewModel.avatarState == .active)

        appState.avatarState = .resting
        #expect(viewModel.avatarState == .resting)

        appState.avatarState = .thinking
        #expect(viewModel.avatarState == .thinking)
    }

    // MARK: - Celebration trigger

    @Test("triggerCelebration sets celebrating state")
    @MainActor
    func test_triggerCelebration_setsCelebrating() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.triggerCelebration()

        #expect(appState.avatarState == .celebrating)
    }

    @Test("triggerCelebration returns to active after delay")
    @MainActor
    func test_triggerCelebration_returnsToActive() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.triggerCelebration()
        #expect(appState.avatarState == .celebrating)

        try await Task.sleep(for: .milliseconds(900))
        #expect(appState.avatarState == .active)
    }

    @Test("triggerCelebration restores previous non-celebrating state")
    @MainActor
    func test_triggerCelebration_restoresPreviousState() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.avatarState = .thinking
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.triggerCelebration()
        #expect(appState.avatarState == .celebrating)

        try await Task.sleep(for: .milliseconds(900))
        #expect(appState.avatarState == .thinking)
    }

    @Test("triggerCelebration from celebrating falls back to active")
    @MainActor
    func test_triggerCelebration_fromCelebrating_fallsToActive() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.avatarState = .celebrating
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.triggerCelebration()

        try await Task.sleep(for: .milliseconds(900))
        #expect(appState.avatarState == .active)
    }

    @Test("Rapid re-trigger cancels previous celebration")
    @MainActor
    func test_triggerCelebration_rapidRetrigger_cancels() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.triggerCelebration()
        try await Task.sleep(for: .milliseconds(200))
        viewModel.triggerCelebration()

        #expect(appState.avatarState == .celebrating)

        try await Task.sleep(for: .milliseconds(900))
        #expect(appState.avatarState == .active)
    }
}
