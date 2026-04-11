import Foundation
import GRDB

final class DatabaseManager: Sendable {
    let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    static func create() throws -> DatabaseManager {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            throw AppError.databaseError(
                underlying: NSError(
                    domain: "DatabaseManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "App Group container not available"]
                )
            )
        }

        let dbURL = containerURL.appendingPathComponent(Constants.databaseFilename)

        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: containerURL.path
        )

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            db.trace { /* structured logging placeholder */ _ in }
        }

        let dbPool = try DatabasePool(path: dbURL.path, configuration: configuration)

        try applyFileProtection(to: dbURL)

        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)

        // Story 11.4: Reconcile the user's iCloud backup exclusion preference
        // on every launch in BOTH directions. The filesystem flag does NOT
        // survive file recreation, GRDB -wal/-shm sidecars created during
        // runtime need the flag too, and a previously-flagged file must be
        // cleared if the user toggled off (or completed Story 11.3 data
        // deletion → re-onboarding with the default `false`). Failures are
        // silently ignored so backup-flag errors never block app startup.
        if let profile = try? dbPool.read({ db in try UserProfile.fetchOne(db) }) {
            do {
                try BackupPreferenceService.forAppGroupContainer()?
                    .setExcludedFromBackup(profile.excludeFromICloudBackup)
            } catch {
                // structured logging placeholder — backup-flag failures are
                // non-fatal; the next launch (or a user toggle) will retry.
            }
        }

        return DatabaseManager(dbPool: dbPool)
    }

    private static func applyFileProtection(to url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }
}
