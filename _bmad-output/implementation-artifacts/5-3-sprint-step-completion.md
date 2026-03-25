# Story 5.3: Sprint Step Completion

Status: done

## Story

As a user working through a sprint,
I want to mark steps as complete and feel the satisfaction of progress,
So that I stay motivated and see my momentum building.

## Acceptance Criteria

1. **Given** a user taps the completion toggle on a sprint step **When** the step is marked complete **Then** the SprintStep record updates with `completed=true` and `completedAt` timestamp **And** a haptic fires (one of ≤3 types per calm budget UX-DR66) **And** the avatar briefly shifts to celebrating state then returns to active **And** the SprintPathView updates to reflect progress

2. **Given** all steps in a sprint are completed **When** the sprint reaches 100% **Then** the sprint status updates to `.complete` **And** a narrative retro appears in the SprintDetailView summarizing the journey

3. **Given** a step completion triggers celebration **When** the transition rhythm applies (UX-DR78) **Then** Celebration → Challenge waits for a full session boundary (no Challenger in the milestone session)

4. **Given** the step completion animation **When** Reduce Motion is enabled **Then** the celebration animation is skipped (haptic only per UX-DR58)

## Tasks / Subtasks

> **IMPORTANT:** Story 5.2 already implemented core step completion mechanics (toggle, haptic, avatar celebration, SprintPathView update, auto-completion, Reduce Motion). Verify those work correctly, then focus on what's missing below.

- [x] Task 1: Generate narrative retro on sprint completion (AC: 2)
  - [x] 1.1 Add `narrativeRetro: String?` column to Sprint model + migration (v10)
  - [x] 1.2 Inject `ChatServiceProtocol` into `SprintDetailViewModel` — update `init(appState:databaseManager:chatService:)` and wire in `RootView.swift` via `ensureSprintDetailViewModel()`
  - [x] 1.3 Add `handleSprintRetro()` function in `server/handlers/chat.go` — route `mode == "sprint_retro"` before streaming path (same pattern as `handleSummarize`)
  - [x] 1.4 Add `SprintRetroPrompt()` method to `server/prompts/builder.go` — standalone prompt assembly using only `base-persona` + `sprint-retro.md` (skip coaching sections: mood, challenger, mode-transitions, safety, tagging, cultural)
  - [x] 1.5 Create `server/prompts/sections/sprint-retro.md` prompt template
  - [x] 1.6 Add `SprintRetroRequest` struct to carry step descriptions + coachContext to server (see Dev Notes for payload design)
  - [x] 1.7 Implement `generateNarrativeRetro()` in `SprintDetailViewModel` — call BEFORE setting sprint status to `.complete` in `toggleStep()` (see timing fix in Dev Notes)
  - [x] 1.8 Add retro loading state UI: show placeholder text with pulsing opacity animation while streaming, then crossfade to generated text
  - [x] 1.9 Persist generated retro to `Sprint.narrativeRetro` for offline access
  - [x] 1.10 Add VoiceOver for retro section: `accessibilityLabel("Sprint retrospective from your coach")` with `accessibilitySortPriority(1)`

- [x] Task 2: Add celebration milestone context to SprintContext (AC: 3)
  - [x] 2.1 Add `lastStepCompletedAt: Date?` to Sprint model + migration v10 (same migration as 1.1)
  - [x] 2.2 Update `toggleStep()` to persist `lastStepCompletedAt` on the Sprint record when a step is completed
  - [x] 2.3 Add `lastStepCompletedAt: String?` (ISO 8601) and `sprintJustCompleted: Bool?` to `ActiveSprintInfo` (iOS + Go)
  - [x] 2.4 Update `buildSprintContext()` in CoachingViewModel: read `sprint.lastStepCompletedAt` from DB, set `sprintJustCompleted = true` only if sprint status is `.complete` AND `lastStepCompletedAt` is within 1 hour of now
  - [x] 2.5 Update server `builder.go` to inject milestone context into coaching prompt when fields are present
  - [x] 2.6 Update `docs/api-contract.md` with new SprintContext fields

