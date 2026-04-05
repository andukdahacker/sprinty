import Foundation
import GRDB
import WidgetKit

/// Permanently deletes all user data from the app per FR61 / NFR14.
///
/// The full deletion sequence runs inside a single `dbPool.write { db in }`
/// transaction so either everything succeeds or nothing is partially deleted.
/// Before clearing tables, a final audit entry is written to
/// `SafetyComplianceLog` (per NFR15) — it is wiped along with the rest of the
/// log, which is acceptable for MVP (on-device compliance log only; full audit
/// preservation is a Phase 2 server-side concern).
final class DataDeletionService: DataDeletionServiceProtocol, Sendable {
    private let dbPool: DatabasePool
    private let keychainHelper: any KeychainHelperProtocol
    private let notificationScheduler: (any NotificationSchedulerProtocol)?
    nonisolated(unsafe) private let userDefaults: UserDefaults
    private let widgetReloader: @Sendable () -> Void

    /// Sentinel session identifier for the deletion audit entry. The
    /// compliance log schema requires a non-null `sessionId`, so we use an
    /// all-zero UUID as an "orphan" marker for events not tied to a
    /// particular conversation session.
    private static let deletionAuditSessionId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    init(
        dbPool: DatabasePool,
        keychainHelper: any KeychainHelperProtocol = KeychainHelper(),
        notificationScheduler: (any NotificationSchedulerProtocol)? = nil,
        userDefaults: UserDefaults = .standard,
        widgetReloader: (@Sendable () -> Void)? = nil
    ) {
        self.dbPool = dbPool
        self.keychainHelper = keychainHelper
        self.notificationScheduler = notificationScheduler
        self.userDefaults = userDefaults
        self.widgetReloader = widgetReloader ?? { WidgetCenter.shared.reloadAllTimelines() }
    }

    func deleteAllData() async throws {
        // Perform all SQLite mutations in a single transaction so either
        // everything succeeds or nothing is partially deleted.
        try await dbPool.write { db in
            // Step 1: write the deletion audit entry BEFORE clearing tables
            // so the structural pattern is preserved even though the entry
            // is wiped along with the rest of the compliance log below.
            let auditEntry = SafetyComplianceLog(
                id: UUID(),
                sessionId: Self.deletionAuditSessionId,
                timestamp: Date(),
                safetyLevel: .green,
                classificationSource: "data_deletion",
                eventType: "data_deletion",
                previousLevel: nil
            )
            try auditEntry.insert(db)

            // Step 2: delete all rows from the 9 GRDB record tables in
            // dependency order (children before parents). FTS5 delete
            // triggers (`message_fts_delete`) auto-clear `MessageFTS` rows
            // when Message rows are deleted.
            try Message.deleteAll(db)
            try ConversationSummary.deleteAll(db)
            try CheckIn.deleteAll(db)
            try SprintStep.deleteAll(db)
            try SafetyComplianceLog.deleteAll(db)
            try NotificationDelivery.deleteAll(db)
            try ConversationSession.deleteAll(db)
            try Sprint.deleteAll(db)
            try UserProfile.deleteAll(db)
        }

        // Keychain entries — clear device identity and auth token so the app
        // re-registers on next launch.
        keychainHelper.delete(key: Constants.keychainDeviceUUIDKey)
        keychainHelper.delete(key: Constants.keychainAuthJWTKey)

        // UserDefaults — clear the only known app-specific key.
        userDefaults.removeObject(forKey: "pendingSprintProposal")

        // Cancel any pending local notifications.
        await notificationScheduler?.removeAllScheduledNotifications()

        // Refresh widget timelines so they render empty/default state.
        widgetReloader()
    }
}
