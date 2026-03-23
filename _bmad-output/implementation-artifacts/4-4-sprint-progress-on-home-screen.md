# Story 4.4: Sprint Progress on Home Screen

Status: done

## Story

As a user with an active sprint,
I want to see my progress at a glance on the home screen,
So that I stay motivated without needing to dig into details.

## Acceptance Criteria

1. **Given** a user has an active sprint **When** the home screen renders **Then** the SprintProgressView compact variant displays (5pt height trail metaphor) with step marker dots along the track **And** a sprint label shows the sprint name **And** it's glanceable — understandable in under 2 seconds

2. **Given** VoiceOver is enabled **When** the sprint progress renders **Then** it announces "Sprint progress" with value "Step [n] of [total], day [n] of [total]"

3. **Given** no active sprint exists **When** the home screen renders **Then** the sprint area is absent (no placeholder, no "Start a sprint!" guilt)

4. **Given** the user is in Pause Mode **When** the home screen renders **Then** the sprint display is muted (opacity 0.4) but not removed — consistent with epics AC and Story 4.2 AC ("sprint display is muted, not removed"). Note: UX spec Rule 2 says "suppressed" but the epics override this to "muted but visible" for sprint on home screen.

5. **Given** Reduce Motion is enabled **When** step markers render **Then** no pulse or glow animations play on the current step marker — static display only

## Tasks / Subtasks

- [x] Task 1: Enhance SprintProgressView with trail metaphor step markers and sprint label (AC: 1, 4, 5)
  - [x] 1.1 Add step marker dots along the progress track (completed steps filled, remaining steps as outlines)
  - [x] 1.2 Add sprint name label above the progress bar using the existing `sprintLabelStyle()` view modifier
  - [x] 1.3 Ensure muted state (Pause Mode) reduces opacity of entire component (label + track + markers)
  - [x] 1.4 Check `@Environment(\.accessibilityReduceMotion)` — if any animation added to current step marker, provide static fallback
  - [x] 1.5 Verify glanceability — progress + step markers + label readable in under 2 seconds
- [x] Task 2: Add day tracking to HomeViewModel and VoiceOver (AC: 2)
  - [x] 2.1 Add `sprintName`, `sprintDayNumber`, `sprintTotalDays` properties to HomeViewModel
  - [x] 2.2 Update `loadActiveSprint()` to query `name`, `startDate`, `endDate` from Sprint table
  - [x] 2.3 Calculate day number: `Calendar.current.dateComponents([.day], from: startDate, to: Date()).day + 1`
  - [x] 2.4 Calculate total days: `Calendar.current.dateComponents([.day], from: startDate, to: endDate).day`
  - [x] 2.5 Handle edge case: if startDate or endDate is nil/unparseable, omit day portion from VoiceOver
  - [x] 2.6 Pass day data and sprint name to SprintProgressView
  - [x] 2.7 Update VoiceOver `.accessibilityValue` to include "day [n] of [total]" when day data available
- [x] Task 3: Update HomeViewModel preview factory (AC: 1, 2)
  - [x] 3.1 Add `sprintName`, `sprintDayNumber`, `sprintTotalDays` params with defaults to `preview()` factory inside `#if DEBUG`
  - [x] 3.2 Ensure preview factory uses only mock/temp data — no network, no real services
  - [x] 3.3 Update HomeView previews to show sprint name and day info
- [x] Task 4: Unit tests (AC: 1, 2, 3, 4, 5)
  - [x] 4.1 Test day calculation from startDate/endDate (edge cases: same day, past endDate, nil dates)
  - [x] 4.2 Test VoiceOver value includes "day [n] of [total]" when dates available
  - [x] 4.3 Test VoiceOver value omits day portion when dates unavailable
  - [x] 4.4 Test no sprint → homeStage stays at insightUnlocked/welcome (existing HomeDisclosureStage tests)
  - [x] 4.5 Test Pause Mode → isMuted=true passed to SprintProgressView
  - [x] 4.6 Test graceful fallback when Sprint table doesn't exist (returns defaults)
  - [x] 4.7 Test sprintName populated from Sprint table query

## Dev Notes

### Progressive Disclosure Stage Mapping

| Stage | Enum Value | What's Visible |
|-------|-----------|----------------|
| Stage 1 | `welcome` | Avatar + greeting + button only |
| Stage 2 | `insightUnlocked` | + InsightCard (no sprint) |
| Stage 3 | `sprintActive` | + SprintProgressView + check-in summary |
| Stage 4 | `paused` | Sprint muted (opacity 0.4), insight softens, avatar rests |

Check-in summary positioning (below sprint) is deferred to Story 5.4 — this story only implements the SprintProgressView enhancements.

### What Already Exists (DO NOT Recreate)

