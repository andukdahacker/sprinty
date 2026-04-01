# Story 7.1: Pause Mode Activation & Deactivation

Status: done

## Story

As a user who needs a break,
I want to pause all coaching activity with one gesture and return whenever I'm ready,
so that the app respects my boundaries without making me feel guilty.

## Acceptance Criteria

### AC 1: Activation — Immediate Response

```
Given a user wants to pause
When they activate Pause Mode (one gesture, no confirmation per UX-DR48)
Then Pause activates immediately
And the coach says "Rest well" (1 beat)
And the UI quiets: PauseModeTransition plays (1200ms desaturation per UX-DR39)
And the avatar shifts to resting state
And the insight card softens to a Pause message
And the sprint display is muted (not removed)
And all notifications are suppressed (zero during Pause per UX-DR66)
```

### AC 2: Deactivation — Warm Return

```
Given the user is in Pause Mode
When they tap "Talk to your coach"
Then Pause deactivates immediately
And a warm return greeting appears (zero "you've been away" messaging per UX-DR48)
And the UI restores (600ms deactivation per UX-DR75)
```

### AC 3: VoiceOver Accessibility

```
Given VoiceOver is enabled
When Pause activates
Then "Pause Mode activated" is announced (UX-DR39)
And deactivation announces similarly
```

### AC 4: Reduce Motion Support

```
Given Reduce Motion is enabled
When Pause activates/deactivates
Then palette change is instant (no animation per UX-DR58)
```

### AC 5: System-Suggested Pausing

```
Given the coach detects sustained high-intensity engagement (FR35)
When the system suggests pausing
Then the coach asks in-conversation: "Want to take a breather?"
And the user can accept or decline naturally
```

### AC 6: Pause State Persistence

```
Given the user activates Pause Mode
When they force-quit and relaunch the app
Then Pause Mode is still active (persisted to database)
And the UI shows pause state correctly on launch
```

## Tasks / Subtasks

- [x] Task 1: Database migration for pause state persistence (AC: 6)
  - [x] 1.1 Add migration v14: add `isPaused` (Bool, default false) and `pausedAt` (Date, nullable) columns to UserProfile table
  - [x] 1.2 Load persisted pause state into AppState on app launch in RootView
  - [x] 1.3 Write tests for migration v14 and pause state round-trip

- [x] Task 2: Implement `CoachingTheme.applyingPauseMode()` (AC: 1, 4)
  - [x] 2.1 Light mode: reduce saturation across all palette colors (desaturated sage → gray-greens)
  - [x] 2.2 Dark mode: shift to near-monochrome warmth (earth tones → warm grays)
  - [x] 2.3 Avatar retains gentle color/glow in both modes (avatar is only saturated element)
  - [x] 2.4 Update existing theme tests — stub returning `self` must now return modified theme
  - [x] 2.5 Verify safety override ordering: in `themeFor()`, safety is applied before pause — confirm this remains correct (no new code needed, just verification)

- [x] Task 3: Pause toggle UI and activation flow (AC: 1, 3)
  - [x] 3.1 Add pause toggle to HomeView — one gesture, no confirmation dialog
  - [x] 3.2 On activation: set `appState.isPaused = true`, persist to UserProfile via GRDB
  - [x] 3.3 Derive `appState.avatarState = .resting` when paused (already in AvatarState.derive)
  - [x] 3.4 PauseModeTransition animation: 1200ms desaturation (already partially in HomeView as `saturation(0.7)` with 1.2s animation)
  - [x] 3.5 VoiceOver: post `UIAccessibility.Notification.announcement` with "Pause Mode activated"
  - [x] 3.6 Coach "Rest well" message: append a final assistant message to current/last conversation session

- [x] Task 4: Deactivation flow — Warm Return (AC: 2, 3)
  - [x] 4.1 When user taps "Talk to your coach" during pause: set `appState.isPaused = false`, persist
  - [x] 4.2 UI restore animation: 600ms (already partially implemented as 0.6s easeInOut)
  - [x] 4.3 Warm return greeting: use daily greeting flow (RAG-informed, no "you've been away" messaging)
  - [x] 4.4 VoiceOver: post announcement "Pause Mode deactivated"
  - [x] 4.5 Re-enable notification scheduling (call `rescheduleCheckInNotifications`)

