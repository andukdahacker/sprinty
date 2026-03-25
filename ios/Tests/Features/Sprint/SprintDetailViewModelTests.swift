import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SprintDetailViewModel Tests")
struct SprintDetailViewModelTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createActiveSprint(in db: DatabaseManager, stepCount: Int = 3, withCoachContext: Bool = false) async throws -> (Sprint, [SprintStep]) {
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!,
            status: .active
        )
        let steps = (1...stepCount).map { i in
            SprintStep(
                id: UUID(),
                sprintId: sprint.id,
                description: "Step \(i)",
                completed: false,
                completedAt: nil,
                order: i,
                coachContext: withCoachContext ? "Why step \(i) matters" : nil
            )
        }

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            for step in steps {
                try step.insert(dbConn)
            }
        }
        return (sprint, steps)
    }

    // MARK: - Migration v9 Tests

    @Test("Migration v9 adds coachContext column to SprintStep")
    func test_migrationV9_addsCoachContextColumn() async throws {
        let db = try makeTestDB()

        // Insert a sprint step and verify coachContext is nil by default
        let sprint = Sprint(
            id: UUID(),
            name: "Test",
            startDate: Date(),
            endDate: Date(),
            status: .active
        )
        let step = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Step 1",
            completed: false,
            completedAt: nil,
            order: 1,
            coachContext: nil
        )

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            try step.insert(dbConn)
        }

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: step.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.coachContext == nil)
    }

    @Test("Migration v9 preserves existing SprintStep rows with nil coachContext")
    func test_migrationV9_existingRowsHaveNilCoachContext() async throws {
        let db = try makeTestDB()
        let (_, steps) = try await createActiveSprint(in: db, withCoachContext: false)

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.forSprint(id: steps[0].sprintId).fetchAll(dbConn)
        }
        #expect(fetched.count == 3)
        #expect(fetched.allSatisfy { $0.coachContext == nil })
    }

    @Test("SprintStep persists and reads coachContext when present")
    func test_sprintStep_coachContextRoundtrip() async throws {
        let db = try makeTestDB()
        let (_, steps) = try await createActiveSprint(in: db, withCoachContext: true)

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.forSprint(id: steps[0].sprintId).fetchAll(dbConn)
        }
        #expect(fetched[0].coachContext == "Why step 1 matters")
        #expect(fetched[1].coachContext == "Why step 2 matters")
    }

    // MARK: - ProposalStep Backward Compatibility

    @Test("ProposalStep decodes coachContext when present")
    func test_proposalStep_decodesCoachContext() throws {
        let json = """
        {"description": "Step 1", "order": 1, "coachContext": "This builds momentum"}
        """.data(using: .utf8)!
        let step = try JSONDecoder().decode(SprintProposalData.ProposalStep.self, from: json)
        #expect(step.coachContext == "This builds momentum")
    }

    @Test("ProposalStep decodes with nil coachContext when absent (backward compat)")
    func test_proposalStep_nilCoachContextWhenAbsent() throws {
        let json = """
        {"description": "Step 1", "order": 1}
        """.data(using: .utf8)!
        let step = try JSONDecoder().decode(SprintProposalData.ProposalStep.self, from: json)
        #expect(step.coachContext == nil)
    }

    // MARK: - Load Tests

    @Test("load fetches active sprint and steps")
    @MainActor func test_load_fetchesActiveSprint() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, _) = try await createActiveSprint(in: db, stepCount: 3, withCoachContext: true)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.sprint != nil)
        #expect(vm.sprint?.status == .active)
        #expect(vm.steps.count == 3)
        #expect(vm.steps[0].coachContext == "Why step 1 matters")
    }

    @Test("load with no active sprint results in nil sprint")
    @MainActor func test_load_noActiveSprint() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.sprint == nil)
        #expect(vm.steps.isEmpty)
    }

    // MARK: - Toggle Step Tests

    @Test("toggleStep marks step as completed with timestamp")
    @MainActor func test_toggleStep_marksCompleted() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        #expect(vm.steps[0].completed == true)
        #expect(vm.steps[0].completedAt != nil)
        // Verify persisted
        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.completed == true)
    }

    @Test("toggleStep detects sprint completion when all steps done")
    @MainActor func test_toggleStep_sprintCompletion() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Complete first step
        await vm.toggleStep(vm.steps[0])
        #expect(vm.sprint?.status == .active)

        // Complete second step — sprint should complete
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .complete)
        #expect(appState.activeSprint == nil)

        // Verify in DB
        let fetchedSprint = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetchedSprint?.status == .complete)
    }

    @Test("toggleStep works offline — no network dependency")
    @MainActor func test_toggleStep_worksOffline() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (_, _) = try await createActiveSprint(in: db, stepCount: 2)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        #expect(vm.steps[0].completed == true)
    }

    @Test("toggleStep reactivates sprint when uncompleting a step after completion")
    @MainActor func test_toggleStep_reactivatesSprintOnUncomplete() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Complete all steps → sprint becomes complete
        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .complete)
        #expect(appState.activeSprint == nil)

        // Uncomplete one step → sprint should reactivate
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .active)
        #expect(appState.activeSprint != nil)
        #expect(vm.steps[1].completed == false)

        // Verify in DB
        let fetchedSprint = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetchedSprint?.status == .active)
    }

    // MARK: - Computed Properties

    @Test("progress computes correct percentage")
    @MainActor func test_progress_computation() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, _) = try await createActiveSprint(in: db, stepCount: 4)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.progress == 0.0)

        await vm.toggleStep(vm.steps[0])
        #expect(vm.progress == 0.25)

        await vm.toggleStep(vm.steps[1])
        #expect(vm.progress == 0.5)
    }

    @Test("completedCount returns number of completed steps")
    @MainActor func test_completedCount() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, _) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.completedCount == 0)

        await vm.toggleStep(vm.steps[0])
        #expect(vm.completedCount == 1)
    }
}
