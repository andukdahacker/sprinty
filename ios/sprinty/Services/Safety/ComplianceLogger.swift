import Foundation
import GRDB

final class ComplianceLogger: ComplianceLoggerProtocol {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func logSafetyBoundary(sessionId: UUID, level: SafetyLevel, source: SafetyClassificationSource, previousLevel: SafetyLevel?) async {
        let entry = SafetyComplianceLog(
            id: UUID(),
            sessionId: sessionId,
            timestamp: Date(),
            safetyLevel: level,
            classificationSource: source.rawValue,
            eventType: "boundary_detected",
            previousLevel: previousLevel?.rawValue
        )
        try? await databaseManager.dbPool.write { db in
            try entry.insert(db)
        }
    }
}
