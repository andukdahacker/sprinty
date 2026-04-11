import Foundation

/// Sets or reads the iCloud backup exclusion flag on the on-device SQLite
/// database (and its WAL/SHM sidecars) per Story 11.4 / NFR36.
protocol BackupPreferenceServiceProtocol: Sendable {
    func setExcludedFromBackup(_ excluded: Bool) throws
    func isExcludedFromBackup() throws -> Bool
}
