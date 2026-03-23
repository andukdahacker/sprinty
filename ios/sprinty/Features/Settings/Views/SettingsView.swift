import SwiftUI

struct SettingsView: View {
    @Bindable var memoryViewModel: MemoryViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var theme: CoachingTheme {
        themeFor(context: .home, colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("What Your Coach Knows") {
                        MemoryView(viewModel: memoryViewModel)
                    }
                } header: {
                    Text("Your Coach")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                }

                Section {
                    Text("Your data stays on your phone. You can export or delete everything anytime.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                } header: {
                    Text("Privacy")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
#Preview("Light") {
    SettingsView(memoryViewModel: .preview())
        .environment(AppState())
}

#Preview("Dark") {
    SettingsView(memoryViewModel: .preview())
        .environment(AppState())
        .preferredColorScheme(.dark)
}
#endif
