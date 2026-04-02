import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 5.4 Code Review Fix Tests ---

@Suite("SettingsViewModel Check-in Notification Tests")
struct SettingsViewModelCheckInTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager) async throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }
    }

    @Test("updateCheckInCadence calls rescheduleCheckIn")
    @MainActor
    func test_updateCadence_reschedulesNotification() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let mockNotifService = MockCheckInNotificationService()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService)
        vm.checkInTimeHour = 10

        vm.updateCheckInCadence("weekly")

        // Wait for background Task to complete
        try await Task.sleep(for: .milliseconds(200))

        #expect(mockNotifService.rescheduleCallCount == 1)
    }

    @Test("updateCheckInTime calls rescheduleCheckIn")
    @MainActor
    func test_updateTime_reschedulesNotification() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let mockNotifService = MockCheckInNotificationService()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService)
        vm.checkInCadence = "daily"

        vm.updateCheckInTime(14)

        try await Task.sleep(for: .milliseconds(200))

        #expect(mockNotifService.rescheduleCallCount == 1)
    }

    // --- Story 9.2 Tests ---

    @Test("Profile hour change triggers reschedule")
    @MainActor
    func test_updateTime_triggersReschedule() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let mockNotifService = MockCheckInNotificationService()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService)
        await vm.loadProfile()

        vm.updateCheckInTime(15)

        try await Task.sleep(for: .milliseconds(200))

        #expect(mockNotifService.rescheduleCallCount == 1)

        // Verify the hour was persisted in DB
        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.checkInTimeHour == 15)
    }

    @Test("Profile cadence change triggers reschedule")
    @MainActor
    func test_updateCadence_triggersReschedule() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let mockNotifService = MockCheckInNotificationService()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService)
        await vm.loadProfile()

        vm.updateCheckInCadence("weekly")

        try await Task.sleep(for: .milliseconds(200))

        #expect(mockNotifService.rescheduleCallCount == 1)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.checkInCadence == "weekly")
        #expect(profile?.checkInWeekday != nil)
    }

    @Test("No notification service does not crash")
    @MainActor
    func test_noCrash_withoutNotificationService() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let vm = SettingsViewModel(databaseManager: db)
        vm.updateCheckInCadence("weekly")
        vm.updateCheckInTime(8)

        try await Task.sleep(for: .milliseconds(200))
        // No crash = graceful nil handling
    }
}
