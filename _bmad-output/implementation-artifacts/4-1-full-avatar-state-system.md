# Story 4.1: Full Avatar State System

Status: done

## Story

As a user,
I want my avatar to reflect my coaching state — active when I'm engaged, resting when I'm taking a break, celebrating when I hit milestones,
So that the app feels alive and connected to my journey.

## Acceptance Criteria

1. **Given** the AvatarView on the home screen (64pt), **When** the user's coaching state changes, **Then** the avatar displays the correct state from five options: Active (upright, full saturation), Resting (relaxed, gentle desaturation), Celebrating (joyful, brightest saturation), Thinking (contemplative, neutral saturation), Struggling (slightly hunched, muted but warm tones) — **And** transitions between states use SwiftUI crossfade (standard 0.4s timing).

2. **Given** avatar state transitions, **When** animations play, **Then** they render at 60fps on iPhone 12 or newer (NFR7).

3. **Given** Reduce Motion is enabled (NFR37), **When** an avatar state changes, **Then** the transition is instant (no animation) — **And** the avatar remains functional but static.

4. **Given** VoiceOver is enabled, **When** the avatar state changes, **Then** the `accessibilityValue` updates to the current state name — **And** the state change is announced.

5. **Given** the celebrating state, **When** triggered by a step completion, **Then** it plays briefly and returns to active — **And** a haptic fires on celebration (one of ≤3 haptic types per calm budget UX-DR66).

## Tasks / Subtasks

