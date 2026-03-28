import Foundation
import Testing
import GRDB
@testable import sprinty

@Suite("ComplianceLogger Tests")
struct ComplianceLoggerTests {
    private func makeTestDB() throws -> DatabasePool {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return dbPool
    }

    @Test("logSafetyBoundary inserts compliance log entry")
    func test_logSafetyBoundary_insertsEntry() async throws {
        let dbPool = try makeTestDB()
        let dbManager = DatabaseManager(dbPool: dbPool)
        let logger = ComplianceLogger(databaseManager: dbManager)
        let sessionId = UUID()

        await logger.logSafetyBoundary(
            sessionId: sessionId,
            level: .yellow,
            source: .genuine,
            previousLevel: nil
        )

        let logs = try await dbPool.read { db in
            try SafetyComplianceLog.fetchAll(db)
        }
        #expect(logs.count == 1)
        #expect(logs[0].sessionId == sessionId)
        #expect(logs[0].safetyLevel == .yellow)
        #expect(logs[0].classificationSource == "genuine")
        #expect(logs[0].eventType == "boundary_detected")
        #expect(logs[0].previousLevel == nil)
    }

    @Test("logSafetyBoundary records previousLevel when provided")
    func test_logSafetyBoundary_recordsPreviousLevel() async throws {
        let dbPool = try makeTestDB()
        let dbManager = DatabaseManager(dbPool: dbPool)
        let logger = ComplianceLogger(databaseManager: dbManager)
        let sessionId = UUID()

        await logger.logSafetyBoundary(
            sessionId: sessionId,
            level: .orange,
            source: .failsafe,
            previousLevel: .yellow
        )

        let logs = try await dbPool.read { db in
            try SafetyComplianceLog.fetchAll(db)
        }
        #expect(logs.count == 1)
        #expect(logs[0].safetyLevel == .orange)
        #expect(logs[0].classificationSource == "failsafe")
        #expect(logs[0].previousLevel == "yellow")
    }

    @Test("logSafetyBoundary creates unique entries for multiple calls")
    func test_logSafetyBoundary_multipleEntries() async throws {
        let dbPool = try makeTestDB()
        let dbManager = DatabaseManager(dbPool: dbPool)
        let logger = ComplianceLogger(databaseManager: dbManager)
        let sessionId = UUID()

        await logger.logSafetyBoundary(sessionId: sessionId, level: .yellow, source: .genuine, previousLevel: nil)
        await logger.logSafetyBoundary(sessionId: sessionId, level: .orange, source: .genuine, previousLevel: .yellow)
        await logger.logSafetyBoundary(sessionId: sessionId, level: .red, source: .genuine, previousLevel: .orange)

        let logs = try await dbPool.read { db in
            try SafetyComplianceLog.fetchAll(db)
        }
        #expect(logs.count == 3)
    }

    @Test("logSafetyBoundary stores red level correctly")
    func test_logSafetyBoundary_redLevel() async throws {
        let dbPool = try makeTestDB()
        let dbManager = DatabaseManager(dbPool: dbPool)
        let logger = ComplianceLogger(databaseManager: dbManager)

        await logger.logSafetyBoundary(
            sessionId: UUID(),
            level: .red,
            source: .genuine,
            previousLevel: .orange
        )

        let logs = try await dbPool.read { db in
            try SafetyComplianceLog.fetchAll(db)
        }
        #expect(logs.count == 1)
        #expect(logs[0].safetyLevel == .red)
    }
}
