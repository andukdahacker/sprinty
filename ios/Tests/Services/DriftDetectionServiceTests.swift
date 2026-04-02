import Testing
import Foundation
import UserNotifications
import GRDB
@testable import sprinty

// MARK: - Spy

final class SpyNotificationCenter: NotificationCenterScheduling, @unchecked Sendable {
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [[String]] = []
    var stubbedSettings: UNNotificationSettings?
    var stubbedPendingRequests: [UNNotificationRequest] = []

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        stubbedPendingRequests
    }

    func notificationSettings() async -> UNNotificationSettings {
        // UNNotificationSettings can't be directly constructed; tests using
        // NotificationScheduler should use the mock scheduler instead.
        // This default is only used by SpyNotificationCenter in DriftDetection tests
        // which don't call notificationSettings().
        fatalError("SpyNotificationCenter.notificationSettings() not stubbed — use MockNotificationScheduler for scheduler tests")
    }
}

// --- Story 7.2 Tests ---

@Suite("DriftDetectionService Tests")
struct DriftDetectionServiceTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(
        in db: DatabaseManager,
        createdAt: Date = Date(timeIntervalSinceNow: -2 * 86400),
        isPaused: Bool = false,
        pausedAt: Date? = nil,
        lastSafetyBoundaryAt: Date? = nil
    ) async throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            lastSafetyBoundaryAt: lastSafetyBoundaryAt,
            isPaused: isPaused,
            pausedAt: pausedAt,
            createdAt: createdAt,
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }
    }

    private func createSession(
        in db: DatabaseManager,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) async throws {
        let session = ConversationSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green
        )
        try await db.dbPool.write { dbConn in
            try session.insert(dbConn)
        }
    }

    // MARK: - Happy path: recent session arms dead-man's-switch (AC 1, 5)

    @Test("Schedules nudge for remaining time when session is recent")
    func test_evaluateAndSchedule_recentSession_schedulesForRemainingTime() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db)
        // Session 1 hour ago — nudge should fire in ~71 hours
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -3600))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.count == 1)
        let trigger = spy.addedRequests[0].trigger as! UNTimeIntervalNotificationTrigger
        // threshold (259200) - gap (3600) = 255600 ± tolerance
        #expect(trigger.timeInterval > 255000)
        #expect(trigger.timeInterval < 256000)
        #expect(trigger.repeats == false)
    }

    // MARK: - Happy path: stale session fires soon (AC 1, 5)

    @Test("Schedules nudge with minimum delay when session already exceeds threshold")
    func test_evaluateAndSchedule_pastThreshold_schedulesMinimumDelay() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db)
        // Session 4 days ago — already past 72h threshold
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -4 * 86400))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.count == 1)
        let trigger = spy.addedRequests[0].trigger as! UNTimeIntervalNotificationTrigger
        #expect(trigger.timeInterval == 60) // minimum delay
    }

    // MARK: - Pause suppression (AC 2)

    @Test("Does NOT schedule when isPaused is true (healthy pause)")
    func test_evaluateAndSchedule_paused_noSchedule() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db, isPaused: true, pausedAt: Date())
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -4 * 86400))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.isEmpty)
    }

    // MARK: - Post-crisis suppression (AC 4)

    @Test("Does NOT schedule when lastSafetyBoundaryAt is set (post-crisis)")
    func test_evaluateAndSchedule_postCrisis_noSchedule() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db, lastSafetyBoundaryAt: Date())
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -4 * 86400))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.isEmpty)
    }

    // MARK: - New user (AC 5)

    @Test("Does NOT schedule when no sessions exist (new user)")
    func test_evaluateAndSchedule_noSessions_noSchedule() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db)

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.isEmpty)
    }

    // MARK: - Cancel (AC 1)

    @Test("cancelReEngagementNudge removes pending notification by identifier")
    func test_cancelReEngagementNudge_removesPending() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)

        await service.cancelReEngagementNudge()

        #expect(spy.removedIdentifiers.count == 1)
        #expect(spy.removedIdentifiers[0] == [DriftDetectionService.reEngagementIdentifier])
    }

    // MARK: - Notification content (AC 1)

    @Test("Notification uses correct copy, identifier, and no sound")
    func test_notificationContent_correctCopyAndIdentifier() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db)
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -4 * 86400))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.count == 1)
        let request = spy.addedRequests[0]
        #expect(request.identifier == "com.ducdo.sprinty.reengagement")
        #expect(request.content.title == "")
        #expect(request.content.body == "Your coach has a thought for you.")
        #expect(request.content.sound == nil)
    }

    // MARK: - Config (AC 5)

    @Test("Default threshold is 72 hours, configurable via DriftDetectionConfig")
    func test_config_defaultThreshold() {
        let defaultConfig = DriftDetectionConfig()
        #expect(defaultConfig.inactivityThresholdHours == 72)
        #expect(defaultConfig.inactivityThresholdSeconds == 259200) // 72 * 3600

        let customConfig = DriftDetectionConfig(inactivityThresholdHours: 48)
        #expect(customConfig.inactivityThresholdHours == 48)
        #expect(customConfig.inactivityThresholdSeconds == 172800) // 48 * 3600
    }

    // MARK: - 24-hour install rule

    @Test("Does NOT schedule when profile created less than 24 hours ago")
    func test_evaluateAndSchedule_recentInstall_noSchedule() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db, createdAt: Date())
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -4 * 86400))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.isEmpty)
    }

    // MARK: - No profile

    @Test("Does NOT schedule when no profile exists")
    func test_evaluateAndSchedule_noProfile_noSchedule() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -4 * 86400))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.isEmpty)
    }

    // MARK: - Custom threshold

    @Test("Respects custom inactivity threshold for time-until-nudge calculation")
    func test_evaluateAndSchedule_customThreshold_respectsConfig() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db)
        // Session 12 hours ago, 24h custom threshold → nudge in ~12h
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -12 * 3600))

        let customConfig = DriftDetectionConfig(inactivityThresholdHours: 24)
        let service = DriftDetectionService(databaseManager: db, config: customConfig, notificationCenter: spy)
        await service.evaluateAndSchedule()

        #expect(spy.addedRequests.count == 1)
        let trigger = spy.addedRequests[0].trigger as! UNTimeIntervalNotificationTrigger
        // threshold (86400) - gap (43200) = 43200 ± tolerance
        #expect(trigger.timeInterval > 42500)
        #expect(trigger.timeInterval < 44000)
    }

    // MARK: - Cancel-before-schedule behavior

    @Test("evaluateAndSchedule cancels existing nudge before scheduling new one")
    func test_evaluateAndSchedule_cancelsBeforeScheduling() async throws {
        let db = try makeTestDB()
        let spy = SpyNotificationCenter()
        try await createProfile(in: db)
        try await createSession(in: db, startedAt: Date(timeIntervalSinceNow: -3600))

        let service = DriftDetectionService(databaseManager: db, notificationCenter: spy)
        await service.evaluateAndSchedule()

        // Should cancel first, then add
        #expect(spy.removedIdentifiers.count == 1)
        #expect(spy.addedRequests.count == 1)
    }
}
