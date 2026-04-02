import Testing
import Foundation
import UserNotifications
import GRDB
@testable import sprinty

// --- Story 9.1 Tests ---

@Suite("NotificationScheduler Tests")
struct NotificationSchedulerTests {

    // MARK: - Helpers

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func makeScheduler(dbManager: DatabaseManager, center: SpyNotificationCenter = SpyNotificationCenter(), permitted: Bool = true) -> (NotificationScheduler, SpyNotificationCenter) {
        let scheduler = NotificationScheduler(
            databaseManager: dbManager,
            notificationCenter: center,
            permissionChecker: { permitted }
        )
        return (scheduler, center)
    }

    private func createProfile(in dbManager: DatabaseManager, createdAt: Date = Date().addingTimeInterval(-48 * 3600), isPaused: Bool = false, lastSafetyBoundaryAt: Date? = nil) throws {
        try dbManager.dbPool.write { db in
            var profile = UserProfile(
                id: UUID(),
                avatarId: "avatar_classic",
                coachAppearanceId: "coach_sage",
                coachName: "Coach",
                onboardingStep: 5,
                onboardingCompleted: true,
                createdAt: createdAt,
                updatedAt: Date()
            )
            profile.isPaused = isPaused
            profile.lastSafetyBoundaryAt = lastSafetyBoundaryAt
            try profile.save(db)
        }
    }

    private func todayDeliveryCount(in dbManager: DatabaseManager) throws -> Int {
        try dbManager.dbPool.read { db in
            try NotificationDelivery.todayCount(in: db)
        }
    }

    // MARK: - Test 9.1: Daily cap enforcement

    @Test func test_dailyCap_allowsUpToTwo() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        #expect(spy.addedRequests.count == 1)

        await scheduler.scheduleIfAllowed(type: .reEngagement, trigger: trigger)
        #expect(spy.addedRequests.count == 2)

        // Third of SAME or LOWER priority — blocked (reEngagement priority 4 is not < reEngagement priority 4)
        await scheduler.scheduleIfAllowed(type: .reEngagement, trigger: trigger)
        #expect(spy.addedRequests.count == 2)

