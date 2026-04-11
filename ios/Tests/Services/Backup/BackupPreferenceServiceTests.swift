import Testing
import Foundation
@testable import sprinty

@Suite("BackupPreferenceService")
struct BackupPreferenceServiceTests {

    // MARK: - Fixtures

    /// Creates a unique temp directory and returns (mainURL, walURL, shmURL).
    /// The main file is created on disk; sidecar files are NOT created here —
    /// individual tests opt in to creating them.
    private func makeTempDatabaseFiles() throws -> (mainURL: URL, walURL: URL, shmURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let mainURL = tempDir.appendingPathComponent("sprinty.sqlite")
        let walURL = tempDir.appendingPathComponent("sprinty.sqlite-wal")
        let shmURL = tempDir.appendingPathComponent("sprinty.sqlite-shm")

        // Real on-disk file is required — URLResourceValues.isExcludedFromBackup
        // operates on filesystem extended attributes.
        #expect(FileManager.default.createFile(atPath: mainURL.path, contents: Data()))

        return (mainURL, walURL, shmURL)
    }

    private func cleanup(_ url: URL) {
        let parent = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parent)
    }

    private func isExcluded(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values.isExcludedFromBackup ?? false
    }

    // MARK: - setExcludedFromBackup(true)

    @Test
    func test_setExcludedFromBackup_true_setsFlagOnMainFile() throws {
        let (mainURL, _, _) = try makeTempDatabaseFiles()
        defer { cleanup(mainURL) }
        let service = BackupPreferenceService(mainDatabaseURL: mainURL)

        try service.setExcludedFromBackup(true)

        #expect(try isExcluded(mainURL) == true)
    }

    @Test
    func test_setExcludedFromBackup_false_clearsPreviouslySetFlag() throws {
        let (mainURL, _, _) = try makeTempDatabaseFiles()
        defer { cleanup(mainURL) }
        let service = BackupPreferenceService(mainDatabaseURL: mainURL)

        try service.setExcludedFromBackup(true)
        try service.setExcludedFromBackup(false)

        #expect(try isExcluded(mainURL) == false)
    }

    @Test
    func test_setExcludedFromBackup_isIdempotent() throws {
        let (mainURL, _, _) = try makeTempDatabaseFiles()
        defer { cleanup(mainURL) }
        let service = BackupPreferenceService(mainDatabaseURL: mainURL)

        try service.setExcludedFromBackup(true)
        try service.setExcludedFromBackup(true)

        #expect(try isExcluded(mainURL) == true)
    }

    @Test
    func test_setExcludedFromBackup_flagsExistingWalAndShmSidecars() throws {
        let (mainURL, walURL, shmURL) = try makeTempDatabaseFiles()
        defer { cleanup(mainURL) }
        #expect(FileManager.default.createFile(atPath: walURL.path, contents: Data()))
        #expect(FileManager.default.createFile(atPath: shmURL.path, contents: Data()))
        let service = BackupPreferenceService(mainDatabaseURL: mainURL)

        try service.setExcludedFromBackup(true)

        #expect(try isExcluded(mainURL) == true)
        #expect(try isExcluded(walURL) == true)
        #expect(try isExcluded(shmURL) == true)
    }

    @Test
    func test_setExcludedFromBackup_skipsMissingSidecarsWithoutThrowing() throws {
        let (mainURL, _, _) = try makeTempDatabaseFiles()
        defer { cleanup(mainURL) }
        let service = BackupPreferenceService(mainDatabaseURL: mainURL)

        // Sidecar -wal/-shm files do NOT exist — should still succeed.
        try service.setExcludedFromBackup(true)

        #expect(try isExcluded(mainURL) == true)
    }

    // MARK: - isExcludedFromBackup

    @Test
    func test_isExcludedFromBackup_returnsFalseForUnflaggedFile() throws {
        let (mainURL, _, _) = try makeTempDatabaseFiles()
        defer { cleanup(mainURL) }
        let service = BackupPreferenceService(mainDatabaseURL: mainURL)

        #expect(try service.isExcludedFromBackup() == false)
    }

    @Test
    func test_isExcludedFromBackup_returnsTrueAfterSet() throws {
        let (mainURL, _, _) = try makeTempDatabaseFiles()
        defer { cleanup(mainURL) }
        let service = BackupPreferenceService(mainDatabaseURL: mainURL)

        try service.setExcludedFromBackup(true)

        #expect(try service.isExcludedFromBackup() == true)
    }
}
