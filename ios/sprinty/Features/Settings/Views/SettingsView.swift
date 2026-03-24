import SwiftUI

struct SettingsView: View {
    @Bindable var memoryViewModel: MemoryViewModel
    @State private var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(memoryViewModel: MemoryViewModel, databaseManager: DatabaseManager) {
        self.memoryViewModel = memoryViewModel
        self._viewModel = State(initialValue: SettingsViewModel(databaseManager: databaseManager))
    }

    private var theme: CoachingTheme {
        themeFor(context: .home, colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        SettingsAvatarSelectionView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(viewModel.avatarId)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                            Text("Your Avatar")
                        }
                    }

                    NavigationLink {
                        SettingsCoachAppearanceView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(viewModel.coachAppearanceId)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                            Text(viewModel.coachName)
                                .insightTextStyle()
                        }
                    }
                } header: {
                    Text("Appearance")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                }

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
            .task {
                await viewModel.loadProfile()
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    SettingsView(memoryViewModel: .preview(), databaseManager: SettingsViewModel.previewDB())
        .environment(AppState())
}

#Preview("Dark") {
    SettingsView(memoryViewModel: .preview(), databaseManager: SettingsViewModel.previewDB())
        .environment(AppState())
        .preferredColorScheme(.dark)
}
#endif