- [x] Task 3: Sprint completion celebration (differentiated from single-step) (AC: 1, 2)
  - [x] 3.1 Add `.medium` haptic for sprint completion vs `.light` for step completion
  - [x] 3.2 Extend avatar celebrating duration for sprint completion (1.2s vs 0.8s for step)
  - [x] 3.3 Add visual sprint completion indicator in SprintDetailView (confetti-free, earned pride)

- [x] Task 4: Unit tests (AC: 1, 2, 3, 4)
  - [x] 4.1 Test narrative retro generation request on sprint completion
  - [x] 4.2 Test retro generation with `MockChatService` — verify mode is `"sprint_retro"` and step descriptions are sent
  - [x] 4.3 Test narrative retro persistence and display from `Sprint.narrativeRetro`
  - [x] 4.4 Test retro generation failure — verify placeholder text remains, `narrativeRetro` stays nil
  - [x] 4.5 Test retro retry on next view when previous generation failed
  - [x] 4.6 Test `lastStepCompletedAt` persisted on Sprint record when step completed
  - [x] 4.7 Test `sprintJustCompleted` is `true` only within 1-hour window, `false`/nil otherwise
  - [x] 4.8 Test differentiated celebration (step vs sprint completion haptic + duration)
  - [x] 4.9 Test Sprint model migration v10 (narrativeRetro + lastStepCompletedAt columns)
  - [x] 4.10 Go: `TestSprintRetroHandler` integration test — verify mode routing and prompt assembly
  - [x] 4.11 Go: `TestSprintContextMilestoneFields` — verify new fields in SprintContext

- [x] Task 5: XcodeGen + project.yml (AC: all)
  - [x] 5.1 Run `xcodegen generate` after adding new files
  - [x] 5.2 Verify all new test files in project.yml test target

## Dev Notes

### What's Already Implemented (Story 5.2 — DO NOT DUPLICATE)

Story 5.2 already built and tested these mechanics. They are DONE. Verify they work, don't rebuild:

- **Step toggle**: `SprintDetailViewModel.toggleStep()` — marks `completed=true`, sets `completedAt = Date()`, single DB transaction with atomic sprint completion check
- **Haptic**: `UIImpactFeedbackGenerator(style: .light)` on step completion
- **Avatar celebration**: `.celebrating` state for 800ms, then revert to `.active`
- **Reduce Motion**: Checks `reduceMotion` param — skips animation, fires haptic only
- **Auto-completion**: When `allSteps.allSatisfy(\.completed)` → sprint status `.complete`, `appState.activeSprint = nil`
- **Auto-reactivation**: Uncompleting a step after sprint completion → status back to `.active`
- **SprintPathView update**: Progress reflected in real-time
- **Retro section UI shell**: `retroSection` computed property shows when `sprint?.status == .complete` — but currently hardcoded placeholder text

### Key Files to Modify

| File | Change |
|------|--------|
| `ios/sprinty/Models/Sprint.swift` | Add `narrativeRetro: String?` and `lastStepCompletedAt: Date?` fields |
| `ios/sprinty/Services/Database/Migrations.swift` | Add v10 migration for both new columns |
| `ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift` | Add `ChatServiceProtocol` dependency, retro generation, differentiated celebration |
| `ios/sprinty/Features/Sprint/Views/SprintDetailView.swift` | Display dynamic retro content, loading state, VoiceOver |
| `ios/sprinty/Features/Coaching/Models/ChatRequest.swift` | Add `lastStepCompletedAt`, `sprintJustCompleted` to ActiveSprintInfo; add `SprintRetroRequest` |
| `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` | Update `buildSprintContext()` — read `lastStepCompletedAt` from Sprint record, compute `sprintJustCompleted` with 1-hour TTL |
| `ios/sprinty/App/RootView.swift` | Pass `chatService` to `SprintDetailViewModel` init |
| `server/providers/provider.go` | Add fields to `ActiveSprintInfo` Go struct; add `SprintRetroRequest` struct |
| `server/prompts/builder.go` | Add `SprintRetroPrompt()` method; update `Build()` to inject milestone context |
| `server/prompts/sections/sprint-retro.md` | New prompt template for retro generation |
| `server/handlers/chat.go` | Add `handleSprintRetro()` function with mode routing |
| `docs/api-contract.md` | Document new fields, sprint_retro mode, and retro request payload |

