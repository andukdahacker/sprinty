import SwiftUI

struct TextInputView: View {
    @Binding var text: String
    let isDisabled: Bool
    let onSend: () -> Void
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("What's on your mind...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius.input)
                        .stroke(theme.palette.inputBorder, lineWidth: 1)
                )
                .foregroundStyle(theme.palette.userDialogue)
                .disabled(isDisabled)
                .accessibilityLabel("Message your coach")

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.palette.sendButton)
            }
            .disabled(isDisabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .frame(minWidth: theme.spacing.minTouchTarget, minHeight: theme.spacing.minTouchTarget)
            .accessibilityLabel("Send message")
        }
        .padding(.top, theme.spacing.inputAreaTop)
    }
}
