import SwiftUI

struct SessionSummaryCardView: View {
    let summary: ConversationSummary
    @State private var isExpanded = false
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale().dialogueBreath) {
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Session Summary")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.palette.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(theme.palette.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(summary.summary)
                    .insightTextStyle()
                    .foregroundStyle(theme.palette.textPrimary)

                let moments = summary.decodedKeyMoments
                if !moments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(moments, id: \.self) { moment in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\u{2022}")
                                    .foregroundStyle(theme.palette.textSecondary)
                                Text(moment)
                                    .insightTextStyle()
                                    .foregroundStyle(theme.palette.textPrimary)
                            }
                        }
                    }
                }

                let tags = summary.decodedDomainTags
                if !tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.palette.insightBackground)
                                .clipShape(Capsule())
                                .foregroundStyle(theme.palette.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(theme.palette.insightBackground)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens().container))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    private var accessibilityText: String {
        var text = "Session summary: \(summary.summary)"
        let moments = summary.decodedKeyMoments
        if !moments.isEmpty {
            text += ". Key moments: \(moments.joined(separator: ", "))"
        }
        return text
    }
}

// MARK: - Flow Layout for Domain Tags

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
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
        var totalHeight: CGFloat = 0

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
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Previews

#if DEBUG
private let previewSummary = ConversationSummary(
    id: UUID(),
    sessionId: UUID(),
    summary: "Discussed career transition from engineering to management. Explored fears around loss of technical identity and excitement about mentoring.",
    keyMoments: ConversationSummary.encodeArray(["realized pattern of avoiding leadership", "committed to shadow a manager"]),
    domainTags: ConversationSummary.encodeArray(["career", "personal-growth"]),
    emotionalMarkers: ConversationSummary.encodeArray(["anxious", "hopeful"]),
    keyDecisions: nil,
    goalReferences: nil,
    embedding: nil,
    createdAt: Date()
)

#Preview("Light") {
    SessionSummaryCardView(summary: previewSummary)
        .padding()
        .environment(\.coachingTheme, themeFor(context: .conversation, colorScheme: .light))
}

#Preview("Dark") {
    SessionSummaryCardView(summary: previewSummary)
        .padding()
        .environment(\.colorScheme, .dark)
        .environment(\.coachingTheme, themeFor(context: .conversation, colorScheme: .dark))
}

#Preview("Accessibility XL") {
    SessionSummaryCardView(summary: previewSummary)
        .padding()
        .environment(\.dynamicTypeSize, .xxxLarge)
        .environment(\.coachingTheme, themeFor(context: .conversation, colorScheme: .light))
}
#endif
