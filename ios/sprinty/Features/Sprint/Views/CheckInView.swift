import SwiftUI

struct CheckInView: View {
    @Bindable var viewModel: CheckInViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var theme: CoachingTheme {
        themeFor(context: .conversation, colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.homeElement) {
                Spacer()

                if viewModel.coachResponse.isEmpty && viewModel.isStreaming {
                    ProgressView()
                        .accessibilityLabel("Your coach is thinking")
                } else if !viewModel.coachResponse.isEmpty {
                    Text(viewModel.coachResponse)
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, theme.spacing.screenMargin(for: 390))
                        .accessibilityLabel("Coach says: \(viewModel.coachResponse)")
                }

                Spacer()

                if viewModel.isComplete {
                    Button {
                        Task {
                            await viewModel.saveCheckIn()
                            dismiss()
                        }
                    } label: {
                        Text("Done")
                            .font(theme.typography.sectionHeadingFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.palette.primaryActionStart)
                    .padding(.horizontal, theme.spacing.screenMargin(for: 390))
                    .accessibilityLabel("Close check-in")
                }

                if let error = viewModel.localError {
                    Text(error)
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(.red)
                        .padding(.horizontal, theme.spacing.screenMargin(for: 390))
                }
            }
            .padding(.bottom, theme.spacing.sectionGap)
            .background(
                LinearGradient(
                    colors: [theme.palette.backgroundStart, theme.palette.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.cancelStreaming()
                        dismiss()
                    }
                }
            }
        }
        .environment(\.coachingTheme, theme)
        .task {
            viewModel.startCheckIn()
        }
    }
}

#if DEBUG
#Preview("Streaming") {
    CheckInView(viewModel: .preview(coachResponse: "You're showing up, and that matters...", isStreaming: true))
        .environment(AppState())
}

#Preview("Complete") {
    CheckInView(viewModel: .preview(coachResponse: "You're showing up, and that matters. Keep that momentum going.", isComplete: true))
        .environment(AppState())
}
#endif
