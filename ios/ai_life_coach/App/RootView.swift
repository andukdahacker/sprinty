import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            if appState.isAuthenticated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Authenticated")
                    .font(.headline)
            } else if appState.needsReauth {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Re-authentication needed")
                    .font(.headline)
            } else if !appState.isOnline {
                Image(systemName: "wifi.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("No connection")
                    .font(.headline)
            } else {
                ProgressView()
                Text("Connecting...")
                    .font(.headline)
            }
        }
    }
}
