import SwiftUI

struct CoachCharacterView: View {
    let expression: CoachExpression
    var coachAppearanceId: String = "coach_sage"
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var portraitSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 80 : 100
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(expression.assetName(for: coachAppearanceId))
                .resizable()
                .scaledToFill()
                .frame(width: portraitSize, height: portraitSize)
                .clipShape(Circle())
                .id(expression)
                .transition(.opacity)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: expression)

            Text("Your Coach")
                .coachNameStyle()
                .foregroundStyle(theme.palette.coachNameText)

            if !expression.statusText.isEmpty {
                Text(expression.statusText)
                    .coachStatusStyle()
                    .foregroundStyle(theme.palette.coachStatusText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your coach")
        .accessibilityValue(expression.rawValue)
    }
}