### Narrative Retro Architecture

**Decision: On-demand generation via existing `/v1/chat` endpoint with `mode: "sprint_retro"`**

Do NOT create a new API endpoint. Use the existing chat streaming endpoint with a new mode. This follows the existing `mode: "summarize"` pattern:

- `chat.go` has `if req.Mode == "summarize" { handleSummarize(...); return }` — add the same for `sprint_retro`
- `handleSummarize()` uses `promptBuilder.SummarizePrompt()` (a dedicated method, not `Build()`) — create `SprintRetroPrompt()` the same way
- Standard `event: token` streaming + `event: done` — no new SSE event types needed
- iOS accumulates tokens, saves full text to `Sprint.narrativeRetro` on `done`

**Server handler routing (chat.go):**
```go
// Add BEFORE the streaming path, after the summarize check
if req.Mode == "sprint_retro" {
    handleSprintRetro(w, r, req, provider, promptBuilder)
    return
}
```

**Prompt assembly — `SprintRetroPrompt()` in builder.go:**

This is a standalone prompt, NOT assembled via `Build()`. It uses only `base-persona` + `sprint-retro.md`. Skip all coaching sections (mood, challenger, mode-transitions, safety, tagging, cultural) — they are irrelevant for narrative retro generation.

```go
func (b *Builder) SprintRetroPrompt(sprintName string, durationDays int, steps []SprintRetroStep) string {
    var prompt strings.Builder
    prompt.WriteString(b.sections["base-persona"])
    prompt.WriteString("\n\n")
    prompt.WriteString(b.sections["sprint-retro"])
    prompt.WriteString("\n\n## Sprint Details\n")
    prompt.WriteString(fmt.Sprintf("Sprint: \"%s\" (%d days)\n\nSteps completed:\n", sprintName, durationDays))
    for _, s := range steps {
        prompt.WriteString(fmt.Sprintf("- %s", s.Description))
        if s.CoachContext != "" {
            prompt.WriteString(fmt.Sprintf(" (context: %s)", s.CoachContext))
        }
        prompt.WriteString("\n")
    }
    return prompt.String()
}
```

**Step descriptions payload — NEW struct to carry step details to server:**

`ActiveSprintInfo` only has aggregate counts. The retro needs actual step descriptions and coachContext. Add a dedicated request structure:

```swift
// iOS — in ChatRequest.swift
struct SprintRetroStep: Codable, Sendable {
    let description: String
    let coachContext: String?
}
```

```go
// Go — in provider.go
type SprintRetroStep struct {
    Description  string `json:"description"`
    CoachContext string `json:"coachContext,omitempty"`
}
```

Send step details as part of the `sprint_retro` mode request. The chat request already has `sprintContext` — extend it with an optional `retroSteps: [SprintRetroStep]?` field, populated only for retro mode:

```swift
struct SprintContext: Codable, Sendable {
    let activeSprint: ActiveSprintInfo?
    let pendingProposal: PendingSprintProposal?
    let retroSteps: [SprintRetroStep]?  // NEW — populated only for sprint_retro mode
}
```

### Critical Timing Fix: Retro Generation Before Sprint Completion

**Problem:** Story 5.2's `toggleStep()` sets `sprint.status = .complete` and `appState.activeSprint = nil` atomically when all steps are done. If retro generation happens after, `buildSprintContext()` calls `sprintService.activeSprint()` which only returns `.active` sprints — the sprint context would be `nil`.

**Solution:** Restructure `toggleStep()` to generate retro BEFORE marking sprint complete:

