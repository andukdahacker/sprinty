import Foundation

struct ChatRequestMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct ChatProfile: Codable, Sendable {
    let coachName: String
    let values: [String]?
    let goals: [String]?
    let personalityTraits: [String]?
    let domainStates: [String: DomainState]?
}

struct UserState: Codable, Sendable {
    let engagementLevel: String
    let recentMoods: [String]
    let avgMessageLength: String
    let sessionCount: Int
    let lastSessionGapHours: Int?
    let recentSessionIntensity: String

    init(from snapshot: EngagementSnapshot) {
        self.engagementLevel = snapshot.engagementLevel.rawValue
        self.recentMoods = snapshot.recentMoods
        self.avgMessageLength = snapshot.avgMessageLength.rawValue
        self.sessionCount = snapshot.sessionCount
        self.lastSessionGapHours = snapshot.lastSessionGapHours
        self.recentSessionIntensity = snapshot.recentSessionIntensity.rawValue
    }
}

struct ActiveSprintInfo: Codable, Sendable {
    let name: String
    let status: String
    let stepsCompleted: Int
    let stepsTotal: Int
    let dayNumber: Int
    let totalDays: Int
}

struct SprintContext: Codable, Sendable {
    let activeSprint: ActiveSprintInfo?
    let pendingProposal: PendingSprintProposal?
}

struct ChatRequest: Codable, Sendable {
    let messages: [ChatRequestMessage]
    let mode: String
    let promptVersion: String
    let profile: ChatProfile?
    let userState: UserState?
    let ragContext: String?
    let sprintContext: SprintContext?

    init(messages: [ChatRequestMessage], mode: String, promptVersion: String, profile: ChatProfile?, userState: UserState? = nil, ragContext: String? = nil, sprintContext: SprintContext? = nil) {
        self.messages = messages
        self.mode = mode
        self.promptVersion = promptVersion
        self.profile = profile
        self.userState = userState
        self.ragContext = ragContext
        self.sprintContext = sprintContext
    }

    enum CodingKeys: String, CodingKey {
        case messages
        case mode
        case promptVersion
        case profile
        case userState
        case ragContext
        case sprintContext
    }
}
