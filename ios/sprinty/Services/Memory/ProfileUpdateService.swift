import Foundation
import GRDB
import OSLog

struct ProfileUpdateService: ProfileUpdateServiceProtocol, Sendable {
    private let databaseManager: DatabaseManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "profile")

    private static let maxArrayItems = 20
    private static let maxDomains = 10
    private static let maxStringLength = 200
    private static let validDomainKeys: Set<String> = [
        "career", "relationships", "health", "finance",
        "personal-growth", "creativity", "education", "family"
    ]

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func applyUpdate(_ update: ProfileUpdate, to profileId: UUID) async throws {
        try await databaseManager.dbPool.write { db in
            guard var profile = try UserProfile.fetchOne(db, key: profileId) else {
                return
            }

            if let newValues = update.values {
                let existing = profile.decodedValues ?? []
                let merged = mergeAndDeduplicate(existing: existing, new: newValues, cap: Self.maxArrayItems)
                profile.values = UserProfile.encodeArray(merged)
            }

            if let newGoals = update.goals {
                let existing = profile.decodedGoals ?? []
                let merged = mergeAndDeduplicate(existing: existing, new: newGoals, cap: Self.maxArrayItems)
                profile.goals = UserProfile.encodeArray(merged)
            }

            if let newTraits = update.personalityTraits {
                let existing = profile.decodedPersonalityTraits ?? []
                let merged = mergeAndDeduplicate(existing: existing, new: newTraits, cap: Self.maxArrayItems)
                profile.personalityTraits = UserProfile.encodeArray(merged)
            }

            if let newDomainStates = update.domainStates {
                var existing = profile.decodedDomainStates ?? [:]
                for (key, state) in newDomainStates {
                    guard Self.validDomainKeys.contains(key) else { continue }
                    existing[key] = state
                }
                // Cap at maxDomains — keep existing entries, drop excess
                if existing.count > Self.maxDomains {
                    let keys = Array(existing.keys.prefix(Self.maxDomains))
                    existing = existing.filter { keys.contains($0.key) }
                }
                profile.domainStates = UserProfile.encodeDomainStates(existing)
            }

            if let corrections = update.corrections {
                for correction in corrections {
                    logger.info("Profile correction: \(correction)")
                }
            }

            profile.updatedAt = Date()
            try profile.update(db)

            logger.info("Profile updated for user \(profileId)")
        }
    }

    private func mergeAndDeduplicate(existing: [String], new: [String], cap: Int) -> [String] {
        var result = existing
        let existingLower = Set(existing.map { String($0.lowercased().prefix(Self.maxStringLength)) })
        for item in new {
            let truncated = String(item.prefix(Self.maxStringLength))
            if !existingLower.contains(truncated.lowercased()) {
                result.append(truncated)
            }
        }
        return Array(result.prefix(cap))
    }
}