```swift
func toggleStep(_ step: SprintStep, reduceMotion: Bool) async {
    // ... existing step update logic ...

    let (updatedSteps, allDone) = try await databaseManager.dbPool.write { db -> ([SprintStep], Bool) in
        try stepToWrite.update(db)
        let allSteps = try SprintStep.forSprint(id: stepToWrite.sprintId).fetchAll(db)
        let allDone = allSteps.allSatisfy(\.completed)
        // Also persist lastStepCompletedAt on Sprint record
        if stepToWrite.completed, var sprint = try Sprint.active().fetchOne(db) {
            sprint.lastStepCompletedAt = Date()
            try sprint.update(db)
        }
        return (allSteps, allDone)
    }

    self.steps = updatedSteps

    if allDone {
        // 1. Generate retro FIRST (sprint is still .active at this point)
        if let sprint = self.sprint {
            await generateNarrativeRetro(for: sprint, steps: updatedSteps)
        }
        // 2. THEN mark sprint complete
        try await databaseManager.dbPool.write { db in
            if var activeSprint = try Sprint.active().fetchOne(db) {
                activeSprint.status = .complete
                try activeSprint.update(db)
            }
        }
        appState.activeSprint = nil
        // 3. Differentiated celebration
        triggerSprintCompletion(reduceMotion: reduceMotion)
    } else {
        triggerCelebration(reduceMotion: reduceMotion)
    }
}
```

**Fallback:** If retro generation fails (offline, network error, auth expired), proceed with sprint completion anyway. Set `narrativeRetro = nil` — the UI shows placeholder text. On next view of SprintDetailView, if `sprint.status == .complete && sprint.narrativeRetro == nil`, retry generation.

### Retro Generation with Error Handling

```swift
func generateNarrativeRetro(for sprint: Sprint, steps: [SprintStep]) async {
    isGeneratingRetro = true
    defer { isGeneratingRetro = false }

    let retroSteps = steps.map { SprintRetroStep(description: $0.description, coachContext: $0.coachContext) }
    let totalDays = max(1, (Calendar.current.dateComponents([.day], from: sprint.startDate, to: sprint.endDate).day ?? 0) + 1)

    let sprintCtx = SprintContext(
        activeSprint: ActiveSprintInfo(
            name: sprint.name,
            status: sprint.status.rawValue,
            stepsCompleted: steps.filter(\.completed).count,
            stepsTotal: steps.count,
            dayNumber: totalDays,
            totalDays: totalDays,
            lastStepCompletedAt: nil,
            sprintJustCompleted: true
        ),
        pendingProposal: nil,
        retroSteps: retroSteps
    )

    do {
        var retroText = ""
        let messages = [ChatRequestMessage(role: "user", content: "Generate sprint retrospective")]
        let stream = chatService.streamChat(
            messages: messages,
            mode: "sprint_retro",
            profile: nil,
            userState: nil,
            ragContext: nil,
            sprintContext: sprintCtx
        )
        for try await event in stream {
            if case .token(let text) = event {
                retroText += text
            }
        }

        guard !retroText.isEmpty else { return }

        let sprintId = sprint.id
        let finalText = retroText
        try await databaseManager.dbPool.write { db in
            if var sprintRecord = try Sprint.fetchOne(db, id: sprintId) {
                sprintRecord.narrativeRetro = finalText
                try sprintRecord.update(db)
            }
        }
        self.sprint?.narrativeRetro = finalText
    } catch {
        // Retro is non-critical — log error, keep placeholder
        // Next view of SprintDetailView will retry if narrativeRetro is nil
    }
}
```

### Retro Retry on View Load

In `SprintDetailViewModel.load()`, after fetching sprint and steps:
```swift
// Retry retro generation if sprint is complete but retro is missing
if sprint?.status == .complete, sprint?.narrativeRetro == nil {
    if let sprint = self.sprint {
        Task { [weak self] in
            await self?.generateNarrativeRetro(for: sprint, steps: self?.steps ?? [])
        }
    }
}
```

### Retro Loading State UI

Add `isGeneratingRetro: Bool` property to SprintDetailViewModel. In SprintDetailView's `retroSection`:

