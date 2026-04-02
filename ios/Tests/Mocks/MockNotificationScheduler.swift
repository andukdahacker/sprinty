@testable import sprinty
import Foundation
import UserNotifications

final class MockNotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    var scheduleCallCount = 0
    var removeAllCallCount = 0
    var shouldScheduleCallCount = 0
    var lastScheduledType: NotificationType?
    var lastTrigger: UNNotificationTrigger?
    var stubbedShouldSchedule = true

    func shouldSchedule(type: NotificationType) async -> Bool {
        shouldScheduleCallCount += 1
        return stubbedShouldSchedule
    }

    func scheduleIfAllowed(type: NotificationType, trigger: UNNotificationTrigger) async {
        scheduleCallCount += 1
        lastScheduledType = type
        lastTrigger = trigger
    }

    func removeAllScheduledNotifications() async {
        removeAllCallCount += 1
    }
}