| File | What It Does | What to Change |
|------|-------------|---------------|
| `ios/sprinty/Features/Home/Views/SprintProgressView.swift` | 5pt linear progress bar with gradient, muting, basic VoiceOver | Add step marker dots, sprint name label, day info to VoiceOver |
| `ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift` | Loads sprint data via raw SQL with table existence check | Add `sprintName`, `sprintDayNumber`, `sprintTotalDays` properties + query columns |
| `ios/sprinty/Features/Home/Views/HomeView.swift` | Conditionally renders SprintProgressView at Stage 3/Paused | Pass new sprint name/day params to SprintProgressView |
| `ios/sprinty/Features/Home/Views/CheckInSummaryView.swift` | Displays latest check-in text (deferred to 5.4) | No changes |
| `ios/sprinty/Core/State/HomeDisclosureStage.swift` | Enum: welcome, insightUnlocked, sprintActive, paused | No changes |

### Architecture Compliance

**MVVM + @Observable Pattern:**
- ViewModels: `@MainActor @Observable final class` — all three decorators required
- DI: Protocol-based injection via init, no singletons
- AppState via `@Environment(AppState.self)` in Views, via init in ViewModels
- CoachingTheme via `@Environment(\.coachingTheme)` in Views

**Swift Concurrency Rules:**
- Use `Task { [weak self] in ... }` in ViewModels to prevent retain cycles
- Check `Task.isCancelled` before state mutations in async operations
- `@MainActor` on entire ViewModel class, not individual methods
- GRDB async access: `databaseManager.dbPool.read { db in }` — never synchronous

**Sprint Data Loading Pattern (Already Implemented in HomeViewModel:114-141):**
```swift
// Current raw SQL approach — extend, don't rewrite
let sprintData = try await databaseManager.dbPool.read { db in
    guard try db.tableExists("Sprint") else { return defaults }
    guard let row = try Row.fetchOne(db, sql: "SELECT id, name, startDate, endDate FROM Sprint WHERE status = 'active' LIMIT 1") else { return defaults }
    // ... extract name, dates, step counts
}
```

**Key:** Sprint/SprintStep tables may not exist yet (created in Story 5.1). The existing `db.tableExists()` guard handles this gracefully. **Preserve this pattern.** Database migrations are append-only — never modify existing migrations.

### Design Token Usage

| Token | Value | Usage |
|-------|-------|-------|
| `theme.palette.sprintTrack` | `rgba(139,155,122, 0.12)` light / `0.08` dark | Background track + remaining step marker outlines |
| `theme.palette.sprintProgressStart` | `#748465` light / `#8B9B7A` dark | Progress fill gradient start + completed step marker fill |
| `theme.palette.sprintProgressEnd` | `#7A8B6B` | Progress fill gradient end |
| `theme.cornerRadius.sprintTrack` | 3pt | Track corner radius |
| `theme.palette.textSecondary` | Muted sage | Sprint label color |
| `theme.spacing.homeElement` | 16pt | Spacing between sprint label and track |

**Existing view modifier for sprint label:** Use `Text(sprintName).sprintLabelStyle()` — this is already defined in `TypographyScale.swift:92-97` and encapsulates the 3-property pattern (font + weight + lineSpacing). Do NOT manually wire `sprintLabelFont.weight(sprintLabelWeight)`.

### Step Marker Implementation Guidance

The "trail metaphor" means step markers (small dots/circles) positioned along the 5pt track at evenly spaced intervals:
- **Completed steps:** Filled circles using `sprintProgressStart` color
- **Current step:** Slightly larger filled circle (trail marker "you are here")
- **Remaining steps:** Outline circles using `sprintTrack` color
- **Size:** ~6pt diameter dots centered vertically on the 5pt track (extends 0.5pt above/below)
- Use `Circle()` shapes positioned with `GeometryReader` width calculations
- The progress gradient bar remains underneath as the "trail path"
- **Reduce Motion:** If any pulse/glow animation is added to current step marker, gate it behind `@Environment(\.accessibilityReduceMotion)` with instant/static fallback

### VoiceOver Requirements

Current: `.accessibilityValue("Step \(currentStep) of \(totalSteps)")`
Required: `.accessibilityValue("Step \(currentStep) of \(totalSteps), day \(dayNumber) of \(totalDays)")`

When day data is unavailable (Sprint table missing or dates nil/unparseable), omit the day portion — just keep the step count.

### Pause Mode Behavior

Already implemented: `isMuted` flag → `opacity(0.4)`. No changes needed to muting logic itself. The sprint label should also respect the same muted opacity — wrap label + track in a single container that applies `opacity(isMuted ? 0.4 : 1.0)`.

HomeView also applies `.saturation(0.7)` at the container level (line 111) — this stacks with the opacity reduction.

### Sprint Table Schema (For SQL Queries)

```sql
-- Sprint table (created in Story 5.1, may not exist yet)
Sprint(id TEXT PRIMARY KEY, name TEXT, startDate TEXT, endDate TEXT, status TEXT)
-- SprintStep table
SprintStep(id TEXT PRIMARY KEY, sprintId TEXT, description TEXT, completedAt TEXT, "order" INTEGER)
```

