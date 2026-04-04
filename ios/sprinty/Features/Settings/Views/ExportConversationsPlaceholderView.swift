import SwiftUI

struct ExportConversationsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.coachingTheme) private var theme
    @State private var showShareSheet = false

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    headerSection
                    statusSection
                    emptyStateSection
                    exportButton
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
        .navigationTitle("Export Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.checkHasConversations()
        }
        .onChange(of: viewModel.exportFileURL) { _, newValue in
            showShareSheet = newValue != nil
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            viewModel.exportFileURL = nil
        }) {
            if let url = viewModel.exportFileURL {
                ShareSheetView(activityItems: [url]) { completed in
                    if completed {
                        viewModel.exportSuccessMessage = "Your conversation belongs to you"
                    }
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        Text("Export Conversations")
            .sectionHeadingStyle()
            .foregroundStyle(theme.palette.textPrimary)
            .accessibilityAddTraits(.isHeader)

        Text("Your coaching conversations are yours. Export them as a readable file you can save, share, or keep as a personal record of your journey.")
            .font(theme.typography.insightTextFont)
            .foregroundStyle(theme.palette.textSecondary)
            .lineSpacing(theme.typography.insightTextLineSpacing)
    }

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isExporting {
            exportingView
        } else if let successMessage = viewModel.exportSuccessMessage {
            successView(message: successMessage)
        } else if viewModel.exportError != nil {
            errorView
        }
    }

    @ViewBuilder
    private var emptyStateSection: some View {
        if !viewModel.hasConversations {
            Text("No conversations yet. Start a coaching conversation and come back when you're ready to export.")
                .font(theme.typography.insightTextFont)
                .foregroundStyle(theme.palette.textSecondary)
                .lineSpacing(theme.typography.insightTextLineSpacing)
        }
    }

    private var exportingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Preparing your conversation...")
                .font(theme.typography.insightTextFont)
                .foregroundStyle(theme.palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing your conversation for export")
        .onAppear {
            AccessibilityNotification.Announcement("Preparing your conversation for export").post()
        }
    }

    private func successView(message: String) -> some View {
        Text(message)
            .font(theme.typography.insightTextFont)
            .foregroundStyle(theme.palette.primaryActionStart)
            .onAppear {
                AccessibilityNotification.Announcement(message).post()
            }
    }

    private var errorView: some View {
        Text("Couldn't prepare your export. Try again in a moment.")
            .font(theme.typography.insightTextFont)
            .foregroundStyle(.red)
            .onAppear {
                AccessibilityNotification.Announcement("Couldn't prepare your export").post()
            }
    }

    private var exportButton: some View {
        let isEnabled = viewModel.hasConversations && !viewModel.isExporting
        return Button {
            Task { [weak viewModel] in
                await viewModel?.exportConversations()
            }
        } label: {
            Text("Export My Conversations")
                .font(theme.typography.insightTextFont.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isEnabled ? theme.palette.primaryActionStart : theme.palette.primaryActionStart.opacity(0.4))
                )
        }
        .disabled(!isEnabled)
        .accessibilityLabel("Export my conversations")
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onCompletion: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onCompletion?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        ExportConversationsView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
}

#Preview("Dark") {
    NavigationStack {
        ExportConversationsView(viewModel: SettingsViewModel(databaseManager: SettingsViewModel.previewDB()))
    }
    .preferredColorScheme(.dark)
}
#endif
