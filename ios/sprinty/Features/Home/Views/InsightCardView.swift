import SwiftUI

struct InsightCardView: View {
    let content: String
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Coach Insight")
                .font(theme.typography.sprintLabelFont.weight(theme.typography.sprintLabelWeight))
                .lineSpacing(theme.typography.sprintLabelLineSpacing)
                .foregroundStyle(theme.palette.textSecondary)

            Text(content)
                .font(theme.typography.insightTextFont.weight(theme.typography.insightTextWeight))
                .lineSpacing(theme.typography.insightTextLineSpacing)
                .foregroundStyle(theme.palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.insightPadding)
        .background(theme.palette.insightBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.container))
        .accessibilityLabel("Coach insight: \(content)")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: content)
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

#Preview("Long Insight") {
    InsightCardView(content: "You showed great resilience when discussing the challenges at work today. Your willingness to explore different perspectives is a real strength.")
        .padding()
}
#endif
