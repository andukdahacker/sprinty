import Foundation

protocol InsightServiceProtocol: Sendable {
    func generateDailyInsight() async -> String?
}
