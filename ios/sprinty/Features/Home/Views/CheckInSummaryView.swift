import SwiftUI

struct CheckInSummaryView: View {
    let summary: String
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        Text(summary)
            .font(theme.typography.insightTextFont.weight(theme.typography.insightTextWeight))
            .lineSpacing(theme.typography.insightTextLineSpacing)
            .foregroundStyle(theme.palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Latest check-in: \(summary)")
    }
}

#if DEBUG
#Preview("Check-in Summary") {
    CheckInSummaryView(summary: "Yesterday you reflected on balancing work deadlines with personal time.")
        .padding()
}
#endif
