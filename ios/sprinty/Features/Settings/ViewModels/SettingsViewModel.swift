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

    let databaseManager: DatabaseManager
    private let notificationService: CheckInNotificationServiceProtocol?

    init(databaseManager: DatabaseManager, notificationService: CheckInNotificationServiceProtocol? = nil) {
        self.databaseManager = databaseManager
        self.notificationService = notificationService
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
    func updateCheckInCadence(_ newCadence: String) {
        checkInCadence = newCadence
        if newCadence == "weekly" && checkInWeekday == nil {
            checkInWeekday = Calendar.current.component(.weekday, from: Date())
        }
        let weekday = checkInWeekday
        let hour = checkInTimeHour
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
                await notificationService?.scheduleCheckInNotification(
                    cadence: newCadence,
                    hour: hour,
                    weekday: newCadence == "weekly" ? weekday : nil
                )
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
    }

    func updateCheckInTime(_ newHour: Int) {
        checkInTimeHour = newHour
        let cadence = checkInCadence
        let weekday = checkInWeekday
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
                await notificationService?.scheduleCheckInNotification(
                    cadence: cadence,
                    hour: newHour,
                    weekday: cadence == "weekly" ? weekday : nil
                )
            } catch {
                // Write failed — local state already updated for responsiveness
            }
        }
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
