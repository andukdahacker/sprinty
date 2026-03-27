import Foundation
import UserNotifications
import GRDB

protocol CheckInNotificationServiceProtocol: Sendable {
    func scheduleCheckInNotification(cadence: String, hour: Int, weekday: Int?) async
    func cancelCheckInNotifications() async
    func requestPermissionIfNeeded() async -> Bool
}

final class CheckInNotificationService: CheckInNotificationServiceProtocol, @unchecked Sendable {
    private let notificationCenter: UNUserNotificationCenter
    private let databaseManager: DatabaseManager

    static let checkInIdentifier = "com.ducdo.sprinty.checkin"

    init(databaseManager: DatabaseManager, notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
        self.databaseManager = databaseManager
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert])
        } catch {
            return false
        }
    }

    func scheduleCheckInNotification(cadence: String, hour: Int, weekday: Int?) async {
        // Cancel existing check-in notifications first
        await cancelCheckInNotifications()

        // Enforce 24-hour no-notification rule
        guard await isInstallOlderThan24Hours() else { return }

        // Check for active sprint — no sprint = no check-in notifications
        guard await hasActiveSprint() else { return }

        // Check Pause Mode
        // Note: Pause Mode check should be done at the call site (AppState is @MainActor)
        // The caller should not call this when isPaused is true

        var dateComponents = DateComponents()
        dateComponents.hour = hour

        if cadence == "weekly", let weekday {
            dateComponents.weekday = weekday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = ""
        content.body = "Your coach has a thought for you."
        content.sound = nil // Silent notification

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

    private func isInstallOlderThan24Hours() async -> Bool {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            guard let profile else { return false }
            return Date().timeIntervalSince(profile.createdAt) >= 86400
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