        #expect(try todayDeliveryCount(in: dbManager) == 2)
    }

    @Test func test_dailyCap_thirdScheduleOfSamePriorityBlocked() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        #expect(spy.addedRequests.count == 2)

        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        #expect(spy.addedRequests.count == 2)
    }

    // MARK: - Test 9.2: Priority ordering

    @Test func test_priorityOrdering_higherPriorityWinsWhenCapReached() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        // Fill cap with low-priority notifications
        await scheduler.scheduleIfAllowed(type: .reEngagement, trigger: trigger)
        await scheduler.scheduleIfAllowed(type: .pauseSuggestion, trigger: trigger)
        #expect(spy.addedRequests.count == 2)

        // Higher-priority milestone (1) displaces lowest-priority reEngagement (4)
        await scheduler.scheduleIfAllowed(type: .sprintMilestone, trigger: trigger)
        #expect(spy.addedRequests.count == 3) // 3 total add() calls
        #expect(spy.removedIdentifiers.count == 1) // displaced notification removed
        #expect(spy.removedIdentifiers[0] == [NotificationType.reEngagement.identifier])
        #expect(try todayDeliveryCount(in: dbManager) == 2) // hard cap maintained
    }

    @Test func test_priorityOrdering_lowerPriorityBlockedWhenCapReachedWithHigher() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        // Fill cap with high-priority notifications
        await scheduler.scheduleIfAllowed(type: .sprintMilestone, trigger: trigger)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        #expect(spy.addedRequests.count == 2)

        // Lower-priority re-engagement (4) should be blocked — doesn't beat checkIn (2)
        await scheduler.scheduleIfAllowed(type: .reEngagement, trigger: trigger)
        #expect(spy.addedRequests.count == 2)
    }

    // MARK: - Test 9.3: Pause mode suppression

    @Test func test_pauseMode_suppressesAllNotifications() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager, isPaused: true)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        await scheduler.scheduleIfAllowed(type: .sprintMilestone, trigger: trigger)
        await scheduler.scheduleIfAllowed(type: .pauseSuggestion, trigger: trigger)
        await scheduler.scheduleIfAllowed(type: .reEngagement, trigger: trigger)

        #expect(spy.addedRequests.count == 0)
    }

    // MARK: - Test 9.4: 24-hour install rule

    @Test func test_24hourInstallRule_suppressesNewUser() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager, createdAt: Date())

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)

        #expect(spy.addedRequests.count == 0)
    }

    @Test func test_24hourInstallRule_allowsAfter24Hours() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager, createdAt: Date().addingTimeInterval(-25 * 3600))

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)

        #expect(spy.addedRequests.count == 1)
    }

    // MARK: - Test 9.5: Post-crisis suppression

    @Test func test_postCrisis_suppressesNotifications() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager, lastSafetyBoundaryAt: Date())

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)

        #expect(spy.addedRequests.count == 0)
    }

    // MARK: - Test 9.6: Sprint milestone trigger

    @Test func test_milestoneNotification_contentIsCorrect() {
        let content = NotificationType.sprintMilestone.content
        #expect(content.title == "")
        #expect(content.body == "You hit a milestone. Your coach noticed.")
        #expect(content.sound == nil)
    }

    @Test func test_milestoneNotification_identifierIsCorrect() {
        #expect(NotificationType.sprintMilestone.identifier == "com.ducdo.sprinty.milestone")
    }

    @Test func test_milestoneNotification_priorityIsCorrect() {
        #expect(NotificationType.sprintMilestone.priority == 1)
    }

    // MARK: - Test 9.7: Pause suggestion trigger

    @Test func test_pauseSuggestionNotification_contentIsCorrect() {
        let content = NotificationType.pauseSuggestion.content
        #expect(content.title == "")
        #expect(content.body == "Your coach thinks you might need a breather.")
        #expect(content.sound == nil)
    }

    @Test func test_pauseSuggestionNotification_identifierIsCorrect() {
        #expect(NotificationType.pauseSuggestion.identifier == "com.ducdo.sprinty.pausesuggestion")
    }

    // MARK: - Test 9.8: Full scheduling flow

    @Test func test_fullSchedulingFlow_respectsAllRules() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        await scheduler.scheduleIfAllowed(type: .sprintMilestone, trigger: trigger)
        #expect(spy.addedRequests.count == 1)
        #expect(spy.addedRequests[0].identifier == "com.ducdo.sprinty.milestone")

        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        #expect(spy.addedRequests.count == 2)
        #expect(spy.addedRequests[1].identifier == "com.ducdo.sprinty.checkin")

        for request in spy.addedRequests {
            #expect(request.content.title == "")
            #expect(request.content.sound == nil)
        }
    }

    // MARK: - Test: Permission denied

    @Test func test_permissionDenied_suppressesNotifications() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager, permitted: false)
        try createProfile(in: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)

        #expect(spy.addedRequests.count == 0)
    }

    // MARK: - Test: removeAllScheduledNotifications

    @Test func test_removeAll_removesAllIdentifiers() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)

        await scheduler.removeAllScheduledNotifications()

        #expect(spy.removedIdentifiers.count == 1)
        let removed = spy.removedIdentifiers[0]
        #expect(removed.contains("com.ducdo.sprinty.checkin"))
        #expect(removed.contains("com.ducdo.sprinty.milestone"))
        #expect(removed.contains("com.ducdo.sprinty.pausesuggestion"))
        #expect(removed.contains("com.ducdo.sprinty.reengagement"))
    }

    @Test func test_removeAll_clearsDeliveryRecords() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, _) = makeScheduler(dbManager: dbManager)
        try createProfile(in: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
        #expect(try todayDeliveryCount(in: dbManager) == 1)

        await scheduler.removeAllScheduledNotifications()
        #expect(try todayDeliveryCount(in: dbManager) == 0)
    }

    // MARK: - Test: NotificationType properties

    @Test func test_notificationType_allPrioritiesOrdered() {
        #expect(NotificationType.sprintMilestone.priority < NotificationType.checkIn.priority)
        #expect(NotificationType.checkIn.priority < NotificationType.pauseSuggestion.priority)
        #expect(NotificationType.pauseSuggestion.priority < NotificationType.reEngagement.priority)
    }

    @Test func test_notificationType_checkInContent() {
        let content = NotificationType.checkIn.content
        #expect(content.body == "Your coach has a thought for you.")
    }

    @Test func test_notificationType_reEngagementContent() {
        let content = NotificationType.reEngagement.content
        #expect(content.body == "Your coach has a thought for you.")
    }

    // MARK: - Test: NotificationDelivery model

    @Test func test_notificationDelivery_databaseRoundTrip() throws {
        let dbManager = try makeTestDB()

        let delivery = NotificationDelivery(
            id: UUID(),
            type: NotificationType.checkIn.rawValue,
            scheduledAt: Date(),
            deliveredAt: nil,
            priority: NotificationType.checkIn.priority
        )

        try dbManager.dbPool.write { db in
            try delivery.save(db)
        }

        let fetched = try dbManager.dbPool.read { db in
            try NotificationDelivery.fetchOne(db, key: delivery.id)
        }

        #expect(fetched != nil)
        #expect(fetched?.type == "checkIn")
        #expect(fetched?.priority == 2)
    }

    @Test func test_notificationDelivery_todayCount() throws {
        let dbManager = try makeTestDB()

        try dbManager.dbPool.write { db in
            try NotificationDelivery(
                id: UUID(),
                type: "checkIn",
                scheduledAt: Date(),
                deliveredAt: nil,
                priority: 2
            ).save(db)

            try NotificationDelivery(
                id: UUID(),
                type: "reEngagement",
                scheduledAt: Date().addingTimeInterval(-25 * 3600),
                deliveredAt: nil,
                priority: 4
            ).save(db)
        }

        let count = try dbManager.dbPool.read { db in
            try NotificationDelivery.todayCount(in: db)
        }

        #expect(count == 1)
    }

    @Test func test_notificationDelivery_cleanupOldEntries() throws {
        let dbManager = try makeTestDB()

        try dbManager.dbPool.write { db in
            try NotificationDelivery(
                id: UUID(),
                type: "checkIn",
                scheduledAt: Date().addingTimeInterval(-72 * 3600),
                deliveredAt: nil,
                priority: 2
            ).save(db)

            try NotificationDelivery(
                id: UUID(),
                type: "checkIn",
                scheduledAt: Date(),
                deliveredAt: nil,
                priority: 2
            ).save(db)
        }

        try dbManager.dbPool.write { db in
            try NotificationDelivery.cleanupOldEntries(in: db)
        }

        let count = try dbManager.dbPool.read { db in
            try NotificationDelivery.fetchCount(db)
        }

        #expect(count == 1)
    }

    // MARK: - Test: No profile = no notifications

    @Test func test_noProfile_suppressesNotifications() async throws {
        let dbManager = try makeTestDB()
        let (scheduler, spy) = makeScheduler(dbManager: dbManager)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)

        #expect(spy.addedRequests.count == 0)
    }

    // MARK: - Test: MockNotificationScheduler

    @Test func test_mockScheduler_recordsCalls() async {
        let mock = MockNotificationScheduler()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        await mock.scheduleIfAllowed(type: .sprintMilestone, trigger: trigger)

        #expect(mock.scheduleCallCount == 1)
        #expect(mock.lastScheduledType == .sprintMilestone)
    }
}