```swift
private var retroSection: some View {
    VStack(alignment: .leading, spacing: theme.spacing.homeElement) {
        Text("Your Journey")
            .sectionHeadingStyle()
            .foregroundStyle(theme.palette.textPrimary)

        if let retroText = viewModel.sprint?.narrativeRetro {
            // Dynamic retro content
            Text(retroText)
                .coachVoiceStyle()
                .foregroundStyle(theme.palette.textSecondary)
                .accessibilityLabel("Sprint retrospective from your coach: \(retroText)")
        } else {
            // Placeholder with optional pulse during generation
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
```

### Celebration → Challenge Enforcement (UX-DR78)

**Problem solved:** `lastStepCompletedAt` needs to be read by CoachingViewModel but is set by SprintDetailViewModel. These are separate ViewModels with no direct communication.

**Solution:** Persist `lastStepCompletedAt` on the Sprint DB record itself (new column in migration v10). Both ViewModels share the same DatabaseManager, so CoachingViewModel reads the latest value from DB when building sprint context.

**Population path:**
1. User completes step → `SprintDetailViewModel.toggleStep()` writes `sprint.lastStepCompletedAt = Date()` to DB
2. User opens coaching → `CoachingViewModel.buildSprintContext()` reads Sprint from DB, gets `lastStepCompletedAt`
3. If `lastStepCompletedAt` is within 1 hour of now → set `sprintJustCompleted` or inject milestone note

**TTL/lifecycle for `sprintJustCompleted`:**
```swift
// In buildSprintContext()
let recentCelebration: Bool
if let lastCompleted = result.sprint.lastStepCompletedAt {
    let hourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
    recentCelebration = lastCompleted > hourAgo
} else {
    recentCelebration = false
}

let justCompleted = result.sprint.status == .complete && recentCelebration
```

This naturally expires: after 1 hour, `recentCelebration` is `false` regardless of sprint state. No reset mechanism needed.

