import SwiftUI

struct AvatarSelectionView: View {
    let selectedAvatarId: String?
    let onSelect: (String) -> Void
    let onConfirm: () -> Void

    @Environment(\.coachingTheme) private var theme

    private let avatarOptions = AvatarOptions.avatarOptions

    var body: some View {
        VStack(spacing: theme.spacing.sectionGap) {
            Spacer()

            Text("This is you")
                .homeTitleStyle()
                .foregroundStyle(theme.palette.textPrimary)

            HStack(spacing: theme.spacing.dialogueTurn) {
                ForEach(avatarOptions, id: \.id) { option in
                    avatarButton(for: option)
                }
            }

            if selectedAvatarId != nil {
                confirmButton
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentColumn()
    }

    private func avatarButton(for option: (id: String, name: String)) -> some View {
        let isSelected = selectedAvatarId == option.id

        return Button {
            onSelect(option.id)
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
        .accessibilityLabel(option.name)
        .accessibilityHint("Double tap to select")
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Text("Continue")
                .primaryButtonStyle()
                .foregroundStyle(theme.palette.primaryActionText)
                .frame(maxWidth: .infinity)
                .frame(height: theme.spacing.minTouchTarget)
                .background(
                    LinearGradient(
                        colors: [theme.palette.primaryActionStart, theme.palette.primaryActionEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.button))
        }
        .accessibilityLabel("Continue")
        .padding(.horizontal, 40)
    }
}

#Preview {
    AvatarSelectionView(
        selectedAvatarId: "person.circle.fill",
        onSelect: { _ in },
        onConfirm: {}
    )
    .background(
        LinearGradient(
            colors: [ColorPalette.homeLight.backgroundStart, ColorPalette.homeLight.backgroundEnd],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    )
}
