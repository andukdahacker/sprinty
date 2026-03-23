import SwiftUI

struct SprintProgressView: View {
    let progress: Double
    let currentStep: Int
    let totalSteps: Int
    let isMuted: Bool

    @Environment(\.coachingTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: theme.cornerRadius.sprintTrack)
                    .fill(theme.palette.sprintTrack)
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: theme.cornerRadius.sprintTrack)
                    .fill(
                        LinearGradient(
                            colors: [theme.palette.sprintProgressStart, theme.palette.sprintProgressEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 5)
            }
        }
        .frame(height: 5)
        .opacity(isMuted ? 0.4 : 1.0)
        .accessibilityLabel("Sprint progress")
        .accessibilityValue("Step \(currentStep) of \(totalSteps)")
    }
}

#if DEBUG
#Preview("50% Progress") {
    SprintProgressView(progress: 0.5, currentStep: 3, totalSteps: 6, isMuted: false)
        .padding()
}

#Preview("Complete") {
    SprintProgressView(progress: 1.0, currentStep: 6, totalSteps: 6, isMuted: false)
        .padding()
}

#Preview("Muted/Paused") {
    SprintProgressView(progress: 0.5, currentStep: 3, totalSteps: 6, isMuted: true)
        .padding()
}
#endif
