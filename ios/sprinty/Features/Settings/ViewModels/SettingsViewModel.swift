import Foundation
import GRDB
import WidgetKit

@MainActor
@Observable
final class SettingsViewModel {
    var showMemoryView = false
    var avatarId: String = "person.circle.fill"
    var coachAppearanceId: String = "person.circle.fill"
    var coachName: String = "Sage"

    let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
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
