import Foundation
import GRDB
import OSLog

struct ProfileEnricher: ProfileEnricherProtocol, Sendable {
    private let databaseManager: DatabaseManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "profile")

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func enrich(from summary: ConversationSummary) async throws {
        let domainTags = summary.decodedDomainTags
        guard !domainTags.isEmpty else { return }

        try await databaseManager.dbPool.write { db in
            guard var profile = try UserProfile.current().fetchOne(db) else {
                return
            }

            var states = profile.decodedDomainStates ?? [:]
            let now = ISO8601DateFormatter().string(from: Date())

            for tag in domainTags {
                if var existing = states[tag] {
                    let newCount = (existing.conversationCount ?? 0) + 1
                    existing = DomainState(
                        status: existing.status,
                        conversationCount: newCount,
                        lastUpdated: now
                    )
                    states[tag] = existing
                } else {
                    states[tag] = DomainState(
                        status: nil,
                        conversationCount: 1,
                        lastUpdated: now
                    )
                }
            }

            profile.domainStates = UserProfile.encodeDomainStates(states)
            profile.updatedAt = Date()
            try profile.update(db)

            logger.info("Profile enriched from summary with domains: \(domainTags.joined(separator: ", "))")
        }
    }
}
