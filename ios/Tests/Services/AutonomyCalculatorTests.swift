import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 7.3 Tests ---

@Suite("AutonomyCalculator Tests")
struct AutonomyCalculatorTests {

    // MARK: - Test 6.3: Returns .none for new users (< 5 sessions)

    @Test func test_computeAutonomySnapshot_fewSessions_returnsNone() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // Create 3 sessions over 15 days
        try createSessions(in: dbPool, count: 3, organicCount: 3, daysSpread: 15)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.autonomyLevel == .none)
        #expect(snapshot.totalSessions == 3)
        #expect(snapshot.organicSessions == 3)
    }

    // MARK: - Test 6.4: Returns .none for users with < 14 days of data

    @Test func test_computeAutonomySnapshot_recentData_returnsNone() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // Create 10 sessions all within the last 10 days (not enough history)
        try createSessions(in: dbPool, count: 10, organicCount: 8, daysSpread: 10)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.autonomyLevel == .none)
        #expect(snapshot.totalSessions == 10)
    }

    // MARK: - Test 6.5: Computes correct voluntarySessionRate from mixed sessions

    @Test func test_computeAutonomySnapshot_mixedSessions_correctRate() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // 6 organic, 4 notification = 60% voluntary rate
        try createSessions(in: dbPool, count: 10, organicCount: 6, daysSpread: 20)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.voluntarySessionRate >= 0.59 && snapshot.voluntarySessionRate <= 0.61)
        #expect(snapshot.organicSessions == 6)
        #expect(snapshot.notificationTriggeredSessions == 4)
    }

    // MARK: - Test 6.6: Returns .light when voluntaryRate >= 0.6 with sufficient data

    @Test func test_computeAutonomySnapshot_sixtyPercentOrganic_returnsLight() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // 6/10 organic = 0.6, 20 days spread
        try createSessions(in: dbPool, count: 10, organicCount: 6, daysSpread: 20)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.autonomyLevel == .light)
    }

    // MARK: - Test 6.7: Returns .moderate when voluntaryRate >= 0.75

    @Test func test_computeAutonomySnapshot_seventyFivePercentOrganic_returnsModerate() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // 8/10 organic = 0.8, 20 days spread
        try createSessions(in: dbPool, count: 10, organicCount: 8, daysSpread: 20)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.autonomyLevel == .moderate)
    }

    // MARK: - Test 6.8: Returns .high when voluntaryRate >= 0.9 AND >= 20 sessions

    @Test func test_computeAutonomySnapshot_ninetyPercentAnd20Sessions_returnsHigh() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // 19/20 organic = 0.95, 25 days spread
        try createSessions(in: dbPool, count: 20, organicCount: 19, daysSpread: 25)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.autonomyLevel == .high)
    }

    @Test func test_computeAutonomySnapshot_ninetyPercentButFewSessions_returnsModerate() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // 9/10 organic = 0.9 but only 10 sessions (< 20 for .high)
        try createSessions(in: dbPool, count: 10, organicCount: 9, daysSpread: 20)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        // 0.9 >= 0.75, so moderate (not high because < 20 sessions)
        #expect(snapshot.autonomyLevel == .moderate)
    }

    // MARK: - Test 6.9: autonomyAdjustedCadence returns correct values

    @Test func test_autonomyAdjustedCadence_noneKeepsDailyCadence() {
        let result = RootView.autonomyAdjustedCadence(userCadence: "daily", autonomyLevel: .none)
        #expect(result == "daily")
    }

    @Test func test_autonomyAdjustedCadence_lightKeepsDailyCadence() {
        let result = RootView.autonomyAdjustedCadence(userCadence: "daily", autonomyLevel: .light)
        #expect(result == "daily")
    }

    @Test func test_autonomyAdjustedCadence_moderateOverridesDailyToWeekly() {
        let result = RootView.autonomyAdjustedCadence(userCadence: "daily", autonomyLevel: .moderate)
        #expect(result == "weekly")
    }

    @Test func test_autonomyAdjustedCadence_highOverridesDailyToWeekly() {
        let result = RootView.autonomyAdjustedCadence(userCadence: "daily", autonomyLevel: .high)
        #expect(result == "weekly")
    }

    @Test func test_autonomyAdjustedCadence_weeklyUnchangedAtHigh() {
        let result = RootView.autonomyAdjustedCadence(userCadence: "weekly", autonomyLevel: .high)
        #expect(result == "weekly")
    }

    // MARK: - Test 6.10: DriftDetectionService.evaluateAndSchedule(autonomyLevel:) thresholds

    @Test func test_driftDetection_autonomyAdjustedThreshold_none() {
        let base = TimeInterval(72 * 3600)
        let result = DriftDetectionService.autonomyAdjustedThreshold(
            baseThresholdSeconds: base,
            autonomyLevel: .none
        )
        #expect(result == base)
    }

    @Test func test_driftDetection_autonomyAdjustedThreshold_light() {
        let result = DriftDetectionService.autonomyAdjustedThreshold(
            baseThresholdSeconds: 72 * 3600,
            autonomyLevel: .light
        )
        #expect(result == TimeInterval(96 * 3600))
    }

    @Test func test_driftDetection_autonomyAdjustedThreshold_moderate() {
        let result = DriftDetectionService.autonomyAdjustedThreshold(
            baseThresholdSeconds: 72 * 3600,
            autonomyLevel: .moderate
        )
        #expect(result == TimeInterval(120 * 3600))
    }

    @Test func test_driftDetection_autonomyAdjustedThreshold_high() {
        let result = DriftDetectionService.autonomyAdjustedThreshold(
            baseThresholdSeconds: 72 * 3600,
            autonomyLevel: .high
        )
        #expect(result == TimeInterval(168 * 3600))
    }

    // MARK: - Test 6.11: AutonomySnapshot correct counts

    @Test func test_computeAutonomySnapshot_correctCounts() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        // Create 7 organic, 3 notification-triggered
        try createSessions(in: dbPool, count: 10, organicCount: 7, daysSpread: 20)

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.totalSessions == 10)
        #expect(snapshot.organicSessions == 7)
        #expect(snapshot.notificationTriggeredSessions == 3)
    }

    @Test func test_computeAutonomySnapshot_noSessions_returnsZeros() throws {
        let dbPool = try makeTestDB()
        let calculator = AutonomyCalculator()

        let snapshot = try dbPool.read { db in
            try calculator.computeAutonomySnapshot(db: db)
        }

        #expect(snapshot.totalSessions == 0)
        #expect(snapshot.organicSessions == 0)
        #expect(snapshot.notificationTriggeredSessions == 0)
        #expect(snapshot.voluntarySessionRate == 0.0)
        #expect(snapshot.autonomyLevel == .none)
    }

    // MARK: - Helpers

    private func makeTestDB() throws -> DatabasePool {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return dbPool
    }

    private func createSessions(
        in dbPool: DatabasePool,
        count: Int,
        organicCount: Int,
        daysSpread: Int
    ) throws {
        try dbPool.write { db in
            for i in 0..<count {
                let daysAgo = Double(daysSpread) * Double(i) / Double(max(count - 1, 1))
                let startedAt = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date())!
                let source: EngagementSource = i < organicCount ? .organic : .checkInNotification
                let session = ConversationSession(
                    id: UUID(),
                    startedAt: startedAt,
                    endedAt: startedAt.addingTimeInterval(300),
                    type: .coaching,
                    mode: .discovery,
                    safetyLevel: .green,
                    engagementSource: source
                )
                try session.save(db)
            }
        }
    }
}
