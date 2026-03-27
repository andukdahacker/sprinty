# Story 6.2: Safety State Manager & Theme Transformations

Status: done

## Story

As a user in distress,
I want the app's visual environment to shift to match the seriousness of the moment,
So that the interface supports rather than distracts during sensitive situations.

## Acceptance Criteria

1. **Given** the SafetyStateManager receives a classification **When** the safety level changes **Then** relative theme transformations apply: Yellow (warmth increase + subtle desaturation), Orange (noticeable desaturation + gamification hidden), Red (significant desaturation + minimal elements + crisis resources) **And** transitions are immediate (instant timing, 0.0s — no animation per UX-DR74)

2. **Given** a safety state is active (Orange or Red) **When** subsequent turns return Green **Then** the sticky minimum applies: Orange/Red holds for 3 turns or until Green×2 consecutive (UX-DR38) **And** only `source: .genuine` classifications trigger sticky minimum; `source: .failsafe` clears immediately (UX-DR71)

3. **Given** the safety state **When** it conflicts with other states (Pause Mode, coaching mode ambient) **Then** safety always wins — overrides all other visual states (UX-DR94)

4. **Given** VoiceOver is enabled **When** safety state changes **Then** appropriate announcements are made: Yellow ("Coach is being more attentive"), Orange ("Connecting you with resources"), Red ("Safety resources available")

## Tasks / Subtasks

