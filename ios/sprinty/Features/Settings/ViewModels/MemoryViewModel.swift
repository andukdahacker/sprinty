import Foundation
import GRDB
import OSLog

@MainActor
@Observable
final class MemoryViewModel {
    var profileFacts: [ProfileFact] = []
    var memories: [MemoryItem] = []
    var domainTags: [String] = []
    var isEmpty: Bool = false
    var isLoading: Bool = false
    var localError: AppError?

    private let databaseManager: DatabaseManager
    private let embeddingPipeline: EmbeddingPipelineProtocol?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory-view")

    init(databaseManager: DatabaseManager, embeddingPipeline: EmbeddingPipelineProtocol? = nil) {
        self.databaseManager = databaseManager
        self.embeddingPipeline = embeddingPipeline
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }

            let summaryRows: [(summary: ConversationSummary, rowid: Int64)] = try await databaseManager.dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT rowid, * FROM ConversationSummary ORDER BY createdAt DESC")
                return rows.compactMap { row in
                    guard let summary = try? ConversationSummary(row: row),
                          let rowid = row["rowid"] as Int64? else { return nil }
                    return (summary: summary, rowid: rowid)
                }
            }

            guard !Task.isCancelled else { return }
            profileFacts = mapProfileToFacts(profile)
            memories = summaryRows.map { mapSummaryToMemoryItem($0.summary, rowid: $0.rowid) }
            domainTags = aggregateDomainTags(summaryRows.map { $0.summary })
            isEmpty = profileFacts.isEmpty && memories.isEmpty
        } catch {
            localError = .databaseError(underlying: error)
        }
    }

    // MARK: - Profile Fact Editing (Task 2)

    func updateProfileFact(_ fact: ProfileFact, newValue: String) async {
        do {
            try await databaseManager.dbPool.write { db in
                guard var profile = try UserProfile.current().fetchOne(db) else { return }
                self.applyFactUpdate(&profile, fact: fact, newValue: newValue)
                profile.updatedAt = Date()
                try profile.update(db)
            }
            guard !Task.isCancelled else { return }
            await load()
        } catch {
            localError = .databaseError(underlying: error)
        }
    }

    func deleteProfileFact(_ fact: ProfileFact) async {
        do {
            try await databaseManager.dbPool.write { db in
                guard var profile = try UserProfile.current().fetchOne(db) else { return }
                self.applyFactDeletion(&profile, fact: fact)
                profile.updatedAt = Date()
                try profile.update(db)
            }
            guard !Task.isCancelled else { return }
            await load()
        } catch {
            localError = .databaseError(underlying: error)
        }
    }

    // MARK: - Memory Deletion (Task 3)

    func deleteMemory(_ memory: MemoryItem) async {
        do {
            // Delete vector first — if this fails, DB record stays intact (no phantom RAG results).
            // Two separate SQLite databases prevent true single-transaction atomicity.
            if let pipeline = embeddingPipeline {
                try await pipeline.deleteEmbedding(summaryRowid: memory.rowid)
            }
            try await databaseManager.dbPool.write { db in
                try ConversationSummary.deleteOne(db, key: memory.id)
            }
            guard !Task.isCancelled else { return }
            await load()
        } catch {
            localError = .databaseError(underlying: error)
        }
    }

    // MARK: - Domain Tag Removal (Task 4)

    func removeDomainTag(_ tag: String) async {
        do {
            try await databaseManager.dbPool.write { db in
                let summaries = try ConversationSummary.forDomainTag(tag).fetchAll(db)
                for var summary in summaries {
                    var tags = summary.decodedDomainTags
                    tags.removeAll { $0 == tag }
                    summary.domainTags = ConversationSummary.encodeArray(tags)
                    try summary.update(db)
                }
            }
            guard !Task.isCancelled else { return }
            await load()
        } catch {
            localError = .databaseError(underlying: error)
        }
    }

    // MARK: - Mapping Helpers

    private func mapProfileToFacts(_ profile: UserProfile?) -> [ProfileFact] {
        guard let profile else { return [] }
        var facts: [ProfileFact] = []

        facts.append(ProfileFact(
            id: "coachName",
            category: "Coach Name",
            displayLabel: "Your coach's name",
            value: profile.coachName
        ))

        if let values = profile.decodedValues {
            for (i, value) in values.enumerated() {
                facts.append(ProfileFact(
                    id: "values-\(i)",
                    category: "Values",
                    displayLabel: "Something you value",
                    value: value
                ))
            }
        }

        if let goals = profile.decodedGoals {
            for (i, goal) in goals.enumerated() {
                facts.append(ProfileFact(
                    id: "goals-\(i)",
                    category: "Goals",
                    displayLabel: "A goal you're working toward",
                    value: goal
                ))
            }
        }

        if let traits = profile.decodedPersonalityTraits {
            for (i, trait) in traits.enumerated() {
                facts.append(ProfileFact(
                    id: "personality-\(i)",
                    category: "Personality",
                    displayLabel: "A trait your coach sees",
                    value: trait
                ))
            }
        }

        if let domains = profile.decodedDomainStates {
            for (key, state) in domains.sorted(by: { $0.key < $1.key }) {
                let description = state.status ?? "exploring"
                facts.append(ProfileFact(
                    id: "domain-\(key)",
                    category: "Life Situation",
                    displayLabel: key.capitalized,
                    value: description
                ))
            }
        }

        return facts
    }

    private func mapSummaryToMemoryItem(_ summary: ConversationSummary, rowid: Int64) -> MemoryItem {
        MemoryItem(
            id: summary.id,
            rowid: rowid,
            summary: summary.summary,
            keyMoments: summary.decodedKeyMoments,
            date: summary.createdAt,
            domainTags: summary.decodedDomainTags
        )
    }

    private func aggregateDomainTags(_ summaries: [ConversationSummary]) -> [String] {
        var tagSet = Set<String>()
        for summary in summaries {
            for tag in summary.decodedDomainTags {
                tagSet.insert(tag)
            }
        }
        return tagSet.sorted()
    }

    // MARK: - Fact Mutation Helpers

    private nonisolated func applyFactUpdate(_ profile: inout UserProfile, fact: ProfileFact, newValue: String) {
        if fact.id == "coachName" {
            profile.coachName = newValue
            return
        }

        let parts = fact.id.split(separator: "-", maxSplits: 1)
        guard parts.count == 2 else { return }
        let category = String(parts[0])

        // Domain keys are strings, not numeric indices
        if category == "domain" {
            let domainKey = String(parts[1])
            var domains = profile.decodedDomainStates ?? [:]
            if let existing = domains[domainKey] {
                domains[domainKey] = DomainState(
                    status: newValue,
                    conversationCount: existing.conversationCount,
                    lastUpdated: existing.lastUpdated
                )
            }
            profile.domainStates = UserProfile.encodeDomainStates(domains)
            return
        }

        guard let index = Int(parts[1]) else { return }

        switch category {
        case "values":
            var arr = profile.decodedValues ?? []
            guard index < arr.count else { return }
            arr[index] = newValue
            profile.values = UserProfile.encodeArray(arr)
        case "goals":
            var arr = profile.decodedGoals ?? []
            guard index < arr.count else { return }
            arr[index] = newValue
            profile.goals = UserProfile.encodeArray(arr)
        case "personality":
            var arr = profile.decodedPersonalityTraits ?? []
            guard index < arr.count else { return }
            arr[index] = newValue
            profile.personalityTraits = UserProfile.encodeArray(arr)
        default:
            break
        }
    }

    private nonisolated func applyFactDeletion(_ profile: inout UserProfile, fact: ProfileFact) {
        if fact.id == "coachName" {
            return // Cannot delete coach name
        }

        let parts = fact.id.split(separator: "-", maxSplits: 1)
        guard parts.count == 2 else { return }
        let category = String(parts[0])

        // Domain keys are strings, not numeric indices
        if category == "domain" {
            let domainKey = String(parts[1])
            var domains = profile.decodedDomainStates ?? [:]
            domains.removeValue(forKey: domainKey)
            profile.domainStates = domains.isEmpty ? nil : UserProfile.encodeDomainStates(domains)
            return
        }

        guard let index = Int(parts[1]) else { return }

        switch category {
        case "values":
            var arr = profile.decodedValues ?? []
            guard index < arr.count else { return }
            arr.remove(at: index)
            profile.values = arr.isEmpty ? nil : UserProfile.encodeArray(arr)
        case "goals":
            var arr = profile.decodedGoals ?? []
            guard index < arr.count else { return }
            arr.remove(at: index)
            profile.goals = arr.isEmpty ? nil : UserProfile.encodeArray(arr)
        case "personality":
            var arr = profile.decodedPersonalityTraits ?? []
            guard index < arr.count else { return }
            arr.remove(at: index)
            profile.personalityTraits = arr.isEmpty ? nil : UserProfile.encodeArray(arr)
        default:
            break
        }
    }
}

// MARK: - Preview Factory

#if DEBUG
extension MemoryViewModel {
    static func preview() -> MemoryViewModel {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("preview_\(UUID().uuidString).sqlite")
        let dbPool = try! DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try! migrator.migrate(dbPool)
        let dbManager = DatabaseManager(dbPool: dbPool)
        return MemoryViewModel(databaseManager: dbManager)
    }
}
#endif
