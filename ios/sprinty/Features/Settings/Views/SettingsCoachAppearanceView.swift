import SwiftUI

struct SettingsCoachAppearanceView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showConfirmation = false

    private let options = AvatarOptions.coachOptions

    var body: some View {
        VStack(spacing: theme.spacing.sectionGap) {
            Text("Your Coach's Look")
                .homeTitleStyle()
                .foregroundStyle(theme.palette.textPrimary)

            coachOptionsLayout

            if showConfirmation {
                Text("Same coach, new look")
                    .font(theme.typography.insightTextFont.weight(theme.typography.insightTextWeight))
                    .lineSpacing(theme.typography.insightTextLineSpacing)
                    .foregroundStyle(theme.palette.textSecondary)
                    .accessibilityLabel("Same coach, new look")
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Your Coach")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var coachOptionsLayout: some View {
        if dynamicTypeSize >= .accessibility3 {
            VStack(spacing: theme.spacing.dialogueTurn) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    coachButton(for: option, index: index)
                }
            }
        } else {
            HStack(spacing: theme.spacing.dialogueTurn) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    coachButton(for: option, index: index)
                }
            }
        }
    }

    private func coachButton(for option: (id: String, name: String, hint: String), index: Int) -> some View {
        let isSelected = viewModel.coachAppearanceId == option.id

        return Button {
            guard viewModel.coachAppearanceId != option.id else { return }
            let newCoachName: String? = {
                if AvatarOptions.defaultCoachNames.contains(viewModel.coachName) || viewModel.coachName.isEmpty {
                    return option.name
                }
                return nil
            }()

            if reduceMotion {
                viewModel.updateCoachAppearance(option.id, newCoachName: newCoachName)
                showConfirmation = true
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.updateCoachAppearance(option.id, newCoachName: newCoachName)
                    showConfirmation = true
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.id)
                    .font(.system(size: 40))
                    .foregroundStyle(theme.palette.textPrimary)
                    .frame(width: 72, height: 72)
                    .background(
                        Circle()
                            .fill(theme.palette.insightBackground)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? theme.palette.avatarGlow : .clear, lineWidth: 3)
                            .shadow(color: isSelected ? theme.palette.avatarGlow : .clear, radius: 8)
                    )

                Text(option.name)
                    .insightTextStyle()
                    .foregroundStyle(theme.palette.textPrimary)

                Text(option.hint)
                    .sprintLabelStyle()
                    .foregroundStyle(theme.palette.textSecondary)
            }
        }
        .frame(minWidth: theme.spacing.minTouchTarget, minHeight: theme.spacing.minTouchTarget)
        .accessibilityLabel("Coach option \(index + 1) of \(options.count)")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        SettingsCoachAppearanceView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
}

#Preview("Dark") {
    NavigationStack {
        SettingsCoachAppearanceView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
    .preferredColorScheme(.dark)
}
#endif
