import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: SprintyWidgetEntry

    @Environment(\.colorScheme) private var colorScheme

    private var assetName: String {
        AvatarOptions.assetName(for: entry.avatarId, state: entry.avatarState)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .saturation(entry.avatarState.saturationMultiplier)

            if entry.hasActiveSprint {
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
            } else {
                Text("No active sprint")
                    .font(.caption2)
                    .foregroundStyle(colorScheme == .dark ? WidgetColors.textSecondaryDark : WidgetColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(colorScheme == .dark ? WidgetColors.backgroundDark : WidgetColors.backgroundLight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sprint progress")
        .accessibilityValue(entry.hasActiveSprint ? "Step \(entry.currentStep) of \(entry.totalSteps)" : "No active sprint")
    }
}

struct SprintySmallWidget: Widget {
    let kind = "SprintySmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SprintyTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Sprint Progress")
        .description("See your avatar and sprint progress at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
