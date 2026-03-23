import SwiftUI

struct SprintProgressView: View {
    let progress: Double
    let currentStep: Int
    let totalSteps: Int
    let isMuted: Bool
    var sprintName: String = ""
    var dayNumber: Int = 0
    var totalDays: Int = 0

    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.homeElement) {
            if !sprintName.isEmpty {
                Text(sprintName)
                    .sprintLabelStyle()
                    .foregroundStyle(theme.palette.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: theme.cornerRadius.sprintTrack)
                        .fill(theme.palette.sprintTrack)
                        .frame(height: 5)

                    // Progress fill
                    RoundedRectangle(cornerRadius: theme.cornerRadius.sprintTrack)
                        .fill(
                            LinearGradient(
                                colors: [theme.palette.sprintProgressStart, theme.palette.sprintProgressEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 5)

                    // Step marker dots
                    if totalSteps > 0 {
                        stepMarkers(width: geometry.size.width)
                    }
                }
            }
            .frame(height: 6) // 6pt to accommodate marker dots centered on 5pt track
        }
        .opacity(isMuted ? 0.4 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sprint progress")
        .accessibilityValue(voiceOverValue)
    }

    private func stepMarkers(width: CGFloat) -> some View {
        let inset: CGFloat = 4 // half of max marker size to prevent edge clipping
        let usableWidth = max(width - inset * 2, 0)
        return ForEach(0..<totalSteps, id: \.self) { index in
            let position = totalSteps > 1
                ? inset + usableWidth * CGFloat(index) / CGFloat(totalSteps - 1)
                : width / 2
            let isCompleted = index < currentStep
            let isCurrent = index == currentStep
            let markerSize: CGFloat = isCurrent ? 8 : 6

            Circle()
                .fill(isCompleted || isCurrent ? theme.palette.sprintProgressStart : .clear)
                .overlay(
                    Circle()
                        .stroke(
                            isCompleted || isCurrent ? theme.palette.sprintProgressStart : theme.palette.sprintTrack,
                            lineWidth: 1.5
                        )
                )
                .frame(width: markerSize, height: markerSize)
                .position(x: position, y: 3) // centered on 5pt track (midpoint at 2.5, round to 3)
        }
    }

    var voiceOverValue: String {
        let stepPart = "Step \(currentStep) of \(totalSteps)"
        if dayNumber > 0 && totalDays > 0 {
            return "\(stepPart), day \(dayNumber) of \(totalDays)"
        }
        return stepPart
    }
}

#if DEBUG
#Preview("50% Progress") {
    SprintProgressView(
        progress: 0.5, currentStep: 3, totalSteps: 6, isMuted: false,
        sprintName: "Career Growth", dayNumber: 3, totalDays: 7
    )
    .padding()
}

#Preview("Complete") {
    SprintProgressView(
        progress: 1.0, currentStep: 6, totalSteps: 6, isMuted: false,
        sprintName: "Mindfulness Sprint", dayNumber: 7, totalDays: 7
    )
    .padding()
}

#Preview("Muted/Paused") {
    SprintProgressView(
        progress: 0.5, currentStep: 3, totalSteps: 6, isMuted: true,
        sprintName: "Career Growth", dayNumber: 3, totalDays: 7
    )
    .padding()
}

#Preview("No Day Data") {
    SprintProgressView(
        progress: 0.4, currentStep: 2, totalSteps: 5, isMuted: false,
        sprintName: "Quick Sprint"
    )
    .padding()
}
#endif
