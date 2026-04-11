import Foundation

/// Applies the iCloud backup exclusion flag to the on-device SQLite database
/// file and its GRDB WAL/SHM sidecars.
///
/// Per Story 11.4 / NFR36, the user can opt out of including coaching data in
/// iCloud device backup. iOS does not propagate `isExcludedFromBackup` from a
/// SQLite file to its `-wal`/`-shm` siblings — each file must be flagged
/// individually or backups will still contain partial data.
///
/// The flag is a filesystem extended attribute
/// (`com.apple.metadata:com_apple_backup_excludeItem`) — it persists per-file
/// and survives app restarts, but is lost when the file is deleted and
/// recreated. `DatabaseManager.create()` re-applies the persisted preference
/// on every launch.
final class BackupPreferenceService: BackupPreferenceServiceProtocol, Sendable {
    private let mainDatabaseURL: URL

    init(mainDatabaseURL: URL) {
        self.mainDatabaseURL = mainDatabaseURL
    }

    /// Resolves the App Group container URL the same way `DatabaseManager.create()`
    /// does and constructs the production main-database URL.
    ///
    /// Returns `nil` only if the App Group container is unresolvable — an
    /// extreme entitlement-misconfiguration failure that would also break
    /// `DatabaseManager.create()`. Surfacing this as `nil` keeps the toggle
    /// a no-op rather than crashing the Settings flow; the upstream container
    /// failure will already have produced a higher-priority diagnostic.
    static func forAppGroupContainer() -> BackupPreferenceService? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            // structured logging placeholder — App Group container unresolvable;
            // backup preference toggle will be a no-op until container is fixed.
            return nil
        }
        let dbURL = containerURL.appendingPathComponent(Constants.databaseFilename)
        return BackupPreferenceService(mainDatabaseURL: dbURL)
    }

    func setExcludedFromBackup(_ excluded: Bool) throws {
        for url in sidecarURLs(for: mainDatabaseURL) {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            var mutableURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = excluded
            try mutableURL.setResourceValues(values)
        }
    }

    func isExcludedFromBackup() throws -> Bool {
        let values = try mainDatabaseURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values.isExcludedFromBackup ?? false
    }

    private func sidecarURLs(for mainURL: URL) -> [URL] {
        let parent = mainURL.deletingLastPathComponent()
        let baseName = mainURL.lastPathComponent
        let walURL = parent.appendingPathComponent("\(baseName)-wal")
        let shmURL = parent.appendingPathComponent("\(baseName)-shm")
        return [mainURL, walURL, shmURL]
    }
}