**Server prompt injection update** in `builder.go` (within the `Build()` method's sprint context section):
```go
if sprintContext.ActiveSprint.LastStepCompletedAt != nil {
    // Parse ISO 8601, check if within 1 hour
    sprintText.WriteString("IMPORTANT: User recently completed a sprint step. This is a celebration moment. Do NOT activate Challenger mode in this session (UX-DR78 transition rhythm).\n")
}
if sprintContext.ActiveSprint.SprintJustCompleted != nil && *sprintContext.ActiveSprint.SprintJustCompleted {
    sprintText.WriteString("IMPORTANT: User just completed their entire sprint! This is a major milestone. Acknowledge their achievement warmly. No Challenger this session.\n")
}
```

### Differentiated Celebration

| Event | Haptic | Avatar Duration | Visual |
|-------|--------|-----------------|--------|
| Single step completion | `.light` | 800ms | Checkmark + strikethrough |
| Sprint completion (all steps) | `.medium` | 1200ms (`AnimationTiming.slow`) | Retro section fades in |

Add `triggerSprintCompletion(reduceMotion:)` method separate from `triggerCelebration(reduceMotion:)`:
```swift
private func triggerSprintCompletion(reduceMotion: Bool) {
    let generator = UIImpactFeedbackGenerator(style: .medium)  // Stronger than step
    generator.impactOccurred()

    guard !reduceMotion else { return }
    appState.experienceContext = .celebrating
    celebrationTask = Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(1200))  // Longer than step (800ms)
        guard !Task.isCancelled else { return }
        self?.appState.experienceContext = .active
    }
}
```

### Sprint Model Changes

```swift
// Migration v10
migrator.registerMigration("v10_sprintRetroAndMilestone") { db in
    try db.alter(table: "Sprint") { t in
        t.add(column: "narrativeRetro", .text)
        t.add(column: "lastStepCompletedAt", .text)  // ISO 8601 via GRDB Date encoding
    }
}

// Updated Sprint model
struct Sprint: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var status: SprintStatus
    var narrativeRetro: String?       // NEW — LLM-generated on completion
    var lastStepCompletedAt: Date?    // NEW — timestamp of most recent step completion
}
```

### ActiveSprintInfo Changes

```swift
// iOS
struct ActiveSprintInfo: Codable, Sendable {
    let name: String
    let status: String
    let stepsCompleted: Int
    let stepsTotal: Int
    let dayNumber: Int
    let totalDays: Int
    let lastStepCompletedAt: String?  // NEW — ISO 8601, from Sprint record
    let sprintJustCompleted: Bool?    // NEW — true if complete + within 1 hour
}
```

```go
// Go
type ActiveSprintInfo struct {
    Name                string `json:"name"`
    Status              string `json:"status"`
    StepsCompleted      int    `json:"stepsCompleted"`
    StepsTotal          int    `json:"stepsTotal"`
    DayNumber           int    `json:"dayNumber"`
    TotalDays           int    `json:"totalDays"`
    LastStepCompletedAt *string `json:"lastStepCompletedAt,omitempty"`  // NEW
    SprintJustCompleted *bool   `json:"sprintJustCompleted,omitempty"` // NEW
}
```

### sprint-retro.md Prompt Template

```markdown
You are generating a brief narrative retrospective for a completed sprint.

Write in coach voice — warm, reflective, specific to what was accomplished.
Opening pattern: "Here's the chapter we just finished..."
Reference the specific steps and what they represented.
If coach context is available for steps, weave in why each step mattered.
Celebrate the growth, not just the completion.
2-3 paragraphs maximum. No questions, no action items, no next steps.
This is a moment of earned pride — quiet, not performative.
```

### Project Structure Notes

- All new iOS files follow existing `Features/Sprint/` structure
- No new directories needed
- Sprint retro prompt: `server/prompts/sections/sprint-retro.md` (new file)
- Migration v10 appended to existing `Migrations.swift`
- `SprintDetailViewModel` gains `ChatServiceProtocol` dependency — wire in `RootView.swift`

### Previous Story Intelligence (5.2 Learnings)

1. **Design token usage**: Use `.insightTextStyle()` + `.italic()` for coach voice, `.coachVoiceStyle()` for narrative content, `.sectionHeadingStyle()` for headings
2. **SQL reserved words**: Quote `"order"` column in GRDB queries
3. **Strict concurrency**: Use `let` bindings from DB transactions (not `var` captured in closures). Example: `let sprintId = sprint.id` before the closure, not `var sprint` inside it
4. **XcodeGen**: Run after adding any new files
5. **Type checker performance**: Extract complex view sections as computed properties
6. **Theme inheritance**: Sheets inherit theme from environment — no `themeFor()` call needed
7. **Test pattern**: In-memory GRDB with real migrations, Swift Testing framework (`@Suite`, `@Test`, `#expect`)
8. **VoiceOver**: Use `accessibilitySortPriority` for reading order, contextual prefixes like "Your coach says:"
9. **Celebration**: `UIImpactFeedbackGenerator(style:)` — `.light` for steps, `.medium` for sprint completion
10. **Single DB transaction**: Step toggle + completion check in one `dbPool.write` block

### Testing Standards

- Swift Testing: `@Suite struct`, `@Test`, `#expect()`, `@MainActor` for ViewModel tests
- In-memory GRDB with real migrations via `makeTestDB()`
- Test naming: `test_{function}_{scenario}_{expected}`
- Mock services: `Mock{ServiceName}` with recorded args and stub injection — create `MockChatService` stub for retro streaming (return preset tokens then done)
- New test files in `ios/Tests/Features/Sprint/` mirroring source structure
- Add to `ios/project.yml` test target
- Go tests: `Test<Component><Scenario>` PascalCase, `httptest.Server` for handler tests
- Test both success AND failure paths for retro generation

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5, Story 5.3]
- [Source: _bmad-output/planning-artifacts/architecture.md — Sprint Framework, GRDB patterns, MVVM]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Sprint Detail View, Step Completion, UX-DR58, UX-DR66, UX-DR78]
- [Source: _bmad-output/implementation-artifacts/5-2-sprint-detail-view.md — Previous story learnings, files modified]
- [Source: _bmad-output/project-context.md — Testing rules, anti-patterns, critical rules]
- [Source: server/prompts/sections/mood.md — Celebration → Challenge transition rule]
- [Source: server/prompts/sections/mode-transitions.md — Transition rhythms]
- [Source: server/handlers/chat.go — handleSummarize() pattern for mode-specific routing]
- [Source: server/prompts/builder.go — SummarizePrompt() pattern for standalone prompt assembly]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- All 485 iOS tests pass (22 SprintDetailViewModel tests including 9 new Story 5.3 tests)
- All Go tests pass (5 new Story 5.3 tests: TestSprintRetroHandler, TestSprintRetroHandler_EmptyContext_Returns400, TestSprintContextMilestoneFields, TestSprintRetroPrompt_IncludesBasePersonaAndRetroSection, TestSprintRetroPrompt_EmptySteps)

