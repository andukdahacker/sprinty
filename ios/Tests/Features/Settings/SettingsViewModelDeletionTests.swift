import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SettingsViewModel Deletion")
struct SettingsViewModelDeletionTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    // MARK: - requestDataDeletion

    @Test @MainActor
    func test_requestDataDeletion_showsConfirmationAndClearsError() async throws {
        let vm = SettingsViewModel(databaseManager: try makeTestDB())
        vm.deletionError = .networkUnavailable
        vm.deletionConfirmationText = "stale"

        vm.requestDataDeletion()

        #expect(vm.showDeletionConfirmation == true)
        #expect(vm.deletionError == nil)
        #expect(vm.deletionConfirmationText == "")
    }

    // MARK: - cancelDeletion

    @Test @MainActor
    func test_cancelDeletion_resetsConfirmationState() async throws {
        let vm = SettingsViewModel(databaseManager: try makeTestDB())
        vm.showDeletionConfirmation = true
        vm.deletionConfirmationText = "DELETE"

        vm.cancelDeletion()

        #expect(vm.showDeletionConfirmation == false)
        #expect(vm.deletionConfirmationText == "")
    }

    // MARK: - confirmDataDeletion

    @Test @MainActor
    func test_confirmDataDeletion_rejectedWhenTextNotExactlyDelete() async throws {
        let mockService = MockDataDeletionService()
        let vm = SettingsViewModel(
            databaseManager: try makeTestDB(),
            dataDeletionService: mockService
        )
        vm.deletionConfirmationText = "delete" // lowercase, should be rejected

        await vm.confirmDataDeletion()

        #expect(mockService.callCount == 0)
        #expect(vm.dataDeletionCompleted == false)
        #expect(vm.isDeletingData == false)
    }

    @Test @MainActor
    func test_confirmDataDeletion_rejectedWhenTextIsEmpty() async throws {
        let mockService = MockDataDeletionService()
        let vm = SettingsViewModel(
            databaseManager: try makeTestDB(),
            dataDeletionService: mockService
        )
        vm.deletionConfirmationText = ""

        await vm.confirmDataDeletion()

        #expect(mockService.callCount == 0)
        #expect(vm.dataDeletionCompleted == false)
    }

    @Test @MainActor
    func test_confirmDataDeletion_noService_doesNothing() async throws {
        let vm = SettingsViewModel(databaseManager: try makeTestDB())
        vm.deletionConfirmationText = "DELETE"

        await vm.confirmDataDeletion()

        #expect(vm.dataDeletionCompleted == false)
        #expect(vm.isDeletingData == false)
    }

    @Test @MainActor
    func test_confirmDataDeletion_success_setsCompletedAndResetsIsDeleting() async throws {
        let mockService = MockDataDeletionService()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.onboardingCompleted = true
        appState.tier = .premium
        let vm = SettingsViewModel(
            databaseManager: try makeTestDB(),
            dataDeletionService: mockService,
            appState: appState
        )
        vm.deletionConfirmationText = "DELETE"

        await vm.confirmDataDeletion()

        #expect(mockService.callCount == 1)
        #expect(vm.dataDeletionCompleted == true)
        #expect(vm.isDeletingData == false)
        #expect(vm.deletionError == nil)
    }

    @Test @MainActor
    func test_confirmDataDeletion_failure_setsErrorAndResetsIsDeleting() async throws {
        let mockService = MockDataDeletionService()
        mockService.stubbedError = NSError(domain: "test", code: 42)
        let vm = SettingsViewModel(
            databaseManager: try makeTestDB(),
            dataDeletionService: mockService
        )
        vm.deletionConfirmationText = "DELETE"

        await vm.confirmDataDeletion()

        #expect(mockService.callCount == 1)
        #expect(vm.dataDeletionCompleted == false)
        #expect(vm.isDeletingData == false)
        #expect(vm.deletionError != nil)
    }

    // MARK: - resetAppStateToOnboarding

    @Test @MainActor
    func test_confirmDataDeletion_success_resetsAllMutableAppStateFields() async throws {
        let mockService = MockDataDeletionService()
        let appState = AppState()
        // Populate all 10 resettable mutable fields with non-default values.
        appState.isAuthenticated = true
        appState.needsReauth = true
        appState.onboardingCompleted = true
        appState.tier = .premium
        appState.avatarState = .celebrating
        appState.isPaused = true
        appState.pendingCheckIn = true
        appState.pendingEngagementSource = .reEngagementNudge
        appState.showConversation = true
        appState.activeSprint = Sprint(
            id: UUID(),
            name: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            status: .active,
            narrativeRetro: nil,
            lastStepCompletedAt: nil
        )
        // Non-resettable fields — should remain unchanged.
        appState.isOnline = false

        let vm = SettingsViewModel(
            databaseManager: try makeTestDB(),
            dataDeletionService: mockService,
            appState: appState
        )
        vm.deletionConfirmationText = "DELETE"

        await vm.confirmDataDeletion()

        #expect(appState.isAuthenticated == false)
        #expect(appState.needsReauth == false)
        #expect(appState.onboardingCompleted == false)
        #expect(appState.tier == .free)
        #expect(appState.avatarState == .active)
        #expect(appState.isPaused == false)
        #expect(appState.pendingCheckIn == false)
        #expect(appState.pendingEngagementSource == nil)
        #expect(appState.showConversation == false)
        #expect(appState.activeSprint == nil)
        // Non-resettable fields preserved.
        #expect(appState.isOnline == false)
    }

    @Test @MainActor
    func test_resetAppStateToOnboarding_noAppState_doesNothing() async throws {
        let vm = SettingsViewModel(databaseManager: try makeTestDB())
        // Should not crash when no AppState is wired.
        vm.resetAppStateToOnboarding()
    }
}