- [x] Task 5: System-suggested pausing (AC: 5)
  - [x] 5.1 Create new `server/prompts/sections/autonomy.md` prompt section with breather suggestion instruction
  - [x] 5.2 Define intensity signals in prompt: consecutive long exchanges, emotional escalation, rapid back-and-forth turns, extended session duration
  - [x] 5.3 Register `autonomy.md` section in `server/prompts/builder.go` for conditional inclusion
  - [x] 5.4 Server-side: no structured field changes — suggestion is natural language in conversation
  - [x] 5.5 If user accepts in conversation, require explicit pause activation (user still taps pause toggle)

- [x] Task 6: Tests (AC: all)
  - [x] 6.1 Unit tests: pause state persistence (GRDB in-memory DB)
  - [x] 6.2 Unit tests: theme transformation produces different palette when paused
  - [x] 6.3 Unit tests: ExperienceContext/HomeDisclosureStage correctly derives paused state
  - [x] 6.4 Unit tests: notification suppression when paused
  - [x] 6.5 Unit tests: safety level override beats pause theme
  - [x] 6.6 Unit tests: AvatarState.derive(isPaused: true) returns .resting

## Dev Notes

### What Already Exists (DO NOT Recreate)

The following pause mode infrastructure is **already implemented** in the codebase. Reuse, extend, or verify — never recreate:

| Component | File | What Exists |
|-----------|------|-------------|
| `AppState.isPaused` | `App/AppState.swift` | Boolean flag, runtime only (needs persistence) |
| `HomeDisclosureStage.paused` | `Core/State/HomeDisclosureStage.swift` | Enum case + priority override in HomeViewModel |
| Home screen desaturation | `Features/Home/Views/HomeView.swift` | `saturation(0.7)` on full view, `1/0.7` boost on CoachActionButton, 1.2s/0.6s animation with Reduce Motion support |
| Sprint progress muting | `Features/Home/Views/SprintProgressView.swift` | `isMuted` prop → 0.4 opacity |
| Sprint tap disabled | `Features/Home/Views/HomeView.swift` | `.disabled(homeStage == .paused)` |
| Insight card pause text | `Features/Home/ViewModels/HomeViewModel.swift` | Returns "Your coach is here when you're ready." when paused |
| Avatar resting state | `Core/State/AvatarState.swift` | `.resting` case with 0.65 saturation, `derive(isPaused:)` method |
| Notification suppression | `App/RootView.swift` (line 262) | `guard !appState.isPaused` before scheduling |
| Theme function param | `Core/Theme/CoachingTheme.swift` | `themeFor(isPaused:)` calls `applyingPauseMode()` |
| Theme stub | `Core/Theme/CoachingTheme.swift` | `applyingPauseMode()` returns `self` — **this is what you fill in** |
| Safety palette pattern | `Core/Theme/ColorPalette.swift` (lines 199-253) | `applying(safetyOverride:)` with `transformAll()` — **follow this exact pattern for pause** |
| Color transform helpers | `Core/Theme/Color+SafetyTransformations.swift` | `adjustedSaturation(by:)` and `adjustedWarmth(by:)` — ready to use for pause palette |
| Test coverage | Multiple test files | HomeDisclosureStage, AvatarState, theme stub, sprint muting tests exist |

### What Needs to Be Built

1. **Database persistence** — Add migration v14: `isPaused` Bool + `pausedAt` Date? to UserProfile. Load on launch, save on toggle.

2. **`applyingPauseMode()` implementation** — Currently a stub. Implement per UX-DR5 Pause Mode Palette:
   - Light: reduce saturation of all `ColorPalette` tokens. Sage → gray-greens. Avatar retains color.
   - Dark: near-monochrome warmth. Avatar retains soft green glow.
   - Return a new `CoachingTheme` with modified palette (DO NOT mutate in place — `CoachingTheme` uses `let palette`).
   - **Follow the exact pattern in `ColorPalette.swift` lines 199-253:** The `applying(safetyOverride:)` method uses a private `transformAll()` helper to process all 25 color tokens. Use the same approach for pause. Transformation helpers `adjustedSaturation(by:)` and `adjustedWarmth(by:)` are available in `Color+SafetyTransformations.swift`.