- [x] Task 1: Implement color transformation utilities (AC: #1)
  - [x] 1.1 Create `Color+SafetyTransformations.swift` in `Core/Theme/` with functions to adjust saturation and warmth of a `Color` value. Use SwiftUI's HSB color model — convert hex-initialized colors to HSB, adjust saturation/brightness, return new `Color`. Keep it simple: `func adjustedSaturation(by factor: CGFloat) -> Color` and `func adjustedWarmth(by factor: CGFloat) -> Color` on Color extension
  - [x] 1.2 Verify transformations produce correct results across all four base palettes (homeLight, homeDark, conversationLight, conversationDark) — especially dark mode where desaturation must produce warm grays, not cold grays

- [x] Task 2: Implement `applying(safetyOverride:)` on CoachingTheme (AC: #1)
  - [x] 2.1 Fill in the existing stub at `CoachingTheme.swift:27-28` (currently returns `self`). The `themeFor()` helper already passes the `safetyLevel` parameter and calls `applying(safetyOverride:)` — so filling in this stub is sufficient to activate safety theme transformations everywhere. The method returns a new `CoachingTheme` with a transformed `ColorPalette`
  - [x] 2.2 For `.warmthIncrease` (Yellow): increase warmth ~5-10% (shift hue slightly toward orange/warm), reduce saturation ~10-15%. Subtle — user should feel "cared for, not flagged"
  - [x] 2.3 For `.noticeableDesaturation` (Orange): reduce saturation ~40-50%, slight warmth increase. Visibly different — "the space quiets"
  - [x] 2.4 For `.significantDesaturation` (Red): reduce saturation ~70-80%, maximize calm warmth. Near-monochrome with warm undertone — "minimal elements visible, crisis resources prominent"
  - [x] 2.5 Create `ColorPalette.applying(safetyOverride:)` that returns a new palette with ALL 25 color properties transformed. **IMPORTANT**: existing shift methods (`discoveryWarmShift`, etc.) only replace `backgroundStart`/`backgroundEnd` (2 of 25 properties). Safety transformation is fundamentally different — it must transform backgrounds, text colors, accents, gradients, avatar colors, action buttons, portrait colors, etc. Construct and return a new `ColorPalette(...)` with all 25 properties adjusted. Crisis resource colors in `ProfessionalResourcesView` use hardcoded colors (not palette tokens), so they remain legible automatically
  - [x] 2.6 Ensure crisis resource colors remain high-contrast and legible even under heavy desaturation (Red state) — verify `ProfessionalResourcesView` hardcoded colors contrast against the desaturated palette backgrounds

- [x] Task 3: Implement SafetyStateManager with sticky minimum logic (AC: #2)
  - [x] 3.1 Create `SafetyStateManager.swift` in `Services/Safety/`. This is a `@MainActor @Observable final class` — it is a logic component, NOT a view. Conforms to `Sendable` only via `@MainActor`
  - [x] 3.2 Add `SafetyClassificationSource` enum: `.genuine` (real classification from server/on-device), `.failsafe` (fail-safe Yellow from classification failure per UX-DR71)
  - [x] 3.3 Implement sticky minimum state tracking properties: `private var turnsAtElevatedLevel: Int = 0`, `private var consecutiveGreenCount: Int = 0`, `private var activeElevatedLevel: SafetyLevel? = nil` (only set when Orange/Red active)
  - [x] 3.4 Implement `func processClassification(_ level: SafetyLevel, source: SafetyClassificationSource) -> SafetyLevel` — the core logic:
    - If source is `.failsafe` → return the level directly, clear sticky state immediately, reset counters
    - If level is Orange or Red → set `activeElevatedLevel`, reset `consecutiveGreenCount` to 0, set `turnsAtElevatedLevel` to 0
    - If level is Green and sticky is active → increment `turnsAtElevatedLevel`, increment `consecutiveGreenCount`. If `turnsAtElevatedLevel >= 3` OR `consecutiveGreenCount >= 2` → clear sticky, return Green. Else → return `activeElevatedLevel!`
    - If level is Yellow and sticky is active → reset `consecutiveGreenCount` to 0, increment `turnsAtElevatedLevel`. Return `activeElevatedLevel!` (sticky holds)
    - If no sticky active → return level as-is
  - [x] 3.5 Expose `@Observable` property `var currentLevel: SafetyLevel = .green` that views can observe
  - [x] 3.6 Add `func resetSession()` to clear all sticky state — called when conversation session ends or user returns after crisis (Story 6.3 will use this)
  - [x] 3.7 Create `SafetyStateManagerProtocol` for testability

- [x] Task 4: Wire SafetyStateManager into CoachingViewModel (AC: #1, #2, #3)
  - [x] 4.1 Add `safetyStateManager: SafetyStateManagerProtocol` as dependency on `CoachingViewModel` (protocol-based DI, same pattern as `safetyHandler`)
  - [x] 4.2 On SSE `done` event: after existing `safetyHandler.classify(serverLevel:)` call, pass result through `safetyStateManager.processClassification(_:source:)`. Source is `.genuine` for normal classifications, `.failsafe` when `safetyHandler.classify()` was called with nil serverLevel
  - [x] 4.3 Update `currentSafetyUIState` from the SafetyStateManager's processed level (not raw server level)
  - [x] 4.4 Wire SafetyStateManager in `RootView.swift` DI container — create once, inject into CoachingViewModel
  - [x] 4.5 Call `safetyStateManager.resetSession()` when starting a new conversation session

- [x] Task 5: Enforce safety-wins-all override in theme construction (AC: #3)
  - [x] 5.1 In `CoachingView.swift`, update `conversationTheme` computed property: when safety level is Yellow or above, do NOT apply coaching mode ambient shifts (`.applyingAmbientMode()`) or challenger shift (`.applyingChallengerShift()`). Safety overrides all other visual states per UX-DR94
  - [x] 5.2 Same logic for HomeView theme if safety state is propagated there — safety override must take precedence over any future Pause Mode palette

- [x] Task 6: VoiceOver accessibility announcements (AC: #4)
  - [x] 6.1 Verify existing VoiceOver announcements from Story 6.1 (CoachingView already has announcements). If already implemented, confirm they trigger on SafetyStateManager level changes (not just raw server level)
  - [x] 6.2 Ensure announcements fire when sticky minimum prevents de-escalation (no announcement on "still holding at Orange") — only announce on actual visible level changes
  - [x] 6.3 Ensure announcements fire when sticky minimum releases (e.g., Orange→Green transition after 3 turns)

- [x] Task 7: Tests (AC: #1, #2, #3, #4)
  - [x] 7.1 `SafetyStateManagerTests.swift` — test sticky minimum logic exhaustively (OR = first-to-occur: releases when EITHER turnsAtElevated >= 3 OR consecutiveGreen >= 2):
    - Green→Orange→Green→Green→Green should return: Green, Orange, Orange, Green, Green (Green×2 consecutive releases at turn 2, before 3-turn threshold)
    - Green→Red→Green→Green should return: Green, Red, Red, Green (Green×2 consecutive releases at turn 2)
    - Green→Orange→Yellow→Green→Green→Green should return: Green, Orange, Orange, Orange, Green, Green (Yellow resets consecutiveGreen to 0; after Yellow: turn 2 Green has consecutiveGreen=1, turn 3 Green has turnsAtElevated=3 → releases)
    - Green→Orange→Green→Yellow→Green→Green→Green should return: Green, Orange, Orange, Orange, Orange, Green, Green (Yellow at turn 2 resets consecutiveGreen; turn 3 has turnsAtElevated=3 → releases via 3-turn threshold)
    - Failsafe source: Orange(failsafe)→Green should return: Orange, Green (no sticky)
    - Orange(genuine)→Orange(genuine)→Green→Green: sticky resets on re-escalation — returns Orange, Orange, Orange, Green (turnsAtElevated resets to 0 on second Orange)
    - Session reset clears all state
  - [x] 7.2 `CoachingThemeSafetyTests.swift` — test theme transformations:
    - `.none` returns identical palette
    - `.warmthIncrease` produces measurably warmer, slightly less saturated colors
    - `.noticeableDesaturation` produces visibly desaturated colors
    - `.significantDesaturation` produces near-monochrome warm colors
    - Transformations work on all 4 base palettes (light/dark × home/conversation)
  - [x] 7.3 `MockSafetyStateManager.swift` in `Tests/Mocks/` — stub with recorded calls
  - [x] 7.4 Update existing `CoachingViewModelSafetyTests` to verify SafetyStateManager integration (sticky minimum applied before UI state update)
  - [x] 7.5 Test safety-wins-all: verify ambient mode shifts suppressed when safety active

## Dev Notes

### What Already Exists (DO NOT RECREATE)

Story 6.1 established the complete safety foundation. These files already exist and work:

- **SafetyLevel enum** — `ios/sprinty/Models/ConversationSession.swift:14-34` — cases: `.green`, `.yellow`, `.orange`, `.red` with `Comparable` conformance
- **SafetyUIState struct** — `ios/sprinty/Models/SafetyUIState.swift` — holds `level`, `hiddenElements`, `coachExpression`, `notificationBehavior`, `showCrisisResources`
- **HiddenElement enum** — `.gamification`, `.sprintProgress`, `.avatarActivity`, `.celebrations`
- **SafetyHandlerProtocol + SafetyHandler** — `ios/sprinty/Services/Safety/` — `classify(serverLevel:)` fail-safes to `.yellow` when nil; `uiState(for:)` maps level to UI state
- **SafetyThemeOverride enum** — `ios/sprinty/Core/Theme/CoachingTheme.swift:12-17` — `.none`, `.warmthIncrease`, `.noticeableDesaturation`, `.significantDesaturation`
- **`applying(safetyOverride:)` stub** — `CoachingTheme.swift:27-28` — exists but returns `self` unchanged. THIS IS WHAT STORY 6.2 FILLS IN
- **CoachingView safety integration** — already maps `currentSafetyUIState.level` → `SafetyThemeOverride`, hides gamification, shows crisis resources, does VoiceOver announcements
- **ProfessionalResourcesView** — crisis resources UI (741741, 988, therapist finder)
- **CoachExpression.gentle** — already used for Yellow+ states
- **Immediate transitions** — `.animation(nil)` already applied in CoachingView for safety changes
- **Complete server pipeline** — prompt section, tool schema, parsing, SSE done event, API contract all working
- **MockSafetyHandler** — `ios/Tests/Mocks/MockSafetyHandler.swift`

### What This Story Creates NEW

1. **Color transformation utilities** — HSB-based saturation/warmth adjustment on `Color`
2. **`applying(safetyOverride:)` implementation** — the actual palette transformation logic (currently a stub returning `self`)
3. **SafetyStateManager** — new `@Observable` class managing sticky minimum logic (3 turns / Green×2)
4. **SafetyClassificationSource enum** — `.genuine` vs `.failsafe` to discriminate sticky behavior
5. **Safety-wins-all enforcement** — suppressing ambient mode shifts when safety active

### Architecture Patterns to Follow

- **@MainActor @Observable final class** for SafetyStateManager (same pattern as all ViewModels)
- **Protocol-based DI** — create `SafetyStateManagerProtocol`, inject via init, mock in tests
- **Services are created in RootView.swift** DI container — add SafetyStateManager there
- **Swift Testing framework** — use `@Test` and `#expect`, NOT XCTest
- **GRDB records** conform to `Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable`
- **No Combine** — use `@Observable` + async/await only
- **Never use `DispatchQueue.main.async`** — use `@MainActor` instead
- **Access control** — `internal` default, `private` for implementation details, explicit `public`/`package` for cross-feature types

### Theme Transformation Design

Safety palette transformations are **relative** (modify current active palette, not absolute values). Work in **HSB color space** — convert to hue/saturation/brightness, adjust, return new Color.

- **Yellow**: Hue warmth +5-10°, saturation -10-15%
- **Orange**: Saturation -40-50%, slight warmth increase
- **Red**: Saturation -70-80%, maximize calm warmth → near-monochrome

Dark mode: desaturation must produce **warm grays** (amber/earth undertone), not cold grays. Dark palettes already have low saturation — reduce remaining saturation proportionally. Avatar glow and crisis resources should remain most visually prominent at Red.

### Sticky Minimum Logic (UX-DR38)

This is the KEY new behavior. After Orange or Red classification:
- The elevated safety state **holds** until EITHER condition is met (OR / first-to-occur):
  - `turnsAtElevatedLevel >= 3` (3 subsequent turns have passed), OR
  - `consecutiveGreenCount >= 2` (2 consecutive Green classifications received)
- Whichever condition triggers **first** releases the sticky state
- Yellow does NOT trigger sticky minimum — only Orange and Red
- Yellow during sticky DOES reset the consecutive green counter to 0 but does NOT reset the turn counter
- Re-escalation (new Orange/Red while sticky active) resets `turnsAtElevatedLevel` to 0 and `consecutiveGreenCount` to 0
- `source: .failsafe` bypasses sticky entirely — clears immediately on next turn
- Sticky state is **session-scoped** — resets when conversation session ends

### State Priority (UX-DR94)

Safety ALWAYS wins. When safety override is active (Yellow+):
- Coaching mode ambient shifts (Discovery warm, Directive cool, Challenger deep) are suppressed
- Future Pause Mode desaturation is suppressed
- Only one visual state at a time — safety IS that state

### Accessibility Cross-Testing Requirements (UX-DR103)

- Safety × VoiceOver: announcements on level changes
- Safety × Dynamic Type: crisis resources visible without truncation at XXXL
- Safety × Reduced Motion: transitions already instant (0.0s), compliant
- Safety × Color Blindness: transformations validated across deuteranopia, protanopia, tritanopia — color cannot be sole indicator of state

### Project Structure Notes

New files go in existing directories:
- `ios/sprinty/Core/Theme/Color+SafetyTransformations.swift` — color utilities
- `ios/sprinty/Services/Safety/SafetyStateManager.swift` — sticky minimum manager
- `ios/sprinty/Services/Safety/SafetyStateManagerProtocol.swift` — protocol
- `ios/sprinty/Services/Safety/SafetyClassificationSource.swift` — source enum
- `ios/Tests/Services/SafetyStateManagerTests.swift` — tests
- `ios/Tests/Features/CoachingThemeSafetyTests.swift` — theme tests
- `ios/Tests/Mocks/MockSafetyStateManager.swift` — mock

Modified files:
- `ios/sprinty/Core/Theme/CoachingTheme.swift` — implement `applying(safetyOverride:)`
- `ios/sprinty/Core/Theme/ColorPalette.swift` — add `applying(safetyOverride:)` with color transforms
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — add SafetyStateManager DI, wire sticky logic
- `ios/sprinty/Features/Coaching/Views/CoachingView.swift` — suppress ambient shifts when safety active
- `ios/sprinty/App/RootView.swift` — create and inject SafetyStateManager
- `ios/sprinty.xcodeproj/project.pbxproj` — new source files

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2] — acceptance criteria, BDD scenarios
- [Source: _bmad-output/planning-artifacts/architecture.md#Safety Classification Pipeline] — SafetyHandler flow, theme system, state management
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR38] — SafetyStateManager spec, sticky minimum
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR74] — instant safety transitions (0.0s)
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR94] — safety always wins state combination rule
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR6] — safety tier palette transformations
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR71] — failsafe classifications clear immediately
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR103] — accessibility cross-testing
- [Source: _bmad-output/implementation-artifacts/6-1-on-device-safety-classification.md] — previous story files, patterns, decisions

### Previous Story Intelligence (Story 6.1)

**Build gotchas from 6.1 — avoid repeating:**
- RadiusTokens has no `card` — use `container`. ColorPalette has no `cardBackground` — use `insightBackground`
- Always verify exact property names in existing code before using them (common source of build errors)
- project.pbxproj must be updated for new files — include in file list
- No new DB migration needed — SafetyLevel column existed since v1

**Baseline:** 535 tests, 53 suites, all passing. VoiceOver announcements already implemented in CoachingView.

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Build error: SafetyStateManager Sendable conformance — fixed by making SafetyStateManagerProtocol `@MainActor` instead of `Sendable` (MainActor class can't satisfy nonisolated Sendable protocol requirements in Swift 6 strict concurrency)

### Completion Notes List
- Task 1: Created `Color+SafetyTransformations.swift` with `adjustedSaturation(by:)` and `adjustedWarmth(by:)` HSB-based transformations. Warmth shifts hue toward amber (0.08). Desaturation reduces by factor. UIColor bridge for HSB extraction.
- Task 2: Implemented `CoachingTheme.applying(safetyOverride:)` delegating to `ColorPalette.applying(safetyOverride:)`. Yellow: warmth +8%, desat 12%. Orange: warmth +5%, desat 45%. Red: warmth +10%, desat 75%. All 25 palette properties transformed (vs ambient shifts that only change 2 background properties). ProfessionalResourcesView uses hardcoded colors — remains legible under all safety states.
- Task 3: Created SafetyStateManager as `@MainActor @Observable final class` with sticky minimum logic. SafetyClassificationSource enum (`.genuine`/`.failsafe`). Protocol is `@MainActor` (not plain Sendable) to match the Observable class pattern.
- Task 4: Wired SafetyStateManager into CoachingViewModel via protocol DI. Done event handler now routes through `processClassification(_:source:)`. Source determined by whether serverLevel parsed as nil (failsafe) or valid (genuine). Session reset called on new conversation creation.
- Task 5: CoachingView `conversationTheme` now suppresses ambient mode shifts and challenger shift when safety override is active (`.none` check). HomeView safety propagation deferred — safety state not currently surfaced on home screen.
- Task 6: VoiceOver announcements verified — they fire on `currentSafetyUIState.level` changes which now reflect processed (sticky) level. No announcement during sticky hold (no level change). Announcement fires on sticky release (level actually changes).
- Task 7: 23 new tests across 3 files. SafetyStateManagerTests: 10 tests covering all sticky minimum scenarios. CoachingThemeSafetyTests: 11 tests covering transformations across all 4 palettes + warm grays. CoachingViewModelSafetyTests: 2 new integration tests. MockSafetyStateManager created.

### Change Log
- 2026-03-27: Story context created by create-story workflow
- 2026-03-27: Story 6.2 implementation complete — all 7 tasks, 558 tests passing (23 new)
- 2026-03-27: Code review fixes — hue wrapping bug in adjustedWarmth (circular shortest path), added 2 safety-wins-all tests (Task 7.5), improved .none override test coverage

### File List
- ios/sprinty/Core/Theme/Color+SafetyTransformations.swift (new)
- ios/sprinty/Core/Theme/ColorPalette.swift (modified — added `applying(safetyOverride:)` and `transformAll`)
- ios/sprinty/Core/Theme/CoachingTheme.swift (modified — implemented `applying(safetyOverride:)` stub)
- ios/sprinty/Services/Safety/SafetyClassificationSource.swift (new)
- ios/sprinty/Services/Safety/SafetyStateManager.swift (new)
- ios/sprinty/Services/Safety/SafetyStateManagerProtocol.swift (new)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified — added SafetyStateManager DI, sticky logic wiring, session reset)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified — safety-wins-all theme override)
- ios/sprinty/App/RootView.swift (modified — create and inject SafetyStateManager)
- ios/Tests/Services/SafetyStateManagerTests.swift (new)
- ios/Tests/Features/CoachingThemeSafetyTests.swift (new)
- ios/Tests/Mocks/MockSafetyStateManager.swift (new)
- ios/Tests/Features/CoachingViewModelSafetyTests.swift (modified — added SafetyStateManager integration tests)
- ios/sprinty.xcodeproj/project.pbxproj (regenerated via xcodegen)
