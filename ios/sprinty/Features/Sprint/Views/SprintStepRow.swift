import SwiftUI

struct SprintStepRow: View {
    let step: SprintStep
    let theme: CoachingTheme
    let reduceMotion: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: step.completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(step.completed ? theme.palette.sprintProgressStart : theme.palette.textSecondary)

                    Text(step.description)
                        .font(.body)
                        .foregroundStyle(theme.palette.textPrimary)
                        .strikethrough(step.completed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let coachContext = step.coachContext {
                    Text(coachContext)
                        .insightTextStyle()
                        .italic()
                        .foregroundStyle(theme.palette.textSecondary)
                        .padding(.leading, 36) // align with text after icon
                        .accessibilityLabel("Your coach says: \(coachContext)")
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: theme.spacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: step.completed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.order): \(step.description)")
        .accessibilityValue(step.completed ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to mark \(step.completed ? "incomplete" : "complete")")
    }
}
