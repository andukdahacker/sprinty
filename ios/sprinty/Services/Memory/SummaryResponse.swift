import Foundation

struct SummaryResponse: Codable, Sendable {
    let summary: String
    let keyMoments: [String]
    let domainTags: [String]
    let emotionalMarkers: [String]?
    let keyDecisions: [String]?
}
