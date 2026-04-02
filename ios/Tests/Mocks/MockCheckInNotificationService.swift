@testable import sprinty
import Foundation

final class MockCheckInNotificationService: CheckInNotificationServiceProtocol, @unchecked Sendable {
    var scheduleCallCount = 0
    var cancelCallCount = 0
    var requestPermissionCallCount = 0
    var rescheduleCallCount = 0
    var lastCadence: String?
    var lastHour: Int?
    var lastWeekday: Int?
    var lastRescheduleProfile: UserProfile?
    var stubbedPermissionResult = true

    func scheduleCheckInNotification(cadence: String, hour: Int, weekday: Int?) async {
        scheduleCallCount += 1
        lastCadence = cadence
        lastHour = hour
        lastWeekday = weekday
    }

    func cancelCheckInNotifications() async {
        cancelCallCount += 1
    }

    func requestPermissionIfNeeded() async -> Bool {
        requestPermissionCallCount += 1
        return stubbedPermissionResult
    }

    func rescheduleCheckIn(profile: UserProfile?) async {
        rescheduleCallCount += 1
        lastRescheduleProfile = profile
    }
}
