import SwiftUI

struct SettingsView: View {
    @Bindable var memoryViewModel: MemoryViewModel
    @State private var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(memoryViewModel: MemoryViewModel, databaseManager: DatabaseManager, appState: AppState, notificationService: CheckInNotificationServiceProtocol? = nil, notificationScheduler: NotificationSchedulerProtocol? = nil) {
        self.memoryViewModel = memoryViewModel
        let exportService = ConversationExportService(dbPool: databaseManager.dbPool)
        let dataDeletionService = DataDeletionService(
            dbPool: databaseManager.dbPool,
            notificationScheduler: notificationScheduler
        )
        self._viewModel = State(initialValue: SettingsViewModel(
            databaseManager: databaseManager,
            notificationService: notificationService,
            notificationScheduler: notificationScheduler,
            exportService: exportService,
            dataDeletionService: dataDeletionService,
            appState: appState
        ))
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
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    NavigationLink("What Your Coach Knows") {
                        MemoryView(viewModel: memoryViewModel)
                    }
                } header: {
                    Text("Your Coach")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
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
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    Text("Your data stays on your phone. You can export or delete everything anytime.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)

                    NavigationLink("Coaching Disclaimer") {
                        CoachingDisclaimerView()
                    }
                    .accessibilityLabel("View coaching disclaimer")

                    NavigationLink("Privacy Information") {
                        PrivacyInformationView()
                    }
                    .accessibilityLabel("View privacy information")

                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                    .accessibilityLabel("View terms of service")

                    NavigationLink("Export Conversations") {
                        ExportConversationsView(viewModel: viewModel)
                    }
                    .accessibilityLabel("Export your conversations")

                    NavigationLink("Delete All Data") {
                        DeleteAllDataView(viewModel: viewModel)
                    }
                    .accessibilityLabel("Delete all your data")
                } header: {
                    Text("Privacy")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                            .foregroundStyle(theme.palette.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("App version \(viewModel.appVersion), build \(viewModel.buildNumber)")

                    NavigationLink("Acknowledgments") {
                        AcknowledgmentsView()
                    }
                    .accessibilityLabel("View acknowledgments")

                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                    .accessibilityLabel("View terms of service")

                    NavigationLink("Privacy Policy") {
                        PrivacyInformationView()
                    }
                    .accessibilityLabel("View privacy policy")
                } header: {
                    Text("About")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
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
    SettingsView(memoryViewModel: .preview(), databaseManager: SettingsViewModel.previewDB(), appState: AppState())
        .environment(AppState())
}

#Preview("Dark") {
    SettingsView(memoryViewModel: .preview(), databaseManager: SettingsViewModel.previewDB(), appState: AppState())
        .environment(AppState())
        .preferredColorScheme(.dark)
}
#endif
