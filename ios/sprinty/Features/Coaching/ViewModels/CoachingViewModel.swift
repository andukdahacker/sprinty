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
    private(set) var memoryReferencedMessages: [UUID: Bool] = [:]
    var coachAppearanceId: String = "coach_sage"
    var dailyGreeting: String?
    private(set) var summariesBySession: [UUID: ConversationSummary] = [:]
    private(set) var hasMoreHistory: Bool = true
    private(set) var isLoadingHistory: Bool = false

    // MARK: - Sprint Proposal State
    var sprintProposal: SprintProposalData?

    // MARK: - Search State
    var isSearchActive: Bool = false
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []
    var currentResultIndex: Int = 0
    private(set) var hasSearched: Bool = false
    private(set) var lastVisibleMessageId: UUID?
    private var preSearchMessageId: UUID?
    private var searchTask: Task<Void, Never>?

    private let appState: AppState
    private let chatService: ChatServiceProtocol
    private let databaseManager: DatabaseManager
    private var streamingTask: Task<Void, Never>?
    private var currentSession: ConversationSession?
    private var retryAfterTask: Task<Void, Never>?
    private var cachedPromptVersion: String?
    private var historyPageSize: Int = 50
    private var historyOffset: Int = 0

    private let embeddingPipeline: EmbeddingPipelineProtocol?
    private let profileUpdateService: ProfileUpdateServiceProtocol?
    private let profileEnricher: ProfileEnricherProtocol?
    private let searchService: SearchServiceProtocol?
    private let sprintService: SprintServiceProtocol?

    init(appState: AppState, chatService: ChatServiceProtocol, databaseManager: DatabaseManager, embeddingPipeline: EmbeddingPipelineProtocol? = nil, profileUpdateService: ProfileUpdateServiceProtocol? = nil, profileEnricher: ProfileEnricherProtocol? = nil, searchService: SearchServiceProtocol? = nil, sprintService: SprintServiceProtocol? = nil) {
        self.appState = appState
        self.chatService = chatService
        self.databaseManager = databaseManager
        self.embeddingPipeline = embeddingPipeline
        self.profileUpdateService = profileUpdateService
        self.profileEnricher = profileEnricher
        self.searchService = searchService
        self.sprintService = sprintService
    }

    func loadMessages() {
        Task {
            await loadMessagesAsync()
        }
    }

    func loadMessagesAsync() async {
        do {
            // Load coach appearance from user profile
            let profile: UserProfile? = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            if let profile {
                coachAppearanceId = profile.coachAppearanceId.isEmpty ? "coach_sage" : profile.coachAppearanceId
            }

            // Load existing session if available — do NOT create one just for browsing history
            let existingSession: ConversationSession? = try await databaseManager.dbPool.read { db in
                try ConversationSession.order(Column("startedAt").desc).fetchOne(db)
            }
            if let session = existingSession, session.endedAt == nil {
                currentSession = session
                coachingMode = session.mode
                modeSegments = [ModeSegment(mode: session.mode, messageIndex: 0)]
            }

            let pageSize = historyPageSize
            let loaded = try await databaseManager.dbPool.read { db in
                // Load newest messages first (reverse chronological), then reverse for display
                try Message.allConversations(limit: pageSize, offset: 0).fetchAll(db)
            }
            messages = loaded.reversed()
            historyOffset = loaded.count
            hasMoreHistory = loaded.count == pageSize

            // Batch-load summaries for session IDs in this page
            let sessionIds = Array(Set(messages.map(\.sessionId)))
            let summaries = try await databaseManager.dbPool.read { db in
                try ConversationSummary.forSessionIds(sessionIds).fetchAll(db)
            }
            for summary in summaries {
                summariesBySession[summary.sessionId] = summary
            }
        } catch {
            handleError(error)
        }
    }

    func loadHistoryPage() async {
        guard hasMoreHistory, !isLoadingHistory else { return }
        isLoadingHistory = true

        do {
            let pageSize = historyPageSize
            let offset = historyOffset
            let older = try await databaseManager.dbPool.read { db in
                try Message.allConversations(limit: pageSize, offset: offset).fetchAll(db)
            }

            guard !older.isEmpty else {
                hasMoreHistory = false
                isLoadingHistory = false
                return
            }

            // Reverse to chronological order, prepend
            let chronological = older.reversed()
            messages.insert(contentsOf: chronological, at: 0)
            historyOffset += older.count
            hasMoreHistory = older.count == pageSize

            // Batch-load summaries for new session IDs
            let newSessionIds = Array(Set(chronological.map(\.sessionId)).subtracting(summariesBySession.keys))
            if !newSessionIds.isEmpty {
                let summaries = try await databaseManager.dbPool.read { db in
                    try ConversationSummary.forSessionIds(newSessionIds).fetchAll(db)
                }
                for summary in summaries {
                    summariesBySession[summary.sessionId] = summary
                }
            }
        } catch {
            handleError(error)
        }

        isLoadingHistory = false
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

            // Only send current session messages to API (not full history)
            let currentSessionMessages = messages.filter { $0.sessionId == session.id }
            let chatMessages = currentSessionMessages.map { msg in
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

            // Retrieve RAG context (non-blocking — errors fall back to nil)
            let ragContext = await retrieveRAGContext(for: text, lastSessionGapHours: userState?.lastSessionGapHours)

            let sprintCtx = await buildSprintContext()
            let stream = chatService.streamChat(messages: chatMessages, mode: session.mode.rawValue, profile: profile, userState: userState, ragContext: ragContext, sprintContext: sprintCtx)
            let dbManager = databaseManager

            streamingTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await event in stream {
                        if Task.isCancelled { break }

                        switch event {
                        case .token(let tokenText):
                            self.streamingText += tokenText
                        case .sprintProposal(let proposal):
                            self.sprintProposal = proposal
                        case .done(let safetyLevel, _, let mood, let mode, let memoryReferenced, let challengerUsed, _, let promptVersion, let profileUpdate):
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
                            if memoryReferenced == true {
                                self.memoryReferencedMessages[assistantMessage.id] = true
                            }
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

                            if let profileUpdate, let profileUpdateService = self.profileUpdateService {
                                Task { [weak self] in
                                    guard let self else { return }
                                    do {
                                        let profileId = try await self.databaseManager.dbPool.read { db in
                                            try UserProfile.current().fetchOne(db)?.id
                                        }
                                        if let profileId {
                                            try await profileUpdateService.applyUpdate(profileUpdate, to: profileId)
                                        }
                                    } catch {
                                        Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "profile")
                                            .error("Profile update failed: \(error)")
                                    }
                                }
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

    // MARK: - Sprint Proposal Actions

    func confirmSprint() async {
        guard let proposal = sprintProposal, let sprintService else {
            sprintProposal = nil
            return
        }
        do {
            let sprint = try await sprintService.createSprint(from: proposal, durationWeeks: proposal.durationWeeks)
            appState.activeSprint = sprint
            sprintProposal = nil
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "sprint")
                .error("Sprint creation failed: \(error)")
            streamingText = "I had trouble saving that. Let me try again."
        }
    }

    func declineSprint() async {
        guard let proposal = sprintProposal, let sprintService else {
            sprintProposal = nil
            return
        }
        let pending = PendingSprintProposal(
            name: proposal.name,
            steps: proposal.steps
        )
        do {
            try sprintService.savePendingProposal(pending)
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "sprint")
                .error("Failed to save pending proposal: \(error)")
        }
        sprintProposal = nil
    }

    private func buildSprintContext() async -> SprintContext? {
        guard let sprintService else { return nil }
        let now = Date()
        var activeInfo: ActiveSprintInfo?
        if let result = try? await sprintService.activeSprint() {
            let completed = result.steps.filter(\.completed).count
            let dayNumber = max(1, (Calendar.current.dateComponents([.day], from: result.sprint.startDate, to: now).day ?? 0) + 1)
            let totalDays = max(1, (Calendar.current.dateComponents([.day], from: result.sprint.startDate, to: result.sprint.endDate).day ?? 0) + 1)
            activeInfo = ActiveSprintInfo(
                name: result.sprint.name,
                status: result.sprint.status.rawValue,
                stepsCompleted: completed,
                stepsTotal: result.steps.count,
                dayNumber: dayNumber,
                totalDays: totalDays
            )
        }
        let pending = sprintService.loadPendingProposal()
        if activeInfo == nil && pending == nil { return nil }
        return SprintContext(activeSprint: activeInfo, pendingProposal: pending)
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

            if let profileEnricher {
                do {
                    try await profileEnricher.enrich(from: summary)
                } catch {
                    Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "profile")
                        .error("Profile enrichment failed for summary \(summary.id): \(error)")
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
        return ChatProfile(
            coachName: userProfile.coachName,
            values: userProfile.decodedValues,
            goals: userProfile.decodedGoals,
            personalityTraits: userProfile.decodedPersonalityTraits,
            domainStates: userProfile.decodedDomainStates
        )
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

    // MARK: - Daily Greeting

    func generateDailyGreeting() async {
        let fallback = "What's on your mind?"

        do {
            let greeting: String = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await self.buildGreetingFromSummaries()
                }
                group.addTask {
                    try await Task.sleep(for: .milliseconds(500))
                    throw GreetingTimeoutError()
                }

                if let result = try await group.next() {
                    group.cancelAll()
                    return result
                }
                return fallback
            }
            dailyGreeting = greeting
        } catch {
            dailyGreeting = fallback
        }
    }

    private nonisolated func buildGreetingFromSummaries() async throws -> String {
        let summaries: [ConversationSummary] = try await databaseManager.dbPool.read { db in
            try ConversationSummary.recent(limit: 7).fetchAll(db)
        }

        guard !summaries.isEmpty else { return "What's on your mind?" }

        let mostRecent = summaries[0]
        let now = Date()
        let hoursSinceLastSession = now.timeIntervalSince(mostRecent.createdAt) / 3600

        // Gap-aware (> 72 hours)
        if hoursSinceLastSession > 72 {
            return "It's been a few days — what's been on your mind?"
        }

        // Topic-based (default, when key moments available)
        let moments = mostRecent.decodedKeyMoments
        if let firstMoment = moments.first {
            return "Last time we talked about \(firstMoment). How's that going?"
        }

        // Emotion-based (when emotional markers available but no key moments)
        if let markers = mostRecent.decodedEmotionalMarkers, let first = markers.first {
            return "You seemed \(first) last time — how are things now?"
        }

        return "What's on your mind?"
    }

    // MARK: - Search

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        hasSearched = false
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await self.performSearch(query)
        }
    }

    func performSearch(_ query: String) async {
        guard let searchService else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            currentResultIndex = 0
            hasSearched = true
            return
        }

        do {
            let results = try await searchService.search(query: trimmed)
            searchResults = results
            currentResultIndex = 0
            hasSearched = true
        } catch {
            searchResults = []
            currentResultIndex = 0
            hasSearched = true
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "search")
                .error("Search failed: \(error)")
        }
    }

    func navigateToResult(direction: SearchNavigationDirection) {
        guard !searchResults.isEmpty else { return }
        switch direction {
        case .next:
            currentResultIndex = (currentResultIndex + 1) % searchResults.count
        case .previous:
            currentResultIndex = (currentResultIndex - 1 + searchResults.count) % searchResults.count
        }
    }

    func activateSearch() {
        preSearchMessageId = lastVisibleMessageId
        isSearchActive = true
    }

    func dismissSearch() {
        isSearchActive = false
        searchQuery = ""
        searchResults = []
        currentResultIndex = 0
        hasSearched = false
        searchTask?.cancel()
        searchTask = nil
    }

    func trackVisibleMessage(_ messageId: UUID) {
        lastVisibleMessageId = messageId
    }

    var preSearchScrollTarget: UUID? {
        preSearchMessageId
    }

    // MARK: - RAG Context Retrieval

    private nonisolated func retrieveRAGContext(for query: String, lastSessionGapHours: Int?) async -> String? {
        guard let embeddingPipeline else { return nil }

        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "rag")
        do {
            let summaries = try await embeddingPipeline.search(query: query, limit: 5)
            guard !summaries.isEmpty else { return nil }

            let reranked = applyRecencyWeighting(summaries)
            var formatted = formatRAGContext(reranked, lastSessionGapHours: lastSessionGapHours)
            formatted = enforceTokenBudget(formatted, entries: reranked, lastSessionGapHours: lastSessionGapHours)
            return formatted.isEmpty ? nil : formatted
        } catch {
            logger.error("RAG retrieval failed: \(error)")
            return nil
        }
    }

    private nonisolated func applyRecencyWeighting(_ summaries: [ConversationSummary]) -> [ConversationSummary] {
        let now = Date()
        let thirtyDays: TimeInterval = 30 * 24 * 3600

        let scored = summaries.enumerated().map { index, summary -> (summary: ConversationSummary, score: Double) in
            let normalizedDistance = Double(index) / max(Double(summaries.count - 1), 1.0)
            let semanticScore = 1.0 - normalizedDistance

            let age = now.timeIntervalSince(summary.createdAt)
            let recencyBonus = max(0.0, 1.0 - (age / thirtyDays))

            let combined = semanticScore * 0.7 + recencyBonus * 0.3
            return (summary: summary, score: combined)
        }

        return scored.sorted { $0.score > $1.score }.map { $0.summary }
    }

    private nonisolated func formatRAGContext(_ summaries: [ConversationSummary], lastSessionGapHours: Int?) -> String {
        var lines: [String] = ["## Past Conversations (most relevant)"]

        if let gap = lastSessionGapHours, gap > 72 {
            let days = gap / 24
            lines.append("")
            lines.append("User returning after \(days) days away.")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for summary in summaries {
            lines.append("")
            let dateStr = dateFormatter.string(from: summary.createdAt)
            let tags = summary.decodedDomainTags.joined(separator: ", ")
            lines.append("**\(dateStr)** — \(tags)")
            lines.append("Summary: \(summary.summary)")
            let moments = summary.decodedKeyMoments
            if !moments.isEmpty {
                lines.append("Key moments: \(moments.joined(separator: ", "))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private nonisolated func enforceTokenBudget(_ formatted: String, entries: [ConversationSummary], lastSessionGapHours: Int?) -> String {
        let budget = 4000
        if formatted.count <= budget { return formatted }

        // Drop least-relevant entries (from the end) until under budget
        var trimmed = entries
        while trimmed.count > 1 {
            trimmed.removeLast()
            let candidate = formatRAGContext(trimmed, lastSessionGapHours: lastSessionGapHours)
            if candidate.count <= budget { return candidate }
        }
        // Even 1 entry — return it regardless
        return formatRAGContext(trimmed, lastSessionGapHours: lastSessionGapHours)
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

private struct GreetingTimeoutError: Error {}

// MARK: - Preview Helpers

#if DEBUG
extension CoachingViewModel {
    @MainActor
    static func previewInstance() -> CoachingViewModel {
        let dbPool = try! DatabasePool(path: NSTemporaryDirectory() + "preview_\(UUID().uuidString).sqlite")
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try! migrator.migrate(dbPool)
        let dbManager = DatabaseManager(dbPool: dbPool)
        let appState = AppState()
        return CoachingViewModel(appState: appState, chatService: PreviewChatService(), databaseManager: dbManager)
    }

    @MainActor
    static func previewSearchInstance(query: String, results: [SearchResult]) -> CoachingViewModel {
        let vm = previewInstance()
        vm.isSearchActive = true
        vm.searchQuery = query
        vm.searchResults = results
        return vm
    }
}

private struct PreviewChatService: ChatServiceProtocol {
    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState?, ragContext: String?, sprintContext: SprintContext? = nil) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func summarize(messages: [ChatRequestMessage]) async throws -> SummaryResponse {
        SummaryResponse(summary: "Preview", keyMoments: [], domainTags: [], emotionalMarkers: nil, keyDecisions: nil)
    }
}
#endif
