@testable import sprinty
import Foundation

final class MockSprintService: SprintServiceProtocol, @unchecked Sendable {
    var createSprintResult: Sprint?
    var createSprintError: Error?
    var activeSprintResult: (sprint: Sprint, steps: [SprintStep])?
    var pendingProposal: PendingSprintProposal?
    var createSprintCallCount = 0
    var savePendingCallCount = 0
    var clearPendingCallCount = 0
    var lastProposal: SprintProposalData?

    func createSprint(from proposal: SprintProposalData, durationWeeks: Int) async throws -> Sprint {
        createSprintCallCount += 1
        lastProposal = proposal
        if let error = createSprintError { throw error }
        if let result = createSprintResult { return result }
        return Sprint(
            id: UUID(),
            name: proposal.name,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .weekOfYear, value: durationWeeks, to: Date()) ?? Date(),
            status: .active
        )
    }

    func activeSprint() async throws -> (sprint: Sprint, steps: [SprintStep])? {
        activeSprintResult
    }

    func savePendingProposal(_ proposal: PendingSprintProposal) throws {
        savePendingCallCount += 1
        pendingProposal = proposal
    }

    func loadPendingProposal() -> PendingSprintProposal? {
        pendingProposal
    }

    func clearPendingProposal() {
        clearPendingCallCount += 1
        pendingProposal = nil
    }
}
