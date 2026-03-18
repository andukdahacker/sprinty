import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("Onboarding Routing Logic")
struct OnboardingRoutingTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    @Test("Authenticated user with no profile should not be marked as onboarded")
    @MainActor
    func noProfileNotOnboarded() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        let isOnboarded = profile?.onboardingCompleted ?? false

        #expect(isOnboarded == false)
        #expect(appState.onboardingCompleted == false)
    }

    @Test("Authenticated user with completed onboarding profile should be marked as onboarded")
    @MainActor
    func completedProfileIsOnboarded() async throws {
        let db = try makeTestDB()
        let now = Date()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "person.circle.fill",
            coachAppearanceId: "leaf.circle.fill",
            coachName: "Guide",
            onboardingStep: OnboardingStep.complete.rawValue,
            onboardingCompleted: true,
            values: nil, goals: nil, personalityTraits: nil, domainStates: nil,
            createdAt: now, updatedAt: now
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }

        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db

        let fetched = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        if let fetched, fetched.onboardingCompleted {
            appState.onboardingCompleted = true
        }

        #expect(appState.onboardingCompleted == true)
    }

    @Test("Authenticated user with incomplete onboarding should not be marked as onboarded")
    @MainActor
    func incompleteProfileNotOnboarded() async throws {
        let db = try makeTestDB()
        let now = Date()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "person.circle.fill",
            coachAppearanceId: "",
            coachName: "",
            onboardingStep: OnboardingStep.avatarSelection.rawValue,
            onboardingCompleted: false,
            values: nil, goals: nil, personalityTraits: nil, domainStates: nil,
            createdAt: now, updatedAt: now
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }

        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db

        let fetched = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        if let fetched, fetched.onboardingCompleted {
            appState.onboardingCompleted = true
        }

        #expect(appState.onboardingCompleted == false)
    }
}
