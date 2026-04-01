import Foundation
import UserNotifications
import GRDB

// MARK: - Notification Center Protocol

protocol NotificationCenterScheduling: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterScheduling {}

// MARK: - Configuration

struct DriftDetectionConfig: Sendable {
    let inactivityThresholdHours: Int

    init(inactivityThresholdHours: Int = 72) {
        self.inactivityThresholdHours = inactivityThresholdHours
    }

    var inactivityThresholdSeconds: TimeInterval {
        TimeInterval(inactivityThresholdHours * 3600)
    }
}

// MARK: - Protocol

protocol DriftDetectionServiceProtocol: Sendable {
    func evaluateAndSchedule() async
    func evaluateAndSchedule(autonomyLevel: AutonomyLevel) async
    func cancelReEngagementNudge() async
}

// MARK: - Implementation

final class DriftDetectionService: DriftDetectionServiceProtocol, @unchecked Sendable {
    private let notificationCenter: NotificationCenterScheduling
    private let databaseManager: DatabaseManager
    let config: DriftDetectionConfig

    static let reEngagementIdentifier = "com.ducdo.sprinty.reengagement"

    init(
        databaseManager: DatabaseManager,
        config: DriftDetectionConfig = DriftDetectionConfig(),
        notificationCenter: NotificationCenterScheduling = UNUserNotificationCenter.current()
    ) {
        self.databaseManager = databaseManager
        self.config = config
        self.notificationCenter = notificationCenter
    }

    func evaluateAndSchedule() async {
        await evaluateAndSchedule(autonomyLevel: .none)
    }

    func evaluateAndSchedule(autonomyLevel: AutonomyLevel) async {
        // Cancel any existing re-engagement nudge first
        await cancelReEngagementNudge()

        guard let (lastSessionDate, profile) = await readState() else { return }
        guard let profile else { return }

        // 24-hour install rule
        guard Date().timeIntervalSince(profile.createdAt) >= 86400 else { return }

        // Healthy pause — no nudges during pause
        guard !profile.isPaused else { return }

        // Post-crisis suppression
        guard profile.lastSafetyBoundaryAt == nil else { return }

        // No sessions yet — new user, don't nudge
        guard let lastSessionDate else { return }

        // Autonomy-adjusted threshold
        let thresholdSeconds = Self.autonomyAdjustedThreshold(
            baseThresholdSeconds: config.inactivityThresholdSeconds,
            autonomyLevel: autonomyLevel
        )

        // Arm dead-man's-switch: schedule nudge for (threshold - gap) seconds from now.
        // If gap already exceeds threshold, use minimum delay (user already drifted;
        // nudge fires shortly to catch the next drift period if they leave again).
        let gap = Date().timeIntervalSince(lastSessionDate)
        let timeUntilNudge = max(60, thresholdSeconds - gap)
        await scheduleReEngagementNudge(timeInterval: timeUntilNudge)
    }

    static func autonomyAdjustedThreshold(baseThresholdSeconds: TimeInterval, autonomyLevel: AutonomyLevel) -> TimeInterval {
        switch autonomyLevel {
        case .none: return baseThresholdSeconds
        case .light: return max(baseThresholdSeconds, TimeInterval(96 * 3600))
        case .moderate: return max(baseThresholdSeconds, TimeInterval(120 * 3600))
        case .high: return max(baseThresholdSeconds, TimeInterval(168 * 3600))
        }
    }

    // MARK: - Private

    private func scheduleReEngagementNudge(timeInterval: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = ""
        content.body = "Your coach has a thought for you."
        content.sound = nil

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: Self.reEngagementIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Notification scheduling failed — non-critical
        }
    }

    func cancelReEngagementNudge() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.reEngagementIdentifier])
    }

    private func readState() async -> (Date?, UserProfile?)? {
        do {
            let result = try await databaseManager.dbPool.read { db in
                let session = try ConversationSession.recent(limit: 1).fetchOne(db)
                let profile = try UserProfile.current().fetchOne(db)
                return (session?.startedAt, profile)
            }
            return result
        } catch {
            return nil
        }
    }
}
