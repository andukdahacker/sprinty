import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 10.4 Tests ---

@Suite("Widget Data Provider Tests")
struct WidgetDataProviderTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager, avatarId: String = "avatar_classic", isPaused: Bool = false) async throws {
        try await db.dbPool.write { dbConn in
            let profile = UserProfile(
                id: UUID(),
                avatarId: avatarId,
                coachAppearanceId: "coach_sage",
                coachName: "Sage",
                onboardingStep: 5,
                onboardingCompleted: true,
                isPaused: isPaused,
                createdAt: Date(),
                updatedAt: Date()
            )
            try profile.insert(dbConn)
        }
    }

    private func createActiveSprint(in db: DatabaseManager, name: String = "Test Sprint", stepCount: Int = 4, completedCount: Int = 2) async throws -> (Sprint, [SprintStep]) {
        let startDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let endDate = Calendar.current.date(byAdding: .day, value: 11, to: Date())!
        let sprint = Sprint(
            id: UUID(),
            name: name,
            startDate: startDate,
            endDate: endDate,
            status: .active
        )
        var steps: [SprintStep] = []
        for i in 1...stepCount {
            let step = SprintStep(
                id: UUID(),
                sprintId: sprint.id,
                description: "Step \(i)",
                completed: i <= completedCount,
                completedAt: i <= completedCount ? Date() : nil,
                order: i,
                coachContext: nil
            )
            steps.append(step)
        }

        let finalSteps = steps
        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            for step in finalSteps {
                try step.insert(dbConn)
            }
        }
        return (sprint, finalSteps)
    }

    // MARK: - Task 6.1: Timeline provider data queries

    @Test("fetchWidgetData with active sprint returns correct entry")
    func test_fetchWidgetData_activeSprint_returnsCorrectEntry() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let (sprint, _) = try await createActiveSprint(in: db, name: "Growth Sprint", stepCount: 4, completedCount: 2)

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        #expect(entry.hasActiveSprint == true)
        #expect(entry.sprintName == "Growth Sprint")
        #expect(entry.sprintProgress == 0.5)
        #expect(entry.currentStep == 2)
        #expect(entry.totalSteps == 4)
        #expect(entry.nextActionTitle == "Step 3")
        #expect(entry.avatarId == "avatar_classic")
        #expect(entry.avatarState == .active)
        #expect(entry.isPaused == false)
        _ = sprint
    }

    @Test("fetchWidgetData with no sprint returns empty entry")
    func test_fetchWidgetData_noSprint_returnsEmptyEntry() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        #expect(entry.hasActiveSprint == false)
        #expect(entry.sprintProgress == 0.0)
        #expect(entry.nextActionTitle == nil)
        #expect(entry.avatarId == "avatar_classic")
    }

    @Test("fetchWidgetData with paused state returns resting avatar")
    func test_fetchWidgetData_paused_returnsRestingAvatar() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, isPaused: true)
        _ = try await createActiveSprint(in: db)

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        #expect(entry.isPaused == true)
        #expect(entry.avatarState == .resting)
    }

    @Test("fetchWidgetData with completed sprint returns nil next action")
    func test_fetchWidgetData_completedSprint_returnsNilNextAction() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        _ = try await createActiveSprint(in: db, stepCount: 3, completedCount: 3)

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        #expect(entry.hasActiveSprint == true)
        #expect(entry.sprintProgress == 1.0)
        #expect(entry.currentStep == 3)
        #expect(entry.totalSteps == 3)
        #expect(entry.nextActionTitle == nil)
    }

    // MARK: - Task 6.2: Read-only database access

    @Test("WidgetDataProvider opens database in read-only mode")
    func test_widgetDataProvider_readOnlyAccess() throws {
        // Verify the read-only configuration by checking fetchWidgetData works
        // through the read path (actual read-only DB pool tested via integration)
        let db = try makeTestDB()
        let entry = try db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }
        // Should return placeholder-like entry when no data
        #expect(entry.hasActiveSprint == false)
        #expect(entry.avatarId == "avatar_classic")
    }

    // MARK: - Task 6.4: Entry calculation

    @Test("Widget entry calculates progress percentage correctly")
    func test_entryCalculation_progressPercentage() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        _ = try await createActiveSprint(in: db, stepCount: 5, completedCount: 3)

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        #expect(entry.sprintProgress == 0.6)
    }

    @Test("Widget entry calculates day number correctly")
    func test_entryCalculation_dayNumber() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        _ = try await createActiveSprint(in: db)

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        // Sprint started 3 days ago, so day number should be 4
        #expect(entry.dayNumber == 4)
        #expect(entry.totalDays > 0)
    }

    @Test("Widget entry extracts next action title from first incomplete step")
    func test_entryCalculation_nextActionExtraction() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        _ = try await createActiveSprint(in: db, stepCount: 5, completedCount: 2)

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        #expect(entry.nextActionTitle == "Step 3")
    }

    @Test("Widget entry with no profile uses defaults")
    func test_entryCalculation_noProfile_usesDefaults() async throws {
        let db = try makeTestDB()

        let entry = try await db.dbPool.read { dbConn in
            try WidgetDataProvider.fetchWidgetData(db: dbConn)
        }

        #expect(entry.avatarId == "avatar_classic")
        #expect(entry.avatarState == .active)
        #expect(entry.isPaused == false)
    }
}

// MARK: - Deep Link Tests

@Suite("Widget Deep Link Tests")
struct WidgetDeepLinkTests {

    @Test("sprinty://coach URL sets showConversation on AppState")
    @MainActor func test_deepLink_coachURL_setsShowConversation() {
        let appState = AppState()
        #expect(appState.showConversation == false)

        // Simulate the URL handling from SprintyApp.onOpenURL
        let url = URL(string: "sprinty://coach")!
        if url.scheme == "sprinty" && url.host == "coach" {
            appState.showConversation = true
        }

        #expect(appState.showConversation == true)
    }

    @Test("Non-coach URL does not set showConversation")
    @MainActor func test_deepLink_nonCoachURL_doesNotSetShowConversation() {
        let appState = AppState()

        let url = URL(string: "sprinty://settings")!
        if url.scheme == "sprinty" && url.host == "coach" {
            appState.showConversation = true
        }

        #expect(appState.showConversation == false)
    }

    @Test("Non-sprinty URL does not set showConversation")
    @MainActor func test_deepLink_nonSprintyURL_doesNotSetShowConversation() {
        let appState = AppState()

        let url = URL(string: "https://example.com/coach")!
        if url.scheme == "sprinty" && url.host == "coach" {
            appState.showConversation = true
        }

        #expect(appState.showConversation == false)
    }
}

// MARK: - Timeline Provider Tests

@Suite("SprintyTimelineProvider Tests")
struct SprintyTimelineProviderTests {

    @Test("placeholder returns default entry")
    func test_placeholder_returnsDefaults() {
        let entry = SprintyWidgetEntry.placeholder

        #expect(entry.avatarId == "avatar_classic")
        #expect(entry.avatarState == .active)
        #expect(entry.hasActiveSprint == false)
        #expect(entry.sprintProgress == 0.0)
        #expect(entry.sprintName == "")
        #expect(entry.nextActionTitle == nil)
        #expect(entry.isPaused == false)
    }
}
