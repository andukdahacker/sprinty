import SwiftUI

struct DeleteAllDataView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.coachingTheme) private var theme

    /// Two-step flow within the destination: explanation → type-DELETE confirmation.
    @State private var showTypeConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    if viewModel.dataDeletionCompleted {
                        farewellSection
                    } else if showTypeConfirmation {
                        typeConfirmationSection
                    } else {
                        explanationSection
                    }
                }
                .padding(.horizontal, margin)
                .padding(.top, theme.spacing.sectionGap)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [theme.palette.backgroundStart, theme.palette.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .navigationTitle("Delete All Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step 1: Explanation

    @ViewBuilder
    private var explanationSection: some View {
        Text("We're sorry to see you go")
            .sectionHeadingStyle()
            .foregroundStyle(theme.palette.textPrimary)
            .accessibilityAddTraits(.isHeader)

        Text("This will remove everything — your conversations, what your coach has learned about you, your sprints, and all preferences.")
            .font(theme.typography.insightTextFont)
            .foregroundStyle(theme.palette.textSecondary)
            .lineSpacing(theme.typography.insightTextLineSpacing)

        VStack(alignment: .leading, spacing: 8) {
            bullet("All coaching conversations")
            bullet("Memories and profile your coach built")
            bullet("Sprints, steps, and check-ins")
            bullet("Avatar and preferences")
            bullet("Notification schedule")
        }
        .font(theme.typography.insightTextFont)
        .foregroundStyle(theme.palette.textSecondary)

        Text("Once deleted, there's no way to bring it back. Your data, your choice — always.")
            .font(theme.typography.insightTextFont.weight(.semibold))
            .foregroundStyle(theme.palette.textPrimary)
            .lineSpacing(theme.typography.insightTextLineSpacing)

        Button {
            showTypeConfirmation = true
            AccessibilityNotification.Announcement("Type DELETE to confirm").post()
        } label: {
            Text("Continue")
                .font(theme.typography.insightTextFont.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.palette.primaryActionStart)
                )
        }
        .accessibilityLabel("Continue to confirmation")
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }

    // MARK: - Step 2: Type DELETE

    @ViewBuilder
    private var typeConfirmationSection: some View {
        Text("Type DELETE to confirm")
            .sectionHeadingStyle()
            .foregroundStyle(theme.palette.textPrimary)
            .accessibilityAddTraits(.isHeader)

        Text("To make sure this is really what you want, please type the word DELETE below. This cannot be undone.")
            .font(theme.typography.insightTextFont)
            .foregroundStyle(theme.palette.textSecondary)
            .lineSpacing(theme.typography.insightTextLineSpacing)

        TextField("Type DELETE", text: $viewModel.deletionConfirmationText)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .disabled(viewModel.isDeletingData)
            .accessibilityLabel("Confirmation text field")

        if let error = viewModel.deletionError {
            Text(errorMessage(for: error))
                .font(theme.typography.insightTextFont)
                .foregroundStyle(.red)
                .onAppear {
                    AccessibilityNotification.Announcement(errorMessage(for: error)).post()
                }
        }

        if viewModel.isDeletingData {
            HStack(spacing: 12) {
                ProgressView()
                Text("Deleting your data...")
                    .font(theme.typography.insightTextFont)
                    .foregroundStyle(theme.palette.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Deleting your data")
            .onAppear {
                AccessibilityNotification.Announcement("Deleting your data").post()
            }
        }

        Button(role: .destructive) {
            Task { [weak viewModel] in
                await viewModel?.confirmDataDeletion()
            }
        } label: {
            Text("Delete Everything")
                .font(theme.typography.insightTextFont.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(deleteButtonEnabled ? Color.red : Color.red.opacity(0.4))
                )
        }
        .disabled(!deleteButtonEnabled)
        .accessibilityLabel("Delete everything")

        Button {
            viewModel.cancelDeletion()
            showTypeConfirmation = false
        } label: {
            Text("Cancel")
                .font(theme.typography.insightTextFont)
                .foregroundStyle(theme.palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .disabled(viewModel.isDeletingData)
        .accessibilityLabel("Cancel deletion")
    }

    private var deleteButtonEnabled: Bool {
        viewModel.deletionConfirmationText == "DELETE" && !viewModel.isDeletingData
    }

    private func errorMessage(for error: AppError) -> String {
        "Something went wrong while deleting your data. Please try again in a moment."
    }

    // MARK: - Farewell

    @ViewBuilder
    private var farewellSection: some View {
        Text("Goodbye")
            .sectionHeadingStyle()
            .foregroundStyle(theme.palette.textPrimary)
            .accessibilityAddTraits(.isHeader)

        Text("Your data has been deleted. Take care of yourself.")
            .font(theme.typography.insightTextFont)
            .foregroundStyle(theme.palette.textSecondary)
            .lineSpacing(theme.typography.insightTextLineSpacing)
            .onAppear {
                AccessibilityNotification.Announcement("Your data has been deleted").post()
            }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        DeleteAllDataView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
}

#Preview("Dark") {
    NavigationStack {
        DeleteAllDataView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
    .preferredColorScheme(.dark)
}
#endif