3. **Pause toggle UI** — Add to HomeView or SettingsView. One gesture, no confirmation (UX-DR48). Simplest: a button/toggle on the home screen near the avatar area.

4. **"Rest well" message** — On activation, append an assistant message to the most recent conversation session. Use `DatabaseManager` to write a `Message` record with `role: .assistant`, `content: "Rest well."`.

5. **Warm return greeting** — On deactivation + "Talk to your coach" tap, the daily greeting system (already in HomeViewModel) handles the return naturally. Verify it doesn't include any "you've been away" language.

6. **VoiceOver announcements** — Post `UIAccessibility.post(notification: .announcement, argument: "Pause Mode activated")` on state change. Check `UIAccessibility.isVoiceOverRunning` if needed.

7. **System-suggested pause (AC5)** — `autonomy.md` does NOT exist yet in `server/prompts/sections/` (13 sections exist; autonomy is not among them). Create it from scratch with coaching instructions for suggesting breathers after sustained intensity. Define concrete intensity signals: consecutive long exchanges, emotional escalation, rapid back-and-forth, extended session duration. Register in `prompts/builder.go`. This is conversational only — no structured field or special handling needed at MVP.

### Architecture Compliance

**State Management:**
- `AppState` is `@MainActor @Observable` — all mutations on main actor
- Persist via GRDB `dbPool.write` (async) — update UserProfile record
- On launch: `dbPool.read` to load `isPaused` into AppState

**Theme System:**
- `CoachingTheme` uses `let` properties — return new instance from `applyingPauseMode()`
- Safety override rule: in `themeFor()`, safety transformation is applied BEFORE pause. If safety is elevated, its theme wins (already correct order in existing code)

**Notification Service:**
- Check-in notifications already guarded by `!appState.isPaused` in RootView
- Verify no other notification paths bypass this guard

**Concurrency:**
- ViewModels: `@MainActor @Observable final class`
- Database writes: `await databaseManager.dbPool.write { db in ... }`
- Never use `DispatchQueue.main.async` — use `@MainActor`

### File Structure Requirements

**Files to modify:**
```
ios/sprinty/Services/Database/Migrations.swift          — Add v14 migration
ios/sprinty/Models/UserProfile.swift                    — Add isPaused, pausedAt columns
ios/sprinty/Core/Theme/CoachingTheme.swift               — Implement applyingPauseMode()
ios/sprinty/Core/Theme/ColorPalette.swift                 — Add applyingPauseMode() palette transformation (follow applying(safetyOverride:) pattern at lines 199-253)
ios/sprinty/Features/Home/Views/HomeView.swift            — Add pause toggle UI
ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift  — Add togglePause() method
ios/sprinty/App/RootView.swift                            — Load persisted pause state on launch
server/prompts/builder.go                                 — Register autonomy.md section
```

**Files to create:**
```
server/prompts/sections/autonomy.md                      — New prompt section for breather suggestion (AC5, FR35)
```

**Test files to modify/create:**
```
ios/Tests/Theme/ThemeForTests.swift                      — Update stub tests → real transformation tests
ios/Tests/Models/UserProfileTests.swift                  — Add isPaused persistence tests (if exists)
ios/Tests/Services/Database/MigrationTests.swift         — Add v14 migration test (if exists)
```

### Library & Framework Requirements

- **GRDB.swift** — Used for all database operations. Async-only access (`dbPool.read`, `dbPool.write`). Migrations via `DatabaseMigrator`.
- **Swift Testing** — NOT XCTest. Use `@Test` and `#expect` macros.
- **Observation framework** — NOT Combine. `@Observable` for state.
- **SwiftUI** — iOS 17+ minimum. Use `@Environment(\.accessibilityReduceMotion)` for Reduce Motion.
- **No new dependencies needed** for this story.

### Testing Standards

