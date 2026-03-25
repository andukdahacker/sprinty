import SwiftUI

struct SprintProposalView: View {
    let proposal: SprintProposalData
    let onConfirm: () -> Void
    let onDecline: () -> Void

    @Environment(\.coachingTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(proposal.name)
                .coachVoiceEmphasisStyle()
                .foregroundStyle(theme.palette.textPrimary)

            Text("\(proposal.durationWeeks)-week sprint \u{2022} \(proposal.steps.count) steps")
                .insightTextStyle()
                .foregroundStyle(theme.palette.textSecondary)
                .italic()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(proposal.steps.sorted(by: { $0.order < $1.order }), id: \.order) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(step.order).")
                            .coachVoiceStyle()
                            .foregroundStyle(theme.palette.textSecondary)
                            .frame(width: 20, alignment: .trailing)
                        Text(step.description)
                            .coachVoiceStyle()
                            .foregroundStyle(theme.palette.textPrimary)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text("Start this sprint")
                        .primaryButtonStyle()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(theme.palette.sprintProgressStart)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.sprintTrack))
                }
                .accessibilityHint("Starts this sprint")

                Button(action: onDecline) {
                    Text("Not right now")
                        .coachVoiceStyle()
                        .foregroundStyle(theme.palette.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .accessibilityHint("Declines this sprint proposal")
            }
        }
        .padding(16)
        .background(theme.palette.sprintTrack)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.sprintTrack))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sprint proposal: \(proposal.name)")
    }
}
