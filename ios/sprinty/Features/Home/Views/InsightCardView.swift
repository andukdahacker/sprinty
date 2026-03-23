import SwiftUI

struct InsightCardView: View {
    let content: String
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        Text(content)
            .font(theme.typography.insightTextFont.weight(theme.typography.insightTextWeight))
            .lineSpacing(theme.typography.insightTextLineSpacing)
            .foregroundStyle(theme.palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.insightPadding)
            .background(theme.palette.insightBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.container))
            .accessibilityLabel("Coach insight: \(content)")
    }
}

#if DEBUG
#Preview("With Insight") {
    InsightCardView(content: "You've been making great progress on career goals this week.")
        .padding()
}

#Preview("Fallback Text") {
    InsightCardView(content: "Your coach is getting to know you...")
        .padding()
}

#Preview("Pause Mode") {
    InsightCardView(content: "Your coach is here when you're ready.")
        .padding()
}
#endif