- Test naming: `test_methodName_condition_expectedResult`
- Use in-memory GRDB database for persistence tests
- Test both pause activation AND deactivation paths
- Test safety override: paused + elevated safety → safety theme wins
- Test Reduce Motion: animation duration is 0 when enabled
- Mocks must be `@unchecked Sendable`

### Previous Story Intelligence

**From Story 6.2 (Safety State Manager & Theme Transformations):**
- Established the `SafetyThemeOverride` enum and `themeFor()` function pattern
- Theme transformations return new `CoachingTheme` instances with modified palettes
- Safety override applied via `theme.applying(safetyOverride:)` — this is the pattern to follow for `applyingPauseMode()`
- `CoachingTheme` has `let palette: ColorPalette` — modifications return new instances

**From Story 6.5 (Safety Regression Suite):**
- Build tag pattern for test isolation
- Benchmark approach for non-deterministic behavior
- Code review fixed computation ordering and added missing metrics

**Patterns from recent commits:**
- All stories follow pattern: feat commit with code review fixes applied
- Code review feedback has consistently caught: computation ordering, missing metrics/fields, edge case handling
- Tests are non-negotiable — every story includes comprehensive test coverage

### Git Intelligence

Recent commits (all Epic 6 — Safety & Clinical Boundaries):
- `605017f` Story 6.5 — Safety regression suite
- `2692eb1` Story 6.4 — Compliance logging
- `0a51ee8` Story 6.3 — Post-crisis re-engagement
- `2115d5b` Story 6.2 — Safety state manager and theme transformations
- `e25c966` Story 6.1 — On-device safety classification

Story 6.2 is most relevant — it established the theme transformation system that this story extends. The `themeFor()` function, `SafetyThemeOverride`, and palette modification patterns are the direct foundation.

### Pause Mode Palette Specification (UX-DR5)

**Light Mode:**
- Reduce saturation across all home palette tokens
- Sage tones fade to gentle gray-greens
- Avatar retains gentle color; everything else softens to near-monochrome warmth

**Dark Mode:**
- Near-monochrome. Earth tones desaturate to warm grays
- Avatar is only element with remaining color — soft green glow
- "Everything has gone to sleep"

**Animation Timing (UX-DR75):**
- Activation: 1200ms (slow, deliberate — "the slowness IS the design")
- Deactivation: 600ms (faster — "life returning")
- Reduce Motion: instant (no animation)

**Already implemented in HomeView:**
- `saturation(0.7)` on full view — this is the visual desaturation
- `1/0.7` saturation boost on CoachActionButton — keeps primary action vibrant
- Animation durations already correct (1.2s activation, 0.6s deactivation)
- Reduce Motion already supported via `@Environment(\.accessibilityReduceMotion)`

The `applyingPauseMode()` implementation adds **theme-level** color modification on top of the view-level saturation that already exists. This affects the actual color tokens (background, text, accent colors) for a richer pause visual — not just opacity/saturation modifiers.

**Implementation pattern:** Follow `ColorPalette.applying(safetyOverride:)` (lines 199-253 in `ColorPalette.swift`). It uses a private `transformAll()` method to process all 25 semantic color tokens via `adjustedSaturation(by:)` and `adjustedWarmth(by:)` from `Color+SafetyTransformations.swift`. Create a parallel `applyingPauseMode()` on `ColorPalette` with pause-specific saturation/warmth factors, then call it from `CoachingTheme.applyingPauseMode()`.

### Critical Constraints

1. **One gesture, no confirmation** — Pause activates instantly. No "Are you sure?" dialog. (UX-DR48)
2. **Zero notifications during Pause** — All non-safety notifications suppressed. Safety (Orange/Red) still fires. (UX-DR66)
3. **Zero "you've been away" messaging** — On return, greeting is warm and natural, never guilt-inducing. (UX-DR48)
4. **Safety always wins** — If safety level is elevated during Pause, safety theme/behavior overrides Pause visuals. (UX-DR94)
5. **"Talk to your coach" always enabled** — Primary action button is never disabled, even during Pause. (UX-DR29)
6. **Coach message "Rest well"** — Exactly this text, one beat, on activation. Frames pause as self-care.
7. **No server changes for Pause state** — Server is stateless. Pause is entirely on-device. The only server touch is AC5 (prompt section for suggesting breathers).

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 7, Story 7.1, FRs 34-36]
- [Source: _bmad-output/planning-artifacts/architecture.md — AppState, ExperienceContext, CoachingTheme, SafetyHandler]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR5, UX-DR29, UX-DR39, UX-DR48, UX-DR58, UX-DR66, UX-DR75, UX-DR94]
- [Source: _bmad-output/planning-artifacts/prd.md — FR34-38, FR48-49, FR52]
- [Source: _bmad-output/project-context.md — Swift 6 concurrency rules, GRDB patterns, testing standards]
- [Source: _bmad-output/implementation-artifacts/6-5-safety-regression-suite.md — Previous story patterns]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- No debug issues encountered