- [x] Task 1: Create `AvatarState` enum (AC: #1, #4)
  - [x]1.1 Define `AvatarState` enum in `Core/State/AvatarState.swift` with five cases: `.active`, `.resting`, `.celebrating`, `.thinking`, `.struggling`
  - [x]1.2 Add `displayName: String` computed property for VoiceOver accessibility values
  - [x]1.3 Add `saturationMultiplier: Double` computed property per state: active=1.0, resting=0.65, celebrating=1.15, thinking=0.85, struggling=0.55
  - [x]1.4 Add `static func derive(isPaused: Bool) -> AvatarState` — returns `.resting` when isPaused, `.active` otherwise. Signature accepts only `isPaused` for now; future stories add parameters
  - [x]1.5 Add unit tests for all computed properties and derivation

- [x] Task 2: Add `avatarState` to `AppState` (AC: #1)
  - [x]2.1 Add `var avatarState: AvatarState = .active` to `AppState`
  - [x]2.2 Add `var isPaused: Bool = false` to `AppState` — stub for Story 7.1 (Pause Mode), needed now so derivation compiles

- [x] Task 3: Upgrade `AvatarView` to support state-based rendering (AC: #1, #2, #3, #4)
  - [x]3.1 Add `var state: AvatarState = .active` parameter to `AvatarView` with default value (keeps existing call sites compiling; `avatarId` remains for appearance selection — they are independent: `avatarId` = which art, `state` = which visual mood)
  - [x]3.2 Add `@Environment(\.accessibilityReduceMotion)` check
  - [x]3.3 Apply `.saturation(state.saturationMultiplier)` modifier to avatar image for visual state differentiation
  - [x]3.4 Implement SwiftUI crossfade: use `.id(state)` + `.transition(.opacity)` + `.animation(.easeInOut(duration: 0.4))` — skip animation when reduceMotion is true
  - [x]3.5 Set `.accessibilityValue(state.displayName)` for VoiceOver announcement
  - [x]3.6 Add `#Preview` variants for each avatar state in both light/dark modes

- [x] Task 4: Update `HomeViewModel` to expose avatar state (AC: #1)
  - [x]4.1 Read `appState.avatarState` and expose it to the view
  - [x]4.2 Update `HomeView` to pass `appState.avatarState` to `AvatarView`
  - [x]4.3 Update preview factory to accept `avatarState` parameter

- [x] Task 5: Implement celebrating state auto-return and haptic (AC: #5)
  - [x]5.1 Add `func triggerCelebration()` to `HomeViewModel` — sets avatarState to `.celebrating`, fires haptic, schedules 0.8s return to `.active`
  - [x]5.2 Use `UIImpactFeedbackGenerator(style: .medium)` for celebration haptic — this is one of ≤3 haptic types per calm budget
  - [x]5.3 Use `Task.sleep(for: .milliseconds(800))` then restore previous state (check `Task.isCancelled` before mutation)
  - [x]5.4 Add unit test verifying celebration returns to active after delay

- [x] Task 6: Regenerate project (AC: all)
  - [x]6.1 App source files (`Core/State/AvatarState.swift`) are auto-included from `sprinty/` source directory — no `project.yml` change needed for app target
  - [x]6.2 Verify test files are included in test target (auto-scanned via `- path: Tests` in `project.yml` — no manifest change needed)
  - [x]6.3 Run `xcodegen generate` to regenerate `.xcodeproj`

- [x] Task 7: Write tests (AC: all)
  - [x]7.1 `ios/Tests/Models/AvatarStateTests.swift` — enum properties, saturation values, display names, derivation logic (isPaused→resting, default→active)
  - [x]7.2 `ios/Tests/Features/Home/HomeViewModelAvatarTests.swift` — celebration trigger, auto-return timing, haptic not tested (side effect). **Note:** existing `ios/Tests/Features/Home/HomeViewModelTests.swift` contains other HomeViewModel tests — this is a companion file, not a replacement
  - [x]7.3 Verify test count increases from baseline (335 tests)

## Dev Notes

### What Already Exists — DO NOT Recreate

- **AvatarView** — `ios/sprinty/Features/Home/Views/AvatarView.swift`. Currently a simple circular image with glow shadow. Takes `avatarId: String` and `size: CGFloat`. **Modify in place** — do not create a new view.
- **HomeView** — `ios/sprinty/Features/Home/Views/HomeView.swift`. Passes `viewModel.avatarId` to AvatarView. Already has `@Environment(\.accessibilityReduceMotion)`.
- **HomeViewModel** — `ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift`. Has `avatarId: String`. Add `avatarState` alongside it.
- **AppState** — `ios/sprinty/App/AppState.swift`. Currently minimal: `isAuthenticated`, `needsReauth`, `isOnline`, `onboardingCompleted`, `databaseManager`. Add `avatarState` and `isPaused` (stub) here. **Note:** `isPaused` does NOT exist yet — add it as `var isPaused = false` stub so derivation compiles. Story 7.1 (Pause Mode) will implement the real logic.
- **ExperienceContext** — Defined in `ios/sprinty/Core/Theme/CoachingTheme.swift` as `enum ExperienceContext { case home, conversation }`. This is the theme context, NOT the avatar state. Do NOT conflate them. The architecture doc describes a richer `ExperienceContext` enum — that's a future expansion. For this story, create a separate `AvatarState` enum.
- **CoachExpression** — `ios/sprinty/Features/Coaching/Models/CoachExpression.swift`. Five expression states for the coach character. AvatarState is the user's avatar equivalent — same pattern, different purpose.
- **ColorPalette** — `ios/sprinty/Core/Theme/ColorPalette.swift`. Has `avatarGlow`, `avatarGradientStart`, `avatarGradientEnd` colors already defined.
- **CoachingTheme** — `ios/sprinty/Core/Theme/CoachingTheme.swift`. Theme with `.applying(safetyOverride:)` and `.applyingPauseMode()` stubs.
- **project.yml** — `ios/project.yml`. XcodeGen project definition. All new files auto-included from `sprinty/` source directory, but test files need explicit addition if in a separate target.

### Architecture Compliance

**AvatarState enum placement:** `Core/State/AvatarState.swift` — this is a shared model used by Home, Widgets, and potentially other features. It does NOT go in `Features/Home/Models/` because multiple features will read it.

**MVVM Pattern (three required markers):**
```swift
@MainActor @Observable final class HomeViewModel { ... }
```

**Swift Concurrency Rules:**
- `@MainActor` on ViewModels (they update UI state)
- `Task { [weak self] in }` for async operations in ViewModel methods
- Check `Task.isCancelled` before state mutations after any `await`
- NEVER use Combine (`ObservableObject`, `@Published`, `PassthroughSubject`)

**Error Handling:**
- Database errors: local error on ViewModel (`self.localError`)
- Use `AppError` enum exclusively
- No global AppState error for local operations

**Animation Pattern (established in codebase):**
```swift
// Standard pattern used throughout the app:
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// For value-based transitions:
.animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: state)

// For explicit animations:
withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { ... }
```

**Animation Timing Constants (from UX spec):**
- `0.4s` (standard) — Avatar state changes, coach expressions
- `0.8s` (slow - 400ms) — Avatar celebration (brief joy, spring curve)
- `0.25s` (quick) — Functional interactions
- All animations: `accessibilityReduceMotion` → instant (0ms)

**Testing Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect()`) — NEVER XCTest. Database tests use `makeTestDB()` for in-memory GRDB.

### Implementation Strategy — Placeholder Art via Saturation

Story 4.6 (Art Asset Commissioning) will provide final avatar illustrations with per-state Lottie animations. For this story, the existing `Image(avatarId)` continues to render the user's chosen avatar appearance. Visual state differentiation is achieved purely through the `.saturation()` SwiftUI modifier — no SF Symbols, no new images, no Lottie yet. The key deliverable is the state management system, not the art.

**Important distinction:** `avatarId` (String) = which avatar the user picked during onboarding (appearance/style). `AvatarState` (enum) = what behavioral mood the avatar is in (active, resting, etc.). They are independent — the same avatar image is shown in all states, just with different saturation levels.

When Story 4.6 delivers final art, `AvatarView` will switch from saturation-only to Lottie playback with `@Environment(\.accessibilityReduceMotion)` gating animation vs. static fallback. The `AvatarState` enum and derivation logic remain unchanged.

### Saturation-Based Visual Differentiation

Until final art arrives, visual state differentiation uses SwiftUI's `.saturation()` modifier on the avatar image:

| State | Saturation | Visual Effect |
|-------|-----------|---------------|
| Active | 1.0 | Full color — engaged |
| Resting | 0.65 | Gentle desaturation — relaxed |
| Celebrating | 1.15 | Brightest — above normal warmth |
| Thinking | 0.85 | Neutral — slightly muted |
| Struggling | 0.55 | Muted but warm — never cold/sad |

### AvatarState Derivation — Minimal for This Story

Derivation lives as `static func derive(isPaused:)` on `AvatarState` itself (not a separate file — too simple to warrant one). Future stories expand the signature:

| Signal | AvatarState | Story |
|--------|-------------|-------|
| `isPaused == true` | `.resting` | **This story (4.1)** |
| Default (no signals) | `.active` | **This story (4.1)** |
| Active sprint + recent activity | `.active` | Story 5.x |
| Step completion | `.celebrating` (transient) | Story 5.3 |
| Safety yellow+ | Varies | Story 6.2 |
| Missed goals acknowledged | `.struggling` | Story 5.4 |
| Mid-sprint processing | `.thinking` | Story 5.2 |

### Celebrating State — Transient with Haptic

Celebration plays for 0.8s then auto-returns to previous state. Haptic: `UIImpactFeedbackGenerator(style: .medium)` — one of ≤3 haptic types per calm budget (UX-DR66). See Task 5 for implementation pattern. Key points:
- Use `Task { [weak self] in }` with `Task.isCancelled` check
- Restore the state that was active *before* celebration (not always `.active` — could be `.thinking`)
- If previous state was `.celebrating` (rapid re-triggers), fall back to `.active`

### VoiceOver Accessibility

**AC #4 requirements:**
- `accessibilityValue` must update to current state name (e.g., "Active", "Resting")
- State change must be announced — use `.accessibilityValue(state.displayName)` on AvatarView; SwiftUI automatically announces value changes to VoiceOver users
- Keep existing `.accessibilityLabel("Your avatar")` and `.accessibilityAddTraits(.isImage)`

### File Structure

New files:
```
ios/sprinty/Core/State/
└── AvatarState.swift                      # NEW — enum with 5 states, derivation, computed properties

ios/Tests/Models/
└── AvatarStateTests.swift                 # NEW — enum property + derivation tests

ios/Tests/Features/Home/
└── HomeViewModelAvatarTests.swift         # NEW — celebration tests (companion to existing HomeViewModelTests.swift)
```

Modified files:
```
ios/sprinty/App/AppState.swift                         # Add avatarState + isPaused stub
ios/sprinty/Features/Home/Views/AvatarView.swift       # Add state parameter (default .active), crossfade, saturation, a11y
ios/sprinty/Features/Home/Views/HomeView.swift          # Pass appState.avatarState to AvatarView
ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift # Add celebration trigger
```

### Project Structure Notes

- `Core/State/` directory already exists (currently empty) — place `AvatarState.swift` here
- AvatarState is a shared enum (not feature-local) because Widgets (Story 10.4) and Home both need it
- No new dependencies required — uses only SwiftUI, UIKit (for haptics), and Foundation
- Existing test file `ios/Tests/Features/Home/HomeViewModelTests.swift` has `makeTestDB()` and `createProfile()` helpers — reuse in the new avatar test file

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.1]
- [Source: _bmad-output/planning-artifacts/architecture.md — ExperienceContext, AvatarView, Home feature structure]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Avatar State Visuals table, Animation Timing, Emotional Design Principles]
- [Source: _bmad-output/planning-artifacts/prd.md — FR30-FR33 Avatar System, NFR7 60fps, NFR37 Reduce Motion]
- [Source: ios/sprinty/Features/Home/Views/AvatarView.swift — Current implementation]
- [Source: ios/sprinty/App/AppState.swift — Current minimal state]
- [Source: ios/sprinty/Core/Theme/CoachingTheme.swift — ExperienceContext enum, theme system]

### Previous Story Intelligence

**From Story 3.7 (Memory View & Profile Editing):**
- Test baseline: 335 tests — maintain or increase
- All ViewModels use `@MainActor @Observable final class` — three required markers
- `Task { [weak self] in }` required for all async operations to prevent retain cycles
- Check `Task.isCancelled` before state mutations after `await`
- Code review caught: unreachable code paths, swipeActions context issues, deletion order safety — be precise with state mutation ordering
- `#if DEBUG` static preview factory pattern required on all ViewModels
- App source files auto-scan from `sprinty/` directory — no `project.yml` change needed for app target
- Test files DO need explicit addition to `project.yml` test target sources
- Run `xcodegen generate` after modifying `project.yml`
- HomeViewModel tests already exist at `ios/Tests/Features/Home/HomeViewModelTests.swift` — follow same patterns

**Git commit pattern:** `feat: Story 4.1 — Full avatar state system`

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None — clean implementation, no debug issues encountered.

### Completion Notes List
- Created `AvatarState` enum with 5 cases, `displayName`, `saturationMultiplier`, and `derive(isPaused:)` static method
- Added `avatarState` and `isPaused` stub to `AppState`
- Upgraded `AvatarView` with saturation-based state rendering, crossfade animation, reduce-motion support, and VoiceOver accessibility
- Updated `HomeViewModel` with computed `avatarState` property and `triggerCelebration()` method (haptic + 0.8s auto-return)
- Updated `HomeView` to pass avatar state through to `AvatarView`
- Updated preview factory to accept `avatarState` parameter
- Added 10 `#Preview` variants (5 states x light/dark) to `AvatarView`
- 21 new tests: 15 AvatarState enum tests + 6 HomeViewModel avatar tests
- Test count: 335 → 356 (all pass, zero regressions)
- Regenerated `.xcodeproj` via xcodegen

### Change Log
- 2026-03-23: Story 4.1 implementation complete — all 7 tasks, 21 new tests, 356 total passing
- 2026-03-23: Code review — 1 MEDIUM (Task 6.2 description corrected), 1 LOW fixed (AvatarView previews wrapped in #if DEBUG for consistency), 1 LOW accepted (haptic side effect not abstracted — by design per story)

### File List
New files:
- `ios/sprinty/Core/State/AvatarState.swift`
- `ios/Tests/Models/AvatarStateTests.swift`
- `ios/Tests/Features/Home/HomeViewModelAvatarTests.swift`

Modified files:
- `ios/sprinty/App/AppState.swift`
- `ios/sprinty/Features/Home/Views/AvatarView.swift`
- `ios/sprinty/Features/Home/Views/HomeView.swift`
- `ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift`

Regenerated:
- `ios/sprinty.xcodeproj/` (via `xcodegen generate`)
