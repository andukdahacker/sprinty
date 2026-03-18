import Foundation
import Observation
import GRDB

@MainActor
@Observable
final class CoachingViewModel {
    var messages: [Message] = []
    var streamingText: String = ""
    var isStreaming: Bool = false
    var coachExpression: CoachExpression = .welcoming
    var localError: AppError?
    var retryAfterSeconds: Int = 0

    private let appState: AppState
    private let chatService: ChatServiceProtocol
    private let databaseManager: DatabaseManager
    private var streamingTask: Task<Void, Never>?
    private var currentSession: ConversationSession?
    private var retryAfterTask: Task<Void, Never>?
    private var cachedPromptVersion: String?

    init(appState: AppState, chatService: ChatServiceProtocol, databaseManager: DatabaseManager) {
        self.appState = appState
        self.chatService = chatService
        self.databaseManager = databaseManager
    }

    func loadMessages() {
        Task {
            await loadMessagesAsync()
        }
    }

    private func loadMessagesAsync() async {
        do {
            let session = try await getOrCreateSession()
            currentSession = session
            let loaded = try await databaseManager.dbPool.read { db in
                try Message.forSession(id: session.id).fetchAll(db)
            }
            messages = loaded
        } catch {
            handleError(error)
        }
    }

    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isStreaming else { return }
        guard retryAfterSeconds == 0 else { return }

        localError = nil

        do {
            let session = try await getOrCreateSession()
            currentSession = session

            let userMessage = Message(
                id: UUID(),
                sessionId: session.id,
                role: .user,
                content: text,
                timestamp: Date()
            )

            try await databaseManager.dbPool.write { db in
                try userMessage.save(db)
            }
            messages.append(userMessage)

            coachExpression = .thinking
            isStreaming = true
            streamingText = ""

            let chatMessages = messages.map { msg in
                ChatRequestMessage(
                    role: msg.role == .user ? "user" : "assistant",
                    content: msg.content
                )
            }

            // Load user profile for coach name
            let profile = try await loadChatProfile()

            let stream = chatService.streamChat(messages: chatMessages, mode: session.mode.rawValue, profile: profile)
            let dbManager = databaseManager

            streamingTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await event in stream {
                        if Task.isCancelled { break }

                        switch event {
                        case .token(let tokenText):
                            self.streamingText += tokenText
                        case .done(let safetyLevel, _, let mood, _, let promptVersion):
                            // Cache promptVersion from first done event per session
                            if let promptVersion, self.cachedPromptVersion == nil {
                                self.cachedPromptVersion = promptVersion
                            }

                            let assistantMessage = Message(
                                id: UUID(),
                                sessionId: session.id,
                                role: .assistant,
                                content: self.streamingText,
                                timestamp: Date()
                            )

                            do {
                                try await dbManager.dbPool.write { db in
                                    try assistantMessage.save(db)
                                }
                            } catch {
                                self.handleError(error)
                            }

                            self.messages.append(assistantMessage)
                            self.coachExpression = CoachExpression(mood: mood)
                            self.streamingText = ""
                            self.isStreaming = false

                            if let level = SafetyLevel(rawValue: safetyLevel) {
                                await self.updateSessionSafetyLevel(level)
                            }
                        }
                    }

                    if self.isStreaming {
                        self.isStreaming = false
                    }
                } catch {
                    self.isStreaming = false
                    self.streamingText = ""
                    self.handleError(error)
                }
            }
        } catch {
            isStreaming = false
            handleError(error)
        }
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        streamingText = ""
    }

    private func loadChatProfile() async throws -> ChatProfile? {
        let userProfile: UserProfile? = try await databaseManager.dbPool.read { db in
            try UserProfile.current().fetchOne(db)
        }
        guard let userProfile else { return nil }
        return ChatProfile(coachName: userProfile.coachName)
    }

    private func getOrCreateSession() async throws -> ConversationSession {
        if let session = currentSession {
            return session
        }

        let existing: ConversationSession? = try await databaseManager.dbPool.read { db in
            try ConversationSession.order(Column("startedAt").desc).fetchOne(db)
        }

        if let existing, existing.endedAt == nil {
            currentSession = existing
            return existing
        }

        return try await createNewSession()
    }

    private func createNewSession() async throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: cachedPromptVersion ?? "1.0"
        )

        try await databaseManager.dbPool.write { db in
            try session.save(db)
        }

        currentSession = session
        return session
    }

    private func updateSessionSafetyLevel(_ level: SafetyLevel) async {
        guard var session = currentSession else { return }
        session.safetyLevel = level
        let updatedSession = session
        do {
            try await databaseManager.dbPool.write { db in
                try updatedSession.update(db)
            }
            currentSession = updatedSession
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        guard let appError = error as? AppError else {
            localError = .providerError(message: "Something unexpected happened.", retryAfter: nil)
            return
        }

        switch appError {
        case .authExpired:
            appState.needsReauth = true
        case .networkUnavailable:
            appState.isOnline = false
        case .providerError(_, let retryAfter):
            localError = appError
            if let retryAfter, retryAfter > 0 {
                startRetryAfterTimer(seconds: retryAfter)
            }
        case .databaseError:
            localError = appError
        default:
            localError = appError
        }
    }

    private func startRetryAfterTimer(seconds: Int) {
        retryAfterTask?.cancel()
        retryAfterSeconds = seconds
        retryAfterTask = Task { [weak self] in
            guard let self else { return }
            for i in stride(from: seconds, through: 0, by: -1) {
                if Task.isCancelled { break }
                self.retryAfterSeconds = i
                if i > 0 {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            self.retryAfterSeconds = 0
        }
    }
}