**Date format in SQLite:** ISO 8601 strings. Parse with `ISO8601DateFormatter` or GRDB's built-in date decoding. Handle nil/empty gracefully.

### Testing Standards

- Framework: Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect()`) — NEVER XCTest
- Naming: `test_{function}_{scenario}_{expected}`
- Database tests: `makeTestDB()` with real GRDB migrations (in-memory)
- Mocks: `final class MockXxx: XxxProtocol, @unchecked Sendable`
- Preview factories: `#if DEBUG` guard, temp DB, mock services only — never hit network
- Baseline: **396 tests** from Story 4.3 — zero regressions expected

### Project Structure Notes

- All files in existing directories — no new folders needed
- SprintProgressView stays in `Features/Home/Views/`
- Tests go in `ios/Tests/Features/Home/`
- If adding new test files, add to `ios/project.yml` sources (XcodeGen is source of truth) — do NOT edit `.xcodeproj` directly
- Run `xcodegen generate` after modifying `project.yml`

### Previous Story Intelligence (Story 4.3)

Key learnings to apply:
- **Use existing view modifiers:** `sprintLabelStyle()` already encapsulates sprint label typography
- **Pause Mode desaturation:** Container applies `.saturation(0.7)` at HomeView level — SprintProgressView uses `opacity(0.4)` for its own muting
- **Database queries:** Use `databaseManager.dbPool.read { db in }` async pattern with `Task { [weak self] in }` and `Task.isCancelled` checks
- **Preview factory:** Add new params to `HomeViewModel.preview()` static method with defaults, inside `#if DEBUG`
- **VoiceOver sort priorities:** greeting(5) → avatar(4) → insight(3) → sprint(2) → button(1) — sprint stays at priority 2
- **Reduce Motion:** Always check `@Environment(\.accessibilityReduceMotion)` — provide static fallbacks for any animation
- **DI in RootView:** Services created in `RootView.swift`, passed via constructor injection

### Git Intelligence

Recent commits show consistent pattern: each story is a single commit with format `feat: Story X.Y — Description with code review fixes`. All 10 recent commits follow this pattern. Current branch is `main`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4, Story 4.4]
- [Source: _bmad-output/planning-artifacts/architecture.md#Sprint Framework, Home Screen]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#SprintPathView Component, Home Scene]
- [Source: _bmad-output/project-context.md#Critical Implementation Rules]
- [Source: ios/sprinty/Features/Home/Views/SprintProgressView.swift — existing implementation]
- [Source: ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift:114-141 — loadActiveSprint()]
- [Source: ios/sprinty/Core/Theme/TypographyScale.swift:92-97 — sprintLabelStyle() modifier]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation with no debugging issues.

### Completion Notes List

- **Task 1:** Enhanced SprintProgressView with trail metaphor step markers (Circle() shapes positioned via GeometryReader), sprint name label using existing `sprintLabelStyle()` modifier, muted opacity applied to entire VStack container (label + track + markers). No animations added to current step marker so no reduceMotion gating needed beyond environment declaration. Glanceable: sprint name + progress bar + step dots visible at a glance.
- **Task 2:** Added `sprintName`, `sprintDayNumber`, `sprintTotalDays` properties to HomeViewModel. Extended `loadActiveSprint()` SQL to query `name`, `startDate`, `endDate`. Day calculation uses `Calendar.current.dateComponents([.day], ...)`. Nil/unparseable dates → 0 values → VoiceOver omits day portion. VoiceOver now: "Step N of M, day N of M" when day data available.
- **Task 3:** Updated preview factory with 3 new params (defaults: "", 0, 0). Updated HomeView Stage 3 and Stage 4 previews with sprint name/day data. All preview factories use temp DB and mock services only.
- **Task 4:** Created HomeViewModelSprintTests.swift with 11 tests covering: day calculation (mid-sprint, same day, past endDate, nil dates), sprint name from DB, no sprint defaults, pause mode, graceful table fallback, VoiceOver with/without day data.

### Change Log

- 2026-03-23: Implemented Story 4.4 — Sprint Progress on Home Screen (all 4 tasks, 11 new tests, 407 total passing)
- 2026-03-23: Code review fixes — totalDays inclusive (+1), voiceOverValue made internal with 2 string-format tests added (13 total), step marker edge clipping fixed with inset, .xcodeproj regenerated via xcodegen

### File List

- `ios/sprinty/Features/Home/Views/SprintProgressView.swift` (modified — added step markers, sprint label, day VoiceOver)
- `ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift` (modified — added sprintName/dayNumber/totalDays props, extended loadActiveSprint SQL, updated preview factory)
- `ios/sprinty/Features/Home/Views/HomeView.swift` (modified — pass new sprint params to SprintProgressView, updated previews)
- `ios/sprinty.xcodeproj/project.pbxproj` (regenerated via xcodegen — includes new test file)
- `ios/Tests/Features/Home/HomeViewModelSprintTests.swift` (new — 13 unit tests for sprint progress)
