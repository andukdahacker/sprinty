import SwiftUI

struct AvatarView: View {
    let avatarId: String
    var size: CGFloat = 64

    @Environment(\.coachingTheme) private var theme

    var body: some View {
        Image(avatarId)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: theme.palette.avatarGlow, radius: 8)
            .accessibilityLabel("Your avatar")
            .accessibilityAddTraits(.isImage)
    }
}

#Preview("Light 64pt") {
    AvatarView(avatarId: "avatar_default", size: 64)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .light))
}

#Preview("Dark 56pt SE") {
    AvatarView(avatarId: "avatar_default", size: 56)
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .dark))
}
