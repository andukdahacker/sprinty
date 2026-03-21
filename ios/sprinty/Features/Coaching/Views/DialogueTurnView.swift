import SwiftUI

struct DialogueTurnView: View {
    let content: String
    let role: MessageRole
    var memoryReferenced: Bool = false
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        Group {
            switch role {
            case .assistant, .system:
                coachTurn
            case .user:
                userTurn
            }
        }
    }

    private var coachTurn: some View {
        paragraphStack(content)
            .coachVoiceStyle()
            .foregroundStyle(theme.palette.coachDialogue)
            .italic(memoryReferenced)
            .opacity(memoryReferenced ? 0.7 : 1.0)
            .accessibilityLabel("Coach says: \(content)")
            .accessibilityHint(memoryReferenced ? "Referencing a past conversation." : "")
    }

    private var userTurn: some View {
        paragraphStack(content)
            .userVoiceStyle()
            .foregroundStyle(theme.palette.userDialogue)
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(theme.palette.userAccent)
                    .frame(width: 3)
            }
            .accessibilityLabel("You said: \(content)")
    }

    private func paragraphStack(_ text: String) -> some View {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: theme.spacing.dialogueBreath) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
