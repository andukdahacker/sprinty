import SwiftUI

struct CoachingView: View {
    @Bindable var viewModel: CoachingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var inputText = ""

    private var conversationTheme: CoachingTheme {
        themeFor(context: .conversation, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)
            .applyingAmbientMode(viewModel.coachingMode, colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let margin = SpacingScale().screenMargin(for: geometry.size.width)

            VStack(spacing: 0) {
                CoachCharacterView(expression: viewModel.coachExpression)
                    .padding(.bottom, conversationTheme.spacing.coachCharacterBottom)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: conversationTheme.spacing.dialogueTurn) {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                if shouldShowDateSeparator(at: index) {
                                    DateSeparatorView(date: message.timestamp)
                                }

                                DialogueTurnView(content: message.content, role: message.role)
                                    .id(message.id)
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
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.streamingText) {
                        if viewModel.isStreaming {
                            proxy.scrollTo("streaming", anchor: .bottom)
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
        .task {
            viewModel.loadMessages()
        }
        .onDisappear {
            viewModel.cancelStreaming()
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

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index]
        let previous = viewModel.messages[index - 1]
        return !Calendar.current.isDate(current.timestamp, inSameDayAs: previous.timestamp)
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

#Preview("Directive Ambient — Light (Stub)") {
    AmbientModePreview(mode: .directive, colorScheme: .light)
        .environment(\.colorScheme, .light)
}

#Preview("Directive Ambient — Dark (Stub)") {
    AmbientModePreview(mode: .directive, colorScheme: .dark)
        .environment(\.colorScheme, .dark)
}
#endif
