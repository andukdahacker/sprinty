import Foundation

enum PreviewData {
    static let sampleSession = ConversationSession(
        id: UUID(),
        startedAt: Date(),
        endedAt: nil,
        type: .coaching,
        mode: .discovery,
        safetyLevel: .green,
        promptVersion: nil
    )

    static let sampleMessage = Message(
        id: UUID(),
        sessionId: UUID(),
        role: .assistant,
        content: "Welcome to your coaching session.",
        timestamp: Date()
    )
}
