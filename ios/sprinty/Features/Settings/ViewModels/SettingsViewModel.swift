import Foundation
import GRDB
import WidgetKit

@MainActor
@Observable
final class SettingsViewModel {
    var showMemoryView = false
    var avatarId: String = "avatar_classic"
    var coachAppearanceId: String = "coach_sage"
    var coachName: String = "Sage"
    var checkInCadence: String = "daily"
    var checkInTimeHour: Int = 9
    var checkInWeekday: Int?
    var notificationsMuted: Bool = false
    var isExporting: Bool = false
    var exportError: AppError?
    var hasConversations: Bool = false
    var exportFileURL: URL?
    var exportSuccessMessage: String?
    var isDeletingData: Bool = false
    var deletionError: AppError?
    var showDeletionConfirmation: Bool = false
    var deletionConfirmationText: String = ""
    var dataDeletionCompleted: Bool = false

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    let databaseManager: DatabaseManager
    private let notificationService: CheckInNotificationServiceProtocol?
    private let notificationScheduler: NotificationSchedulerProtocol?
    private let exportService: ConversationExportServiceProtocol?
    private let dataDeletionService: DataDeletionServiceProtocol?
    private weak var appState: AppState?

    init(databaseManager: DatabaseManager, notificationService: CheckInNotificationServiceProtocol? = nil, notificationScheduler: NotificationSchedulerProtocol? = nil, exportService: ConversationExportServiceProtocol? = nil, dataDeletionService: DataDeletionServiceProtocol? = nil, appState: AppState? = nil) {
        self.databaseManager = databaseManager
        self.notificationService = notificationService
        self.notificationScheduler = notificationScheduler
        self.exportService = exportService
        self.dataDeletionService = dataDeletionService
        self.appState = appState
    }

    func loadProfile() async {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.fetchOne(db)
            }
            guard !Task.isCancelled else { return }
            if let profile {
                self.avatarId = profile.avatarId
                self.coachAppearanceId = profile.coachAppearanceId
                self.coachName = profile.coachName
                self.checkInCadence = profile.checkInCadence
                self.checkInTimeHour = profile.checkInTimeHour
                self.checkInWeekday = profile.checkInWeekday
                self.notificationsMuted = profile.notificationsMuted
            }
        } catch {
            // Profile not found — keep defaults
        }
    }

    func updateAvatar(_ newAvatarId: String) {
        avatarId = newAvatarId
        Task { [weak self] in
            guard let self else { return }
            do {
                try await databaseManager.dbPool.write { db in
                    if var profile = try UserProfile.fetchOne(db) {
                        profile.avatarId = newAvatarId
                        profile.updatedAt = Date()
                        try profile.update(db)
                    }
                }
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
    }

    func updateCoachAppearance(_ newAppearanceId: String, newCoachName: String?) {
        coachAppearanceId = newAppearanceId
        if let newCoachName {
            coachName = newCoachName
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await databaseManager.dbPool.write { db in
                    if var profile = try UserProfile.fetchOne(db) {
                        profile.coachAppearanceId = newAppearanceId
                        if let newCoachName {
                            profile.coachName = newCoachName
                        }
                        profile.updatedAt = Date()
                        try profile.update(db)
                    }
                }
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
    }
    func updateNotificationsMuted(_ muted: Bool) {
        notificationsMuted = muted
        Task { [weak self] in
            guard let self else { return }
            do {
                try await databaseManager.dbPool.write { db in
                    if var profile = try UserProfile.fetchOne(db) {
                        profile.notificationsMuted = muted
                        profile.updatedAt = Date()
                        try profile.update(db)
                    }
                }
                if muted {
                    await notificationScheduler?.removeAllScheduledNotifications()
                } else {
                    await notificationService?.rescheduleCheckIn(profile: nil)
                }
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
    }

    func updateCheckInWeekday(_ weekday: Int) {
        checkInWeekday = weekday
        Task { [weak self] in
            guard let self else { return }
            do {
                try await databaseManager.dbPool.write { db in
                    if var profile = try UserProfile.fetchOne(db) {
                        profile.checkInWeekday = weekday
                        profile.updatedAt = Date()
                        try profile.update(db)
                    }
                }
                await notificationService?.rescheduleCheckIn(profile: nil)
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
    }

    func updateCheckInCadence(_ newCadence: String) {
        checkInCadence = newCadence
        if newCadence == "weekly" && checkInWeekday == nil {
            checkInWeekday = Calendar.current.component(.weekday, from: Date())
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await databaseManager.dbPool.write { db in
                    if var profile = try UserProfile.fetchOne(db) {
                        profile.checkInCadence = newCadence
                        if newCadence == "weekly" && profile.checkInWeekday == nil {
                            profile.checkInWeekday = Calendar.current.component(.weekday, from: Date())
                        }
                        profile.updatedAt = Date()
                        try profile.update(db)
                    }
                }
                await notificationService?.rescheduleCheckIn(profile: nil)
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
    }

    func updateCheckInTime(_ newHour: Int) {
        checkInTimeHour = newHour
        Task { [weak self] in
            guard let self else { return }
            do {
                try await databaseManager.dbPool.write { db in
                    if var profile = try UserProfile.fetchOne(db) {
                        profile.checkInTimeHour = newHour
                        profile.updatedAt = Date()
                        try profile.update(db)
                    }
                }
                await notificationService?.rescheduleCheckIn(profile: nil)
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
    }
    // MARK: - Export

    func checkHasConversations() async {
        guard let exportService else { return }
        do {
            let result = try await exportService.hasConversations()
            guard !Task.isCancelled else { return }
            hasConversations = result
        } catch {
            hasConversations = false
        }
    }

    func exportConversations() async {
        guard let exportService else { return }
        isExporting = true
        exportError = nil
        defer { isExporting = false }
        do {
            let url = try await exportService.exportConversations()
            guard !Task.isCancelled else { return }
            exportFileURL = url
        } catch {
            guard !Task.isCancelled else { return }
            exportError = .databaseError(underlying: error)
        }
    }

    func dismissExportSuccess() {
        exportSuccessMessage = nil
    }

    // MARK: - Data Deletion

    func requestDataDeletion() {
        deletionError = nil
        deletionConfirmationText = ""
        showDeletionConfirmation = true
    }

    func cancelDeletion() {
        showDeletionConfirmation = false
        deletionConfirmationText = ""
    }

    func confirmDataDeletion() async {
        guard deletionConfirmationText == "DELETE" else { return }
        guard let dataDeletionService else { return }
        isDeletingData = true
        deletionError = nil
        defer { isDeletingData = false }
        do {
            try await dataDeletionService.deleteAllData()
            guard !Task.isCancelled else { return }
            dataDeletionCompleted = true
            resetAppStateToOnboarding()
        } catch {
            guard !Task.isCancelled else { return }
            deletionError = .databaseError(underlying: error)
        }
    }

    func resetAppStateToOnboarding() {
        guard let appState else { return }
        appState.isAuthenticated = false
        appState.needsReauth = false
        appState.onboardingCompleted = false
        appState.tier = .free
        appState.avatarState = .active
        appState.isPaused = false
        appState.pendingCheckIn = false
        appState.pendingEngagementSource = nil
        appState.showConversation = false
        appState.activeSprint = nil
        // Intentionally do NOT reset: isOnline, databaseManager, connectivityMonitor
    }
}

// MARK: - Preview Factory

#if DEBUG
extension SettingsViewModel {
    static func previewDB() -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("preview_\(UUID().uuidString).sqlite")
        let dbPool = try! DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try! migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }
}
#endif
