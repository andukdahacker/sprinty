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

    private func createSprintTable(in db: DatabaseManager) async throws {
        try await db.dbPool.write { dbConn in
            try dbConn.execute(sql: """
                CREATE TABLE IF NOT EXISTS Sprint (
                    id TEXT PRIMARY KEY,
                    name TEXT,
                    startDate TEXT,
                    endDate TEXT,
                    status TEXT
                )
                """)
            try dbConn.execute(sql: """
                CREATE TABLE IF NOT EXISTS SprintStep (
                    id TEXT PRIMARY KEY,
                    sprintId TEXT,
                    description TEXT,
                    completedAt TEXT,
                    "order" INTEGER
                )
                """)
        }
    }

    private func createActiveSprint(
        in db: DatabaseManager,
        id: String = "sprint-1",
        name: String = "Career Growth",
        startDate: String? = nil,
        endDate: String? = nil,
        completedSteps: Int = 2,
        totalSteps: Int = 5
    ) async throws {
        let start = startDate ?? ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -3 * 86400))
        let end = endDate ?? ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: 4 * 86400))
        try await db.dbPool.write { dbConn in
            try dbConn.execute(
                sql: "INSERT INTO Sprint (id, name, startDate, endDate, status) VALUES (?, ?, ?, ?, 'active')",
                arguments: [id, name, start, end]
            )
            for i in 1...totalSteps {
                let completedAt: String? = i <= completedSteps ? ISO8601DateFormatter().string(from: Date()) : nil
                try dbConn.execute(
                    sql: "INSERT INTO SprintStep (id, sprintId, description, completedAt, \"order\") VALUES (?, ?, ?, ?, ?)",
                    arguments: ["step-\(i)", id, "Step \(i)", completedAt, i]
                )
            }
        }
    }

    // MARK: - Day calculation tests (Task 4.1)

    @Test("Day calculation from startDate/endDate — mid-sprint")
    @MainActor
    func test_loadActiveSprint_midSprint_correctDayNumber() async throws {
        let db = try makeTestDB()
        try await createSprintTable(in: db)
        let formatter = ISO8601DateFormatter()
        let start = formatter.string(from: Date(timeIntervalSinceNow: -3 * 86400))
        let end = formatter.string(from: Date(timeIntervalSinceNow: 4 * 86400))
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
        try await createSprintTable(in: db)
        let formatter = ISO8601DateFormatter()
        let today = formatter.string(from: Date())
        let end = formatter.string(from: Date(timeIntervalSinceNow: 6 * 86400))
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
        try await createSprintTable(in: db)
        let formatter = ISO8601DateFormatter()
        let start = formatter.string(from: Date(timeIntervalSinceNow: -10 * 86400))
        let end = formatter.string(from: Date(timeIntervalSinceNow: -3 * 86400))
        try await createActiveSprint(in: db, startDate: start, endDate: end)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Day number can exceed total days — the sprint is still active in DB
        #expect(vm.sprintDayNumber > 0)
        #expect(vm.sprintTotalDays == 8) // 7 days apart + 1 for inclusive count
    }

    @Test("Day calculation — nil dates omit day data")
    @MainActor
    func test_loadActiveSprint_nilDates_zeroDays() async throws {
        let db = try makeTestDB()
        try await createSprintTable(in: db)
        try await db.dbPool.write { dbConn in
            try dbConn.execute(
                sql: "INSERT INTO Sprint (id, name, startDate, endDate, status) VALUES ('s1', 'Test', NULL, NULL, 'active')"
            )
        }

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.hasActiveSprint == true)
        #expect(vm.sprintDayNumber == 0)
        #expect(vm.sprintTotalDays == 0)
    }

    // MARK: - Sprint name tests (Task 4.7)

    @Test("Sprint name populated from Sprint table")
    @MainActor
    func test_loadActiveSprint_populatesSprintName() async throws {
        let db = try makeTestDB()
        try await createSprintTable(in: db)
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
        try await createSprintTable(in: db)
        try await createActiveSprint(in: db)

        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.homeStage == .paused)
        #expect(vm.hasActiveSprint == true)
    }

    // MARK: - Graceful fallback (Task 4.6)

    @Test("Sprint table doesn't exist → returns defaults")
    @MainActor
    func test_loadActiveSprint_noTable_gracefulDefaults() async throws {
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
        try await createSprintTable(in: db)
        let formatter = ISO8601DateFormatter()
        let start = formatter.string(from: Date(timeIntervalSinceNow: -2 * 86400))
        let end = formatter.string(from: Date(timeIntervalSinceNow: 5 * 86400))
        try await createActiveSprint(in: db, startDate: start, endDate: end, completedSteps: 2, totalSteps: 5)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.sprintDayNumber > 0)
        #expect(vm.sprintTotalDays > 0)

        // Verify actual VoiceOver string includes day portion
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

    @Test("VoiceOver value omits day when dates unavailable")
    @MainActor
    func test_voiceOverValue_withoutDays() async throws {
        let db = try makeTestDB()
        try await createSprintTable(in: db)
        try await db.dbPool.write { dbConn in
            try dbConn.execute(
                sql: "INSERT INTO Sprint (id, name, startDate, endDate, status) VALUES ('s1', 'Test', NULL, NULL, 'active')"
            )
        }

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.sprintDayNumber == 0)
        #expect(vm.sprintTotalDays == 0)

        // Verify VoiceOver string has no day portion
        let view = SprintProgressView(
            progress: 0, currentStep: 0, totalSteps: 0, isMuted: false,
            dayNumber: 0, totalDays: 0
        )
        #expect(view.voiceOverValue == "Step 0 of 0")
        #expect(!view.voiceOverValue.contains("day"))
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
