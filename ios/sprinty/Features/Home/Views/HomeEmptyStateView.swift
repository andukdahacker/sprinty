import SwiftUI

struct HomeEmptyStateView: View {
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        Text("Your story starts here")
            .font(theme.typography.insightTextFont.weight(theme.typography.insightTextWeight))
            .lineSpacing(theme.typography.insightTextLineSpacing)
            .foregroundStyle(theme.palette.textSecondary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Your story starts here")
    }
}

#if DEBUG
#Preview("Empty State") {
    HomeEmptyStateView()
        .padding()
}
#endif
