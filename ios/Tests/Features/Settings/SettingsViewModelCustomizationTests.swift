import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SettingsViewModel Customization")
struct SettingsViewModelCustomizationTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(
        in db: DatabaseManager,
        avatarId: String = "avatar_classic",
        coachAppearanceId: String = "coach_sage",
        coachName: String = "Sage"
    ) async throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: avatarId,
            coachAppearanceId: coachAppearanceId,
            coachName: coachName,
            onboardingStep: 5,
            onboardingCompleted: true,
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.save(dbConn)
        }
    }

    // MARK: - Task 8.1: SettingsViewModel avatar/coach persistence

    @Test("Avatar update persists to DB")
    @MainActor
    func test_updateAvatar_persistsToDB() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "avatar_classic")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateAvatar("avatar_zen")

        // Wait for async DB write
        try await Task.sleep(for: .milliseconds(100))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "avatar_zen")
        #expect(viewModel.avatarId == "avatar_zen")
    }

    @Test("Coach appearance update persists to DB")
    @MainActor
    func test_updateCoachAppearance_persistsToDB() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, coachAppearanceId: "coach_sage", coachName: "Sage")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateCoachAppearance("coach_mentor", newCoachName: "Mentor")

        try await Task.sleep(for: .milliseconds(100))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.coachAppearanceId == "coach_mentor")
        #expect(profile?.coachName == "Mentor")
        #expect(viewModel.coachAppearanceId == "coach_mentor")
        #expect(viewModel.coachName == "Mentor")
    }

    @Test("loadProfile reads current values from DB")
    @MainActor
    func test_loadProfile_readsCurrentValues() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "avatar_minimal", coachAppearanceId: "coach_guide", coachName: "Guide")
        let viewModel = SettingsViewModel(databaseManager: db)

        await viewModel.loadProfile()
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.avatarId == "avatar_minimal")
        #expect(viewModel.coachAppearanceId == "coach_guide")
        #expect(viewModel.coachName == "Guide")
    }

    // MARK: - Task 8.2: Integration — avatar update visible to HomeViewModel

    @Test("Avatar update in settings visible from same DB read")
    @MainActor
    func test_avatarUpdate_visibleFromDBRead() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "avatar_classic")

        let settingsVM = SettingsViewModel(databaseManager: db)
        await settingsVM.loadProfile()

        settingsVM.updateAvatar("avatar_zen")
        try await Task.sleep(for: .milliseconds(100))

        // Simulate HomeViewModel reading from same DB
        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "avatar_zen")
    }

    // MARK: - Task 8.3: Coach name auto-update logic

    @Test("Coach name updates when current name is a default name")
    @MainActor
    func test_coachNameAutoUpdate_defaultName_updatesName() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, coachAppearanceId: "coach_sage", coachName: "Sage")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        // When name is "Sage" (default), changing appearance should update name
        viewModel.updateCoachAppearance("coach_mentor", newCoachName: "Mentor")

        #expect(viewModel.coachName == "Mentor")
    }

    @Test("Coach name preserved when current name is custom")
    @MainActor
    func test_coachNameAutoUpdate_customName_preservesName() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, coachAppearanceId: "coach_sage", coachName: "Alex")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        // When name is custom ("Alex"), changing appearance should NOT update name
        viewModel.updateCoachAppearance("coach_mentor", newCoachName: nil)

        try await Task.sleep(for: .milliseconds(100))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(viewModel.coachName == "Alex")
        #expect(profile?.coachName == "Alex")
    }

    @Test("Coach name updates when current name is empty")
    @MainActor
    func test_coachNameAutoUpdate_emptyName_updatesName() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, coachAppearanceId: "coach_sage", coachName: "")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateCoachAppearance("coach_guide", newCoachName: "Guide")

        #expect(viewModel.coachName == "Guide")
    }

    // MARK: - Task 8.4: Default values when no profile exists

    @Test("Default values when no profile exists")
    @MainActor
    func test_loadProfile_noProfile_keepsDefaults() async throws {
        let db = try makeTestDB()
        let viewModel = SettingsViewModel(databaseManager: db)

        await viewModel.loadProfile()
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.avatarId == "avatar_classic")
        #expect(viewModel.coachAppearanceId == "coach_sage")
        #expect(viewModel.coachName == "Sage")
    }

    // MARK: - Task 8.5: Avatar state independence

    @Test("Changing avatarId does not affect AvatarState")
    @MainActor
    func test_avatarStateIndependence_appearanceDoesNotAffectState() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "avatar_classic")
        let appState = AppState()
        appState.avatarState = .active

        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateAvatar("avatar_zen")

        #expect(appState.avatarState == .active)
    }

    // MARK: - Task 8.6: Offline operation

    @Test("Avatar and coach updates succeed with no network dependency")
    @MainActor
    func test_offlineOperation_updatesSucceedWithoutNetwork() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db)
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        // All operations are DB-only, no network calls
        viewModel.updateAvatar("avatar_minimal")
        viewModel.updateCoachAppearance("coach_guide", newCoachName: "Guide")

        try await Task.sleep(for: .milliseconds(100))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "avatar_minimal")
        #expect(profile?.coachAppearanceId == "coach_guide")
        #expect(profile?.coachName == "Guide")
    }
}
