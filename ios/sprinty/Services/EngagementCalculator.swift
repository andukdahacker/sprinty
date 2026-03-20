import Foundation
import GRDB

struct EngagementCalculator: Sendable {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func compute() async throws -> EngagementSnapshot {
        try await dbPool.read { db in
            let sessions = try ConversationSession
                .order(Column("startedAt").desc)
                .limit(10)
                .fetchAll(db)

            let sessionCount = sessions.count

            guard let mostRecent = sessions.first else {
                return EngagementSnapshot(
                    engagementLevel: .low,
                    recentMoods: [],
                    avgMessageLength: .short,
                    sessionCount: 0,
                    lastSessionGapHours: nil,
                    recentSessionIntensity: .light
                )
            }

            // Last session gap
            let gapHours = Int(Date().timeIntervalSince(mostRecent.startedAt) / 3600)

            // Average message length from recent sessions (up to last 3 sessions)
            let recentSessionIds = sessions.prefix(3).map { $0.id }
            let userMessages = try Message
                .filter(recentSessionIds.contains(Column("sessionId")))
                .filter(Column("role") == MessageRole.user.rawValue)
                .order(Column("timestamp").desc)
                .fetchAll(db)

            let avgLength = computeAvgMessageLength(userMessages)

            // Engagement level heuristic
            let engagementLevel = computeEngagementLevel(
                gapHours: gapHours,
                avgLength: avgLength,
                messageCount: userMessages.count
            )

            // Recent moods from last 3-5 sessions
            let recentMoods = collectRecentMoods(from: Array(sessions.prefix(5)))

            // Session intensity from most recent session
            let intensity = try computeSessionIntensity(session: mostRecent, in: db)

            return EngagementSnapshot(
                engagementLevel: engagementLevel,
                recentMoods: recentMoods,
                avgMessageLength: avgLength,
                sessionCount: sessionCount,
                lastSessionGapHours: gapHours,
                recentSessionIntensity: intensity
            )
        }
    }

    private func computeAvgMessageLength(_ messages: [Message]) -> MessageLength {
        guard !messages.isEmpty else { return .short }
        let totalChars = messages.reduce(0) { $0 + $1.content.count }
        let avg = totalChars / messages.count
        if avg > 200 { return .long }
        if avg > 50 { return .medium }
        return .short
    }

    private func computeEngagementLevel(gapHours: Int, avgLength: MessageLength, messageCount: Int) -> EngagementLevel {
        // Low: gap > 72h or very short messages with few messages
        if gapHours > 72 { return .low }
        if avgLength == .short && messageCount < 3 { return .low }

        // High: active in last 24h with moderate+ message length
        if gapHours <= 24 && (avgLength == .medium || avgLength == .long) { return .high }

        // Everything else
        return .medium
    }

    private func collectRecentMoods(from sessions: [ConversationSession]) -> [String] {
        var moods: [String] = []
        for session in sessions {
            guard let moodHistoryJSON = session.moodHistory,
                  let data = moodHistoryJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                continue
            }
            moods.append(contentsOf: decoded)
        }
        // Return last 5 moods
        return Array(moods.prefix(5))
    }

    private func computeSessionIntensity(session: ConversationSession, in db: Database) throws -> SessionIntensity {
        let messageCount = try Message
            .filter(Column("sessionId") == session.id)
            .fetchCount(db)

        let durationMinutes: Double
        if let endedAt = session.endedAt {
            durationMinutes = endedAt.timeIntervalSince(session.startedAt) / 60
        } else {
            durationMinutes = Date().timeIntervalSince(session.startedAt) / 60
        }

        // Deep: >15 messages or >20min
        if messageCount > 15 || durationMinutes > 20 { return .deep }
        // Light: <5 messages or <5min
        if messageCount < 5 || durationMinutes < 5 { return .light }
        return .moderate
    }
}
