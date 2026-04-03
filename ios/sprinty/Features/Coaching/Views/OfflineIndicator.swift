import SwiftUI

enum OfflineIndicatorState: Equatable {
    case online
    case offline
    case reconnecting
    case reconnected
}

struct OfflineIndicator: View {
    let state: OfflineIndicatorState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible: Bool = false

    var body: some View {
        Group {
            if state != .online || isVisible {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.caption2)
                    Text(labelText)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityText)
            }
        }
        .onChange(of: state) { oldValue, newValue in
            switch newValue {
            case .offline, .reconnecting:
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.05)) {
                    isVisible = true
                }
            case .reconnected:
                isVisible = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                        isVisible = false
                    }
                }
            case .online:
                if oldValue == .reconnected {
                    // Already handled by reconnected timer
                } else {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                        isVisible = false
                    }
                }
            }
        }
        .onAppear {
            isVisible = state != .online
        }
    }

    private var iconName: String {
        switch state {
        case .online: "wifi"
        case .offline: "wifi.slash"
        case .reconnecting: "arrow.triangle.2.circlepath"
        case .reconnected: "checkmark.circle"
        }
    }

    private var labelText: String {
        switch state {
        case .online: ""
        case .offline: "Coach offline"
        case .reconnecting: "Reconnecting..."
        case .reconnected: "Back online"
        }
    }

    private var accessibilityText: String {
        switch state {
        case .online: ""
        case .offline: "Coach is offline"
        case .reconnecting: "Reconnecting"
        case .reconnected: "Coach is back online"
        }
    }
}

#if DEBUG
#Preview("Offline — Light") {
    VStack(spacing: 20) {
        OfflineIndicator(state: .offline)
        OfflineIndicator(state: .reconnecting)
        OfflineIndicator(state: .reconnected)
    }
    .preferredColorScheme(.light)
}

#Preview("Offline — Dark") {
    VStack(spacing: 20) {
        OfflineIndicator(state: .offline)
        OfflineIndicator(state: .reconnecting)
        OfflineIndicator(state: .reconnected)
    }
    .preferredColorScheme(.dark)
}
#endif
