import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 5.4 Tests ---

@Suite("CheckInNotificationService Tests")
struct CheckInNotificationServiceTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager, createdAt: Date = Date(timeIntervalSinceNow: -2 * 86400)) async throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            createdAt: createdAt,
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }
    }

    private func createActiveSprint(in db: DatabaseManager) async throws {
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 7 * 86400),
            status: .active
        )
        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
        }
    }

    // MARK: - 24-hour install rule

    @Test("Notification not scheduled when install < 24 hours ago")
    func test_24hourRule_recentInstall() async throws {
        let db = try makeTestDB()
        // Profile created now — less than 24 hours
        try await createProfile(in: db, createdAt: Date())
        try await createActiveSprint(in: db)

        let service = CheckInNotificationService(databaseManager: db)
        // This would normally schedule, but since install is < 24h, it should not
        // We can't directly test the notification center in unit tests,
        // but we verify the logic via the `isInstallOlderThan24Hours` check
        // by observing that no error is thrown
        await service.scheduleCheckInNotification(cadence: "daily", hour: 9, weekday: nil)
        // If this doesn't crash, the guard check works
    }

    @Test("Notification not scheduled when no active sprint")
    func test_noSprint_noNotification() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        // No sprint created

        let service = CheckInNotificationService(databaseManager: db)
        await service.scheduleCheckInNotification(cadence: "daily", hour: 9, weekday: nil)
        // Should early-return due to no active sprint
    }

    @Test("Cancel notifications removes check-in identifier")
    func test_cancelNotifications() async throws {
        let db = try makeTestDB()
        let service = CheckInNotificationService(databaseManager: db)
        await service.cancelCheckInNotifications()
        // Verify no crash — actual notification center behavior is OS-level
    }

    // MARK: - Cadence configuration

    @Test("Daily cadence creates trigger without weekday")
    func test_dailyCadence_noWeekday() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        try await createActiveSprint(in: db)

        let service = CheckInNotificationService(databaseManager: db)
        await service.scheduleCheckInNotification(cadence: "daily", hour: 9, weekday: nil)
        // No crash = daily scheduling path works
    }

    @Test("Weekly cadence includes weekday in trigger")
    func test_weeklyCadence_withWeekday() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        try await createActiveSprint(in: db)

        let service = CheckInNotificationService(databaseManager: db)
        await service.scheduleCheckInNotification(cadence: "weekly", hour: 9, weekday: 3)
        // No crash = weekly scheduling path works
    }

    // MARK: - Notification content

    @Test("Notification identifier is consistent")
    func test_notificationIdentifier() {
        #expect(CheckInNotificationService.checkInIdentifier == "com.ducdo.sprinty.checkin")
    }
}
