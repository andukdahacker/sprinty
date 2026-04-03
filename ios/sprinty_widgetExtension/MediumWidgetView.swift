import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: SprintyWidgetEntry

    @Environment(\.colorScheme) private var colorScheme

    private var assetName: String {
        AvatarOptions.assetName(for: entry.avatarId, state: entry.avatarState)
    }

    private var primaryText: Color {
        colorScheme == .dark ? WidgetColors.textPrimaryDark : WidgetColors.textPrimary
    }

    private var secondaryText: Color {
        colorScheme == .dark ? WidgetColors.textSecondaryDark : WidgetColors.textSecondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .saturation(entry.avatarState.saturationMultiplier)

            if entry.hasActiveSprint {
                sprintInfoView
            } else {
                noSprintView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(colorScheme == .dark ? WidgetColors.backgroundDark : WidgetColors.backgroundLight)
        }
        .widgetURL(URL(string: "sprinty://coach")!)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sprint progress")
        .accessibilityValue(accessibilityDescription)
    }

    private var sprintInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.sprintName)
                .font(.headline)
                .foregroundStyle(primaryText)
                .lineLimit(1)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(WidgetColors.sprintTrack)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(
                            LinearGradient(
                                colors: [WidgetColors.sprintProgressStart, WidgetColors.sprintProgressEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(max(entry.sprintProgress, 0), 1), height: 5)
                }
            }
            .frame(height: 5)
            .opacity(entry.isPaused ? 0.4 : 1.0)

            if entry.isPaused {
                Text("Your coach is here when you're ready")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            } else if let nextAction = entry.nextActionTitle {
                Text("Next: \(nextAction)")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private var noSprintView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.isPaused {
                Text("Your coach is here when you're ready")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
            } else {
                Text("Talk to your coach")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(primaryText)
            }
        }
    }

    private var accessibilityDescription: String {
        if entry.hasActiveSprint {
            return "Step \(entry.currentStep) of \(entry.totalSteps), \(entry.sprintName)"
        }
        return "No active sprint"
    }
}

struct SprintyMediumWidget: Widget {
    let kind = "SprintyMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SprintyTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Sprint Dashboard")
        .description("See your avatar, sprint progress, and next action.")
        .supportedFamilies([.systemMedium])
    }
}
