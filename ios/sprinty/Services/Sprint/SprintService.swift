import Foundation
import GRDB

protocol SprintServiceProtocol: Sendable {
    func createSprint(from proposal: SprintProposalData, durationWeeks: Int) async throws -> Sprint
    func activeSprint() async throws -> (sprint: Sprint, steps: [SprintStep])?
    func savePendingProposal(_ proposal: PendingSprintProposal) throws
    func loadPendingProposal() -> PendingSprintProposal?
    func clearPendingProposal()
}

struct SprintProposalData: Codable, Sendable {
    let name: String
    let steps: [ProposalStep]
    let durationWeeks: Int

    struct ProposalStep: Codable, Sendable {
        let description: String
        let order: Int
    }
}

struct PendingSprintProposal: Codable, Sendable {
    let name: String
    let steps: [SprintProposalData.ProposalStep]
}

final class SprintService: SprintServiceProtocol {
    private let databaseManager: DatabaseManager
    private static let pendingProposalKey = "pendingSprintProposal"

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    enum SprintError: Error, Sendable {
        case invalidDuration
        case emptySteps
        case dateCalculationFailed
    }

    func createSprint(from proposal: SprintProposalData, durationWeeks: Int) async throws -> Sprint {
        guard durationWeeks >= 1 && durationWeeks <= 4 else {
            throw SprintError.invalidDuration
        }
        guard !proposal.steps.isEmpty else {
            throw SprintError.emptySteps
        }
        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .weekOfYear, value: durationWeeks, to: now) else {
            throw SprintError.dateCalculationFailed
        }
        let sprint = Sprint(
            id: UUID(),
            name: proposal.name,
            startDate: now,
            endDate: endDate,
            status: .active
        )
        let steps = proposal.steps.map { step in
            SprintStep(
                id: UUID(),
                sprintId: sprint.id,
                description: step.description,
                completed: false,
                completedAt: nil,
                order: step.order
            )
        }

        try await databaseManager.dbPool.write { db in
            try sprint.insert(db)
            for step in steps {
                try step.insert(db)
            }
        }

        clearPendingProposal()
        return sprint
    }

    func activeSprint() async throws -> (sprint: Sprint, steps: [SprintStep])? {
        try await databaseManager.dbPool.read { db in
            guard let sprint = try Sprint.active().fetchOne(db) else {
                return nil
            }
            let steps = try SprintStep.forSprint(id: sprint.id).fetchAll(db)
            return (sprint, steps)
        }
    }

    func savePendingProposal(_ proposal: PendingSprintProposal) throws {
        let data = try JSONEncoder().encode(proposal)
        UserDefaults.standard.set(data, forKey: Self.pendingProposalKey)
    }

    func loadPendingProposal() -> PendingSprintProposal? {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingProposalKey) else {
            return nil
        }
        return try? JSONDecoder().decode(PendingSprintProposal.self, from: data)
    }

    func clearPendingProposal() {
        UserDefaults.standard.removeObject(forKey: Self.pendingProposalKey)
    }
}
