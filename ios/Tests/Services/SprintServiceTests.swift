import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SprintService Tests")
struct SprintServiceTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func makeProposal(
        name: String = "Career Growth",
        steps: Int = 3,
        durationWeeks: Int = 2
    ) -> SprintProposalData {
        SprintProposalData(
            name: name,
            steps: (1...steps).map { i in
                SprintProposalData.ProposalStep(description: "Step \(i)", order: i)
            },
            durationWeeks: durationWeeks
        )
    }

    // MARK: - createSprint

    @Test("createSprint writes Sprint and SprintSteps in single transaction")
    func test_createSprint_writesBothRecords() async throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)
        let proposal = makeProposal()

        let sprint = try await service.createSprint(from: proposal, durationWeeks: 2)

        let fetchedSprint = try await db.dbPool.read { db in
            try Sprint.fetchOne(db, key: sprint.id)
        }
        #expect(fetchedSprint != nil)
        #expect(fetchedSprint?.name == "Career Growth")
        #expect(fetchedSprint?.status == .active)

        let steps = try await db.dbPool.read { db in
            try SprintStep.forSprint(id: sprint.id).fetchAll(db)
        }
        #expect(steps.count == 3)
        #expect(steps[0].order == 1)
        #expect(steps[1].order == 2)
        #expect(steps[2].order == 3)
        #expect(steps.allSatisfy { !$0.completed })
    }

    @Test("createSprint sets correct endDate based on durationWeeks")
    func test_createSprint_endDateCalculation() async throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)
        let proposal = makeProposal(durationWeeks: 3)

        let sprint = try await service.createSprint(from: proposal, durationWeeks: 3)

        let daysBetween = Calendar.current.dateComponents([.day], from: sprint.startDate, to: sprint.endDate).day ?? 0
        #expect(daysBetween >= 20) // ~21 days for 3 weeks
        #expect(daysBetween <= 22)
    }

    @Test("createSprint clears pending proposal")
    func test_createSprint_clearsPendingProposal() async throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)

        let pending = PendingSprintProposal(
            name: "Old Proposal",
            steps: [SprintProposalData.ProposalStep(description: "Step 1", order: 1)]
        )
        try service.savePendingProposal(pending)
        #expect(service.loadPendingProposal() != nil)

        let proposal = makeProposal()
        _ = try await service.createSprint(from: proposal, durationWeeks: 2)

        #expect(service.loadPendingProposal() == nil)
    }

    @Test("createSprint supports single-step lightweight sprints")
    func test_createSprint_singleStep() async throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)
        let proposal = makeProposal(steps: 1)

        let sprint = try await service.createSprint(from: proposal, durationWeeks: 1)

        let steps = try await db.dbPool.read { db in
            try SprintStep.forSprint(id: sprint.id).fetchAll(db)
        }
        #expect(steps.count == 1)
    }

    // MARK: - activeSprint

    @Test("activeSprint returns sprint with ordered steps")
    func test_activeSprint_returnsSprintAndSteps() async throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)
        let proposal = makeProposal()
        _ = try await service.createSprint(from: proposal, durationWeeks: 2)

        let result = try await service.activeSprint()

        #expect(result != nil)
        #expect(result?.sprint.status == .active)
        #expect(result?.steps.count == 3)
        #expect(result?.steps[0].order == 1)
    }

    @Test("activeSprint returns nil when no active sprint")
    func test_activeSprint_returnsNilWhenEmpty() async throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)

        let result = try await service.activeSprint()

        #expect(result == nil)
    }

    // MARK: - Pending Proposal

    @Test("savePendingProposal and loadPendingProposal roundtrips")
    func test_pendingProposal_roundtrip() throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)

        let pending = PendingSprintProposal(
            name: "Career Clarity",
            steps: [
                SprintProposalData.ProposalStep(description: "Research roles", order: 1),
                SprintProposalData.ProposalStep(description: "Update portfolio", order: 2),
            ]
        )
        try service.savePendingProposal(pending)

        let loaded = service.loadPendingProposal()
        #expect(loaded != nil)
        #expect(loaded?.name == "Career Clarity")
        #expect(loaded?.steps.count == 2)
        #expect(loaded?.steps[0].description == "Research roles")
    }

    @Test("loadPendingProposal returns nil when nothing saved")
    func test_loadPendingProposal_nilWhenEmpty() throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)
        service.clearPendingProposal()

        #expect(service.loadPendingProposal() == nil)
    }

    @Test("clearPendingProposal removes saved proposal")
    func test_clearPendingProposal() throws {
        let db = try makeTestDB()
        let service = SprintService(databaseManager: db)

        let pending = PendingSprintProposal(
            name: "Test",
            steps: [SprintProposalData.ProposalStep(description: "Step 1", order: 1)]
        )
        try service.savePendingProposal(pending)
        #expect(service.loadPendingProposal() != nil)

        service.clearPendingProposal()
        #expect(service.loadPendingProposal() == nil)
    }
}
