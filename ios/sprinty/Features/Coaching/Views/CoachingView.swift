import SwiftUI

struct CoachingView: View {
    @Bindable var viewModel: CoachingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var inputText = ""

    private var conversationTheme: CoachingTheme {
        var theme = themeFor(context: .conversation, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)
            .applyingAmbientMode(viewModel.coachingMode, colorScheme: colorScheme)
        if viewModel.challengerActive {
            theme = theme.applyingChallengerShift(colorScheme: colorScheme)
        }
        return theme
    }

    var body: some View {
        GeometryReader { geometry in
            let margin = SpacingScale().screenMargin(for: geometry.size.width)

            VStack(spacing: 0) {
                CoachCharacterView(expression: viewModel.coachExpression, coachAppearanceId: viewModel.coachAppearanceId)
                    .padding(.bottom, conversationTheme.spacing.coachCharacterBottom)

                SearchOverlayView(viewModel: viewModel)
                    .padding(.horizontal, margin)
                    .padding(.bottom, 4)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: conversationTheme.spacing.dialogueTurn) {
                            if let greeting = viewModel.dailyGreeting, viewModel.messages.isEmpty || shouldShowDateSeparator(at: 0) {
                                DateSeparatorView(date: Date())
                                DialogueTurnView(content: greeting, role: .assistant)
                            }

                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                // Scroll-triggered pagination: load more when near top (single trigger at index 0)
                                if index == 0 {
                                    Color.clear
                                        .frame(height: 0)
                                        .onAppear {
                                            if viewModel.hasMoreHistory && !viewModel.isLoadingHistory {
                                                let anchorId = viewModel.messages.first?.id
                                                Task {
                                                    let countBefore = viewModel.messages.count
                                                    await viewModel.loadHistoryPage()
                                                    if viewModel.messages.count > countBefore, let anchorId {
                                                        proxy.scrollTo(anchorId, anchor: .top)
                                                    }
                                                }
                                            }
                                        }
                                }

                                // Summary card for previous session at session boundary
                                if isSessionBoundary(at: index) {
                                    let previousSessionId = viewModel.messages[index - 1].sessionId
                                    if let summary = viewModel.summariesBySession[previousSessionId] {
                                        SessionSummaryCardView(summary: summary)
                                    }
                                }

                                if shouldShowDateSeparator(at: index) {
                                    DateSeparatorView(date: message.timestamp)
                                }

                                DialogueTurnView(
                                    content: message.content,
                                    role: message.role,
                                    memoryReferenced: viewModel.memoryReferencedMessages[message.id] == true,
                                    highlightQuery: viewModel.isSearchActive ? viewModel.searchQuery : nil,
                                    isCurrentResult: isCurrentSearchResult(messageId: message.id)
                                )
                                .id(message.id)
                                .onAppear {
                                    viewModel.trackVisibleMessage(message.id)
                                }
                            }

                            if viewModel.isStreaming && !viewModel.streamingText.isEmpty {
                                DialogueTurnView(content: viewModel.streamingText, role: .assistant)
                                    .id("streaming")
                            }
                        }
                        .padding(.horizontal, margin)
                        .contentColumn()
                    }
                    .onChange(of: viewModel.messages.count) {
                        if !viewModel.isLoadingHistory {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onChange(of: viewModel.streamingText) {
                        if viewModel.isStreaming {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.currentResultIndex) {
                        scrollToCurrentSearchResult(proxy: proxy)
                    }
                    .onChange(of: viewModel.searchResults.count) {
                        if !viewModel.searchResults.isEmpty {
                            scrollToCurrentSearchResult(proxy: proxy)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.isSearchActive) {
                        if !viewModel.isSearchActive, let target = viewModel.preSearchScrollTarget {
                            proxy.scrollTo(target, anchor: .center)
                        }
                    }
                }

                if let localError = viewModel.localError {
                    errorView(for: localError)
                        .padding(.horizontal, margin)
                }

                TextInputView(
                    text: $inputText,
                    isDisabled: viewModel.isStreaming,
                    onSend: sendMessage
                )
                .padding(.horizontal, margin)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [conversationTheme.palette.backgroundStart, conversationTheme.palette.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .environment(\.coachingTheme, conversationTheme)
        .animation(
            UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.4),
            value: viewModel.coachingMode
        )
        .animation(
            UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.4),
            value: viewModel.challengerActive
        )
        .task {
            await viewModel.loadMessagesAsync()
            await viewModel.generateDailyGreeting()
            await viewModel.retryMissingSummaries()
            await viewModel.retryMissingEmbeddings()
        }
        .onDisappear {
            viewModel.cancelStreaming()
            Task {
                await viewModel.endSession()
            }
        }
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        Task {
            await viewModel.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func isCurrentSearchResult(messageId: UUID) -> Bool {
        guard viewModel.isSearchActive, !viewModel.searchResults.isEmpty else { return false }
        return viewModel.searchResults[viewModel.currentResultIndex].messageId == messageId
    }

    private func scrollToCurrentSearchResult(proxy: ScrollViewProxy) {
        guard !viewModel.searchResults.isEmpty else { return }
        let targetId = viewModel.searchResults[viewModel.currentResultIndex].messageId

        // Check if message is already loaded
        if viewModel.messages.contains(where: { $0.id == targetId }) {
            withAnimation {
                proxy.scrollTo(targetId, anchor: .center)
            }
        } else {
            // Load pagination until found
            Task {
                while viewModel.hasMoreHistory {
                    await viewModel.loadHistoryPage()
                    if viewModel.messages.contains(where: { $0.id == targetId }) {
                        proxy.scrollTo(targetId, anchor: .center)
                        break
                    }
                }
            }
        }
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index]
        let previous = viewModel.messages[index - 1]
        // Show separator at session boundaries (even same day) or different days
        if current.sessionId != previous.sessionId { return true }
        return !Calendar.current.isDate(current.timestamp, inSameDayAs: previous.timestamp)
    }

    private func isSessionBoundary(at index: Int) -> Bool {
        guard index > 0 else { return false }
        return viewModel.messages[index].sessionId != viewModel.messages[index - 1].sessionId
    }

    private func errorView(for error: AppError) -> some View {
        HStack {
            Image(systemName: "cloud.sun")
                .foregroundStyle(conversationTheme.palette.coachStatusText)
            Text(errorMessage(for: error))
                .coachStatusStyle()
                .foregroundStyle(conversationTheme.palette.coachStatusText)
        }
        .padding(.vertical, 8)
    }

    private func errorMessage(for error: AppError) -> String {
        switch error {
        case .providerError(let message, _):
            return message
        case .databaseError:
            return "Something went wrong saving your conversation."
        default:
            return "Something unexpected happened."
        }
    }
}

// MARK: - Ambient Mode Previews

#if DEBUG
private struct AmbientModePreview: View {
    let mode: CoachingMode
    let colorScheme: ColorScheme

    var body: some View {
        let base = themeFor(context: .conversation, colorScheme: colorScheme)
        let themed = base.applyingAmbientMode(mode, colorScheme: colorScheme)
        VStack {
            Text("\(mode.rawValue.capitalized) — \(colorScheme == .dark ? "Dark" : "Light")")
                .font(.headline)
                .foregroundStyle(themed.palette.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [themed.palette.backgroundStart, themed.palette.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

#Preview("Discovery Ambient — Light") {
    AmbientModePreview(mode: .discovery, colorScheme: .light)
        .environment(\.colorScheme, .light)
}

#Preview("Discovery Ambient — Dark") {
    AmbientModePreview(mode: .discovery, colorScheme: .dark)
        .environment(\.colorScheme, .dark)
}

#Preview("Directive Ambient — Light") {
    AmbientModePreview(mode: .directive, colorScheme: .light)
        .environment(\.colorScheme, .light)
}

#Preview("Directive Ambient — Dark") {
    AmbientModePreview(mode: .directive, colorScheme: .dark)
        .environment(\.colorScheme, .dark)
}

private struct ChallengerAmbientPreview: View {
    let mode: CoachingMode
    let colorScheme: ColorScheme

    var body: some View {
        let base = themeFor(context: .conversation, colorScheme: colorScheme)
        let themed = base.applyingAmbientMode(mode, colorScheme: colorScheme)
            .applyingChallengerShift(colorScheme: colorScheme)
        VStack {
            Text("Challenger + \(mode.rawValue.capitalized) — \(colorScheme == .dark ? "Dark" : "Light")")
                .font(.headline)
                .foregroundStyle(themed.palette.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [themed.palette.backgroundStart, themed.palette.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

#Preview("Challenger Ambient — Light") {
    ChallengerAmbientPreview(mode: .discovery, colorScheme: .light)
        .environment(\.colorScheme, .light)
}

#Preview("Challenger Ambient — Dark") {
    ChallengerAmbientPreview(mode: .discovery, colorScheme: .dark)
        .environment(\.colorScheme, .dark)
}
#endif
