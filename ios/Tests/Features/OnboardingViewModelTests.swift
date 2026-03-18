import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    @MainActor
    private func makeViewModel(dbManager: DatabaseManager? = nil) throws -> (OnboardingViewModel, DatabaseManager, AppState) {
        let db = try dbManager ?? makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        let viewModel = OnboardingViewModel(appState: appState, databaseManager: db)
        return (viewModel, db, appState)
    }

    @Test("Initial step is welcome")
    @MainActor
    func initialStep() throws {
        let (viewModel, _, _) = try makeViewModel()
        #expect(viewModel.currentStep == .welcome)
    }

    @Test("Advance from welcome persists avatarSelection step to DB")
    @MainActor
    func advanceFromWelcome() async throws {
        let (viewModel, db, _) = try makeViewModel()
        await viewModel.advanceFromWelcome()

        #expect(viewModel.currentStep == .avatarSelection)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile != nil)
        #expect(profile?.onboardingStep == OnboardingStep.avatarSelection.rawValue)
    }

    @Test("Select and confirm avatar persists to DB and advances to coachSelection")
    @MainActor
    func confirmAvatar() async throws {
        let (viewModel, db, _) = try makeViewModel()
        await viewModel.advanceFromWelcome()

        viewModel.selectAvatar("figure.mind.and.body")
        await viewModel.confirmAvatar()

        #expect(viewModel.currentStep == .coachSelection)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "figure.mind.and.body")
        #expect(profile?.onboardingStep == OnboardingStep.coachSelection.rawValue)
    }

    @Test("Confirm avatar does nothing without selection")
    @MainActor
    func confirmAvatarWithoutSelection() async throws {
        let (viewModel, _, _) = try makeViewModel()
        await viewModel.advanceFromWelcome()
        await viewModel.confirmAvatar()

        #expect(viewModel.currentStep == .avatarSelection)
    }

    @Test("Select and confirm coach persists to DB and advances to complete")
    @MainActor
    func confirmCoach() async throws {
        let (viewModel, db, _) = try makeViewModel()
        await viewModel.advanceFromWelcome()
        viewModel.selectAvatar("person.circle.fill")
        await viewModel.confirmAvatar()

        viewModel.selectCoachAppearance("leaf.circle.fill")
        viewModel.updateCoachName("Guide")
        await viewModel.confirmCoach()

        #expect(viewModel.currentStep == .complete)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.coachAppearanceId == "leaf.circle.fill")
        #expect(profile?.coachName == "Guide")
        #expect(profile?.onboardingStep == OnboardingStep.complete.rawValue)
    }

    @Test("Confirm coach does nothing without appearance selection")
    @MainActor
    func confirmCoachWithoutAppearance() async throws {
        let (viewModel, _, _) = try makeViewModel()
        await viewModel.advanceFromWelcome()
        viewModel.selectAvatar("person.circle.fill")
        await viewModel.confirmAvatar()
        await viewModel.confirmCoach()

        #expect(viewModel.currentStep == .coachSelection)
    }

    @Test("Confirm coach does nothing with empty name")
    @MainActor
    func confirmCoachWithEmptyName() async throws {
        let (viewModel, _, _) = try makeViewModel()
        await viewModel.advanceFromWelcome()
        viewModel.selectAvatar("person.circle.fill")
        await viewModel.confirmAvatar()

        viewModel.selectCoachAppearance("leaf.circle.fill")
        viewModel.updateCoachName("   ")
        await viewModel.confirmCoach()

        #expect(viewModel.currentStep == .coachSelection)
    }

    @Test("Complete onboarding sets appState.onboardingCompleted and persists")
    @MainActor
    func completeOnboarding() async throws {
        let (viewModel, db, appState) = try makeViewModel()
        await viewModel.advanceFromWelcome()
        viewModel.selectAvatar("person.circle.fill")
        await viewModel.confirmAvatar()
        viewModel.selectCoachAppearance("person.circle.fill")
        await viewModel.confirmCoach()
        await viewModel.completeOnboarding()

        #expect(appState.onboardingCompleted == true)

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.onboardingCompleted == true)
    }

    @Test("Resume from last step restores avatar selection step")
    @MainActor
    func resumeFromAvatarStep() async throws {
        let db = try makeTestDB()

        // Simulate a profile saved at avatar selection step
        let now = Date()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "",
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

        let (viewModel, _, _) = try makeViewModel(dbManager: db)
        await viewModel.resumeFromLastStep()

        #expect(viewModel.currentStep == .avatarSelection)
    }

    @Test("Resume from last step restores coach selection step with saved data")
    @MainActor
    func resumeFromCoachStep() async throws {
        let db = try makeTestDB()

        let now = Date()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "figure.mind.and.body",
            coachAppearanceId: "",
            coachName: "",
            onboardingStep: OnboardingStep.coachSelection.rawValue,
            onboardingCompleted: false,
            values: nil, goals: nil, personalityTraits: nil, domainStates: nil,
            createdAt: now, updatedAt: now
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }

        let (viewModel, _, _) = try makeViewModel(dbManager: db)
        await viewModel.resumeFromLastStep()

        #expect(viewModel.currentStep == .coachSelection)
        #expect(viewModel.selectedAvatarId == "figure.mind.and.body")
    }

    @Test("Resume from completed onboarding sets complete step")
    @MainActor
    func resumeFromCompleted() async throws {
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

        let (viewModel, _, _) = try makeViewModel(dbManager: db)
        await viewModel.resumeFromLastStep()

        #expect(viewModel.currentStep == .complete)
        #expect(viewModel.coachName == "Guide")
    }

    @Test("Resume with no profile stays at welcome")
    @MainActor
    func resumeNoProfile() async throws {
        let (viewModel, _, _) = try makeViewModel()
        await viewModel.resumeFromLastStep()

        #expect(viewModel.currentStep == .welcome)
    }
}
