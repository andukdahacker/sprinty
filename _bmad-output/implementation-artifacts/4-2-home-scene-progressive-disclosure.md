# Story 4.2: Home Scene Progressive Disclosure

Status: done

## Story

As a user whose coaching journey deepens over time,
I want the home screen to reveal more information as I engage more,
so that it starts simple and grows with me without overwhelming me early on.

## Acceptance Criteria

1. **Stage 1 — Brand New User:** Given a new user who just completed onboarding (no completed conversations), When the home screen renders, Then only the avatar (64pt), warm greeting, and "Talk to your coach" button are visible, And the empty state text reads "Your story starts here" (UX-DR72), And no InsightCard or SprintPathView appears.

2. **Stage 2 — First Conversation Complete:** Given the user has ≥1 completed conversation with a stored summary, When the home screen renders, Then an InsightCard appears below the greeting area displaying a RAG-informed coaching insight (not generic), And it refreshes once per completed session, And it is read-only (not tappable). If no RAG data is available yet, fallback text is "Your coach is getting to know you..."

3. **Stage 3 — Active Sprint:** Given the user has an active sprint, When the home screen renders, Then a SprintProgressView (compact, 5pt trail height) appears showing progress, And the most recent check-in summary appears below (if a check-in exists), And spacing follows 16-20pt between elements.

4. **Stage 4 — Pause Mode:** Given the user is in Pause Mode (`appState.isPaused == true`), When the home screen renders, Then the sprint display is muted (reduced opacity, not removed), And the InsightCard softens to "Your coach is here when you're ready.", And the avatar shows `.resting` state, And the overall scene feels quiet and warm via desaturation.

5. **Accessibility — VoiceOver Order:** Given VoiceOver is enabled, When navigating the home scene, Then the reading order is: greeting → avatar → insight card (if visible) → sprint progress (if visible) → "Talk to your coach" button (UX-DR60).

6. **Accessibility — Reduce Motion:** Given Reduce Motion is enabled, When stage elements appear or Pause Mode transitions occur, Then all animations are instant (duration 0).

7. **Accessibility — Dynamic Type:** All text uses semantic iOS text styles that scale with system settings. Layout adapts without clipping at all Dynamic Type sizes.

## Tasks / Subtasks

- [x] Task 1: Create HomeDisclosureStage enum and stage computation (AC: 1,2,3,4)
  - [x] 1.1 Create `HomeDisclosureStage` enum in `Core/State/` with cases: `.welcome`, `.insightUnlocked`, `.sprintActive`, `.paused`
  - [x] 1.2 Add `computed var homeStage: HomeDisclosureStage` to `HomeViewModel` that derives stage from: conversation count, active sprint existence, and `appState.isPaused`
  - [x] 1.3 Stage logic: paused overrides all → `.paused`; has active sprint → `.sprintActive`; has ≥1 completed conversation → `.insightUnlocked`; else → `.welcome`
  - [x] 1.4 Write tests for all stage derivation paths

- [x] Task 2: Create InsightCard view component (AC: 2,4,5,6,7)
  - [x] 2.1 Create `InsightCardView.swift` in `Features/Home/Views/`
  - [x] 2.2 Card uses `theme.cornerRadius.container` (16pt), `theme.palette.insightBackground` color, `theme.spacing.insightPadding` (16pt internal)
  - [x] 2.3 Content text styling: `.font(theme.typography.insightTextFont).fontWeight(theme.typography.insightTextWeight).lineSpacing(theme.typography.insightTextLineSpacing)` (15pt Subheadline, regular, 1.5 line height). TypographyScale uses a 3-property pattern per token — there is no single `.insightText` property.
  - [x] 2.4 Display insight text from `HomeViewModel.insightDisplayText` computed property
  - [x] 2.5 Add VoiceOver: `accessibilityLabel("Coach insight: \(content)")`
  - [x] 2.6 Add `#Preview` variants: with insight text, with fallback text, pause mode text

