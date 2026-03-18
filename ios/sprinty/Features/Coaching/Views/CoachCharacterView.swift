import SwiftUI

struct CoachCharacterView: View {
    let expression: CoachExpression
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var portraitSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 80 : 100
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.palette.coachPortraitGradientStart, theme.palette.coachPortraitGradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: portraitSize, height: portraitSize)

                Image(systemName: expression.sfSymbolName)
                    .font(.system(size: portraitSize * 0.5))
                    .foregroundStyle(.white)
                    .id(expression)
                    .transition(.opacity)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: expression)
            }

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
