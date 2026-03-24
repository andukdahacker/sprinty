import SwiftUI

struct SettingsAvatarSelectionView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let options = AvatarOptions.avatarOptions

    var body: some View {
        VStack(spacing: theme.spacing.sectionGap) {
            Text("This is you")
                .homeTitleStyle()
                .foregroundStyle(theme.palette.textPrimary)

            optionsLayout
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Your Avatar")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var optionsLayout: some View {
        if dynamicTypeSize >= .accessibility3 {
            VStack(spacing: theme.spacing.dialogueTurn) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    avatarButton(for: option, index: index)
                }
            }
        } else {
            HStack(spacing: theme.spacing.dialogueTurn) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    avatarButton(for: option, index: index)
                }
            }
        }
    }

    private func avatarButton(for option: (id: String, name: String), index: Int) -> some View {
        let isSelected = viewModel.avatarId == option.id

        return Button {
            guard viewModel.avatarId != option.id else { return }
            if reduceMotion {
                viewModel.updateAvatar(option.id)
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.updateAvatar(option.id)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: option.id)
                    .font(.system(size: 48))
                    .foregroundStyle(theme.palette.textPrimary)
                    .frame(width: 80, height: 80)
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
                    .coachStatusStyle()
                    .foregroundStyle(theme.palette.textSecondary)
            }
        }
        .frame(minWidth: theme.spacing.minTouchTarget, minHeight: theme.spacing.minTouchTarget)
        .accessibilityLabel("Avatar option \(index + 1) of \(options.count)")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        SettingsAvatarSelectionView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
}

#Preview("Dark") {
    NavigationStack {
        SettingsAvatarSelectionView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
    .preferredColorScheme(.dark)
}
#endif