- [x] Task 3: Create SprintProgressView compact component (AC: 3,4,5,6,7)
  - [x] 3.1 Create `SprintProgressView.swift` in `Features/Home/Views/` as a **pure UI component** — init takes `progress: Double` (0.0–1.0), `currentStep: Int`, `totalSteps: Int`, `isMuted: Bool`. No database or model dependency (Sprint/SprintStep models don't exist yet).
  - [x] 3.2 Compact strip: 5pt height trail metaphor using `theme.palette.sprintTrack` (background) and `theme.palette.sprintProgressStart`/`sprintProgressEnd` gradient (fill)
  - [x] 3.3 Display `progress` as fill width fraction of track
  - [x] 3.4 Add VoiceOver: `accessibilityLabel("Sprint progress")`, `accessibilityValue("Step \(currentStep) of \(totalSteps)")`
  - [x] 3.5 Support muted state: reduced opacity (0.4) when `isMuted == true`
  - [x] 3.6 Add `#Preview` variants: 50% progress, complete, muted/paused

- [x] Task 4: Create CheckInSummaryView component (AC: 3,5,7)
  - [x] 4.1 Create `CheckInSummaryView.swift` in `Features/Home/Views/`
  - [x] 4.2 Display most recent check-in summary text from `HomeViewModel.latestCheckIn`
  - [x] 4.3 Uses insight text typography (3-property pattern: `insightTextFont`/`insightTextWeight`/`insightTextLineSpacing`), `theme.palette.textSecondary` color
  - [x] 4.4 Add VoiceOver label

- [x] Task 5: Add empty state view for Stage 1 (AC: 1,7)
  - [x] 5.1 Create `HomeEmptyStateView.swift` in `Features/Home/Views/` displaying "Your story starts here" with warm, intentional styling
  - [x] 5.2 Uses insight text typography (3-property pattern), `theme.palette.textSecondary` color, centered below greeting area

- [x] Task 6: Update HomeViewModel with data loading for new components (AC: 2,3,4)
  - [x] 6.1 Add `latestInsight: String?` property — loaded via existing `ConversationSummary.recent(limit: 1)` query, extract `.summary` field
  - [x] 6.2 Add `latestCheckIn: String?` property — loaded from most recent check-in summary
  - [x] 6.3 Add `activeSprint: Sprint?` property — loaded from database (active sprint query)
  - [x] 6.4 Add `sprintProgress: Double` computed property (completedSteps / totalSteps)
  - [x] 6.5 Add `completedConversationCount: Int` property — count of `ConversationSession` records where `endedAt IS NOT NULL` (endedAt field exists on the model)
  - [x] 6.6 Update `load()` async to fetch all new data
  - [x] 6.7 Compute `insightDisplayText`: if paused → "Your coach is here when you're ready."; if has insight → latest insight summary; if no conversations → nil; if conversations but no insight → "Your coach is getting to know you..."
  - [x] 6.8 Write tests for data loading and insightDisplayText computation

- [x] Task 7: Update HomeView with progressive disclosure layout (AC: 1,2,3,4,5,6)
  - [x] 7.1 Restructure HomeView body to conditionally show elements based on `viewModel.homeStage`
  - [x] 7.2 Layout order: HStack(AvatarView + greeting) → InsightCardView (if stage ≥ `.insightUnlocked`) → SprintProgressView (if stage == `.sprintActive`) → CheckInSummaryView (if check-in exists) → Spacer → CoachActionButton
  - [x] 7.3 Stage 1: Show HomeEmptyStateView below greeting, hide InsightCard and SprintProgress
  - [x] 7.4 Stage 4 (Pause): Show all earned elements but with muted styling; apply desaturation via `.saturation(0.7)` on container
  - [x] 7.5 Element appearance animation: `.transition(.opacity)` with `.animation(reduceMotion ? .none : .easeInOut(duration: 0.2))` for subtle fade-in
  - [x] 7.6 Spacing between elements: `theme.spacing.homeElement` (16pt)
  - [x] 7.7 Set VoiceOver sort priority to enforce reading order: greeting → avatar → insight → sprint → button
  - [x] 7.8 Add `#Preview` variants for each stage (welcome, insight, sprint, paused)

- [x] Task 8: Add Pause Mode visual treatment (AC: 4,6)
  - [x] 8.1 When `appState.isPaused` transitions to true: apply `.saturation(0.7)` to home content container, avatar → `.resting`, insight → pause text
  - [x] 8.2 Transition duration: 1.2s desaturation on enter, 0.6s restoration on exit (respect Reduce Motion)
  - [x] 8.3 CoachActionButton remains fully saturated even during Pause (tapping it deactivates Pause)

- [x] Task 9: Database queries for new data (AC: 2,3)
  - [x] 9.1 Use existing `ConversationSummary.recent(limit: 1)` to fetch the most recent summary — this query already exists. Do NOT create a duplicate `mostRecent()` method.
  - [x] 9.2 Add query extension on `ConversationSession`: `static func completedCount() -> some FetchRequest` returning count of sessions with non-nil `endedAt`
  - [x] 9.3 Sprint queries are deferred to Story 5.1 when Sprint/SprintStep models are created. HomeViewModel should gracefully handle missing Sprint table (catch error, return nil).
  - [x] 9.4 Write database tests for ConversationSummary and ConversationSession queries using `makeTestDB()` pattern

- [x] Task 10: Regenerate Xcode project and run full test suite (AC: all)
  - [x] 10.1 Run `xcodegen generate` to pick up new files
  - [x] 10.2 Build and verify zero compiler errors
  - [x] 10.3 Run full test suite — zero regressions (378 tests, 37 suites, all pass)
  - [x] 10.4 Manual verification: preview all 4 stages in Xcode previews

## Dev Notes

### Architecture Patterns & Constraints

- **MVVM with @Observable (iOS 17+):** All ViewModels must be `@MainActor @Observable final class`. No Combine. Use `async/await` and `Task { [weak self] in }` with `Task.isCancelled` checks.
- **Feature folder structure:** New views go in `ios/sprinty/Features/Home/Views/`, new state types in `ios/sprinty/Core/State/`.
- **Theme system:** Access via `@Environment(\.coachingTheme) private var theme`. Use semantic tokens: `theme.palette.insightBackground`, `theme.spacing.homeElement`, `theme.cornerRadius.container`, etc.
- **Database access:** GRDB async pattern: `try await databaseManager.dbPool.read { db in ... }`. Models are `Sendable`, conform to `FetchableRecord, PersistableRecord, Identifiable`.
- **DI pattern:** Services injected via protocols. HomeViewModel receives `appState` and `databaseManager` via init injection (see RootView.swift).

### Existing Code to Reuse — DO NOT RECREATE

| Component | File | What It Does |
|-----------|------|-------------|
| `AvatarState` enum | `Core/State/AvatarState.swift` | 5 states with `saturationMultiplier`, `displayName`, `derive(isPaused:)` |
| `AvatarView` | `Features/Home/Views/AvatarView.swift` | State-based rendering with saturation, crossfade animation, a11y |
| `HomeView` | `Features/Home/Views/HomeView.swift` | Current layout with `onTalkToCoach: () -> Void` and `onOpenSettings: (() -> Void)?` callbacks, GeometryReader-based responsive margins, `.task { await viewModel.load() }` lifecycle. **Modify in place** — preserve existing callbacks and responsive sizing. |
| `HomeViewModel` | `Features/Home/ViewModels/HomeViewModel.swift` | `init(appState: AppState, databaseManager: DatabaseManager)`. Has: `greeting`, `timeOfDayGreeting`, `avatarId`, `avatarState` (computed), `triggerCelebration()`, `load()` async, `updateGreeting(for:)`. **Extend, don't replace** — add new properties alongside existing ones. |
| `CoachActionButton` | `Features/Home/Views/CoachActionButton.swift` | Full-width gradient button — reuse as-is |
| `AppState` | `App/AppState.swift` | Global state with `avatarState`, `isPaused`, `onboardingCompleted` |
| `CoachingTheme` | `Core/Theme/CoachingTheme.swift` | Theme tokens for palette, typography, spacing, radius |
| `ColorPalette` | `Core/Theme/ColorPalette.swift` | Color tokens including `insightBackground`, `sprintTrack`, `sprintProgress`, `avatarGlow` |
| `TypographyScale` | `Core/Theme/TypographyScale.swift` | Uses 3-property pattern per token: e.g. `insightTextFont`/`insightTextWeight`/`insightTextLineSpacing`. Same for `homeGreeting*`, `homeTitle*`, `sprintLabel*` |
| `SpacingScale` | `Core/Theme/SpacingScale.swift` | Spacing tokens including `.homeElement` (16pt), `.insightPadding`, `.screenMargin(for: width)` (method, not property) |
| `RadiusTokens` | `Core/Theme/RadiusTokens.swift` | Radius tokens including `.container` (16pt), `.button`. Avatar uses `.clipShape(Circle())` — no radius token. |
| View modifiers | `TypographyScale.swift` + `SpacingScale.swift` | `.homeTitleStyle()`, `.homeGreetingStyle()`, `.primaryButtonStyle()` (on TypographyScale), `.contentColumn()` (on SpacingScale). Use these view modifiers for greeting/title text instead of raw font properties. |

### Animation Timing Constants

| Animation | Duration | Curve | Context |
|-----------|----------|-------|---------|
| Element fade-in (stage reveal) | 0.2s | ease-in-out | Subtle appearance of new elements |
| Avatar state crossfade | 0.4s | ease-in-out | Already implemented in AvatarView |
| Insight card content swap | 0.3s | ease-in-out | When insight text changes |
| Pause Mode enter (desaturation) | 1.2s | ease-in-out | Deliberate, emotional transition |
| Pause Mode exit (restoration) | 0.6s | ease-in-out | Faster return to life |
| All animations w/ Reduce Motion | 0.0s | none | Instant, no animation |

### Stage Determination Logic

```
if appState.isPaused → .paused
else if activeSprint != nil → .sprintActive
else if completedConversationCount >= 1 → .insightUnlocked
else → .welcome
```

Stages are **cumulative** — `.sprintActive` shows insight card AND sprint progress. `.paused` shows all earned elements but muted.

### Safety State Override (Future Story 6.2)

At Orange/Red safety levels, gamification elements (sprint progress, celebrations) are hidden. The current implementation should not break when this is later added. Do NOT add safety handling now — just ensure the conditional visibility pattern supports future element hiding via AppState.

### InsightCard Content Priority

1. **Paused:** "Your coach is here when you're ready."
2. **Has summary:** Latest conversation summary text
3. **Has conversations but no summary:** "Your coach is getting to know you..."
4. **No conversations:** InsightCard not shown (Stage 1)

### Sprint & CheckIn Data

Story 5.1 (Sprint Creation) and 5.4 (Daily Check-ins) are not yet implemented. The `Sprint` and `SprintStep` GRDB models do NOT exist yet — they will be created in Story 5.1. For Stage 3, create the SprintProgressView and CheckInSummaryView components now as **UI-only** components that accept data via init parameters. The HomeViewModel should attempt to query for an active sprint, but gracefully return nil if the Sprint table doesn't exist yet. Use optional database queries that catch table-not-found errors. Stage 3 elements simply won't appear until Story 5.1 creates the models and data — no placeholder, no guilt messaging (UX-DR72).

### Layout Reference (HomeSceneView Layout B)

```
HomeSceneView
├── HStack
│   ├── AvatarView (64pt, circular, avatarGradient + avatarGlow)
│   └── VStack (greeting area)
│       ├── .homeGreetingStyle(): "Good evening"  (time-of-day)
│       └── .homeTitleStyle(): "Hey, [name]"
├── Spacing.homeElement (16pt)
├── [Stage 1 only] HomeEmptyStateView ("Your story starts here")
├── [Stage 2+] InsightCardView
│   ├── Container: insightBackground, Radius.container (16pt)
│   └── Content: insightTextFont/Weight/LineSpacing (15pt Subheadline)
├── Spacing.homeElement (16pt)
├── [Stage 3] SprintProgressView (compact, 5pt trail)
├── Spacing.homeElement (16pt)
├── [Stage 3] CheckInSummaryView (if recent check-in exists)
├── Spacer
└── CoachActionButton (always visible, full-width gradient)
```

### Color Tokens for New Components

**InsightCard:**
- Background: `theme.palette.insightBackground` (rgba sage at 10% light / 6% dark)
- Text: `theme.palette.textPrimary`
- Corner radius: `theme.cornerRadius.container` (16pt)

**SprintProgressView:**
- Track: `theme.palette.sprintTrack` (rgba sage at 12% light / 8% dark)
- Fill: `theme.palette.sprintProgressStart` → `theme.palette.sprintProgressEnd` (sage gradient)
- Height: 5pt

**Pause Mode Muting:**
- Container saturation: 0.7
- Sprint opacity: 0.4
- Avatar: `.resting` state (already handled by AvatarState.derive)

### Testing Standards

- **Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`) — NOT XCTest
- **Pattern:** `test_{function}_{scenario}_{expected}`
- **Database tests:** Use `makeTestDB()` helper with real migrations, `DatabasePool` with temp path
- **ViewModel tests:** `@MainActor` on test functions, use `#if DEBUG` preview factory for setup
- **New test files:**
  - `ios/Tests/Core/State/HomeDisclosureStageTests.swift`
  - `ios/Tests/Features/Home/HomeViewModelProgressiveDisclosureTests.swift`
  - `ios/Tests/Models/ConversationSummaryQueryTests.swift` (if adding query extensions)

### Previous Story 4.1 Intelligence

- `AvatarState.derive(isPaused:)` exists but is minimal — only checks isPaused. Future stories expand the signature. For now, use it as-is for Pause Mode avatar state.
- Celebration trigger is in HomeViewModel — don't interfere with it.
- AvatarView uses `.id(state)` + `.transition(.opacity)` pattern — element appearance should use the same SwiftUI animation pattern.
- Test baseline: 356 tests. Zero regressions expected after this story.
- `avatarId` (appearance) and `AvatarState` (behavioral mood) are independent — don't confuse them.

### Git Intelligence

Recent commits show pattern: feature code + test code + xcodegen regeneration in single commits. Follow same pattern. Stories 3.4-3.7 established RAG, search, memory, and profile patterns. ConversationSummary model exists with `summary`, `keyMoments`, `domainTags`, `embedding` fields — query the `summary` field for InsightCard content.

### Project Structure Notes

- All new view files in `ios/sprinty/Features/Home/Views/`
- New enum in `ios/sprinty/Core/State/HomeDisclosureStage.swift`
- Tests mirror source: `ios/Tests/Core/State/`, `ios/Tests/Features/Home/`
- After adding files, run `xcodegen generate` to regenerate `.xcodeproj`
- XcodeGen auto-scans `sprinty/` for app target sources, `Tests/` for test sources

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4, Story 4.2]
- [Source: _bmad-output/planning-artifacts/architecture.md#HomeSceneView, AppState, ExperienceContext]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR26 Layout B, UX-DR27 InsightCard, UX-DR29 CoachActionButton, UX-DR30 SprintPathView, UX-DR39 PauseModeTransition, UX-DR60 VoiceOver order, UX-DR66 Calm Budget, UX-DR72 Empty states]
- [Source: _bmad-output/planning-artifacts/prd.md#FR26-FR29, NFR4, NFR5, NFR7, NFR22, NFR24, NFR37]
- [Source: _bmad-output/implementation-artifacts/4-1-full-avatar-state-system.md]
- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Build compilation error: GRDB `Row` subscript inside `@Sendable` closure — resolved by extracting values within the read closure as a tuple.

### Completion Notes List
- Task 1: Created `HomeDisclosureStage` enum with 4 cases (.welcome, .insightUnlocked, .sprintActive, .paused). Added `homeStage` computed property and `insightDisplayText` to HomeViewModel. 11 tests covering all stage derivation paths and insight text priority.
- Tasks 2-5: Created 4 new view components — InsightCardView (insight card with theme tokens, VoiceOver), SprintProgressView (5pt trail with gradient fill, muted state), CheckInSummaryView (secondary text style), HomeEmptyStateView ("Your story starts here"). All use theme system tokens and include #Preview variants.
- Task 6: Extended HomeViewModel with `completedConversationCount`, `latestInsight`, `latestCheckIn`, sprint properties. Updated `load()` to fetch all new data. Sprint loading gracefully handles missing Sprint/SprintStep tables. 8 tests for data loading.
- Tasks 7-8: Restructured HomeView with progressive disclosure layout based on `homeStage`. Stage-dependent content with `.transition(.opacity)` animations. Pause mode: `.saturation(0.7)` with 1.2s enter / 0.6s exit (respects Reduce Motion). VoiceOver sort priority enforces correct reading order. CoachActionButton stays fully saturated in Pause.
- Task 9: Used existing `ConversationSummary.recent(limit: 1)` for insight. Added `ConversationSession.completedCount()` query. Sprint queries use raw SQL with table existence checks. 3 tests for ConversationSession queries.
- Task 10: 378 tests pass (22 new), zero regressions from baseline of 356.

### Change Log
- 2026-03-23: Story 4.2 implementation complete — progressive disclosure, insight card, sprint progress, pause mode, accessibility
- 2026-03-23: Code review fix — added counteracting `.saturation(1/0.7)` on CoachActionButton so it remains fully saturated during Pause Mode (AC4 / Task 8.3)

### File List
- ios/sprinty/Core/State/HomeDisclosureStage.swift (new)
- ios/sprinty/Features/Home/Views/InsightCardView.swift (new)
- ios/sprinty/Features/Home/Views/SprintProgressView.swift (new)
- ios/sprinty/Features/Home/Views/CheckInSummaryView.swift (new)
- ios/sprinty/Features/Home/Views/HomeEmptyStateView.swift (new)
- ios/sprinty/Features/Home/Views/HomeView.swift (modified)
- ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift (modified)
- ios/sprinty/Models/ConversationSession.swift (modified)
- ios/Tests/Core/State/HomeDisclosureStageTests.swift (new)
- ios/Tests/Features/Home/HomeViewModelProgressiveDisclosureTests.swift (new)
- ios/Tests/Models/ConversationSessionQueryTests.swift (new)
