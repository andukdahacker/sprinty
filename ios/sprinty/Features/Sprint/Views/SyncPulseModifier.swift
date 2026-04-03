import SwiftUI

struct SyncPulseModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.coachingTheme) private var theme
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .background(
                isActive && !reduceMotion
                    ? theme.palette.sprintProgressStart.opacity(isPulsing ? 0.2 : 0)
                    : Color.clear
            )
            .animation(
                isActive && !reduceMotion
                    ? .easeInOut(duration: 0.25)
                    : .none,
                value: isPulsing
            )
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    if !reduceMotion {
                        isPulsing = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            isPulsing = false
                        }
                    }
                    AccessibilityNotification.Announcement("Step synced").post()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(isActive ? "Step synced" : "")
    }
}

#if DEBUG
#Preview("Sync Pulse — Light") {
    VStack(spacing: 12) {
        Text("Step 1: Synced step")
            .padding()
            .modifier(SyncPulseModifier(isActive: true))

        Text("Step 2: Not synced")
            .padding()
            .modifier(SyncPulseModifier(isActive: false))
    }
    .preferredColorScheme(.light)
}

#Preview("Sync Pulse — Dark") {
    VStack(spacing: 12) {
        Text("Step 1: Synced step")
            .padding()
            .modifier(SyncPulseModifier(isActive: true))

        Text("Step 2: Not synced")
            .padding()
            .modifier(SyncPulseModifier(isActive: false))
    }
    .preferredColorScheme(.dark)
}
#endif
