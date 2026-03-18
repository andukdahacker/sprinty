import SwiftUI

struct CoachNamingView: View {
    let selectedCoachAppearanceId: String?
    let coachName: String
    let onSelectAppearance: (String) -> Void
    let onUpdateName: (String) -> Void
    let onConfirm: () -> Void

    @Environment(\.coachingTheme) private var theme

    private let coachOptions: [(id: String, name: String, hint: String)] = [
        ("person.circle.fill", "Sage", "Warm and encouraging"),
        ("brain.head.profile", "Mentor", "Focused and direct"),
        ("leaf.circle.fill", "Guide", "Calm and grounding"),
    ]

    var body: some View {
        VStack(spacing: theme.spacing.sectionGap) {
            Spacer()

            Text("Meet your coach")
                .homeTitleStyle()
                .foregroundStyle(theme.palette.textPrimary)

            HStack(spacing: theme.spacing.dialogueTurn) {
                ForEach(coachOptions, id: \.id) { option in
                    coachButton(for: option)
                }
            }

            nameField

            if selectedCoachAppearanceId != nil {
                confirmButton
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentColumn()
    }

    private func coachButton(for option: (id: String, name: String, hint: String)) -> some View {
        let isSelected = selectedCoachAppearanceId == option.id

        return Button {
            onSelectAppearance(option.id)
            if coachName == "Sage" || coachName == "Mentor" || coachName == "Guide" || coachName.isEmpty {
                onUpdateName(option.name)
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
                    .coachNameStyle()
                    .foregroundStyle(theme.palette.textPrimary)

                Text(option.hint)
                    .coachStatusStyle()
                    .foregroundStyle(theme.palette.textSecondary)
            }
        }
        .frame(minWidth: theme.spacing.minTouchTarget, minHeight: theme.spacing.minTouchTarget)
        .accessibilityLabel("\(option.name), \(option.hint)")
        .accessibilityHint("Double tap to select")
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var nameField: some View {
        TextField("", text: Binding(
            get: { coachName },
            set: { onUpdateName($0) }
        ))
        .textFieldStyle(.plain)
        .multilineTextAlignment(.center)
        .coachVoiceStyle()
        .foregroundStyle(theme.palette.textPrimary)
        .padding(.horizontal, 20)
        .frame(height: theme.spacing.minTouchTarget)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius.input)
                .stroke(theme.palette.inputBorder, lineWidth: 1)
        )
        .padding(.horizontal, 40)
        .accessibilityLabel("Name your coach")
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
    CoachNamingView(
        selectedCoachAppearanceId: "person.circle.fill",
        coachName: "Sage",
        onSelectAppearance: { _ in },
        onUpdateName: { _ in },
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
