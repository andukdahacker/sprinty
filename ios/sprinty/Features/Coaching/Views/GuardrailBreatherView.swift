import SwiftUI

struct GuardrailBreatherView: View {
    let onTakeBreather: () -> Void
    let onDismiss: () -> Void

    @Environment(\.coachingTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Text("Want to take a breather?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.palette.textPrimary)

            HStack(spacing: 12) {
                Button(action: onTakeBreather) {
                    Text("Take a breather")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.palette.primaryActionStart.opacity(0.15))
                        .foregroundStyle(theme.palette.primaryActionStart)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Take a breather")
                .accessibilityHint("Activates Pause Mode to rest and let today's insights settle")

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.subheadline)
                        .foregroundStyle(theme.palette.textSecondary)
                }
                .accessibilityLabel("Continue chatting")
            }
        }
        .padding()
        .background(theme.palette.insightBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("Light") {
    GuardrailBreatherView(onTakeBreather: {}, onDismiss: {})
        .padding()
}

#Preview("Dark") {
    GuardrailBreatherView(onTakeBreather: {}, onDismiss: {})
        .padding()
        .preferredColorScheme(.dark)
}
#endif
