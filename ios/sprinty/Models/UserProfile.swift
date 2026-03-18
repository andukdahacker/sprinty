import Foundation
import GRDB

struct UserProfile: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    // --- Onboarding fields (Story 1.5) ---
    var avatarId: String
    var coachAppearanceId: String
    var coachName: String
    var onboardingStep: Int
    var onboardingCompleted: Bool
    // --- Architecture fields (populated in Story 3.3) ---
    var values: String?
    var goals: String?
    var personalityTraits: String?
    var domainStates: String?
    // --- Timestamps ---
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "UserProfile"
}

// MARK: - Query Extensions

extension UserProfile {
    static func current() -> QueryInterfaceRequest<UserProfile> {
        limit(1)
    }
}
