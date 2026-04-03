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
    // --- Check-in settings (Story 5.4) ---
    var checkInCadence: String = "daily"
    var checkInTimeHour: Int = 9
    var checkInWeekday: Int?
    // --- Safety (Story 6.3) ---
    var lastSafetyBoundaryAt: Date?
    // --- Pause (Story 7.1) ---
    var isPaused: Bool = false
    var pausedAt: Date?
    // --- Notification preferences (Story 9.3) ---
    var notificationsMuted: Bool = false
    // --- Timestamps ---
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "UserProfile"
}

// MARK: - JSON Decode/Encode Helpers

extension UserProfile {
    var decodedValues: [String]? {
        guard let raw = values,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        return decoded
    }

    var decodedGoals: [String]? {
        guard let raw = goals,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        return decoded
    }

    var decodedPersonalityTraits: [String]? {
        guard let raw = personalityTraits,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        return decoded
    }

    var decodedDomainStates: [String: DomainState]? {
        guard let raw = domainStates,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: DomainState].self, from: data)
        else { return nil }
        return decoded
    }

    static func encodeArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func encodeDomainStates(_ states: [String: DomainState]) -> String {
        guard let data = try? JSONEncoder().encode(states) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Query Extensions

extension UserProfile {
    static func current() -> QueryInterfaceRequest<UserProfile> {
        limit(1)
    }
}
