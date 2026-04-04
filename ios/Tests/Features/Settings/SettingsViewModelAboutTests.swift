import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SettingsViewModel About")
struct SettingsViewModelAboutTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    @Test @MainActor
    func test_appVersion_returnsExpectedFormat() async throws {
        let db = try makeTestDB()
        let viewModel = SettingsViewModel(databaseManager: db)

        let version = viewModel.appVersion
        // Should be a string like "1.0" or "1.0.0" — not empty
        #expect(!version.isEmpty)
        // Should contain at least one dot (major.minor format)
        #expect(version.contains("."))
    }

    @Test @MainActor
    func test_buildNumber_returnsNonEmptyString() async throws {
        let db = try makeTestDB()
        let viewModel = SettingsViewModel(databaseManager: db)

        let build = viewModel.buildNumber
        #expect(!build.isEmpty)
    }

    @Test @MainActor
    func test_existingBehavior_loadProfile_setsDefaults() async throws {
        let db = try makeTestDB()
        let viewModel = SettingsViewModel(databaseManager: db)

        // Without a profile in DB, defaults should remain
        await viewModel.loadProfile()

        #expect(viewModel.avatarId == "avatar_classic")
        #expect(viewModel.coachAppearanceId == "coach_sage")
        #expect(viewModel.coachName == "Sage")
        #expect(viewModel.checkInCadence == "daily")
        #expect(viewModel.checkInTimeHour == 9)
        #expect(viewModel.notificationsMuted == false)
    }

    @Test @MainActor
    func test_existingBehavior_loadProfile_loadsFromDB() async throws {
        let db = try makeTestDB()

        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_zen",
            coachAppearanceId: "coach_nova",
            coachName: "Nova",
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

        let viewModel = SettingsViewModel(databaseManager: db)
        await viewModel.loadProfile()

        #expect(viewModel.avatarId == "avatar_zen")
        #expect(viewModel.coachAppearanceId == "coach_nova")
        #expect(viewModel.coachName == "Nova")
    }
}