### Completion Notes List
- Task 1: Added v14 migration with `isPaused` (Bool, default false) and `pausedAt` (Date?) columns to UserProfile. RootView loads persisted pause state on app launch. 4 migration tests added.
- Task 2: Implemented `ColorPalette.applyingPauseMode()` following the `applying(safetyOverride:)` pattern with 55% desaturation and 4% warmth shift. Avatar tokens preserved (only saturated element). Updated `CoachingTheme.applyingPauseMode()` from stub. Verified safety-before-pause ordering in `themeFor()`. Updated ThemeForTests with 4 new pause-specific tests.
- Task 3: Added pause toggle button to HomeView (pause.circle/play.circle icon). `togglePause()` in HomeViewModel handles: state toggle, avatar derivation, VoiceOver announcement, GRDB persistence, and "Rest well." message insertion. HomeView now passes `isPaused` to `themeFor()` for theme-level desaturation.
- Task 4: Deactivation handled by same `togglePause()`. RootView now watches `appState.isPaused` via `onChange` to reschedule check-in notifications on unpause. Verified no "you've been away" messaging exists.
- Task 5: Created `server/prompts/sections/autonomy.md` with breather suggestion instructions, intensity signals, and guard rails. Registered in `builder.go` section list and Build() assembly. Updated all 3 Go test fixture maps.
- Task 6: Created `HomeViewModelPauseTests.swift` with 14 comprehensive tests covering: persistence roundtrip, theme desaturation (light/dark), HomeDisclosureStage derivation, notification suppression, safety override priority, AvatarState derivation, avatar state changes on toggle, "Rest well" message insertion, and no-message on deactivation.

### Change Log
- 2026-03-31: Story 7.1 implementation complete — all 6 tasks, all ACs satisfied, 615 iOS tests + Go tests passing
- 2026-04-01: Code review fixes — AC 2 implementation gap resolved (pause deactivates on "Talk to your coach" tap), stale test names clarified, sleep durations increased for CI robustness

### File List
- ios/sprinty/Services/Database/Migrations.swift — Added v14_pauseMode migration
- ios/sprinty/Models/UserProfile.swift — Added isPaused, pausedAt fields
- ios/sprinty/Core/Theme/CoachingTheme.swift — Implemented applyingPauseMode() (was stub)
- ios/sprinty/Core/Theme/ColorPalette.swift — Added applyingPauseMode() palette transformation
- ios/sprinty/Features/Home/Views/HomeView.swift — Added pause toggle button, theme-level pause support
- ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift — Added togglePause(), appendRestWellMessage()
- ios/sprinty/App/RootView.swift — Load persisted pause state on launch, reschedule notifications on unpause, deactivate pause on "Talk to your coach" tap (code review fix)
- server/prompts/sections/autonomy.md — NEW: breather suggestion prompt section
- server/prompts/builder.go — Registered autonomy.md section
- server/prompts/builder_test.go — Added autonomy.md to test fixtures, updated section count
- server/tests/handlers_test.go — Added autonomy.md to 3 test fixture maps
- ios/Tests/Database/MigrationTests.swift — Added 4 v14 migration tests
- ios/Tests/Theme/ThemeForTests.swift — Replaced stub test with 4 pause mode theme tests; clarified stale test names (code review fix)
- ios/Tests/Features/Home/HomeViewModelPauseTests.swift — NEW: 14 pause mode unit tests; increased sleep durations for CI robustness (code review fix)
