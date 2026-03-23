import SwiftUI

struct AvatarView: View {
    let avatarId: String
    var size: CGFloat = 64
    var state: AvatarState = .active

    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(avatarId)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .saturation(state.saturationMultiplier)
            .shadow(color: theme.palette.avatarGlow, radius: 8)
            .id(state)
            .transition(.opacity)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: state)
            .accessibilityLabel("Your avatar")
            .accessibilityValue(state.displayName)
            .accessibilityAddTraits(.isImage)
    }
}

#if DEBUG
#Preview("Active - Light") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .active)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .light))
}

#Preview("Active - Dark") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .active)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .dark))
}

#Preview("Resting - Light") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .resting)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .light))
}

#Preview("Resting - Dark") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .resting)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .dark))
}

#Preview("Celebrating - Light") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .celebrating)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .light))
}

#Preview("Celebrating - Dark") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .celebrating)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .dark))
}

#Preview("Thinking - Light") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .thinking)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .light))
}

#Preview("Thinking - Dark") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .thinking)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .dark))
}

#Preview("Struggling - Light") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .struggling)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .light))
}

#Preview("Struggling - Dark") {
    AvatarView(avatarId: "avatar_default", size: 64, state: .struggling)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .dark))
}
#endif
