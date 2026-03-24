# Story 4.5: Avatar Customization

Status: done

## Story

As a user,
I want to change my avatar's appearance anytime from settings,
so that my avatar continues to feel like me as my preferences evolve.

## Acceptance Criteria

1. **Avatar Selection from Settings:** Given the user navigates to Settings -> Appearance, when they select avatar customization, then an AvatarSelectionView displays with 2-3 options (same as onboarding) and the current selection is highlighted with a glow ring.

2. **Avatar Update with Immediate Cross-App Sync:** Given the user selects a new avatar, when they confirm, then the avatar updates immediately across the app (home screen, future widgets) with no confirmation dialog (instant, no-friction per UX-DR85).

3. **Coach Appearance Customization with Soft Confirmation:** Given the user also wants to change the coach appearance, when they select coach customization, then a soft confirmation displays: "Same coach, new look" (reassurance, not permission per UX-DR85).

4. **Accessibility Compliance:** All customization options meet VoiceOver (ordinal announcements "Avatar option 1 of 3"), Dynamic Type (scales xSmall-XXXL), touch targets (>=44x44pt), and Reduce Motion requirements.

5. **Offline Operation:** Avatar and coach customization is 100% offline with no network requests required.

## Tasks / Subtasks

- [x] Task 1: Wire databaseManager into SettingsView (AC: #1-#5)
  - [x] 1.1 Update RootView.swift: pass `databaseManager` to SettingsView alongside `memoryViewModel` in the `.sheet` presentation
  - [x] 1.2 Update SettingsView init to accept `databaseManager: DatabaseManager` parameter
  - [x] 1.3 Pass `databaseManager` to SettingsViewModel on construction
  - [x] 1.4 Update SettingsViewModel init to accept and store `databaseManager: DatabaseManager`

- [x] Task 2: Add "Appearance" section to SettingsView (AC: #1, #3)
  - [x] 2.1 Add "Appearance" section header to SettingsView Form, positioned ABOVE the existing "Your Coach" section
  - [x] 2.2 Add NavigationLink for "Your Avatar" — show `Image(systemName: viewModel.avatarId)` as a 32pt circular preview with `.foregroundStyle(theme.palette.textPrimary)`
  - [x] 2.3 Add NavigationLink for "Your Coach" — show `Image(systemName: viewModel.coachAppearanceId)` as a 32pt circular preview + `viewModel.coachName` label using `theme.typography.insightTextStyle()`
  - [x] 2.4 Style section with home palette tokens per UX-DR34 (coaching typography, warm tone consistent with SettingsView)

- [x] Task 3: Extract shared avatar/coach options to constants (AC: #1, #3)
  - [x] 3.1 Create `Core/Utilities/AvatarOptions.swift` with a shared `static let avatarOptions: [(id: String, name: String)]` array — same 3 options currently hardcoded in AvatarSelectionView
  - [x] 3.2 Add `static let coachOptions: [(id: String, name: String, hint: String)]` — same 3 options currently hardcoded in CoachNamingView
  - [x] 3.3 Update AvatarSelectionView to use `AvatarOptions.avatarOptions` instead of its inline `private let`
  - [x] 3.4 Update CoachNamingView to use `AvatarOptions.coachOptions` instead of its inline `private let`

- [x] Task 4: Create SettingsAvatarSelectionView (AC: #1, #2, #4)
  - [x] 4.1 Create `Features/Settings/Views/SettingsAvatarSelectionView.swift`
  - [x] 4.2 Use `AvatarOptions.avatarOptions` for the 3 options (shared constant, no duplication)
  - [x] 4.3 Display "This is you" header using `theme.typography.homeTitleStyle()`
  - [x] 4.4 Render circular avatar options (>=44x44pt touch targets) with glow ring on current selection (`theme.palette.avatarGlow`, 30% light / 20% dark opacity, 3pt stroke, 8pt shadow radius — matching AvatarSelectionView pattern)
  - [x] 4.5 On tap: instantly save new `avatarId` to UserProfile in database (no confirmation dialog per UX-DR85)
  - [x] 4.6 Glow ring animation: respect `@Environment(\.accessibilityReduceMotion)` — instant glow change if enabled, 0.25s easeInOut if not
  - [x] 4.7 VoiceOver: `accessibilityLabel("Avatar option \(index + 1) of \(total)")`, `.accessibilityAddTraits(.isButton)`, `.accessibilityValue("Selected")` on current
  - [x] 4.8 Dynamic Type XXXL: wrap options in flexible layout (HStack with wrapping or VStack fallback) so circles don't clip at extreme sizes

- [x] Task 5: Create SettingsCoachAppearanceView (AC: #3, #4)
  - [x] 5.1 Create `Features/Settings/Views/SettingsCoachAppearanceView.swift`
  - [x] 5.2 Use `AvatarOptions.coachOptions` for the 3 options (shared constant, no duplication)
  - [x] 5.3 Display "Your Coach's Look" header using `theme.typography.homeTitleStyle()`
  - [x] 5.4 Render coach options as circular portraits (>=44x44pt) with glow ring on current, plus name + hint text below each using `theme.typography.insightTextStyle()` for name and `theme.typography.sprintLabelStyle()` for hint
  - [x] 5.5 On selection: immediately save new `coachAppearanceId` to UserProfile AND show "Same coach, new look" text below the selection grid — styled with `theme.palette.textSecondary`, `theme.typography.insightTextStyle()`, fades in with 0.3s easeInOut (respects reduceMotion). Text persists until view is dismissed or a new selection is made.
  - [x] 5.6 Coach name auto-update: replicate existing CoachNamingView behavior — if current `coachName` matches any default name ("Sage"/"Mentor"/"Guide") or is empty, update name to the new option's default name. If user has a custom name, preserve it.
  - [x] 5.7 VoiceOver: ordinal labels "Coach option \(index + 1) of \(total)", `.accessibilityValue("Selected")` on current. "Same coach, new look" announced via `.accessibilityLabel` on the confirmation text element

- [x] Task 6: Update SettingsViewModel (AC: #1, #2, #3, #5)
  - [x] 6.1 Add stored `databaseManager: DatabaseManager` property (received via init)
  - [x] 6.2 Add `avatarId: String` and `coachAppearanceId: String` properties loaded from UserProfile
  - [x] 6.3 Add `coachName: String` property for display
  - [x] 6.4 Add `loadProfile()` method — async, reads UserProfile from database via `dbPool.read`
  - [x] 6.5 Add `updateAvatar(_ newAvatarId: String)` method — writes to DB via `dbPool.write`, updates local `avatarId`
  - [x] 6.6 Add `updateCoachAppearance(_ newAppearanceId: String, newCoachName: String?)` method — writes `coachAppearanceId` (and optionally `coachName`) to DB, updates local state

- [x] Task 7: Ensure cross-app sync (AC: #2)
  - [x] 7.1 After avatar update in SettingsViewModel, HomeViewModel picks up change on next `loadUserProfile()` call
  - [x] 7.2 Verify AvatarView on home screen reflects the updated `avatarId` when Settings sheet dismisses — HomeView uses `.task` modifier which fires on re-appearance, calling `viewModel.load()` -> `loadUserProfile()`
  - [x] 7.3 Widget sync: call `WidgetCenter.shared.reloadAllTimelines()` after saving avatar or coach changes (import WidgetKit). This is a no-op if no widgets are installed. Deferred full widget implementation to Story 10.4, but timeline invalidation ensures future widgets get fresh data.

- [x] Task 8: Write tests (AC: #1-#5)
  - [x] 8.1 SettingsViewModel tests: avatar update persists to DB, coach appearance update persists, loadProfile reads current values
  - [x] 8.2 Integration test: update avatar in settings, verify HomeViewModel reads new avatarId from same DB
  - [x] 8.3 Test coach name auto-update: when current name is a default ("Sage"/"Mentor"/"Guide"), changing appearance updates name; when name is custom, appearance change preserves it
  - [x] 8.4 Test default values when no profile exists
  - [x] 8.5 Test avatar state independence: changing `avatarId` does NOT change `AvatarState` (active/resting/etc.) — verify `appState.avatarState` is unaffected by avatar appearance changes
  - [x] 8.6 Test offline operation: avatar and coach updates succeed with no network dependency (all DB operations, no API calls)

- [x] Task 9: Update project and finalize (AC: all)
  - [x] 9.1 Run `xcodegen generate` to update .xcodeproj with new files
  - [x] 9.2 Verify all existing tests pass (baseline: 407 tests)
  - [x] 9.3 Verify new tests pass
  - [x] 9.4 Add `#Preview` blocks with mock data to new views under `#if DEBUG`

## Dev Notes

### Architecture Compliance

- **MVVM Pattern:** ViewModels must be `@MainActor @Observable final class`
- **No Combine:** Use `@Observable` (iOS 17+), never `ObservableObject` or `@Published`
- **DI:** Protocol-based constructor injection, no singletons
- **Services:** Mark as `Sendable`, not `@MainActor`
- **Theme access:** Via `@Environment(\.coachingTheme) var theme` in views, never hardcode colors/spacing
- **Database:** GRDB async access via `dbPool.read { db in }` / `dbPool.write { db in }`
- **Concurrency:** `Task { [weak self] in }` with `Task.isCancelled` check before state mutations

### Critical: Reuse, Don't Reinvent

**Extract shared constants (Task 3):**
- Create `Core/Utilities/AvatarOptions.swift` with shared `avatarOptions` and `coachOptions` arrays
- Update both `AvatarSelectionView.swift` and `CoachNamingView.swift` to reference `AvatarOptions.*` instead of inline `private let` arrays
- This prevents data duplication across onboarding and settings views

**Existing components to reuse:**
- `AvatarSelectionView.swift` (`Features/Onboarding/Views/`) — glow ring pattern: `.overlay(Circle().stroke(...).shadow(...))`, 3pt stroke, 8pt shadow, `theme.palette.avatarGlow` color
- `CoachNamingView.swift` (`Features/Onboarding/Views/`) — coach name auto-update logic: if name matches default, update to new default; if custom, preserve
- `AvatarView.swift` (`Features/Home/Views/`) — renders avatar with state-based saturation. Use for preview thumbnails in settings.
- `UserProfile` model (`Models/UserProfile.swift`) — already has `avatarId: String` and `coachAppearanceId: String` fields. No schema changes needed.

**Existing patterns to follow:**
- `SettingsView.swift` (`Features/Settings/Views/`) — Form-based layout with NavigationStack. Add new "Appearance" section here.
- `SettingsViewModel.swift` (`Features/Settings/ViewModels/`) — extend this ViewModel, don't create a new one. Currently only has `showMemoryView` bool.
- `MemoryView.swift` / `MemoryViewModel.swift` — example of Settings sub-view pattern with NavigationLink.

### Critical: DatabaseManager Access in SettingsView

SettingsView is presented as a `.sheet` from RootView and currently only receives `memoryViewModel`. It does NOT receive `databaseManager`.

**Required changes to RootView.swift:**
```swift
// Current (line ~87-91):
.sheet(isPresented: $showSettings) {
    if let memoryViewModel {
        SettingsView(memoryViewModel: memoryViewModel)
    }
}

// Updated:
.sheet(isPresented: $showSettings) {
    if let memoryViewModel, let databaseManager = appState.databaseManager {
        SettingsView(memoryViewModel: memoryViewModel, databaseManager: databaseManager)
    }
}
```

SettingsView and SettingsViewModel must both be updated to accept and store `databaseManager`.

### File Structure Requirements

**New files to create:**
```
ios/sprinty/Core/Utilities/AvatarOptions.swift                    — Shared avatar + coach option arrays
ios/sprinty/Features/Settings/Views/SettingsAvatarSelectionView.swift
ios/sprinty/Features/Settings/Views/SettingsCoachAppearanceView.swift
```

**Files to modify:**
```
ios/sprinty/App/RootView.swift                                    — Pass databaseManager to SettingsView
ios/sprinty/Features/Settings/Views/SettingsView.swift            — Accept databaseManager, add "Appearance" section
ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift  — Accept databaseManager, add avatar/coach properties + methods
ios/sprinty/Features/Onboarding/Views/AvatarSelectionView.swift   — Use AvatarOptions.avatarOptions
ios/sprinty/Features/Onboarding/Views/CoachNamingView.swift       — Use AvatarOptions.coachOptions
```

**Test files to create:**
```
ios/Tests/Features/Settings/SettingsViewModelCustomizationTests.swift
```

### Database Access Pattern

UserProfile read/write pattern (from existing codebase):
```swift
// Read
let profile = try await databaseManager.dbPool.read { db in
    try UserProfile.fetchOne(db)
}

// Write
try await databaseManager.dbPool.write { db in
    if var profile = try UserProfile.fetchOne(db) {
        profile.avatarId = newAvatarId
        profile.updatedAt = Date()
        try profile.update(db)
    }
}
```

No new migrations needed — `avatarId` and `coachAppearanceId` columns already exist in UserProfile (migration v2).

### Avatar Options Data (from existing code)

Current avatar options in `AvatarSelectionView.swift`:
- `"person.circle.fill"` — "Classic"
- `"person.circle"` — "Minimal"
- `"figure.mind.and.body"` — "Zen"

Current coach options in `CoachNamingView.swift`:
- `"person.circle.fill"` — "Sage" — "Warm and encouraging"
- `"brain.head.profile"` — "Mentor" — "Focused and direct"
- `"leaf.circle.fill"` — "Guide" — "Calm and grounding"

### Confirmation Pattern (UX-DR85)

- **Avatar change:** NO confirmation dialog. Tap to select, instant save, instant glow ring update.
- **Coach appearance change:** On tap, save immediately AND show "Same coach, new look" text BELOW the selection grid. Specifics:
  - Position: centered below the coach options grid, above any other content
  - Typography: `theme.typography.insightTextStyle()` (15pt Subheadline, Regular)
  - Color: `theme.palette.textSecondary`
  - Animation: fade in with 0.3s easeInOut (instant if reduceMotion enabled)
  - Lifetime: persists until view dismissal or next selection change
  - NOT a modal, NOT an alert, NOT a confirmation gate — save happens on tap regardless
  - VoiceOver: text element with `accessibilityLabel("Same coach, new look")`

### Coach Name Auto-Update Logic

Replicate existing behavior from CoachNamingView:
```swift
// If user has a default name, update it to match the new appearance's default
let defaultNames = ["Sage", "Mentor", "Guide"]
if defaultNames.contains(currentCoachName) || currentCoachName.isEmpty {
    coachName = newOption.name  // e.g., switching to "Mentor" appearance sets name to "Mentor"
}
// If user set a custom name (e.g., "Alex"), preserve it on appearance change
```
This matches user expectations from onboarding and avoids confusion.

### Animation & Accessibility

- Selection glow ring: use `theme.palette.avatarGlow` with 30% opacity (light) / 20% opacity (dark)
- Respect `@Environment(\.accessibilityReduceMotion)` — skip any selection animations if enabled
- Touch targets: all selectable circles >= 44x44pt (`theme.spacing.minTouchTarget`)
- Dynamic Type: use semantic SwiftUI text styles that auto-scale
- VoiceOver selection announcement: use `.accessibilityValue("Selected")` on current avatar
- At Accessibility XXXL: layout should accommodate larger text without clipping

### Cross-App Sync Mechanism

Avatar changes propagate naturally through existing architecture:
1. User selects new avatar in Settings sheet -> writes to UserProfile in GRDB
2. User dismisses Settings sheet -> HomeView reappears
3. HomeView `.task` modifier fires on re-appearance, calling `viewModel.load()`
4. `load()` calls `loadUserProfile()` which reads updated `avatarId` from DB
5. AvatarView renders new avatar via `Image(systemName: avatarId)`
6. `WidgetCenter.shared.reloadAllTimelines()` called after save to invalidate any future widget timelines

No notification system, no @Published, no Combine. Database persistence + view lifecycle + WidgetKit invalidation.

### Testing Standards

- **Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`)
- **Never XCTest** for new tests
- **Database tests:** Use `makeTestDB()` pattern — in-memory GRDB with all migrations
- **ViewModel tests:** `@MainActor` annotation required
- **Naming:** `@Test("descriptive test name")` — no `test_` prefix needed
- **Mocks:** Hand-written protocol mocks in `Tests/Mocks/`
- **Expected test count after:** 407 + ~10-15 new tests

### Previous Story Intelligence

**From Story 4.4 (Sprint Progress):**
- Typography always uses 3-property pattern: font + weight + lineSpacing
- `sprintLabelStyle()` modifier example for consistent typography
- VoiceOver values must include contextual info (e.g., "Step 2 of 5")
- Run `xcodegen generate` after adding any new files
- Database table existence guards with `db.tableExists()` for future-proofing

**From Story 4.1 (Avatar State System):**
- Avatar state (active/resting/etc.) is INDEPENDENT from avatarId (appearance)
- Saturation-based rendering is current placeholder; Lottie comes in Story 4.6
- `#if DEBUG` wrap on preview factories

**From Story 4.2 (Progressive Disclosure):**
- CoachActionButton uses `.saturation(1/0.7)` to counteract parent pause muting
- No placeholder/guilt messaging (UX-DR72)
- VoiceOver sort priorities: greeting(5) -> avatar(4) -> insight(3) -> sprint(2) -> button(1)

**From Story 4.3 (Daily Coaching Insight):**
- Service DI: Direct constructor injection in RootView
- InsightService marked `Sendable`, not `@MainActor`
- NSLock for thread-safe cache in services

### What NOT To Do

- Do NOT create new database migrations — UserProfile already has avatarId and coachAppearanceId
- Do NOT add Combine/ObservableObject — use @Observable only
- Do NOT show alert/modal for avatar or coach changes — avatar is instant, coach is inline text
- Do NOT create separate ViewModels for each sub-view — extend SettingsViewModel
- Do NOT duplicate avatar/coach option arrays — extract to `AvatarOptions` shared constants (Task 3)
- Do NOT touch AvatarState.swift — avatar state (mood) is independent from avatarId (appearance)
- Do NOT modify HomeViewModel — it already reads avatarId from UserProfile on loadData()
- Do NOT add any network calls — this feature is 100% offline
- Do NOT silently drop the coach name when changing coach appearance — follow auto-update logic from CoachNamingView

### Project Structure Notes

- Alignment: New files follow existing `Features/Settings/Views/` and `Features/Settings/ViewModels/` structure
- One new file in `Core/Utilities/` for shared avatar options constants
- SettingsView already has a NavigationStack; add NavigationLinks for the new views
- xcodegen (`project.yml`) handles file discovery — just run `xcodegen generate` after adding files
- Modifying RootView.swift DI wiring — take care to preserve existing MemoryView/MemoryViewModel flow

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.5, FR33, FR76]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR34, UX-DR36, UX-DR37, UX-DR85]
- [Source: _bmad-output/planning-artifacts/architecture.md — MVVM, GRDB, SwiftUI, WidgetKit patterns]
- [Source: ios/sprinty/Features/Onboarding/Views/AvatarSelectionView.swift — Avatar options, glow ring pattern]
- [Source: ios/sprinty/Features/Onboarding/Views/CoachNamingView.swift — Coach options, name auto-update logic]
- [Source: ios/sprinty/Features/Settings/Views/SettingsView.swift — Settings Form structure]
- [Source: ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift — Currently only has showMemoryView]
- [Source: ios/sprinty/App/RootView.swift — SettingsView .sheet presentation, DI wiring (lines ~87-91)]
- [Source: ios/sprinty/Models/UserProfile.swift — avatarId, coachAppearanceId, coachName fields]
- [Source: ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift — loadUserProfile() reads avatarId]
- [Source: ios/sprinty/Features/Home/Views/HomeView.swift — .task modifier triggers load() on appearance]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Wired `databaseManager` through RootView → SettingsView → SettingsViewModel DI chain
- Created `AvatarOptions.swift` shared constants; updated both `AvatarSelectionView` and `CoachNamingView` to use shared arrays (eliminated duplication)
- Created `SettingsAvatarSelectionView` with instant-save avatar selection, glow ring animation (reduceMotion-aware), VoiceOver ordinal labels, and Dynamic Type XXXL VStack fallback
- Created `SettingsCoachAppearanceView` with instant-save coach selection, "Same coach, new look" inline confirmation text (fade-in, reduceMotion-aware), coach name auto-update logic
- Extended `SettingsViewModel` with `loadProfile()`, `updateAvatar()`, `updateCoachAppearance()` — all async GRDB operations
- Cross-app sync via DB persistence + HomeView `.task` lifecycle + `WidgetCenter.shared.reloadAllTimelines()`
- 10 new tests covering: DB persistence, cross-DB reads, coach name auto-update (default/custom/empty), default values, avatar state independence, offline operation
- All 419 tests pass (407 baseline + 10 new + 2 existing increments), zero regressions

### Code Review Fixes (2026-03-24)

- **H1 Fixed:** Removed redundant nested `Task` in `loadProfile()` — method is already `async`, inner Task broke cancellation chain and made `await` return immediately
- **M1 Fixed:** Added Dynamic Type XXXL `VStack` fallback to `SettingsCoachAppearanceView` (matching `SettingsAvatarSelectionView` pattern) for AC4 compliance
- **M2 Fixed:** Updated `CoachNamingView` to use `AvatarOptions.defaultCoachNames.contains()` instead of hardcoded string comparison
- **L1 Fixed:** Moved `WidgetCenter.shared.reloadAllTimelines()` from View button actions to ViewModel `updateAvatar`/`updateCoachAppearance` — now fires only after successful DB write
- **L2 Fixed:** Changed `SettingsView.viewModel` from plain `var` to `@State private var` to preserve ViewModel identity across SwiftUI re-evaluations

### Code Review Fixes #2 (2026-03-24)

- **L1 Fixed:** Added `guard` against re-selecting the same avatar in `SettingsAvatarSelectionView` — prevents unnecessary DB write + WidgetCenter reload
- **L2 Fixed:** Added `guard` against re-selecting the same coach in `SettingsCoachAppearanceView` — prevents unnecessary DB write + WidgetCenter reload + spurious "Same coach, new look" text

### Change Log

- 2026-03-24: Story 4.5 implementation complete — avatar and coach customization from Settings

### File List

**New files:**
- `ios/sprinty/Core/Utilities/AvatarOptions.swift`
- `ios/sprinty/Features/Settings/Views/SettingsAvatarSelectionView.swift`
- `ios/sprinty/Features/Settings/Views/SettingsCoachAppearanceView.swift`
- `ios/Tests/Features/Settings/SettingsViewModelCustomizationTests.swift`

**Modified files:**
- `ios/sprinty/App/RootView.swift`
- `ios/sprinty/Features/Settings/Views/SettingsView.swift`
- `ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift`
- `ios/sprinty/Features/Onboarding/Views/AvatarSelectionView.swift`
- `ios/sprinty/Features/Onboarding/Views/CoachNamingView.swift`
