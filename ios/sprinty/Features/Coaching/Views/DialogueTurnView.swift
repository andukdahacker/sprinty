import SwiftUI

struct DialogueTurnView: View {
    let content: String
    let role: MessageRole
    var memoryReferenced: Bool = false
    var highlightQuery: String? = nil
    var isCurrentResult: Bool = false
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
                if let query = highlightQuery, !query.isEmpty {
                    Text(highlightedText(paragraph, query: query))
                } else {
                    Text(paragraph)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let searchStr = text.lowercased()
        let queryLower = query.lowercased()
        var searchStart = searchStr.startIndex

        while let range = searchStr.range(of: queryLower, range: searchStart..<searchStr.endIndex) {
            if let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
               let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[attrStart..<attrEnd].backgroundColor = isCurrentResult
                    ? theme.palette.userAccent.opacity(0.4)
                    : theme.palette.userAccent.opacity(0.15)
            }
            searchStart = range.upperBound
        }

        return attributed
    }
}
