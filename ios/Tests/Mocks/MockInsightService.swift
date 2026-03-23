@testable import sprinty
import Foundation

final class MockInsightService: InsightServiceProtocol, @unchecked Sendable {
    var generateCallCount: Int = 0
    var stubbedInsight: String?
    var stubbedDelay: Duration?

    func generateDailyInsight() async -> String? {
        generateCallCount += 1
        if let delay = stubbedDelay {
            try? await Task.sleep(for: delay)
        }
        return stubbedInsight
    }
}
