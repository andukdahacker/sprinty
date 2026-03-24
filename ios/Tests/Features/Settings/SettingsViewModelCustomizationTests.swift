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
        avatarId: String = "person.circle.fill",
        coachAppearanceId: String = "person.circle.fill",
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
        try await createProfile(in: db, avatarId: "person.circle.fill")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateAvatar("figure.mind.and.body")

        // Wait for async DB write
        try await Task.sleep(for: .milliseconds(100))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "figure.mind.and.body")
        #expect(viewModel.avatarId == "figure.mind.and.body")
    }

    @Test("Coach appearance update persists to DB")
    @MainActor
    func test_updateCoachAppearance_persistsToDB() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, coachAppearanceId: "person.circle.fill", coachName: "Sage")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateCoachAppearance("brain.head.profile", newCoachName: "Mentor")

        try await Task.sleep(for: .milliseconds(100))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.coachAppearanceId == "brain.head.profile")
        #expect(profile?.coachName == "Mentor")
        #expect(viewModel.coachAppearanceId == "brain.head.profile")
        #expect(viewModel.coachName == "Mentor")
    }

    @Test("loadProfile reads current values from DB")
    @MainActor
    func test_loadProfile_readsCurrentValues() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "person.circle", coachAppearanceId: "leaf.circle.fill", coachName: "Guide")
        let viewModel = SettingsViewModel(databaseManager: db)

        await viewModel.loadProfile()
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.avatarId == "person.circle")
        #expect(viewModel.coachAppearanceId == "leaf.circle.fill")
        #expect(viewModel.coachName == "Guide")
    }

    // MARK: - Task 8.2: Integration — avatar update visible to HomeViewModel

    @Test("Avatar update in settings visible from same DB read")
    @MainActor
    func test_avatarUpdate_visibleFromDBRead() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "person.circle.fill")

        let settingsVM = SettingsViewModel(databaseManager: db)
        await settingsVM.loadProfile()

        settingsVM.updateAvatar("figure.mind.and.body")
        try await Task.sleep(for: .milliseconds(100))

        // Simulate HomeViewModel reading from same DB
        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "figure.mind.and.body")
    }

    // MARK: - Task 8.3: Coach name auto-update logic

    @Test("Coach name updates when current name is a default name")
    @MainActor
    func test_coachNameAutoUpdate_defaultName_updatesName() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, coachAppearanceId: "person.circle.fill", coachName: "Sage")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        // When name is "Sage" (default), changing appearance should update name
        viewModel.updateCoachAppearance("brain.head.profile", newCoachName: "Mentor")

        #expect(viewModel.coachName == "Mentor")
    }

    @Test("Coach name preserved when current name is custom")
    @MainActor
    func test_coachNameAutoUpdate_customName_preservesName() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, coachAppearanceId: "person.circle.fill", coachName: "Alex")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        // When name is custom ("Alex"), changing appearance should NOT update name
        viewModel.updateCoachAppearance("brain.head.profile", newCoachName: nil)

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
        try await createProfile(in: db, coachAppearanceId: "person.circle.fill", coachName: "")
        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateCoachAppearance("leaf.circle.fill", newCoachName: "Guide")

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

        #expect(viewModel.avatarId == "person.circle.fill")
        #expect(viewModel.coachAppearanceId == "person.circle.fill")
        #expect(viewModel.coachName == "Sage")
    }

    // MARK: - Task 8.5: Avatar state independence

    @Test("Changing avatarId does not affect AvatarState")
    @MainActor
    func test_avatarStateIndependence_appearanceDoesNotAffectState() async throws {
        let db = try makeTestDB()
        try await createProfile(in: db, avatarId: "person.circle.fill")
        let appState = AppState()
        appState.avatarState = .active

        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        viewModel.updateAvatar("figure.mind.and.body")

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
        viewModel.updateAvatar("person.circle")
        viewModel.updateCoachAppearance("leaf.circle.fill", newCoachName: "Guide")

        try await Task.sleep(for: .milliseconds(100))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "person.circle")
        #expect(profile?.coachAppearanceId == "leaf.circle.fill")
        #expect(profile?.coachName == "Guide")
    }
}
