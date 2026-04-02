import Foundation
import UserNotifications
import GRDB

protocol CheckInNotificationServiceProtocol: Sendable {
    func scheduleCheckInNotification(cadence: String, hour: Int, weekday: Int?) async
    func cancelCheckInNotifications() async
    func requestPermissionIfNeeded() async -> Bool
}

final class CheckInNotificationService: CheckInNotificationServiceProtocol, @unchecked Sendable {
    private let notificationCenter: NotificationCenterScheduling
    private let databaseManager: DatabaseManager
    private let scheduler: NotificationSchedulerProtocol?

    static let checkInIdentifier = "com.ducdo.sprinty.checkin"

    init(databaseManager: DatabaseManager, notificationCenter: NotificationCenterScheduling = UNUserNotificationCenter.current(), scheduler: NotificationSchedulerProtocol? = nil) {
        self.notificationCenter = notificationCenter
        self.databaseManager = databaseManager
        self.scheduler = scheduler
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        // requestAuthorization is only on UNUserNotificationCenter
        guard let center = notificationCenter as? UNUserNotificationCenter else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert])
        } catch {
            return false
        }
    }

    func scheduleCheckInNotification(cadence: String, hour: Int, weekday: Int?) async {
        // Cancel existing check-in notifications first
        await cancelCheckInNotifications()

        // Enforce 24-hour rule and suppress during post-crisis (single DB read)
        guard await shouldAllowNotifications() else { return }

        // Check for active sprint — no sprint = no check-in notifications
        guard await hasActiveSprint() else { return }

        var dateComponents = DateComponents()
        dateComponents.hour = hour

        if cadence == "weekly", let weekday {
            dateComponents.weekday = weekday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Route through scheduler for cap enforcement if available
        if let scheduler {
            await scheduler.scheduleIfAllowed(type: .checkIn, trigger: trigger)
            return
        }

        // Fallback: schedule directly (backward compatibility)
        let content = UNMutableNotificationContent()
        content.title = ""
        content.body = "Your coach has a thought for you."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: Self.checkInIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Notification scheduling failed — non-critical
        }
    }

    func cancelCheckInNotifications() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.checkInIdentifier])
    }

    private func shouldAllowNotifications() async -> Bool {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            guard let profile else { return false }
            // 24-hour install rule
            guard Date().timeIntervalSince(profile.createdAt) >= 86400 else { return false }
            // Post-crisis suppression
            guard profile.lastSafetyBoundaryAt == nil else { return false }
            return true
        } catch {
            return false
        }
    }

    private func hasActiveSprint() async -> Bool {
        do {
            let sprint = try await databaseManager.dbPool.read { db in
                try Sprint.active().fetchOne(db)
            }
            return sprint != nil
        } catch {
            return false
        }
    }
}
