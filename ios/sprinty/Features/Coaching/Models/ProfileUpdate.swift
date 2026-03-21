import Foundation

struct ProfileUpdate: Codable, Sendable {
    let values: [String]?
    let goals: [String]?
    let personalityTraits: [String]?
    let domainStates: [String: DomainState]?
    let corrections: [String]?
}
