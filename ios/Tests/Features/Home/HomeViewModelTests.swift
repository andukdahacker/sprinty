import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("HomeViewModel")
struct HomeViewModelTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager, avatarId: String = "avatar_classic") async throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: avatarId,
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
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
            try profile.save(dbConn)
        }
    }

    // MARK: - Greeting computation

    @Test("Morning greeting for 8 AM")
    @MainActor
    func test_updateGreeting_morning_goodMorning() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        let morningDate = makeDate(hour: 8)
        viewModel.updateGreeting(for: morningDate)

        #expect(viewModel.timeOfDayGreeting == "Good morning")
    }

    @Test("Afternoon greeting for 2 PM")
    @MainActor
    func test_updateGreeting_afternoon_goodAfternoon() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        let afternoonDate = makeDate(hour: 14)
        viewModel.updateGreeting(for: afternoonDate)

        #expect(viewModel.timeOfDayGreeting == "Good afternoon")
    }

    @Test("Evening greeting for 7 PM")
    @MainActor
    func test_updateGreeting_evening_goodEvening() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        let eveningDate = makeDate(hour: 19)
        viewModel.updateGreeting(for: eveningDate)

        #expect(viewModel.timeOfDayGreeting == "Good evening")
    }

    @Test("Late night greeting for 2 AM")
    @MainActor
    func test_updateGreeting_lateNight_goodEvening() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        let lateNightDate = makeDate(hour: 2)
        viewModel.updateGreeting(for: lateNightDate)

        #expect(viewModel.timeOfDayGreeting == "Good evening")
    }

    @Test("Boundary: 5 AM is morning")
    @MainActor
    func test_updateGreeting_5AM_isMorning() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.updateGreeting(for: makeDate(hour: 5))

        #expect(viewModel.timeOfDayGreeting == "Good morning")
    }

    @Test("Boundary: noon is afternoon")
    @MainActor
    func test_updateGreeting_noon_isAfternoon() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.updateGreeting(for: makeDate(hour: 12))

        #expect(viewModel.timeOfDayGreeting == "Good afternoon")
    }

    @Test("Boundary: 5 PM is evening")
    @MainActor
    func test_updateGreeting_5PM_isEvening() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        viewModel.updateGreeting(for: makeDate(hour: 17))

        #expect(viewModel.timeOfDayGreeting == "Good evening")
    }

    // MARK: - UserProfile loading

    @Test("Load sets avatarId from UserProfile")
    @MainActor
    func test_load_setsAvatarIdFromProfile() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "owl")
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        await viewModel.load()

        #expect(viewModel.avatarId == "owl")
    }

    @Test("Load without profile keeps default avatarId")
    @MainActor
    func test_load_noProfile_keepsDefault() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        await viewModel.load()

        #expect(viewModel.avatarId == "avatar_classic")
    }

    @Test("Load sets greeting and timeOfDayGreeting")
    @MainActor
    func test_load_setsGreeting() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        await viewModel.load()

        #expect(viewModel.greeting == "Welcome back")
        #expect(!viewModel.timeOfDayGreeting.isEmpty)
    }

    // MARK: - Progressive disclosure

    @Test("Default greeting is Welcome back with no user name")
    @MainActor
    func test_greeting_isGenericWelcome() throws {
        let db = try makeTestDB()
        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        #expect(viewModel.greeting == "Welcome back")
    }

    // --- Story 6.3 Tests ---

    @Test("HomeViewModel sets resting avatar when lastSafetyBoundaryAt is present")
    @MainActor
    func test_load_postCrisis_setsRestingAvatar() async throws {
        let db = try makeTestDB()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            lastSafetyBoundaryAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.save(dbConn)
        }

        let appState = AppState()
        appState.avatarState = .active
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        await viewModel.load()

        #expect(viewModel.isPostCrisis == true)
        #expect(appState.avatarState == .resting)
    }

    @Test("HomeViewModel suppresses sprint nudges when post-crisis")
    @MainActor
    func test_load_postCrisis_suppressesSprintNudges() async throws {
        let db = try makeTestDB()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            lastSafetyBoundaryAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.save(dbConn)
        }
        // Create an active sprint
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 7 * 86400),
            status: .active
        )
        try await db.dbPool.write { dbConn in
            try sprint.save(dbConn)
        }

        let appState = AppState()
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)
        await viewModel.load()

        #expect(viewModel.isPostCrisis == true)
        #expect(viewModel.homeStage == .welcome)
        #expect(viewModel.insightDisplayText == nil)
    }

    @Test("HomeViewModel does not set resting avatar when lastSafetyBoundaryAt is nil")
    @MainActor
    func test_load_noCrisis_normalAvatar() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let appState = AppState()
        appState.avatarState = .active
        let viewModel = HomeViewModel(appState: appState, databaseManager: db)

        await viewModel.load()

        #expect(viewModel.isPostCrisis == false)
        #expect(appState.avatarState == .active)
    }

    // MARK: - Helpers

    private func makeDate(hour: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)!
    }
}
