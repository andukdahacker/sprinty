import SwiftUI

struct SettingsView: View {
    @Bindable var memoryViewModel: MemoryViewModel
    @State private var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(memoryViewModel: MemoryViewModel, databaseManager: DatabaseManager, notificationService: CheckInNotificationServiceProtocol? = nil, notificationScheduler: NotificationSchedulerProtocol? = nil) {
        self.memoryViewModel = memoryViewModel
        self._viewModel = State(initialValue: SettingsViewModel(databaseManager: databaseManager, notificationService: notificationService, notificationScheduler: notificationScheduler))
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
                    Toggle("Mute coaching notifications", isOn: Binding(
                        get: { viewModel.notificationsMuted },
                        set: { viewModel.updateNotificationsMuted($0) }
                    ))
                    .accessibilityHint("Silences all coaching notifications")

                    Picker("Cadence", selection: Binding(
                        get: { viewModel.checkInCadence },
                        set: { viewModel.updateCheckInCadence($0) }
                    )) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                    }
                    .disabled(viewModel.notificationsMuted)

                    Picker("Time", selection: Binding(
                        get: { viewModel.checkInTimeHour },
                        set: { viewModel.updateCheckInTime($0) }
                    )) {
                        ForEach(6..<22, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .disabled(viewModel.notificationsMuted)

                    if viewModel.checkInCadence == "weekly" {
                        Picker("Check-in day", selection: Binding(
                            get: { viewModel.checkInWeekday ?? 1 },
                            set: { viewModel.updateCheckInWeekday($0) }
                        )) {
                            ForEach(1..<8, id: \.self) { day in
                                Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                            }
                        }
                        .accessibilityLabel("Check-in day")
                        .disabled(viewModel.notificationsMuted)
                    }
                } header: {
                    Text("Notifications")
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

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        guard let date = Calendar.current.date(from: components) else { return "\(hour):00" }
        return formatter.string(from: date)
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