### Completion Notes List
- Task 1: Implemented full narrative retro pipeline — Sprint model (v10 migration), server handler (`sprint_retro` mode routing), `SprintRetroPrompt()` builder, prompt template, iOS `generateNarrativeRetro()` with timing fix (retro before completion), loading state UI with pulsing animation, persistence, VoiceOver
- Task 2: Added `lastStepCompletedAt` and `sprintJustCompleted` milestone context — persisted on Sprint record, read by CoachingViewModel with 1-hour TTL, injected into coaching prompt with Challenger suppression (UX-DR78)
- Task 3: Differentiated celebration — `.medium` haptic + 1200ms avatar for sprint completion vs `.light` + 800ms for step completion. Retro section fades in as visual indicator
- Task 4: 9 new iOS tests + 5 new Go tests covering all ACs
- Task 5: XcodeGen regenerated, no new files needed in project.yml (Tests auto-discovered from Tests/ directory)

### Change Log
- Story 5.3 implementation completed (2026-03-25)
- Code review fixes applied (2026-03-25): H1 — added `lastStepCompletedAt` to retro request payload; H2 — fixed `load()` to also fetch completed sprints for retro retry, rewrote test; H3 — added `TestSprintRetroPrompt` Go unit tests; M1 — server validates non-empty retroSteps; M2 — rewrote TTL test to cover all edge cases; M3 — added avatar state assertions for differentiated celebration

### File List
- `ios/sprinty/Models/Sprint.swift` — added `narrativeRetro: String?` and `lastStepCompletedAt: Date?`
- `ios/sprinty/Services/Database/Migrations.swift` — added v10 migration
- `ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift` — added `ChatServiceProtocol` dep, `generateNarrativeRetro()`, `triggerSprintCompletion()`, restructured `toggleStep()`, retro retry in `load()`
- `ios/sprinty/Features/Sprint/Views/SprintDetailView.swift` — dynamic retro content, loading state, VoiceOver
- `ios/sprinty/Features/Coaching/Models/ChatRequest.swift` — added `lastStepCompletedAt`, `sprintJustCompleted` to `ActiveSprintInfo`; added `SprintRetroStep`, `retroSteps` to `SprintContext`
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — updated `buildSprintContext()` with milestone context
- `ios/sprinty/App/RootView.swift` — wired `chatService` into `SprintDetailViewModel`
- `server/providers/provider.go` — added `LastStepCompletedAt`, `SprintJustCompleted` to `ActiveSprintInfo`; added `SprintRetroStep`; added `RetroSteps` to `SprintContext`
- `server/prompts/builder.go` — added `SprintRetroPrompt()` method; added `sprint-retro.md` to section files; added milestone context injection in `Build()`
- `server/prompts/sections/sprint-retro.md` — new prompt template
- `server/handlers/chat.go` — added `handleSprintRetro()` with mode routing
- `server/providers/mock.go` — added `sprint_retro` mode handling
- `server/prompts/builder_test.go` — added `sprint-retro.md` to test sections; updated section count assertion
- `server/tests/handlers_test.go` — added `sprint-retro.md` to test helpers; added 3 Story 5.3 tests
- `ios/Tests/Features/Sprint/SprintDetailViewModelTests.swift` — added 9 Story 5.3 tests
- `docs/api-contract.md` — documented `sprint_retro` mode, `sprintContext` fields
