import SwiftUI

struct SearchOverlayView: View {
    @Bindable var viewModel: CoachingViewModel
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        if viewModel.isSearchActive {
            expandedView
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        } else if !viewModel.isStreaming {
            collapsedView
                .transition(reduceMotion ? .opacity : .opacity)
        }
    }

    private var collapsedView: some View {
        Button {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                viewModel.activateSearch()
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.palette.coachStatusText)
                .padding(8)
        }
        .accessibilityLabel("Search conversation history")
        .accessibilityHint("Double tap to search past messages")
    }

    private var expandedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(theme.palette.coachStatusText)

            TextField("Search conversation history", text: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.updateSearchQuery($0) }
            ))
            .textFieldStyle(.plain)
            .font(.callout)
            .foregroundStyle(theme.palette.textPrimary)
            .focused($isFieldFocused)
            .accessibilityLabel("Search conversation history")
            .submitLabel(.search)

            if !viewModel.searchResults.isEmpty {
                resultNavigationView
            } else if viewModel.hasSearched && !viewModel.searchQuery.isEmpty && viewModel.searchQuery.count >= 2 {
                Text("No matches. Try asking your coach.")
                    .font(.caption)
                    .foregroundStyle(theme.palette.coachStatusText)
                    .lineLimit(1)
                    .accessibilityLabel("No matches found. Try asking your coach.")
            }

            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                    viewModel.dismissSearch()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.palette.coachStatusText)
                    .padding(4)
            }
            .accessibilityLabel("Dismiss search")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.palette.backgroundEnd.opacity(0.8))
                .stroke(theme.palette.inputBorder, lineWidth: 1)
        )
        .onAppear {
            isFieldFocused = true
        }
        .onChange(of: viewModel.searchResults.count) {
            let count = viewModel.searchResults.count
            let announcement = count == 0 ? "No matches found" : "\(count) results found"
            AccessibilityNotification.Announcement(announcement).post()
        }
        .onChange(of: viewModel.currentResultIndex) {
            guard !viewModel.searchResults.isEmpty else { return }
            let announcement = "Result \(viewModel.currentResultIndex + 1) of \(viewModel.searchResults.count)"
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    private var resultNavigationView: some View {
        HStack(spacing: 4) {
            let current = viewModel.currentResultIndex + 1
            let total = viewModel.searchResults.count
            Text("Result \(current) of \(total)")
                .font(.caption)
                .foregroundStyle(theme.palette.coachStatusText)
                .lineLimit(1)
                .accessibilityLabel("Result \(current) of \(total)")

            Button {
                viewModel.navigateToResult(direction: .previous)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.palette.coachStatusText)
                    .padding(4)
            }
            .accessibilityLabel("Previous result")

            Button {
                viewModel.navigateToResult(direction: .next)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.palette.coachStatusText)
                    .padding(4)
            }
            .accessibilityLabel("Next result")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Collapsed") {
    let theme = themeFor(context: .conversation, colorScheme: .light)
    VStack {
        SearchOverlayView(viewModel: CoachingViewModel.previewInstance())
    }
    .padding()
    .background(theme.palette.backgroundStart)
    .environment(\.coachingTheme, theme)
}

#Preview("Expanded with results") {
    let theme = themeFor(context: .conversation, colorScheme: .light)
    let vm = CoachingViewModel.previewSearchInstance(
        query: "career",
        results: [
            SearchResult(messageId: UUID(), sessionId: UUID(), content: "career goals", timestamp: Date()),
            SearchResult(messageId: UUID(), sessionId: UUID(), content: "career growth", timestamp: Date())
        ]
    )
    VStack {
        SearchOverlayView(viewModel: vm)
    }
    .padding()
    .background(theme.palette.backgroundStart)
    .environment(\.coachingTheme, theme)
}

#Preview("Expanded empty") {
    let theme = themeFor(context: .conversation, colorScheme: .light)
    let vm = CoachingViewModel.previewSearchInstance(query: "nonexistent", results: [])
    VStack {
        SearchOverlayView(viewModel: vm)
    }
    .padding()
    .background(theme.palette.backgroundStart)
    .environment(\.coachingTheme, theme)
}

#Preview("Accessibility XL") {
    let theme = themeFor(context: .conversation, colorScheme: .light)
    let vm = CoachingViewModel.previewSearchInstance(
        query: "career",
        results: [
            SearchResult(messageId: UUID(), sessionId: UUID(), content: "career goals", timestamp: Date()),
            SearchResult(messageId: UUID(), sessionId: UUID(), content: "career growth", timestamp: Date())
        ]
    )
    VStack {
        SearchOverlayView(viewModel: vm)
    }
    .padding()
    .background(theme.palette.backgroundStart)
    .environment(\.coachingTheme, theme)
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
