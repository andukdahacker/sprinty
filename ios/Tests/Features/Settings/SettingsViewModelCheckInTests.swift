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

// --- Story 9.3 Tests ---

@Suite("SettingsViewModel Notification Preference Tests")
struct SettingsViewModelNotificationPreferenceTests {

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

    @Test("updateNotificationsMuted(true) persists and calls removeAll")
    @MainActor
    func test_updateNotificationsMuted_true_persistsAndRemovesAll() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let mockScheduler = MockNotificationScheduler()
        let vm = SettingsViewModel(databaseManager: db, notificationScheduler: mockScheduler)

        vm.updateNotificationsMuted(true)

        try await Task.sleep(for: .milliseconds(200))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.notificationsMuted == true)
        #expect(mockScheduler.removeAllCallCount == 1)
    }

    @Test("updateNotificationsMuted(false) persists and reschedules")
    @MainActor
    func test_updateNotificationsMuted_false_persistsAndReschedules() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        // Set muted first
        try await db.dbPool.write { dbConn in
            if var profile = try UserProfile.fetchOne(dbConn) {
                profile.notificationsMuted = true
                profile.updatedAt = Date()
                try profile.update(dbConn)
            }
        }

        let mockNotifService = MockCheckInNotificationService()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService)

        vm.updateNotificationsMuted(false)

        try await Task.sleep(for: .milliseconds(200))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.notificationsMuted == false)
        #expect(mockNotifService.rescheduleCallCount == 1)
    }

    @Test("checkProfileRules returns false when muted")
    func test_checkProfileRules_returnsFalse_whenMuted() async throws {
        let db = try makeTestDB()

        // Create profile with notificationsMuted = true, old enough for 24h rule
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            notificationsMuted: true,
            createdAt: Date().addingTimeInterval(-86401),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }

        let scheduler = NotificationScheduler(
            databaseManager: db,
            permissionChecker: { true }
        )
        let allowed = await scheduler.shouldSchedule(type: .checkIn)
        #expect(allowed == false)
    }

    @Test("checkProfileRules blocks non-safety types when muted but would allow bypassesMute types")
    func test_checkProfileRules_respectsBypassesMute() async throws {
        // All current types have bypassesMute = false, so all should be blocked when muted
        // This test documents the bypass architecture for future safety notification types
        #expect(NotificationType.checkIn.bypassesMute == false)
        #expect(NotificationType.sprintMilestone.bypassesMute == false)
        #expect(NotificationType.pauseSuggestion.bypassesMute == false)
        #expect(NotificationType.reEngagement.bypassesMute == false)
    }

    @Test("updateCheckInWeekday persists and reschedules")
    @MainActor
    func test_updateCheckInWeekday_persistsAndReschedules() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let mockNotifService = MockCheckInNotificationService()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService)
        await vm.loadProfile()

        vm.updateCheckInWeekday(4) // Wednesday

        try await Task.sleep(for: .milliseconds(200))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.checkInWeekday == 4)
        #expect(mockNotifService.rescheduleCallCount == 1)
    }

    @Test("Mute state survives loadProfile round-trip")
    @MainActor
    func test_muteState_survivesLoadProfile() async throws {
        let db = try makeTestDB()

        // Create profile with muted = true
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            notificationsMuted: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }

        let vm = SettingsViewModel(databaseManager: db)
        #expect(vm.notificationsMuted == false) // default before load

        await vm.loadProfile()

        #expect(vm.notificationsMuted == true)
    }

    @Test("Existing cadence/time tests pass with new migration")
    @MainActor
    func test_existingCadenceTime_worksWithV17Migration() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)

        let mockNotifService = MockCheckInNotificationService()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService)

        vm.updateCheckInCadence("weekly")
        vm.updateCheckInTime(14)

        try await Task.sleep(for: .milliseconds(200))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.checkInCadence == "weekly")
        #expect(profile?.checkInTimeHour == 14)
        #expect(profile?.notificationsMuted == false) // default preserved
    }

    @Test("SettingsViewModel init accepts both notificationService and notificationScheduler")
    @MainActor
    func test_init_acceptsBothServices() async throws {
        let db = try makeTestDB()

        let mockNotifService = MockCheckInNotificationService()
        let mockScheduler = MockNotificationScheduler()
        let vm = SettingsViewModel(databaseManager: db, notificationService: mockNotifService, notificationScheduler: mockScheduler)

        // Verify VM created successfully with both services
        #expect(vm.notificationsMuted == false)
        #expect(vm.checkInCadence == "daily")

        // Also test nil defaults work (for previews)
        let vmNil = SettingsViewModel(databaseManager: db)
        #expect(vmNil.notificationsMuted == false)
    }
}
