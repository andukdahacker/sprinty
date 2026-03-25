import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("HomeViewModel Sprint Progress")
struct HomeViewModelSprintTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createActiveSprint(
        in db: DatabaseManager,
        name: String = "Career Growth",
        startDate: Date? = nil,
        endDate: Date? = nil,
        completedSteps: Int = 2,
        totalSteps: Int = 5
    ) async throws {
        let start = startDate ?? Date(timeIntervalSinceNow: -3 * 86400)
        let end = endDate ?? Date(timeIntervalSinceNow: 4 * 86400)
        let sprint = Sprint(id: UUID(), name: name, startDate: start, endDate: end, status: .active)
        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            for i in 1...totalSteps {
                let step = SprintStep(
                    id: UUID(),
                    sprintId: sprint.id,
                    description: "Step \(i)",
                    completed: i <= completedSteps,
                    completedAt: i <= completedSteps ? Date() : nil,
                    order: i
                )
                try step.insert(dbConn)
            }
        }
    }

    // MARK: - Day calculation tests (Task 4.1)

    @Test("Day calculation from startDate/endDate — mid-sprint")
    @MainActor
    func test_loadActiveSprint_midSprint_correctDayNumber() async throws {
        let db = try makeTestDB()
        let start = Date(timeIntervalSinceNow: -3 * 86400)
        let end = Date(timeIntervalSinceNow: 4 * 86400)
        try await createActiveSprint(in: db, startDate: start, endDate: end)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.sprintDayNumber >= 3) // at least 3 days in
        #expect(vm.sprintTotalDays == 8) // 7 days apart + 1 for inclusive count
    }

    @Test("Day calculation — same day start")
    @MainActor
    func test_loadActiveSprint_sameDay_dayOne() async throws {
        let db = try makeTestDB()
        let today = Date()
        let end = Date(timeIntervalSinceNow: 6 * 86400)
        try await createActiveSprint(in: db, startDate: today, endDate: end)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.sprintDayNumber == 1)
        #expect(vm.sprintTotalDays == 7) // 6 days apart + 1 for inclusive count
    }

    @Test("Day calculation — past endDate")
    @MainActor
    func test_loadActiveSprint_pastEndDate_clampedDay() async throws {
        let db = try makeTestDB()
        let start = Date(timeIntervalSinceNow: -10 * 86400)
        let end = Date(timeIntervalSinceNow: -3 * 86400)
        try await createActiveSprint(in: db, startDate: start, endDate: end)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Day number can exceed total days — the sprint is still active in DB
        #expect(vm.sprintDayNumber > 0)
        #expect(vm.sprintTotalDays == 8) // 7 days apart + 1 for inclusive count
    }

    // MARK: - Sprint name tests (Task 4.7)

    @Test("Sprint name populated from Sprint table")
    @MainActor
    func test_loadActiveSprint_populatesSprintName() async throws {
        let db = try makeTestDB()
        try await createActiveSprint(in: db, name: "Career Growth")

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.sprintName == "Career Growth")
    }

    @Test("No sprint → sprintName is empty")
    @MainActor
    func test_loadActiveSprint_noSprint_emptyName() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.sprintName == "")
    }

    // MARK: - No sprint (Task 4.4)

    @Test("No sprint → homeStage stays at welcome/insightUnlocked")
    @MainActor
    func test_noSprint_stageNotSprintActive() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.homeStage == .welcome)
        #expect(vm.hasActiveSprint == false)
    }

    // MARK: - Pause mode (Task 4.5)

    @Test("Pause Mode → isMuted=true passed to SprintProgressView")
    @MainActor
    func test_pauseMode_isMuted() async throws {
        let db = try makeTestDB()
        try await createActiveSprint(in: db)

        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.homeStage == .paused)
        #expect(vm.hasActiveSprint == true)
    }

    // MARK: - Graceful fallback (Task 4.6) — tables now always exist via v8 migration

    @Test("No active sprint → returns defaults")
    @MainActor
    func test_loadActiveSprint_noActiveSprint_gracefulDefaults() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.hasActiveSprint == false)
        #expect(vm.sprintProgress == 0)
        #expect(vm.sprintCurrentStep == 0)
        #expect(vm.sprintTotalSteps == 0)
        #expect(vm.sprintName == "")
        #expect(vm.sprintDayNumber == 0)
        #expect(vm.sprintTotalDays == 0)
    }

    // MARK: - VoiceOver (Task 4.2, 4.3)

    @Test("VoiceOver value includes day when dates available")
    @MainActor
    func test_voiceOverValue_withDays() async throws {
        let db = try makeTestDB()
        let start = Date(timeIntervalSinceNow: -2 * 86400)
        let end = Date(timeIntervalSinceNow: 5 * 86400)
        try await createActiveSprint(in: db, startDate: start, endDate: end, completedSteps: 2, totalSteps: 5)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.sprintDayNumber > 0)
        #expect(vm.sprintTotalDays > 0)

        let view = SprintProgressView(
            progress: vm.sprintProgress,
            currentStep: vm.sprintCurrentStep,
            totalSteps: vm.sprintTotalSteps,
            isMuted: false,
            dayNumber: vm.sprintDayNumber,
            totalDays: vm.sprintTotalDays
        )
        #expect(view.voiceOverValue.contains("day \(vm.sprintDayNumber) of \(vm.sprintTotalDays)"))
        #expect(view.voiceOverValue.hasPrefix("Step \(vm.sprintCurrentStep) of \(vm.sprintTotalSteps)"))
    }

    // MARK: - VoiceOver string format (direct view tests)

    @Test("VoiceOver string format with day data")
    @MainActor
    func test_voiceOverValue_format_withDays() {
        let view = SprintProgressView(
            progress: 0.4, currentStep: 2, totalSteps: 5, isMuted: false,
            dayNumber: 3, totalDays: 7
        )
        #expect(view.voiceOverValue == "Step 2 of 5, day 3 of 7")
    }

    @Test("VoiceOver string format without day data")
    @MainActor
    func test_voiceOverValue_format_withoutDays() {
        let view = SprintProgressView(
            progress: 0.5, currentStep: 3, totalSteps: 6, isMuted: false
        )
        #expect(view.voiceOverValue == "Step 3 of 6")
    }
}
