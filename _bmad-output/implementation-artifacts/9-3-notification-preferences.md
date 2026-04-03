# Story 9.3: Notification Preferences

Status: done

## Story

As a user,
I want to control when and what notifications I receive,
So that the app works on my schedule, not the other way around.

## Acceptance Criteria

1. **Given** the user navigates to Settings **When** the Notifications section is displayed **Then** they see: a "Mute coaching notifications" toggle, the existing check-in cadence picker, the existing check-in time picker, and a weekday picker (visible only when cadence is "weekly")

2. **Given** the user enables the "Mute coaching notifications" toggle **When** the toggle is active **Then** all coaching notifications (check-in, milestone, pause suggestion, re-engagement) are suppressed **And** the NotificationScheduler cancels all pending notifications immediately **And** safety-related notifications (if any in future) would still fire

3. **Given** the user disables the "Mute coaching notifications" toggle **When** the toggle is turned off **Then** coaching notifications resume normal scheduling **And** the check-in notification is rescheduled based on current cadence/time settings

4. **Given** the user changes check-in time **When** they select a new time **Then** future check-in notifications reschedule to the new time immediately (already works via `SettingsViewModel.updateCheckInTime`)

5. **Given** the user changes check-in cadence **When** they switch between daily/weekly **Then** notifications reschedule with new cadence immediately (already works via `SettingsViewModel.updateCheckInCadence`)

6. **Given** the user selects weekly cadence **When** the weekday picker appears **Then** they can choose a day of the week **And** the check-in notification reschedules to the selected day and time *(Note: weekday picker is a scope addition beyond the epics AC, which only specifies time picker + mute toggle. The `checkInWeekday` field already exists in UserProfile but has no UI — this is the natural place to expose it. Deprioritize if time-constrained.)*

7. **Given** notification preferences are changed **When** the app is force-quit and relaunched **Then** all preference values persist correctly from UserProfile in the database

## Tasks / Subtasks

