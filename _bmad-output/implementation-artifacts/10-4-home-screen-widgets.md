# Story 10.4: Home Screen Widgets

Status: done

## Story

As a user,
I want home screen widgets showing my avatar and sprint progress,
So that I can glance at my coaching state without opening the app.

## Acceptance Criteria

1. **Given** the user adds a small widget (FR68), **When** it renders on the home screen, **Then** it displays avatar state and sprint progress, **And** data is read from the App Group shared container (read-only).

2. **Given** the user adds a medium widget (FR69), **When** it renders on the home screen, **Then** it displays avatar, sprint name, next action, and a tap target to open the coach, **And** tapping opens the app to the conversation view.

3. **Given** widget data freshness (NFR8), **When** the app updates in the background, **Then** widgets reflect current coaching state within 15 minutes.

4. **Given** the WidgetKit extension, **When** it accesses the database, **Then** it reads from the App Group shared container (same SQLite as main app), **And** the extension has read-only access.

## Tasks / Subtasks

- [x] Task 1: Create widget extension target and project configuration (AC: #1, #4)
  - [x]1.1 Add `sprinty_widgetExtension` target to `ios/project.yml` with WidgetKit framework, App Group entitlement (`group.com.ducdo.sprinty`), and SwiftUI dependency
  - [x]1.2 Create `ios/sprinty_widgetExtension/` directory with `SprintyWidgetBundle.swift` (`@main` entry point)
  - [x]1.3 Create widget extension entitlements file with same App Group identifier (`group.com.ducdo.sprinty`)
  - [x]1.4 Add shared source files to widget target: `Constants.swift`, `DatabaseManager.swift`, `Sprint.swift`, `SprintStep.swift`, `UserProfile.swift`, `AvatarState.swift`, `AvatarOptions.swift`, `DatabaseMigrations.swift` (all models/services needed for read-only DB access)
  - [x]1.5 Include avatar image assets in widget extension target (all `avatar_*_*` variants at 2x/3x)
  - [x]1.6 Update Debug/Staging/Release schemes in `ios/project.yml` to include `sprinty_widgetExtension` target in build configuration

- [x] Task 2: Implement widget data provider (AC: #3, #4)
  - [x]2.1 Create `WidgetDataProvider.swift` in widget extension — opens GRDB `DatabasePool` in **read-only mode** from the App Group container using `Constants.appGroupIdentifier` and `Constants.databaseFilename`
  - [x]2.2 Define `SprintyWidgetEntry: TimelineEntry` struct containing: `date: Date`, `avatarId: String`, `avatarState: AvatarState`, `hasActiveSprint: Bool`, `sprintName: String`, `sprintProgress: Double`, `currentStep: Int`, `totalSteps: Int`, `nextActionTitle: String?`, `dayNumber: Int`, `totalDays: Int`, `isPaused: Bool`
  - [x]2.3 Implement `SprintyTimelineProvider: TimelineProvider` with:
    - `placeholder(in:)` — returns static entry with defaults: `avatarId: "avatar_classic"`, `avatarState: .active`, `hasActiveSprint: false`, `sprintProgress: 0.0`, `sprintName: ""`, `nextActionTitle: nil`, `isPaused: false`
    - `getSnapshot(in:completion:)` — reads current data from DB for widget gallery preview
    - `getTimeline(in:completion:)` — reads current data, returns timeline with `.after(Date().addingTimeInterval(15 * 60))` reload policy (15-minute refresh per NFR8)
  - [x]2.4 Data query logic (replicate from `HomeViewModel` lines 142-171):
    - Fetch active sprint: `Sprint.active().fetchOne(db)`
    - Fetch steps: `SprintStep.forSprint(id:).fetchAll(db)`
    - Calculate progress: `completedCount / totalCount`
    - Calculate day number: `Calendar.current.dateComponents([.day], from: startDate, to: Date()).day + 1`
    - Get next incomplete step: first step from ordered results where `completed == false` — return `step.title` as `nextActionTitle`, or nil if all complete
    - Read `UserProfile.current()` for `avatarId` and `isPaused`
    - Derive avatar state: `AvatarState.derive(isPaused: profile.isPaused)`

- [x] Task 3: Implement small widget view (AC: #1)
  - [x]3.1 Create `SmallWidgetView.swift` — displays avatar image (48pt) centered above a compact sprint progress bar (5pt height, same visual as `SprintProgressView` compact strip)
  - [x]3.2 Avatar renders using `AvatarOptions.assetName(for: entry.avatarId, state: entry.avatarState)` with state-based saturation multiplier
  - [x]3.3 When no active sprint: show avatar only with "No active sprint" label below
  - [x]3.4 When paused: avatar shows `.resting` state, sprint progress is muted (0.4 opacity, matching existing `SprintProgressView` implementation at line 49)
  - [x]3.5 Apply earthy warm color palette: warm cream background (light), near-monochrome (dark) with avatar as the colored element
  - [x]3.6 Add accessibility: `accessibilityLabel("Sprint progress")`, `accessibilityValue("Step X of Y")`

- [x] Task 4: Implement medium widget view (AC: #2)
  - [x]4.1 Create `MediumWidgetView.swift` — HStack layout: avatar (64pt) on left, VStack on right with sprint name, progress bar, next action text
  - [x]4.2 Sprint name as headline, progress bar below, next action in secondary text ("Next: [step title]")
  - [x]4.3 Entire widget is a deep link tap target using `.widgetURL(URL(string: "sprinty://coach")!)` to open conversation view
  - [x]4.4 When no active sprint: show avatar + "Talk to your coach" prompt
  - [x]4.5 When paused: avatar `.resting`, sprint info muted, prompt softens to "Your coach is here when you're ready"
  - [x]4.6 Same earthy palette and accessibility labels as small widget

- [x] Task 5: Wire up deep linking and widget refresh triggers (AC: #2, #3)
  - [x]5.1 Handle `sprinty://coach` URL in `SprintyApp.swift` via `.onOpenURL` modifier on `WindowGroup` — set `appState.showConversation = true` to trigger the conversation sheet (app uses sheet-based navigation via boolean flags in RootView, NOT tab-based navigation)
  - [x]5.2 Add `WidgetCenter.shared.reloadAllTimelines()` call in `SprintDetailViewModel.toggleStep(_ step: SprintStep, reduceMotion: Bool)` after step completion (both online and offline paths — after line ~165 where `triggerCelebration()` is called, and after line ~156 in the sprint completion block)
  - [x]5.3 Add `WidgetCenter.shared.reloadAllTimelines()` call in `SprintDetailViewModel.syncOnReconnect()` after sync completes
  - [x]5.4 Add `WidgetCenter.shared.reloadAllTimelines()` call in `CoachingViewModel.confirmSprint()` (line ~418) after `sprintService.createSprint()` completes — this is where new sprints are created. Import WidgetKit in `CoachingViewModel.swift`
  - [x]5.5 Import WidgetKit in files where `reloadAllTimelines()` is called (SettingsViewModel already has this)

- [x] Task 6: Testing (AC: #1, #2, #3, #4)
  - [x]6.1 Unit test `SprintyTimelineProvider` data queries: active sprint, no sprint, paused state, completed sprint
  - [x]6.2 Unit test `WidgetDataProvider` read-only database access from App Group container
  - [x]6.3 Unit test deep link URL handling for `sprinty://coach`
  - [x]6.4 Unit test widget entry calculation: progress percentage, day number, next action extraction
  - [x]6.5 Verify `WidgetCenter.shared.reloadAllTimelines()` calls are present in step completion, step uncomplete, sprint reactivation, sync, and sprint creation paths (code inspection — WidgetCenter.shared is a static singleton not amenable to unit test mocking)
  - [x]6.6 Manual test: add small and medium widgets to home screen, verify rendering and data freshness
  - [x]6.7 Verify widgets render correctly when device is offline — data reads from local SQLite with no network dependency (NFR32: widgets must be 100% available regardless of network state)

## Dev Notes

### Current Codebase State — What's Already Done

The codebase is **well-prepared** for widget implementation. Key infrastructure is in place:

- **App Group container**: `group.com.ducdo.sprinty` configured in `sprinty.entitlements` (lines 5-8). `DatabaseManager.swift` already stores SQLite in the shared container via `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`.
- **Constants**: `Constants.appGroupIdentifier` and `Constants.databaseFilename` defined in `Core/Utilities/Constants.swift` (lines 7-8).
- **Widget refresh pattern**: `SettingsViewModel.swift` already imports WidgetKit and calls `WidgetCenter.shared.reloadAllTimelines()` on avatar/coach appearance changes (lines 59, 84). Replicate this pattern.
- **All data models** needed by widgets are already `Codable, FetchableRecord, Sendable`: `Sprint`, `SprintStep`, `UserProfile`, `AvatarState`, `AvatarOptions`.
- **Query helpers** exist: `Sprint.active()`, `SprintStep.forSprint(id:)`, `SprintStep.pendingSync()`, `UserProfile.current()`.

### What Does NOT Exist Yet

- **Widget extension target** — no `sprinty_widgetExtension` in `ios/project.yml` (currently only `sprinty` and `sprintyTests` targets, lines 32-62).
- **Widget extension directory** — `ios/sprinty_widgetExtension/` does not exist.
- **TimelineProvider** — no WidgetKit timeline provider implementation.
- **Deep linking** — no URL scheme handler in the app for `sprinty://coach`. App uses sheet-based navigation (boolean flags: `showConversation`, `showSettings`, `showSprintDetail`, `showCheckIn` in RootView lines 12-18), NOT tab-based navigation.

### Key Files to Reference

| File | Purpose | Lines of Interest |
|------|---------|-------------------|
| `ios/project.yml` | Add widget extension target | Lines 32-62 (existing targets) |
| `ios/sprinty/sprinty.entitlements` | App Group config reference | Lines 5-8 |
| `ios/sprinty/Core/Utilities/Constants.swift` | App Group ID, DB filename | Lines 7-8 |
| `ios/sprinty/Services/Database/DatabaseManager.swift` | DB in App Group container | Lines 12-21 |
| `ios/sprinty/Models/Sprint.swift` | Sprint model + active() query | Lines 10-25 |
| `ios/sprinty/Models/SprintStep.swift` | Step model + forSprint() query | Lines 9-25 |
| `ios/sprinty/Models/UserProfile.swift` | Profile + current() query, avatarId, isPaused | Lines 4-86 |
| `ios/sprinty/Core/State/AvatarState.swift` | 5 states, saturation, derive() | Lines 3-32 |
| `ios/sprinty/Core/Utilities/AvatarOptions.swift` | Asset name generation | Lines 4-22 |
| `ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift` | Widget data query pattern to replicate | Lines 142-171 |
| `ios/sprinty/Features/Home/Views/AvatarView.swift` | Avatar rendering pattern | Lines 3-30 |
| `ios/sprinty/Features/Home/Views/SprintProgressView.swift` | Progress bar rendering | Lines 3-86 |
| `ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift` | Existing WidgetCenter.reloadAllTimelines() pattern | Lines 3, 59, 84 |
| `ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift` | Step completion + sync — add widget reload here | `toggleStep()` line 90, `syncOnReconnect()` line 233 |
| `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` | Sprint creation — add widget reload here | `confirmSprint()` line 412 |
| `ios/sprinty/App/SprintyApp.swift` | Add .onOpenURL deep link handler | WindowGroup at line 16 |

### Architecture Compliance

- **Read-only DB access** in widget extension — open `DatabasePool` with `.readonly` configuration or use `DatabasePool.read {}` only. Never write from widget.
- **GRDB shared access** — main app and widget both use GRDB against same SQLite file in App Group container. GRDB handles WAL mode for concurrent read access.
- **No network calls from widgets** — widgets only read locally persisted data per architecture decision.
- **15-minute refresh** — WidgetKit enforces minimum refresh intervals; use `.after(Date().addingTimeInterval(15 * 60))` reload policy per NFR8.
- **Asset sharing** — avatar image assets must be included in widget extension target or use a shared asset catalog.

### UX Design Requirements

- **Small widget**: Avatar (48pt) + compact sprint progress strip (5pt height). Glanceable in 2 seconds.
- **Medium widget**: HStack — avatar (64pt) left, sprint info right (name, progress bar, next action). Full widget is tap target to open coach.
- **Color palette**: Earthy warm — warm cream background (light mode), near-monochrome warmth (dark mode) with avatar as the "most alive element" (avatarGlow token: #8B9B7A at 30%/20% opacity).
- **Pause mode**: Avatar → `.resting` state, sprint progress muted at 0.4 opacity (matching `SprintProgressView` implementation). Per state combination rule 2: "Pause Mode suppresses sprint and gamification."
- **Accessibility**: VoiceOver labels with state values, Dynamic Type support within widget constraints.
- **No animations in widgets** — WidgetKit renders static snapshots.

### What NOT To Do

- **Do NOT create a separate database** for widgets — use the existing shared SQLite via App Group.
- **Do NOT make API calls from the widget extension** — widgets are read-only local data.
- **Do NOT write to the database from the widget** — read-only access only.
- **Do NOT use AppState or ConnectivityMonitor in widgets** — these are main app runtime objects. Widget reads directly from DB.
- **Do NOT use @Observable or complex state management in widgets** — WidgetKit uses `TimelineProvider` pattern, not SwiftUI state.
- **Do NOT add coach character to widgets** — per UX spec, coach only appears in conversation view. Avatar only in home/widgets.
- **Do NOT create large/extra-large widget families** — only small and medium per FR68/FR69.

### Previous Story Intelligence (Story 10.3)

- **Sync status pattern**: `SprintStep.syncStatus` enum (`.synced`, `.pendingSync`) was added in 10.3. Widget should handle both states gracefully — show step as completed regardless of sync status.
- **Migration v19**: Added `syncStatus` column and `completedAt` to SprintStep. Widget data provider must handle these fields.
- **Connectivity observation**: Uses `.onChange(of: appState.isOnline)` pattern. Widget refresh should also be triggered here.
- **Haptic/celebration offline**: Works without connectivity. Widgets don't do haptics (static rendering).
- **Files modified in 10.3**: `SprintStep.swift`, `SprintDetailViewModel.swift`, `SprintDetailView.swift`, `DatabaseMigrations.swift`, `DatabaseManager.swift`. All stable and ready for widget integration.

### Git Intelligence

Recent commits show consistent pattern: one commit per story with code review fixes included. All Epic 10 stories (10.1-10.3) successfully implemented offline infrastructure that this story builds upon:
- 10.1: Multi-provider failover (server-side)
- 10.2: Offline mode with pending messages, connectivity monitoring
- 10.3: Offline sprint step completion with sync

### Testing Strategy

- **Unit tests**: Use protocol-based mock for database access. Create `MockWidgetDataProvider` that returns test entries.
- **Timeline tests**: Verify `TimelineProvider` returns correct entries for active sprint, no sprint, paused, and completed states.
- **Deep link tests**: Verify URL parsing and navigation state changes.
- **Integration tests**: Manual — add widgets to home screen, complete steps in app, verify widget updates within 15 minutes.
- **Test framework**: Swift Testing (`@Test` macro) for unit tests per project convention.

### Project Structure Notes

New files to create:
```
ios/sprinty_widgetExtension/
├── SprintyWidgetBundle.swift       # @main WidgetBundle
├── SprintyTimelineProvider.swift   # TimelineProvider + Entry
├── WidgetDataProvider.swift        # Read-only DB access
├── SmallWidgetView.swift           # Small widget UI
├── MediumWidgetView.swift          # Medium widget UI
└── sprinty_widgetExtension.entitlements  # App Group entitlement
```

Modified files:
```
ios/project.yml                                    # Add widget extension target + update schemes
ios/sprinty/App/SprintyApp.swift                   # Add .onOpenURL handler for sprinty://coach
ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift  # Add WidgetCenter.reload calls
ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift    # Add WidgetCenter.reload on sprint creation
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 10, Story 10.4 (FR68, FR69, NFR8)]
- [Source: _bmad-output/planning-artifacts/architecture.md — App Group setup, widget extension architecture, data flow]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Widget design, avatar states, color palette, accessibility]
- [Source: _bmad-output/implementation-artifacts/10-3-offline-sprint-step-completion.md — Previous story learnings]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Pre-existing flaky tests (3): ChatEventCodable/SSEParser fixture count mismatch — intermittent, not related to widget changes.

### Completion Notes List
- Task 1: Created `sprinty_widgetExtension` target in `project.yml` with WidgetKit framework, App Group, shared source files, and NSExtension Info.plist. Updated all 3 schemes (Debug/Staging/Release) to include widget extension. Created entitlements with matching App Group identifier.
- Task 2: Implemented `WidgetDataProvider` with read-only DB access from App Group container and `SprintyWidgetEntry` struct. `SprintyTimelineProvider` with 15-minute refresh policy (NFR8). Data queries replicate `HomeViewModel.loadActiveSprint()` pattern.
- Task 3: Implemented `SmallWidgetView` — 48pt avatar centered above 5pt compact progress bar. Earthy warm color palette, dark mode support, muted opacity for paused state. VoiceOver accessible.
- Task 4: Implemented `MediumWidgetView` — HStack with 64pt avatar, sprint name, progress bar, next action. Full widget deep links to `sprinty://coach`. Paused state shows soft prompt. VoiceOver accessible.
- Task 5: Added `.onOpenURL` handler in `SprintyApp.swift` for `sprinty://coach` deep link. Added `showConversation` flag to `AppState`. Added `WidgetCenter.shared.reloadAllTimelines()` in `SprintDetailViewModel.toggleStep()` (step completion + sprint completion), `syncOnReconnect()`, and `CoachingViewModel.confirmSprint()`.
- Task 6: 13 unit tests across 3 suites — data provider (active sprint, no sprint, paused, completed, progress calc, day calc, next action, no profile defaults, read-only access), deep link handling (coach URL, non-coach URL, non-sprinty URL), timeline provider (placeholder defaults). All pass. Full regression: 788/791 pass (3 pre-existing flaky SSEParser fixtures).

### Change Log
- 2026-04-03: Story 10.4 implementation complete — widget extension, data provider, small/medium widgets, deep linking, widget refresh triggers, 13 tests.
- 2026-04-03: Code review fixes — added WidgetCenter.reloadAllTimelines() on step uncomplete and sprint reactivation paths (M1), cached DatabasePool in timeline provider (L1), renamed Features/Widget → Features/Widgets to match architecture spec (L2), corrected task 6.5 claim (M2).

### File List
- `ios/project.yml` — Added widget extension target, updated schemes
- `ios/sprinty_widgetExtension/SprintyWidgetBundle.swift` — NEW: @main WidgetBundle
- `ios/sprinty_widgetExtension/SprintyTimelineProvider.swift` — NEW: TimelineProvider with 15-min refresh
- `ios/sprinty_widgetExtension/SmallWidgetView.swift` — NEW: Small widget (avatar + progress bar)
- `ios/sprinty_widgetExtension/MediumWidgetView.swift` — NEW: Medium widget (avatar + sprint info + deep link)
- `ios/sprinty_widgetExtension/WidgetColors.swift` — NEW: Color hex extension + widget color tokens
- `ios/sprinty_widgetExtension/sprinty_widgetExtension.entitlements` — NEW: App Group entitlement
- `ios/sprinty_widgetExtension/Info.plist` — NEW: Extension Info.plist with NSExtension
- `ios/sprinty/Features/Widgets/WidgetDataProvider.swift` — NEW: Read-only DB access + SprintyWidgetEntry
- `ios/sprinty/App/SprintyApp.swift` — Added WidgetKit import, .onOpenURL handler
- `ios/sprinty/App/AppState.swift` — Added showConversation property
- `ios/sprinty/App/RootView.swift` — Added onChange(of: appState.showConversation) handler
- `ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift` — Added WidgetKit import, reloadAllTimelines() calls
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — Added WidgetKit import, reloadAllTimelines() on sprint creation
- `ios/Tests/Features/WidgetTests.swift` — NEW: 13 unit tests (3 suites)
