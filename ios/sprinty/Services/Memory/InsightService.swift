import Foundation
import GRDB
import OSLog

final class InsightService: InsightServiceProtocol, @unchecked Sendable {
    private let databaseManager: DatabaseManager
    private let embeddingPipeline: EmbeddingPipelineProtocol?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "insight")

    private let lock = NSLock()
    private var lastSessionId: UUID?
    private var cachedInsight: String?

    init(databaseManager: DatabaseManager, embeddingPipeline: EmbeddingPipelineProtocol?) {
        self.databaseManager = databaseManager
        self.embeddingPipeline = embeddingPipeline
    }

    private func getCachedInsight() -> String? {
        lock.withLock { cachedInsight }
    }

    private func getCacheState() -> (lastSessionId: UUID?, cachedInsight: String?) {
        lock.withLock { (lastSessionId, cachedInsight) }
    }

    private func updateCache(sessionId: UUID?, insight: String?) {
        lock.withLock {
            lastSessionId = sessionId
            cachedInsight = insight
        }
    }

    func generateDailyInsight() async -> String? {
        // Race with 500ms timeout
        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await self.selectInsight()
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(500))
                return nil
            }

            // Return whichever finishes first; if timeout wins, use cached value
            if let first = await group.next() {
                group.cancelAll()
                if let result = first {
                    return result
                }
                // Timeout won — return cached value
                return self.getCachedInsight()
            }
            return self.getCachedInsight()
        }
    }

    private func selectInsight() async -> String? {
        do {
            // Check most recent completed session for cache invalidation
            let latestSession = try await databaseManager.dbPool.read { db in
                try ConversationSession
                    .filter(Column("endedAt") != nil)
                    .order(Column("startedAt").desc)
                    .limit(1)
                    .fetchOne(db)
            }

            // Cache hit: same session, return cached
            let cacheState = getCacheState()
            if let latestSession, let lastId = cacheState.lastSessionId,
               latestSession.id == lastId, let cached = cacheState.cachedInsight {
                return cached
            }

            // Fetch recent summaries
            let summaries = try await databaseManager.dbPool.read { db in
                try ConversationSummary.recent(limit: 3).fetchAll(db)
            }

            guard !summaries.isEmpty else {
                updateCache(sessionId: latestSession?.id, insight: nil)
                return nil
            }

            // Fallback chain: key moment → summary text → fallback string
            let mostRecent = summaries[0]
            let keyMoments = mostRecent.decodedKeyMoments

            var insight: String?

            // Try semantic search for variety if embedding pipeline available
            if let embeddingPipeline, !mostRecent.summary.isEmpty {
                do {
                    let semanticResults = try await embeddingPipeline.search(query: mostRecent.summary, limit: 1)
                    if let semanticSummary = semanticResults.first,
                       semanticSummary.id != mostRecent.id {
                        let semanticMoments = semanticSummary.decodedKeyMoments
                        if let moment = semanticMoments.first, !moment.isEmpty {
                            insight = moment
                        }
                    }
                } catch {
                    logger.debug("Semantic search failed, falling back: \(error)")
                }
            }

            // Fallback 1: key moment from most recent summary
            if insight == nil, let moment = keyMoments.first, !moment.isEmpty {
                insight = moment
            }

            // Fallback 2: summary text verbatim
            if insight == nil, !mostRecent.summary.isEmpty {
                insight = mostRecent.summary
            }

            // Fallback 3: conversations exist but no usable content
            if insight == nil {
                insight = "Your coach is getting to know you..."
            }

            updateCache(sessionId: latestSession?.id, insight: insight)
            return insight
        } catch {
            logger.error("Insight generation failed: \(error)")
            return getCachedInsight()
        }
    }
}
