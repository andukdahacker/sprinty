import Foundation
import GRDB

protocol AutonomyCalculatorProtocol: Sendable {
    func computeAutonomySnapshot(db: Database) throws -> AutonomySnapshot
}

final class AutonomyCalculator: AutonomyCalculatorProtocol, @unchecked Sendable {
    func computeAutonomySnapshot(db: Database) throws -> AutonomySnapshot {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let sessions = try ConversationSession
            .filter(Column("startedAt") >= thirtyDaysAgo)
            .fetchAll(db)

        let total = sessions.count
        let organic = sessions.filter { $0.engagementSource == .organic }.count
        let rate = total > 0 ? Float(organic) / Float(total) : 0.0

        let level: AutonomyLevel = {
            guard total >= 5 else { return .none }
            let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            guard let earliest = sessions.min(by: { $0.startedAt < $1.startedAt }),
                  earliest.startedAt <= fourteenDaysAgo else { return .none }
            if rate >= 0.9 && total >= 20 { return .high }
            if rate >= 0.75 { return .moderate }
            if rate >= 0.6 { return .light }
            return .none
        }()

        return AutonomySnapshot(
            voluntarySessionRate: rate,
            totalSessions: total,
            organicSessions: organic,
            notificationTriggeredSessions: total - organic,
            autonomyLevel: level
        )
    }
}
