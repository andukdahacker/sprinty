import SwiftUI

struct SprintDetailView: View {
    @Bindable var viewModel: SprintDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let margin = theme.spacing.screenMargin(for: geometry.size.width)

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.homeElement) {
                        headerSection
                            .accessibilitySortPriority(4)

                        expandedProgressSection
                            .accessibilitySortPriority(3)

                        stepsSection
                            .accessibilitySortPriority(2)

                        if viewModel.sprint?.status == .complete {
                            retroSection
                                .accessibilitySortPriority(1)
                        }
                    }
                    .padding(.horizontal, margin)
                    .padding(.vertical, theme.spacing.homeElement)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let sprint = viewModel.sprint {
                Text(sprint.name)
                    .sectionHeadingStyle()
                    .foregroundStyle(theme.palette.textPrimary)

                Text(timelineText(for: sprint))
                    .sprintLabelStyle()
                    .foregroundStyle(theme.palette.textSecondary)
            }
        }
    }

    private var expandedProgressSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.homeElement) {
            SprintProgressView(
                progress: viewModel.progress,
                currentStep: viewModel.completedCount,
                totalSteps: viewModel.steps.count,
                isMuted: false,
                dayNumber: viewModel.dayNumber,
                totalDays: viewModel.totalDays
            )

            // Step node labels — tappable per AC3
            if !viewModel.steps.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                        Button {
                            Task {
                                await viewModel.toggleStep(step, reduceMotion: reduceMotion)
                            }
                        } label: {
                            stepNodeLabel(step: step, index: index)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Step \(step.order): \(String(step.description.prefix(30)))")
                        .accessibilityValue(step.completed ? "Completed" : "Not completed")
                        .accessibilityHint("Double tap to mark \(step.completed ? "incomplete" : "complete")")
                    }
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.steps) { step in
                SprintStepRow(
                    step: step,
                    theme: theme,
                    reduceMotion: reduceMotion,
                    onToggle: {
                        Task {
                            await viewModel.toggleStep(step, reduceMotion: reduceMotion)
                        }
                    }
                )
            }
        }
    }

    private var retroSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.homeElement) {
            Text("Your Journey")
                .sectionHeadingStyle()
                .foregroundStyle(theme.palette.textPrimary)

            if let retroText = viewModel.sprint?.narrativeRetro {
                Text(retroText)
                    .coachVoiceStyle()
                    .foregroundStyle(theme.palette.textSecondary)
                    .accessibilityLabel("Sprint retrospective from your coach: \(retroText)")
            } else {
                Text("Here's the chapter we just finished...")
                    .coachVoiceStyle()
                    .foregroundStyle(theme.palette.textSecondary)
                    .opacity(viewModel.isGeneratingRetro ? 0.5 : 1.0)
                    .animation(
                        viewModel.isGeneratingRetro && !reduceMotion
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .none,
                        value: viewModel.isGeneratingRetro
                    )
            }
        }
        .accessibilitySortPriority(1)
        .transition(.opacity)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: viewModel.sprint?.status)
    }

    // MARK: - Helpers

    private func timelineText(for sprint: Sprint) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: sprint.startDate)
        let end = formatter.string(from: sprint.endDate)
        return "Day \(viewModel.dayNumber) of \(viewModel.totalDays) \u{2022} \(start) – \(end)"
    }

    private func stepNodeLabel(step: SprintStep, index: Int) -> some View {
        let isCompleted = step.completed
        let isCurrent = index == viewModel.completedCount
        let label = String(step.description.prefix(30))

        return VStack(spacing: 4) {
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundStyle(theme.palette.sprintProgressStart)
            } else if isCurrent {
                Circle()
                    .fill(theme.palette.sprintProgressStart)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .stroke(theme.palette.sprintTrack, lineWidth: 1)
                    .frame(width: 6, height: 6)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(isCompleted ? theme.palette.textSecondary : (isCurrent ? theme.palette.textPrimary : theme.palette.textSecondary))
                .fontWeight(isCurrent ? .bold : .regular)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

#if DEBUG
#Preview("Active Sprint") {
    let sprint = Sprint(
        id: UUID(),
        name: "Career Growth",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!,
        status: .active
    )
    let steps = (1...5).map { i in
        SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Step \(i): Do something important",
            completed: i <= 2,
            completedAt: i <= 2 ? Date() : nil,
            order: i,
            coachContext: "This step builds momentum toward your goal"
        )
    }
    let vm = SprintDetailViewModel.preview(sprint: sprint, steps: steps)
    return SprintDetailView(viewModel: vm)
}

#Preview("Completed Sprint") {
    let sprint = Sprint(
        id: UUID(),
        name: "Mindfulness Sprint",
        startDate: Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!,
        endDate: Date(),
        status: .complete
    )
    let steps = (1...3).map { i in
        SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Step \(i): Completed task",
            completed: true,
            completedAt: Date(),
            order: i,
            coachContext: "Great progress here"
        )
    }
    let vm = SprintDetailViewModel.preview(sprint: sprint, steps: steps)
    return SprintDetailView(viewModel: vm)
}

#Preview("Nil Coach Context") {
    let sprint = Sprint(
        id: UUID(),
        name: "Quick Sprint",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!,
        status: .active
    )
    let steps = (1...3).map { i in
        SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Step \(i)",
            completed: false,
            completedAt: nil,
            order: i,
            coachContext: nil
        )
    }
    let vm = SprintDetailViewModel.preview(sprint: sprint, steps: steps)
    return SprintDetailView(viewModel: vm)
}
#endif
