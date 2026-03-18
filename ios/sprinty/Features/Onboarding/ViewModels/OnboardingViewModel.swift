import Foundation
import Observation
import GRDB

enum OnboardingStep: Int, Sendable {
    case welcome = 0
    case avatarSelection = 1
    case coachSelection = 2
    case complete = 3
}

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var selectedAvatarId: String?
    var selectedCoachAppearanceId: String?
    var coachName: String = "Sage"

    private let appState: AppState
    private let databaseManager: DatabaseManager
    private var profileId: UUID?

    init(appState: AppState, databaseManager: DatabaseManager) {
        self.appState = appState
        self.databaseManager = databaseManager
    }

    func resumeFromLastStep() async {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            if let profile {
                profileId = profile.id
                selectedAvatarId = profile.avatarId.isEmpty ? nil : profile.avatarId
                selectedCoachAppearanceId = profile.coachAppearanceId.isEmpty ? nil : profile.coachAppearanceId
                coachName = profile.coachName.isEmpty ? "Sage" : profile.coachName

                if profile.onboardingCompleted {
                    currentStep = .complete
                } else {
                    currentStep = OnboardingStep(rawValue: profile.onboardingStep) ?? .welcome
                }
            }
        } catch {
            handleError(error)
        }
    }

    func advanceFromWelcome() async {
        await persistStep(.avatarSelection)
    }

    func selectAvatar(_ avatarId: String) {
        selectedAvatarId = avatarId
    }

    func confirmAvatar() async {
        guard let avatarId = selectedAvatarId else { return }
        do {
            var profile = try await getOrCreateProfile()
            profile.avatarId = avatarId
            profile.onboardingStep = OnboardingStep.coachSelection.rawValue
            profile.updatedAt = Date()
            let updated = profile
            try await databaseManager.dbPool.write { db in
                try updated.update(db)
            }
            currentStep = .coachSelection
        } catch {
            handleError(error)
        }
    }

    func selectCoachAppearance(_ appearanceId: String) {
        selectedCoachAppearanceId = appearanceId
    }

    func updateCoachName(_ name: String) {
        coachName = name
    }

    func confirmCoach() async {
        guard let appearanceId = selectedCoachAppearanceId else { return }
        let name = coachName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            var profile = try await getOrCreateProfile()
            profile.coachAppearanceId = appearanceId
            profile.coachName = name
            profile.onboardingStep = OnboardingStep.complete.rawValue
            profile.updatedAt = Date()
            let updated = profile
            try await databaseManager.dbPool.write { db in
                try updated.update(db)
            }
            currentStep = .complete
        } catch {
            handleError(error)
        }
    }

    func completeOnboarding() async {
        do {
            var profile = try await getOrCreateProfile()
            profile.onboardingCompleted = true
            profile.updatedAt = Date()
            let updated = profile
            try await databaseManager.dbPool.write { db in
                try updated.update(db)
            }
            appState.onboardingCompleted = true
        } catch {
            handleError(error)
        }
    }

    private func getOrCreateProfile() async throws -> UserProfile {
        if let existingId = profileId {
            let existing = try await databaseManager.dbPool.read { db in
                try UserProfile.fetchOne(db, key: existingId)
            }
            if let existing { return existing }
        }

        let existing = try await databaseManager.dbPool.read { db in
            try UserProfile.current().fetchOne(db)
        }
        if let existing {
            profileId = existing.id
            return existing
        }

        let now = Date()
        let newProfile = UserProfile(
            id: UUID(),
            avatarId: "",
            coachAppearanceId: "",
            coachName: "",
            onboardingStep: 0,
            onboardingCompleted: false,
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            createdAt: now,
            updatedAt: now
        )
        try await databaseManager.dbPool.write { db in
            try newProfile.insert(db)
        }
        profileId = newProfile.id
        return newProfile
    }

    private func persistStep(_ step: OnboardingStep) async {
        do {
            var profile = try await getOrCreateProfile()
            profile.onboardingStep = step.rawValue
            profile.updatedAt = Date()
            let updated = profile
            try await databaseManager.dbPool.write { db in
                try updated.update(db)
            }
            currentStep = step
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            switch appError {
            case .authExpired:
                appState.needsReauth = true
            case .networkUnavailable:
                appState.isOnline = false
            default:
                break
            }
        }
    }
}
