import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SprintStep Sync Status Tests")
struct SprintStepSyncTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    // MARK: - Migration v19 Tests

    @Test("SprintStep default syncStatus is synced")
    func test_sprintStep_defaultSyncStatus_isSynced() async throws {
        let db = try makeTestDB()
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
        #expect(fetched?.syncStatus == .synced)
    }

    @Test("pendingSync query returns only pendingSync steps")
    func test_sprintStep_pendingSyncQuery_returnsPendingSyncOnly() async throws {
        let db = try makeTestDB()
        let sprint = Sprint(
            id: UUID(),
            name: "Test",
            startDate: Date(),
            endDate: Date(),
            status: .active
        )

        let syncedStep = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Synced step",
            completed: true,
            completedAt: Date(),
            order: 1,
            coachContext: nil,
            syncStatus: .synced
        )
        let pendingStep = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Pending step",
            completed: true,
            completedAt: Date(),
            order: 2,
            coachContext: nil,
            syncStatus: .pendingSync
        )

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            try syncedStep.insert(dbConn)
            try pendingStep.insert(dbConn)
        }

        let pending = try await db.dbPool.read { dbConn in
            try SprintStep.pendingSync().fetchAll(dbConn)
        }
        #expect(pending.count == 1)
        #expect(pending[0].id == pendingStep.id)
        #expect(pending[0].syncStatus == .pendingSync)
    }

    @Test("Migration v19 existing steps have synced status")
    func test_migration_existingSteps_haveSyncedStatus() async throws {
        let db = try makeTestDB()
        let sprint = Sprint(
            id: UUID(),
            name: "Test",
            startDate: Date(),
            endDate: Date(),
            status: .active
        )
        let steps = (1...3).map { i in
            SprintStep(
                id: UUID(),
                sprintId: sprint.id,
                description: "Step \(i)",
                completed: false,
                completedAt: nil,
                order: i,
                coachContext: nil
            )
        }

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            for step in steps {
                try step.insert(dbConn)
            }
        }

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.forSprint(id: sprint.id).fetchAll(dbConn)
        }
        #expect(fetched.count == 3)
        #expect(fetched.allSatisfy { $0.syncStatus == .synced })
    }

    @Test("pendingSync query orders by completedAt ascending")
    func test_pendingSyncQuery_orderedByCompletedAt() async throws {
        let db = try makeTestDB()
        let sprint = Sprint(
            id: UUID(),
            name: "Test",
            startDate: Date(),
            endDate: Date(),
            status: .active
        )

        let earlier = Date().addingTimeInterval(-60)
        let later = Date()

        let step1 = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Later step",
            completed: true,
            completedAt: later,
            order: 1,
            coachContext: nil,
            syncStatus: .pendingSync
        )
        let step2 = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Earlier step",
            completed: true,
            completedAt: earlier,
            order: 2,
            coachContext: nil,
            syncStatus: .pendingSync
        )

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            try step1.insert(dbConn)
            try step2.insert(dbConn)
        }

        let pending = try await db.dbPool.read { dbConn in
            try SprintStep.pendingSync().fetchAll(dbConn)
        }
        #expect(pending.count == 2)
        // Earlier completedAt should come first
        #expect(pending[0].id == step2.id)
        #expect(pending[1].id == step1.id)
    }
}
