import SwiftUI

struct MemoryView: View {
    @Bindable var viewModel: MemoryViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var editingFactId: String?
    @State private var editText: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var memoryToDelete: MemoryItem?

    private var theme: CoachingTheme {
        themeFor(context: .home, colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            Group {
                if viewModel.isEmpty {
                    ScrollView {
                        emptyStateView
                            .padding(.horizontal, margin)
                            .padding(.top, theme.spacing.sectionGap)
                    }
                } else {
                    List {
                        if !viewModel.profileFacts.isEmpty {
                            Section {
                                ForEach(viewModel.profileFacts) { fact in
                                    profileFactRow(fact)
                                        .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: 4, trailing: margin))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing) {
                                            if fact.id != "coachName" {
                                                Button(role: .destructive) {
                                                    Task { await viewModel.deleteProfileFact(fact) }
                                                } label: {
                                                    Label("Forget this", systemImage: "trash")
                                                }
                                                .accessibilityLabel("Forget this")
                                            }
                                        }
                                }
                            } header: {
                                Text("Profile Facts")
                                    .sectionHeadingStyle()
                                    .foregroundStyle(theme.palette.textPrimary)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }

                        if !viewModel.memories.isEmpty {
                            Section {
                                ForEach(viewModel.memories) { memory in
                                    memoryRow(memory)
                                        .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: 4, trailing: margin))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                memoryToDelete = memory
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Forget", systemImage: "trash")
                                            }
                                            .accessibilityLabel("Forget this")
                                        }
                                }
                            } header: {
                                Text("Key Memories")
                                    .sectionHeadingStyle()
                                    .foregroundStyle(theme.palette.textPrimary)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }

                        if !viewModel.domainTags.isEmpty {
                            Section {
                                FlowLayout(spacing: 8) {
                                    ForEach(viewModel.domainTags, id: \.self) { tag in
                                        tagChip(tag)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: 4, trailing: margin))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } header: {
                                Text("Domain Tags")
                                    .sectionHeadingStyle()
                                    .foregroundStyle(theme.palette.textPrimary)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }

                        Section {
                            privacyFooter
                                .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: 4, trailing: margin))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [theme.palette.backgroundStart, theme.palette.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .navigationTitle("What Your Coach Knows")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .alert("Forget this memory?", isPresented: $showDeleteConfirmation, presenting: memoryToDelete) { memory in
            Button("Forget", role: .destructive) {
                Task { await viewModel.deleteMemory(memory) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your coach won't bring this up again.")
        }
    }

    // MARK: - Profile Facts

    @ViewBuilder
    private func profileFactRow(_ fact: ProfileFact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fact.displayLabel)
                .font(theme.typography.insightTextFont.weight(theme.typography.insightTextWeight))
                .foregroundStyle(theme.palette.textSecondary)

            if editingFactId == fact.id {
                HStack {
                    TextField("", text: $editText)
                        .font(theme.typography.coachVoiceFont)
                        .foregroundStyle(theme.palette.textPrimary)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task {
                                await viewModel.updateProfileFact(fact, newValue: editText)
                                editingFactId = nil
                            }
                        }

                    Button("Done") {
                        Task {
                            await viewModel.updateProfileFact(fact, newValue: editText)
                            editingFactId = nil
                        }
                    }
                    .font(theme.typography.sprintLabelFont.weight(.semibold))
                }
            } else {
                Text(fact.value)
                    .font(theme.typography.coachVoiceFont)
                    .foregroundStyle(theme.palette.textPrimary)
                    .accessibilityHint("Double tap to edit")
                    .onTapGesture {
                        editText = fact.value
                        editingFactId = fact.id
                    }
            }
        }
        .padding(theme.spacing.insightPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.insightBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.container))
    }

    // MARK: - Key Memories

    @ViewBuilder
    private func memoryRow(_ memory: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memory.summary)
                .font(theme.typography.coachVoiceFont)
                .foregroundStyle(theme.palette.textPrimary)
                .lineSpacing(theme.typography.coachVoiceLineSpacing)

            if !memory.keyMoments.isEmpty {
                ForEach(memory.keyMoments, id: \.self) { moment in
                    Text("• \(moment)")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                }
            }

            Text(memory.date, style: .date)
                .font(theme.typography.dateSeparatorFont)
                .foregroundStyle(theme.palette.textSecondary)
        }
        .padding(theme.spacing.insightPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.insightBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.container))
    }

    // MARK: - Domain Tags

    @ViewBuilder
    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(theme.typography.sprintLabelFont.weight(theme.typography.sprintLabelWeight))
                .foregroundStyle(theme.palette.textPrimary)

            Button {
                Task { await viewModel.removeDomainTag(tag) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.palette.textSecondary)
            }
            .accessibilityLabel("Remove \(tag)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.palette.insightBackground)
        .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: theme.spacing.homeElement) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(theme.palette.textSecondary)
            Text("Your coach is still learning about you")
                .font(theme.typography.homeTitleFont.weight(theme.typography.homeTitleWeight))
                .foregroundStyle(theme.palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("Start a conversation and your coach will begin building an understanding of who you are.")
                .font(theme.typography.insightTextFont)
                .foregroundStyle(theme.palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Privacy Footer

    private var privacyFooter: some View {
        Text("Your data stays on your phone. You can export or delete everything anytime.")
            .font(theme.typography.dateSeparatorFont)
            .foregroundStyle(theme.palette.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, theme.spacing.homeElement)
    }
}

// MARK: - Flow Layout for Tag Chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Light") {
    NavigationStack {
        MemoryView(viewModel: .preview())
    }
    .environment(AppState())
}

#Preview("Dark") {
    NavigationStack {
        MemoryView(viewModel: .preview())
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Empty State") {
    NavigationStack {
        MemoryView(viewModel: .preview())
    }
    .environment(AppState())
}

#Preview("Accessibility XL") {
    NavigationStack {
        MemoryView(viewModel: .preview())
    }
    .environment(AppState())
    .dynamicTypeSize(.accessibility3)
}
#endif
