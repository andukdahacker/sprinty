import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 5.4 Tests ---

@Suite("HomeViewModel Check-in Tests")
struct HomeViewModelCheckInTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager, cadence: String = "daily") async throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            checkInCadence: cadence,
            checkInTimeHour: 9,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }
    }

    private func createSessionAndCheckIn(in db: DatabaseManager, summary: String, createdAt: Date = Date()) async throws {
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 6 * 86400),
            status: .active
        )
        let session = ConversationSession(
            id: UUID(), startedAt: createdAt, endedAt: createdAt,
            type: .checkIn, mode: .discovery, safetyLevel: .green,
            promptVersion: nil, modeHistory: nil, moodHistory: nil
        )
        let checkIn = CheckIn(id: UUID(), sessionId: session.id, sprintId: sprint.id, summary: summary, createdAt: createdAt)

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            try session.insert(dbConn)
            try checkIn.insert(dbConn)
        }
    }

    @Test("loadLatestCheckIn returns check-in summary when one exists today")
    @MainActor
    func test_loadLatestCheckIn_returnsSummary() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        try await createSessionAndCheckIn(in: db, summary: "Feeling focused and ready")

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.latestCheckIn == "Feeling focused and ready")
    }

    @Test("loadLatestCheckIn returns nil when no check-in today")
    @MainActor
    func test_loadLatestCheckIn_nilWhenNoCheckIn() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.latestCheckIn == nil)
    }

    @Test("loadLatestCheckIn returns nil when check-in was yesterday (daily cadence)")
    @MainActor
    func test_loadLatestCheckIn_nilForYesterday() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, cadence: "daily")
        try await createSessionAndCheckIn(in: db, summary: "Yesterday's check-in", createdAt: Date(timeIntervalSinceNow: -86400))

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.latestCheckIn == nil)
    }

    @Test("Check-in absent from home when no check-in done (AC #4)")
    @MainActor
    func test_noGuiltyMessaging_whenNoCheckIn() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // latestCheckIn is nil — no "You missed your check-in!" messaging
        #expect(vm.latestCheckIn == nil)
    }
}
