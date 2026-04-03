import Foundation
import UserNotifications
import GRDB

// MARK: - Protocol

protocol NotificationSchedulerProtocol: Sendable {
    func shouldSchedule(type: NotificationType) async -> Bool
    func scheduleIfAllowed(type: NotificationType, trigger: UNNotificationTrigger) async
    func removeAllScheduledNotifications() async
}

// MARK: - Implementation

final class NotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    private let notificationCenter: NotificationCenterScheduling
    private let databaseManager: DatabaseManager
    private let permissionChecker: @Sendable () async -> Bool
    static let dailyHardCap = 2

    init(
        databaseManager: DatabaseManager,
        notificationCenter: NotificationCenterScheduling = UNUserNotificationCenter.current(),
        permissionChecker: (@Sendable () async -> Bool)? = nil
    ) {
        self.databaseManager = databaseManager
        self.notificationCenter = notificationCenter
        if let permissionChecker {
            self.permissionChecker = permissionChecker
        } else {
            let center = notificationCenter
            self.permissionChecker = {
                let settings = await center.notificationSettings()
                return settings.authorizationStatus == .authorized
            }
        }
    }

    func shouldSchedule(type: NotificationType) async -> Bool {
        // Check notification permission
        guard await permissionChecker() else { return false }

        // Check suppression rules from profile
        guard await checkProfileRules(for: type) else { return false }

        // Check daily cap with priority ordering
        return await checkDailyCap(for: type).allowed
    }

    func scheduleIfAllowed(type: NotificationType, trigger: UNNotificationTrigger) async {
        guard await permissionChecker() else { return }
        guard await checkProfileRules(for: type) else { return }

        let capResult = await checkDailyCap(for: type)
        guard capResult.allowed else { return }

        // Displace lower-priority notification if needed to maintain hard cap
        if let displaced = capResult.displace {
            if let displacedType = NotificationType(rawValue: displaced.type) {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [displacedType.identifier])
            }
            try? await databaseManager.dbPool.write { db in
                _ = try NotificationDelivery.deleteOne(db, key: displaced.id)
            }
        }

        // Record in database for cap tracking
        let delivery = NotificationDelivery(
            id: UUID(),
            type: type.rawValue,
            scheduledAt: Date(),
            deliveredAt: nil,
            priority: type.priority
        )

        do {
            try await databaseManager.dbPool.write { db in
                try delivery.insert(db)
            }
        } catch {
            return
        }

        // Schedule the actual notification
        let content = type.content
        let request = UNNotificationRequest(
            identifier: type.identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Non-critical — clean up the delivery record
            try? await databaseManager.dbPool.write { db in
                _ = try NotificationDelivery.deleteOne(db, key: delivery.id)
            }
        }
    }

    func removeAllScheduledNotifications() async {
        let allIdentifiers = [
            NotificationType.checkIn.identifier,
            NotificationType.sprintMilestone.identifier,
            NotificationType.pauseSuggestion.identifier,
            NotificationType.reEngagement.identifier,
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

        // Clear today's delivery records to keep cap tracking accurate
        try? await databaseManager.dbPool.write { db in
            let startOfDay = Calendar.current.startOfDay(for: Date())
            try NotificationDelivery
                .filter(Column("scheduledAt") >= startOfDay)
                .deleteAll(db)
        }
    }

    // MARK: - Private

    private func checkProfileRules(for type: NotificationType) async -> Bool {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            guard let profile else { return false }

            // 24-hour install rule
            guard Date().timeIntervalSince(profile.createdAt) >= 86400 else { return false }

            // Post-crisis suppression
            guard profile.lastSafetyBoundaryAt == nil else { return false }

            // Pause Mode suppression
            guard !profile.isPaused else { return false }

            // Notification mute preference (safety-related types bypass)
            if !type.bypassesMute {
                guard !profile.notificationsMuted else { return false }
            }

            return true
        } catch {
            return false
        }
    }

    private func checkDailyCap(for type: NotificationType) async -> (allowed: Bool, displace: NotificationDelivery?) {
        do {
            return try await databaseManager.dbPool.read { db in
                let todayDeliveries = try NotificationDelivery.todayByPriority(in: db)
                let todayCount = todayDeliveries.count

                if todayCount < Self.dailyHardCap { return (true, nil) }

                guard let lowestPriority = todayDeliveries.last else { return (false, nil) }
                if type.priority < lowestPriority.priority {
                    return (true, lowestPriority)
                }
                return (false, nil)
            }
        } catch {
            return (false, nil)
        }
    }
}
