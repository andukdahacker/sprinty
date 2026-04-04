import Foundation
import GRDB
import WidgetKit

extension SprintyWidgetEntry: TimelineEntry {}

struct SprintyTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SprintyWidgetEntry {
        SprintyWidgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SprintyWidgetEntry) -> Void) {
        let entry = readCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SprintyWidgetEntry>) -> Void) {
        let entry = readCurrentEntry()
        let refreshDate = Date().addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func readCurrentEntry() -> SprintyWidgetEntry {
        do {
            let dbPool = try CachedDatabasePool.shared.pool()
            return try dbPool.read { db in
                try WidgetDataProvider.fetchWidgetData(db: db)
            }
        } catch {
            return SprintyWidgetEntry.placeholder
        }
    }
}

/// Caches the read-only DatabasePool across timeline reads to avoid
/// creating a new connection on every widget refresh.
private final class CachedDatabasePool: @unchecked Sendable {
    static let shared = CachedDatabasePool()

    private var cachedPool: DatabasePool?
    private let lock = NSLock()

    func pool() throws -> DatabasePool {
        lock.lock()
        defer { lock.unlock() }
        if let cachedPool { return cachedPool }
        let newPool = try WidgetDataProvider.openReadOnlyDatabase()
        cachedPool = newPool
        return newPool
    }
}