- [x] Task 1: Add `notificationsMuted` field to UserProfile (AC: #2, #3, #7)
  - [x] 1.1 Add `var notificationsMuted: Bool = false` to `UserProfile` model
  - [x] 1.2 Add migration `v17_notificationsMuted` in `Migrations.swift` — add `notificationsMuted` column (BOOLEAN, NOT NULL, DEFAULT 0)
  - [x] 1.3 Load `notificationsMuted` in `SettingsViewModel.loadProfile()`

- [x] Task 2: Add mute toggle logic to SettingsViewModel (AC: #2, #3)
  - [x] 2.1 Add `var notificationsMuted: Bool = false` property to `SettingsViewModel`
  - [x] 2.2 Add `func updateNotificationsMuted(_ muted: Bool)` method:
    - Persist to UserProfile in DB
    - If muting: call `notificationScheduler.removeAllScheduledNotifications()` to cancel all pending
    - If unmuting: call `notificationService.scheduleCheckInNotification()` with current cadence/time/weekday to reschedule check-ins
  - [x] 2.3 Inject `NotificationSchedulerProtocol` into `SettingsViewModel` (new init parameter, optional like notificationService). **CRITICAL WIRING:** Also update `SettingsView.init()` to accept `notificationScheduler: NotificationSchedulerProtocol? = nil` and pass it through to SettingsViewModel. Then update the call site in `RootView.swift` (line ~114) to pass the existing `notificationScheduler` instance: `SettingsView(memoryViewModel: memoryViewModel, databaseManager: databaseManager, notificationService: checkInNotificationService, notificationScheduler: notificationScheduler)`

- [x] Task 3: Add weekday picker logic to SettingsViewModel (AC: #6)
  - [x] 3.1 Add `func updateCheckInWeekday(_ weekday: Int)` method — persist to DB + reschedule notification
  - [x] 3.2 Ensure weekday change triggers reschedule via `notificationService.scheduleCheckInNotification()`

- [x] Task 4: Integrate mute check into NotificationScheduler (AC: #2)
  - [x] 4.1 Add `notificationsMuted` check to `checkProfileRules()` in `NotificationScheduler.swift` — if `profile.notificationsMuted == true`, return false (suppress all)
  - [x] 4.2 This automatically blocks all 4 notification types when muted

- [x] Task 5: Update SettingsView UI (AC: #1, #6)
  - [x] 5.1 Rename existing "Check-ins" section to "Notifications"
  - [x] 5.2 Add `Toggle("Mute coaching notifications", isOn:)` bound to `viewModel.notificationsMuted` at top of section
  - [x] 5.3 Add weekday `Picker` visible only when `viewModel.checkInCadence == "weekly"` — display day names (Sunday-Saturday), bind to `viewModel.checkInWeekday`
  - [x] 5.4 When muted, visually disable (but still show) the cadence/time/weekday pickers using `.disabled(viewModel.notificationsMuted)`
  - [x] 5.5 Add accessibility: toggle gets `accessibilityHint("Silences all coaching notifications")`, weekday picker gets `accessibilityLabel("Check-in day")`

- [x] Task 6: Tests (AC: all)
  - [x] 6.1 Test `updateNotificationsMuted(true)` persists to DB and calls `removeAllScheduledNotifications()`
  - [x] 6.2 Test `updateNotificationsMuted(false)` persists to DB and calls `scheduleCheckInNotification()` with current settings
  - [x] 6.3 Test `NotificationScheduler.checkProfileRules()` returns false when `notificationsMuted == true`
  - [x] 6.4 Test `updateCheckInWeekday()` persists to DB and reschedules notification
  - [x] 6.5 Test mute state survives `loadProfile()` round-trip
  - [x] 6.6 Test existing cadence/time tests still pass with new migration
  - [x] 6.7 Test SettingsViewModel init accepts both `notificationService` and `notificationScheduler` (wiring smoke test — verifies the injection chain compiles and nil defaults work for previews)

## Dev Notes

### What Already Exists (DO NOT RECREATE)

**SettingsView** (`Features/Settings/Views/SettingsView.swift`) already has:
- "Check-ins" section with cadence Picker (daily/weekly) and time Picker (6 AM - 9 PM)
- Bindings to `SettingsViewModel` methods `updateCheckInCadence()` and `updateCheckInTime()`
- Both methods already persist to DB AND reschedule via `CheckInNotificationServiceProtocol`
- `formatHour()` helper for time display

**SettingsViewModel** (`Features/Settings/ViewModels/SettingsViewModel.swift`) already has:
- `checkInCadence`, `checkInTimeHour`, `checkInWeekday` properties
- `updateCheckInCadence()` — saves to DB + reschedules + auto-sets weekday to current day if switching to weekly
- `updateCheckInTime()` — saves to DB + reschedules
- `loadProfile()` — reads all profile fields from DB
- `notificationService: CheckInNotificationServiceProtocol?` injected via init
- Preview factory with `previewDB()`

**UserProfile** (`Models/UserProfile.swift`) already has:
- `checkInCadence: String = "daily"` (daily/weekly)
- `checkInTimeHour: Int = 9` (0-23)
- `checkInWeekday: Int?` (1=Sunday through 7=Saturday, for weekly)
- `isPaused: Bool` and `lastSafetyBoundaryAt: Date?` (used by notification suppression)

**NotificationScheduler** (`Services/Notifications/NotificationScheduler.swift`) already has:
- `checkProfileRules()` — checks 24h install, post-crisis, pause mode (after this story: 4 checks total — add `notificationsMuted` as the last guard, after pause mode check at line ~136)
- `removeAllScheduledNotifications()` — cancels all 4 types + clears DB records
- `scheduleIfAllowed()` — central cap enforcement entry point

**What does NOT exist yet:**
- No `notificationsMuted` field on UserProfile
- No mute toggle in SettingsView
- No weekday picker in SettingsView (weekday is auto-set but not user-selectable)
- No `NotificationSchedulerProtocol` injection in SettingsViewModel

### Architecture Compliance

- **MVVM pattern** — SettingsViewModel handles all business logic, SettingsView is purely declarative
- **@Observable** — NOT `ObservableObject`/`@Published` (NEVER Combine)
- **@MainActor** on SettingsViewModel (already applied)
- **Protocol injection** — `CheckInNotificationServiceProtocol` and `NotificationSchedulerProtocol` (both optional for graceful nil handling in previews)
- **GRDB patterns** — `dbPool.write { db in }` for persistence, `dbPool.read { db in }` for queries
- **Migrations append-only** — NEVER modify existing migrations, add v17
- **Swift Testing** — `@Suite`, `@Test`, `#expect()` — NEVER XCTest
- **Sendable** — all models must be `Sendable`
- **Database-first persistence** — no UserDefaults, no @AppStorage

### File Structure

Files to **modify**:
- `ios/sprinty/Models/UserProfile.swift` — Add `notificationsMuted: Bool = false`
- `ios/sprinty/Services/Database/Migrations.swift` — Add `v17_notificationsMuted` migration
- `ios/sprinty/Services/Notifications/NotificationScheduler.swift` — Add `notificationsMuted` check to `checkProfileRules()`
- `ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift` — Add mute property, mute method, weekday method, scheduler injection
- `ios/sprinty/Features/Settings/Views/SettingsView.swift` — Add mute toggle, weekday picker, rename section, add `notificationScheduler` init parameter
- `ios/sprinty/App/RootView.swift` — Pass `notificationScheduler` to SettingsView init (line ~114)
- `ios/Tests/Features/Settings/SettingsViewModelCheckInTests.swift` — Add mute, weekday, and wiring tests

Files that need **NO changes**:
- `CheckInNotificationService.swift` — Already handles scheduling correctly
- `NotificationType.swift` — No new notification types
- `SprintyApp.swift` — No delegate changes needed
- `RootView.swift` — **DOES need a change**: pass `notificationScheduler` to `SettingsView` init at line ~114

### Testing Standards

- Test naming: `test_{function}_{scenario}_{expected}`
- Test struct: `@Suite struct SettingsViewModelNotificationPreferenceTests`
- Database tests: use `makeTestDB()` pattern from existing `SettingsViewModelCheckInTests`
- Profile creation: use `createProfile(in:)` pattern from existing tests
- Mock pattern: `final class Mock{ServiceName}: {Protocol}, @unchecked Sendable`
- Assertions: `#expect(value == expected)` only
- Existing mocks to reuse: `MockCheckInNotificationService` (`Tests/Mocks/`), `MockNotificationScheduler` (`Tests/Mocks/`)
- Background Task await: `try await Task.sleep(for: .milliseconds(200))` pattern (see existing tests)

### Weekday Picker Implementation Detail

`Calendar.current.weekdaySymbols` returns `["Sunday", "Monday", ..., "Saturday"]` indexed 0-6. But `DateComponents.weekday` and `UserProfile.checkInWeekday` use 1-7 (1=Sunday). Map with offset: `weekdaySymbols[weekday - 1]`.

The `Picker` should display full day names and tag each option with its 1-7 integer value.

### Mute vs Pause Mode

Both suppress notifications but serve different purposes:
- **Pause Mode** (`isPaused`) — User activated therapeutic pause. Affects entire app: avatar resting, desaturated theme, zero notifications. Managed by coaching system.
- **Mute** (`notificationsMuted`) — User preference for no push notifications. Only affects notifications. Managed by Settings.

Both are checked in `NotificationScheduler.checkProfileRules()`. They are independent — a user can unmute notifications while still in Pause Mode (notifications still suppressed by pause check).

### Notification Copy Reference (UX-DR69)

| Type | Body | Anti-Pattern |
|------|------|-------------|
| Check-in | "Your coach has a thought for you." | "You haven't checked in today!" |
| Sprint milestone | "You hit a milestone. Your coach noticed." | "Congratulations! 5 steps done!" |
| Pause suggestion | "Your coach thinks you might need a breather." | "Take a break!" |
| Re-engagement | "Your coach has a thought for you." | "We miss you!" / "Come back!" |

### UX Design Notes

- Settings uses SwiftUI `Form` with standard density (familiar iOS patterns, coaching typography)
- Toggle and Picker use standard SwiftUI components — themed via `CoachingTheme` environment
- Privacy section uses reassuring language, not bureaucratic
- Disabled pickers when muted should still be visible (user can see their saved preferences)

### Previous Story Intelligence

**From Story 9.2 (ready-for-dev):**
- Story 9.2 added `rescheduleCheckIn()` method and 50% milestone threshold
- Story 9.2 referenced that Story 9.3 would add the Settings UI for notification preferences
- Story 9.2 Task 3.3 noted: "If no existing UI updates these fields yet (Story 9.3 handles full Settings UI), add the reschedule hook at the profile-save call site"

**From Story 9.1 (done):**
- `NotificationScheduler.checkProfileRules()` already checks: 24h install, post-crisis, pause mode. Adding `notificationsMuted` check follows same pattern
- `removeAllScheduledNotifications()` cancels all 4 identifier types + clears DB delivery records
- `permissionChecker` closure pattern for testability
- Code review: H1 (priority displacement), H2 (deep-link all types), M1 (pause suggestion timing), M2 (removeAll clears DB)
- Test count after 9.1: 698 total (695 passing, 3 pre-existing failures unrelated)

**From SettingsViewModel existing tests:**
- `SettingsViewModelCheckInTests` validates cadence and time changes trigger `scheduleCheckInNotification()`
- Uses `MockCheckInNotificationService` with `scheduleCallCount`, `lastCadence`, `lastHour`, `lastWeekday` tracking
- Pattern: create VM, set properties, call method, sleep 200ms, assert mock state

### No Server Changes

This story is iOS-only. No API changes, no server modifications.

### Project Structure Notes

- Settings feature: `ios/sprinty/Features/Settings/`
- Notification services: `ios/sprinty/Services/Notifications/`
- Shared models: `ios/sprinty/Models/`
- Database migrations: `ios/sprinty/Services/Database/Migrations.swift`
- Tests: `ios/Tests/Features/Settings/`, `ios/Tests/Mocks/`
- All database models: `Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable`
- Last migration: `v16_notificationDelivery` — next is `v17`

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9, Story 9.3 (lines 1775-1796)]
- [Source: _bmad-output/planning-artifacts/architecture.md — Settings feature structure, NotificationService]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — SettingsView sections, Notification patterns, Calm Budget]
- [Source: _bmad-output/planning-artifacts/prd.md — FR51 (notification preferences), FR52 (Pause Mode suppression)]
- [Source: ios/sprinty/Features/Settings/Views/SettingsView.swift — existing Check-ins section]
- [Source: ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift — existing cadence/time/weekday handling]
- [Source: ios/sprinty/Models/UserProfile.swift — existing check-in fields, isPaused, lastSafetyBoundaryAt]
- [Source: ios/sprinty/Services/Notifications/NotificationScheduler.swift — checkProfileRules(), removeAllScheduledNotifications()]
- [Source: ios/sprinty/Services/Notifications/CheckInNotificationService.swift — scheduleCheckInNotification()]
- [Source: ios/Tests/Features/Settings/SettingsViewModelCheckInTests.swift — existing test patterns]
- [Source: _bmad-output/implementation-artifacts/9-1-local-notification-infrastructure.md — notification architecture]
- [Source: _bmad-output/implementation-artifacts/9-2-check-in-and-sprint-milestone-notifications.md — reschedule patterns]
- [Source: _bmad-output/project-context.md — testing rules, GRDB patterns, migration rules]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Full test suite: 732 tests, 729 pass, 3 pre-existing failures (ChatEventCodableTests, SSEParserTests — unrelated to this story)
- Story 9.3 tests: 8/8 pass (7 original + 1 bypassesMute architecture test from code review)

### Completion Notes List
- Added `notificationsMuted: Bool = false` to UserProfile model with v17 migration
- Added `updateNotificationsMuted(_:)` to SettingsViewModel — muting calls `removeAllScheduledNotifications()`, unmuting calls `rescheduleCheckIn()`
- Added `updateCheckInWeekday(_:)` to SettingsViewModel — persists to DB and reschedules
- Injected `NotificationSchedulerProtocol` into SettingsViewModel (optional, nil-safe for previews)
- Added `notificationsMuted` guard to `NotificationScheduler.checkProfileRules()` — blocks all 4 notification types when muted
- Renamed "Check-ins" section to "Notifications" in SettingsView
- Added mute toggle with accessibility hint, weekday picker with day names (1-7 mapping), disabled state on pickers when muted
- Wired `notificationScheduler` through SettingsView → SettingsViewModel → RootView call site
- 8 tests covering mute persistence, removeAll/reschedule dispatch, checkProfileRules suppression, weekday persistence, loadProfile round-trip, migration compatibility, DI wiring, and bypassesMute architecture verification

### Change Log
- Story 9.3 implementation completed (Date: 2026-04-03)
- Code review fix: Added `bypassesMute` property to `NotificationType` and type-aware `checkProfileRules(for:)` so future safety notifications can bypass mute (AC #2 forward-compatibility). Added 1 test. (Date: 2026-04-03)

### File List
- ios/sprinty/Models/UserProfile.swift (modified — added `notificationsMuted` field)
- ios/sprinty/Services/Database/Migrations.swift (modified — added v17_notificationsMuted migration)
- ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift (modified — added notificationsMuted property, updateNotificationsMuted(), updateCheckInWeekday(), notificationScheduler injection)
- ios/sprinty/Features/Settings/Views/SettingsView.swift (modified — renamed section, added mute toggle, weekday picker, disabled state, notificationScheduler init param)
- ios/sprinty/Services/Notifications/NotificationScheduler.swift (modified — added notificationsMuted check to checkProfileRules())
- ios/sprinty/App/RootView.swift (modified — pass notificationScheduler to SettingsView)
- ios/sprinty/Services/Notifications/NotificationType.swift (modified — added `bypassesMute` property for safety notification bypass)
- ios/Tests/Features/Settings/SettingsViewModelCheckInTests.swift (modified — added SettingsViewModelNotificationPreferenceTests suite with 8 tests)
