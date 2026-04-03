import SwiftUI

struct PendingMessageIndicator: View {
    let isPending: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isPending {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Pending")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .transition(reduceMotion ? .identity : .opacity.animation(.easeOut(duration: 0.25)))
            .accessibilityLabel("Message pending, will send when online")
        }
    }
}

#if DEBUG
#Preview("Pending — Light") {
    VStack(spacing: 16) {
        PendingMessageIndicator(isPending: true)
        PendingMessageIndicator(isPending: false)
    }
    .preferredColorScheme(.light)
}

#Preview("Pending — Dark") {
    VStack(spacing: 16) {
        PendingMessageIndicator(isPending: true)
        PendingMessageIndicator(isPending: false)
    }
    .preferredColorScheme(.dark)
}
#endif
