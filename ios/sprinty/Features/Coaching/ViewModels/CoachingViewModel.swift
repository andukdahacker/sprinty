import Foundation
import Observation
import GRDB
import OSLog

@MainActor
@Observable
final class CoachingViewModel {
    var messages: [Message] = []
    var streamingText: String = ""
    var isStreaming: Bool = false
    var coachExpression: CoachExpression = .welcoming
    var localError: AppError?
    var retryAfterSeconds: Int = 0
    var coachingMode: CoachingMode = .discovery
    var challengerActive: Bool = false
    var modeSegments: [ModeSegment] = []
    private(set) var sessionMoods: [String] = []

    private let appState: AppState
    private let chatService: ChatServiceProtocol
    private let databaseManager: DatabaseManager
    private var streamingTask: Task<Void, Never>?
    private var currentSession: ConversationSession?
    private var retryAfterTask: Task<Void, Never>?
    private var cachedPromptVersion: String?

    private let embeddingPipeline: EmbeddingPipelineProtocol?

    init(appState: AppState, chatService: ChatServiceProtocol, databaseManager: DatabaseManager, embeddingPipeline: EmbeddingPipelineProtocol? = nil) {
        self.appState = appState
        self.chatService = chatService
        self.databaseManager = databaseManager
        self.embeddingPipeline = embeddingPipeline
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
            coachingMode = session.mode
            modeSegments = [ModeSegment(mode: session.mode, messageIndex: 0)]
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

            // Compute engagement snapshot for adaptive tone
            let calculator = EngagementCalculator(dbPool: databaseManager.dbPool)
            let snapshot = try? await calculator.compute()
            let userState = snapshot.map { UserState(from: $0) }

            let stream = chatService.streamChat(messages: chatMessages, mode: session.mode.rawValue, profile: profile, userState: userState)
            let dbManager = databaseManager

            streamingTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await event in stream {
                        if Task.isCancelled { break }

                        switch event {
                        case .token(let tokenText):
                            self.streamingText += tokenText
                        case .done(let safetyLevel, _, let mood, let mode, let challengerUsed, _, let promptVersion):
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
                            if let mood {
                                self.sessionMoods.append(mood)
                                await self.persistMoodHistory()
                            }
                            self.streamingText = ""
                            self.isStreaming = false

                            if let level = SafetyLevel(rawValue: safetyLevel) {
                                await self.updateSessionSafetyLevel(level)
                            }

                            if let mode, let newMode = CoachingMode(rawValue: mode), newMode != self.coachingMode {
                                await self.updateSessionMode(newMode)
                            }

                            self.challengerActive = challengerUsed ?? false
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

    func endSession() async {
        guard let session = currentSession, session.endedAt == nil else { return }
        guard messages.count >= 2 else { return }

        var updated = session
        updated.endedAt = Date()
        let sessionToSave = updated
        do {
            try await databaseManager.dbPool.write { db in
                try sessionToSave.update(db)
            }
        } catch {
            handleError(error)
            return
        }

        let sessionId = session.id
        currentSession = nil

        // Fire-and-forget summary generation
        Task { [weak self] in
            await self?.generateSummary(for: sessionId)
        }
    }

    private nonisolated func generateSummary(for sessionId: UUID) async {
        do {
            let msgs = try await databaseManager.dbPool.read { db in
                try Message.forSession(id: sessionId).fetchAll(db)
            }
            guard msgs.count >= 2 else { return }

            let chatMessages = msgs.map { ChatRequestMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content) }
            let response = try await chatService.summarize(messages: chatMessages)

            let summary = ConversationSummary(
                id: UUID(),
                sessionId: sessionId,
                summary: response.summary,
                keyMoments: ConversationSummary.encodeArray(response.keyMoments),
                domainTags: ConversationSummary.encodeArray(response.domainTags),
                emotionalMarkers: response.emotionalMarkers.map { ConversationSummary.encodeArray($0) },
                keyDecisions: response.keyDecisions.map { ConversationSummary.encodeArray($0) },
                goalReferences: nil,
                embedding: nil,
                createdAt: Date()
            )

            let rowid = try await databaseManager.dbPool.write { db in
                try summary.insert(db)
                return db.lastInsertedRowID
            }

            if let embeddingPipeline {
                do {
                    try await embeddingPipeline.embed(summary: summary, rowid: rowid)
                } catch {
                    Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory")
                        .error("Embedding failed for summary \(summary.id): \(error)")
                }
            }
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory").error("Summary generation failed for session \(sessionId): \(error)")
        }
    }

    func retryMissingEmbeddings() async {
        await embeddingPipeline?.retryMissingEmbeddings()
    }

    func retryMissingSummaries() async {
        do {
            let sessionsWithoutSummaries: [ConversationSession] = try await databaseManager.dbPool.read { db in
                try ConversationSession.fetchAll(db, sql: """
                    SELECT s.* FROM ConversationSession s
                    LEFT JOIN ConversationSummary cs ON cs.sessionId = s.id
                    WHERE s.endedAt IS NOT NULL AND cs.id IS NULL
                    """)
            }

            for session in sessionsWithoutSummaries {
                await generateSummary(for: session.id)
            }
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory").error("Retry missing summaries failed: \(error)")
        }
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

    private func updateSessionMode(_ newMode: CoachingMode) async {
        guard var session = currentSession else { return }
        session.mode = newMode
        modeSegments.append(ModeSegment(mode: newMode, messageIndex: messages.count))
        if let encoded = try? JSONEncoder().encode(modeSegments) {
            session.modeHistory = String(data: encoded, encoding: .utf8)
        }
        let updatedSession = session
        do {
            try await databaseManager.dbPool.write { db in
                try updatedSession.update(db)
            }
            currentSession = updatedSession
            coachingMode = newMode
        } catch {
            handleError(error)
        }
    }

    private func persistMoodHistory() async {
        guard var session = currentSession else { return }
        if let encoded = try? JSONEncoder().encode(sessionMoods) {
            session.moodHistory = String(data: encoded, encoding: .utf8)
        }
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
