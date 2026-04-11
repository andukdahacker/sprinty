import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SettingsViewModel Backup Preference")
struct SettingsViewModelBackupTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func insertProfile(_ db: DatabaseManager, excludeFromICloudBackup: Bool = false) async throws {
        try await db.dbPool.write { db in
            let now = Date()
            let profile = UserProfile(
                id: UUID(),
                avatarId: "avatar_classic",
                coachAppearanceId: "coach_sage",
                coachName: "Sage",
                onboardingStep: 3,
                onboardingCompleted: true,
                excludeFromICloudBackup: excludeFromICloudBackup,
                createdAt: now,
                updatedAt: now
            )
            try profile.insert(db)
        }
    }

    // MARK: - loadProfile

    @Test @MainActor
    func test_loadProfile_populatesExcludeFromICloudBackup_true() async throws {
        let db = try makeTestDB()
        try await insertProfile(db, excludeFromICloudBackup: true)
        let vm = SettingsViewModel(databaseManager: db)

        await vm.loadProfile()

        #expect(vm.excludeFromICloudBackup == true)
    }

    @Test @MainActor
    func test_loadProfile_populatesExcludeFromICloudBackup_false() async throws {
        let db = try makeTestDB()
        try await insertProfile(db, excludeFromICloudBackup: false)
        let vm = SettingsViewModel(databaseManager: db)

        await vm.loadProfile()

        #expect(vm.excludeFromICloudBackup == false)
    }

    // MARK: - updateExcludeFromICloudBackup

    @Test @MainActor
    func test_updateExcludeFromICloudBackup_optimisticallyUpdatesLocalState() async throws {
        let db = try makeTestDB()
        try await insertProfile(db, excludeFromICloudBackup: false)
        let mockBackup = MockBackupPreferenceService()
        let vm = SettingsViewModel(
            databaseManager: db,
            backupPreferenceService: mockBackup
        )

        vm.updateExcludeFromICloudBackup(true)

        // Local state updates synchronously, before the Task runs.
        #expect(vm.excludeFromICloudBackup == true)
    }

    @Test @MainActor
    func test_updateExcludeFromICloudBackup_writesNewValueToUserProfile() async throws {
        let db = try makeTestDB()
        try await insertProfile(db, excludeFromICloudBackup: false)
        let mockBackup = MockBackupPreferenceService()
        let vm = SettingsViewModel(
            databaseManager: db,
            backupPreferenceService: mockBackup
        )

        // Deterministically wait for the spawned write task to complete.
        await vm.updateExcludeFromICloudBackup(true).value

        let stored = try await db.dbPool.read { db in
            try UserProfile.fetchOne(db)
        }
        #expect(stored?.excludeFromICloudBackup == true)
    }

    @Test @MainActor
    func test_updateExcludeFromICloudBackup_callsBackupPreferenceService() async throws {
        let db = try makeTestDB()
        try await insertProfile(db, excludeFromICloudBackup: false)
        let mockBackup = MockBackupPreferenceService()
        let vm = SettingsViewModel(
            databaseManager: db,
            backupPreferenceService: mockBackup
        )

        await vm.updateExcludeFromICloudBackup(true).value

        #expect(mockBackup.setCallCount == 1)
        #expect(mockBackup.lastSetValue == true)
    }

    @Test @MainActor
    func test_updateExcludeFromICloudBackup_handlesNilBackupServiceGracefully() async throws {
        let db = try makeTestDB()
        try await insertProfile(db, excludeFromICloudBackup: false)
        let vm = SettingsViewModel(databaseManager: db) // no backupPreferenceService

        await vm.updateExcludeFromICloudBackup(true).value

        // Local state and DB are still updated even when the file-flag service is nil.
        #expect(vm.excludeFromICloudBackup == true)
        let stored = try await db.dbPool.read { db in
            try UserProfile.fetchOne(db)
        }
        #expect(stored?.excludeFromICloudBackup == true)
    }
}
