# Story 9.2: Check-in & Sprint Milestone Notifications

Status: done

## Story

As a user with active goals,
I want timely reminders for check-ins and milestone celebrations,
So that I stay on track and feel acknowledged when I make progress.

## Acceptance Criteria

1. **Given** a user has an active sprint and check-in notifications enabled **When** the scheduled check-in time arrives **Then** a local notification fires with body "Your coach has a thought for you." (UX-DR69) **And** the notification time uses the existing `UserProfile.checkInTimeHour` field (FR51)

2. **Given** a user completes a sprint step that crosses a milestone threshold (50% or 100% of steps) **When** the milestone is reached **Then** a notification fires with body "You hit a milestone. Your coach noticed." (UX-DR69) **And** at most one milestone notification per sprint per threshold

3. **Given** the system detects sustained high-intensity engagement (3+ deep sessions in 24h) **When** a pause suggestion is appropriate **Then** a notification fires with body "Your coach thinks you might need a breather." (UX-DR69)

4. **Given** a user has been away beyond the drift threshold **When** a re-engagement nudge is triggered **Then** the notification uses emotion-safe copy only **And** no return-after-absence notification pattern exists — the daily greeting handles return (UX-DR69)

5. **Given** any notification type fires **When** the calm budget is checked **Then** the 2/day hard cap and priority ordering from Story 9.1 are respected **And** all notifications are silent (no sound, no badge)

6. **Given** the user is in Pause Mode **When** any notification would fire **Then** all non-safety notifications are suppressed (zero notifications during Pause)

7. **Given** check-in time is updated **When** the user changes `checkInTimeHour` or `checkInCadence` **Then** the existing check-in notification is rescheduled to the new time/cadence immediately

## Tasks / Subtasks

- [x] Task 1: Add `rescheduleCheckIn()` to CheckInNotificationService (AC: #1, #7)
  - [x] 1.1 Add `rescheduleCheckIn(profile: UserProfile)` method that cancels existing check-in notification and re-schedules using `profile.checkInTimeHour`, `profile.checkInCadence`, and `profile.checkInWeekday`
  - [x] 1.2 Ensure the method reads profile from DB if not passed, and routes through NotificationScheduler
  - [x] 1.3 Extend existing `CheckInNotificationServiceTests.swift` with tests: reschedule cancels old + schedules new, handles daily and weekly cadence, respects all suppression rules

- [x] Task 2: Add intermediate sprint milestone notifications (AC: #2)
  - [x] 2.1 In `SprintDetailViewModel`, detect when step completion crosses the 50% threshold (e.g., completing step 3 of 6 steps). Currently only fires at 100% (final step `allDone`).
  - [x] 2.2 Track which milestone thresholds have already fired per sprint to prevent duplicates. Options: add a `milestonesNotified` field on Sprint model (requires migration v17), or check `NotificationDelivery` records filtered by sprint context, or use a simple in-memory set on the ViewModel (lost on restart but acceptable since milestones are step-completion-driven)
  - [x] 2.3 Keep existing 100% (final step) milestone notification from Story 9.1 unchanged
  - [x] 2.4 Write tests: 50% threshold fires, duplicate prevention for same threshold, 100% still fires, step completion below 50% does not fire, odd step counts round correctly (e.g., 3 of 5 = 60% triggers 50% milestone)

- [x] Task 3: Wire up check-in rescheduling from profile changes (AC: #7)
  - [x] 3.1 Identify where `UserProfile.checkInTimeHour` / `checkInCadence` is updated (likely `MemoryView` profile editing or a settings flow)
  - [x] 3.2 After profile save, call `rescheduleCheckIn()` so the next notification fires at the new time
  - [x] 3.3 If no existing UI updates these fields yet (Story 9.3 handles full Settings UI), add the reschedule hook at the profile-save call site so it triggers automatically when 9.3 adds the UI
  - [x] 3.4 Write test: profile hour change triggers cancel + reschedule

- [x] Task 4: Comprehensive notification scenario tests (AC: #3, #4, #5, #6)
  - [x] 4.1 **Pause suggestion verification:** Confirm `RootView.checkPauseSuggestion()` detects 3+ deep sessions in 24h (deep = `EngagementCalculator` intensity `.deep`) and schedules via `NotificationScheduler.scheduleIfAllowed(type: .pauseSuggestion, trigger:)` with 10-second delay trigger
  - [x] 4.2 **Re-engagement verification:** Confirm `DriftDetectionService` routes through `NotificationScheduler`, uses emotion-safe copy "Your coach has a thought for you.", and cancels pending re-engagement via explicit `cancelReEngagementNudge()` call (NOTE: cancellation happens when coaching view closes, NOT automatically on app open — this is by design since the daily greeting handles return)
  - [x] 4.3 **Cross-type calm budget tests:** Schedule multiple notification types in same day, verify 2/day hard cap enforced, verify priority displacement (milestone priority 1 displaces check-in priority 2)
  - [x] 4.4 **Pause Mode suppression tests:** Verify all 4 notification types suppressed when `isPaused == true`
  - [x] 4.5 **Notification content tests:** Verify all 4 types produce empty title `""`, nil sound, no badge, correct body copy per `NotificationType.content`

## Dev Notes

### What Story 9.1 Already Built (DO NOT RECREATE)

Story 9.1 implemented the full notification infrastructure AND basic triggers for all 4 types:

- **NotificationScheduler** (`Services/Notifications/NotificationScheduler.swift`) — Central coordinator with 2/day cap, priority-based displacement, 5 suppression rules (permission, 24h install, post-crisis, pause mode, daily cap)
- **NotificationType** (`Services/Notifications/NotificationType.swift`) — Enum with all 4 types, priorities, identifiers, and `UNMutableNotificationContent` generation. Priority: Milestone(1) > CheckIn(2) > PauseSuggestion(3) > ReEngagement(4)
- **NotificationDelivery** (`Models/NotificationDelivery.swift`) — GRDB model for persistent cap tracking (migration v16)
- **MockNotificationScheduler** (`Tests/Mocks/MockNotificationScheduler.swift`) — Test mock tracking call counts, last type, last trigger
- **NotificationDelegate** in `SprintyApp.swift` — Routes all 4 notification type taps to `appState` flags for deep-linking to conversation view
- **CheckInNotificationService** (`Services/Notifications/CheckInNotificationService.swift`) — Already schedules check-ins using `UNCalendarNotificationTrigger` with configurable `hour`, `cadence`, `weekday` parameters. Routes through NotificationScheduler. Guard clauses: 24h install, post-crisis, active sprint required.
- **DriftDetectionService** (`Services/Notifications/DriftDetectionService.swift`) — Already schedules re-engagement nudges with autonomy-adjusted threshold (72h base, up to 168h). Cancel via explicit `cancelReEngagementNudge()` (called when coaching view closes, NOT on app open).
- **SprintDetailViewModel** — Already fires milestone notification on final step completion (5s delay trigger via `UNTimeIntervalNotificationTrigger`)
- **RootView** — Creates NotificationScheduler, injects into services, handles pause suggestion detection (3+ deep sessions in 24h, 10s delay trigger)

### Existing Check-in Configuration Fields (ALREADY IN UserProfile — migration v11)

```swift
var checkInCadence: String = "daily"   // "daily" or "weekly"
var checkInTimeHour: Int = 9           // 0-23 hour of day
var checkInWeekday: Int?               // 1-7 for weekly cadence
```

DO NOT create `preferredCheckInHour` or a new migration for check-in time. These fields exist.

### What This Story Adds

1. **`rescheduleCheckIn()` method** — Cancel existing + re-schedule when user changes time/cadence
2. **50% intermediate milestone** — Fire milestone notification at halfway point, not just 100%
3. **Milestone duplicate prevention** — Track which thresholds fired per sprint
4. **Reschedule wiring** — Hook reschedule into profile-save call sites
5. **Comprehensive cross-type tests** — End-to-end tests covering all 4 notification types, calm budget across types, priority displacement, Pause Mode suppression

### Architecture Compliance

- **MVVM pattern** — ViewModel handles trigger logic, service handles scheduling
- **Protocol injection** — `NotificationSchedulerProtocol` for testability
- **No new migrations unless needed** — Only add v17 if milestone tracking requires a new DB field
- **Swift concurrency** — `async/await`, `@MainActor` on ViewModels
- **@Observable** — Not `ObservableObject` / `@Published` (NEVER use Combine)
- **Swift Testing** — `@Suite struct`, `@Test`, `#expect()` — NEVER XCTest/XCTAssert
- **Sendable** — All models must be `Sendable`

### File Structure

Files to **modify**:
- `ios/sprinty/Services/Notifications/CheckInNotificationService.swift` — Add `rescheduleCheckIn()` method
- `ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift` — Add 50% milestone threshold detection + duplicate prevention
- `ios/Tests/Services/NotificationSchedulerTests.swift` — Add cross-type calm budget and Pause Mode tests
- `ios/Tests/Services/CheckInNotificationServiceTests.swift` (exists, 144 lines) — Extend with reschedule tests

Files to **possibly modify** (if milestone tracking needs DB persistence):
- `ios/sprinty/Models/Sprint.swift` — Add `milestonesNotified: String?` field (JSON-encoded set of thresholds)
- `ios/sprinty/Services/Database/Migrations.swift` — Add v17 migration only if Sprint model needs new column

### Testing Standards

- Test naming: `test_{function}_{scenario}_{expected}`
- Test struct: `@Suite struct CheckInNotificationTests`
- Database tests: use `makeTestDB()` with real GRDB migrations against in-memory database
- Mock pattern: `final class Mock{ServiceName}: {ServiceProtocol}, @unchecked Sendable`
- Use existing helpers: `createSession()`, `createMessage()`, `makeDate(hour:)`
- Assertions: `#expect(value == expected)` only
- Existing test mocks to reuse: `SpyNotificationCenter` (records add/remove calls), `MockNotificationScheduler` (tracks schedule calls)

### Notification Copy Reference (UX-DR69)

| Type | Body | Anti-Pattern |
|------|------|-------------|
| Check-in | "Your coach has a thought for you." | "You haven't checked in today!" |
| Sprint milestone | "You hit a milestone. Your coach noticed." | "Congratulations! 5 steps done!" |
| Pause suggestion | "Your coach thinks you might need a breather." | "Take a break!" |
| Re-engagement | "Your coach has a thought for you." | "We miss you!" / "Come back!" |

All notifications: empty title `""`, nil sound, no badge count. Silent only.

### Calm Budget Constraints

- Hard cap: 2 notifications/day (design target 1/day)
- Zero during Pause Mode
- Priority ordering when cap exceeded: higher priority displaces lower
- "Would I want to receive this at 10pm on a bad day?" — if no, don't send

### Previous Story Intelligence

**From Story 9.1 code review:**
- H1: Priority displacement properly maintains hard cap
- H2: Deep-link navigation works for all 4 notification types
- M1: Pause suggestion runs after each conversation ends in `computeAutonomyAndSchedule()`
- M2: `removeAllScheduledNotifications()` clears database delivery records
- L2: Old delivery records cleaned up in daily compute cycle

**Key patterns from 9.1:**
- `permissionChecker` closure on NotificationScheduler for testability (avoids constructing UNNotificationSettings directly)
- `NotificationCenterScheduling` protocol extends `UNUserNotificationCenter` for DI
- `SpyNotificationCenter` in tests records add/remove calls
- `EngagementCalculator.computeSessionIntensitySync()` for synchronous DB operations in read blocks

**Existing CheckInNotificationService implementation detail:**
- Accepts `cadence: String`, `hour: Int`, `weekday: Int?` parameters
- Uses `UNCalendarNotificationTrigger(dateMatching:, repeats: true)` — daily sets only hour, weekly sets hour + weekday
- Cancels existing check-in notification before scheduling new one
- Routes through NotificationScheduler if injected, falls back to direct scheduling

**Existing DriftDetectionService cancel behavior:**
- `cancelReEngagementNudge()` removes pending notifications with `.reEngagement` identifier
- Called explicitly when coaching view closes — NOT auto-called on app open
- This is intentional: the daily greeting handles return, so no return-after-absence notification needed

**Test count as of 9.1:** 698 total (695 passing, 3 pre-existing failures unrelated)

### Project Structure Notes

- Notification services: `ios/sprinty/Services/Notifications/`
- Sprint feature: `ios/sprinty/Features/Sprint/ViewModels/`
- Shared models: `ios/sprinty/Models/`
- Database: `ios/sprinty/Services/Database/`
- Tests mirror source: `ios/Tests/Services/`, `ios/Tests/Mocks/`
- GRDB async: `dbPool.read { db in }` and `dbPool.write { db in }` — never synchronous
- Database migrations append-only, sequential — NEVER modify existing migrations

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9, Story 9.2 (lines 1749-1773)]
- [Source: _bmad-output/planning-artifacts/architecture.md — Notifications (lines 697-712), Sprint schema (lines 512-517)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Notification patterns (lines 2025-2038), Calm Budget (lines 113-118)]
- [Source: _bmad-output/planning-artifacts/prd.md — FR46-FR52 (lines 797-803)]
- [Source: _bmad-output/implementation-artifacts/9-1-local-notification-infrastructure.md]
- [Source: ios/sprinty/Models/UserProfile.swift — checkInTimeHour, checkInCadence, checkInWeekday fields (migration v11)]
- [Source: ios/sprinty/Services/Notifications/CheckInNotificationService.swift — existing configurable scheduling]
- [Source: ios/sprinty/Services/Notifications/DriftDetectionService.swift — explicit cancelReEngagementNudge()]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Full regression: 725 tests, 722 passing, 3 pre-existing failures (ChatEventCodableTests, SSEParserTests — unrelated to this story)

### Completion Notes List
- **Task 1:** Added `rescheduleCheckIn(profile:)` to `CheckInNotificationServiceProtocol` and implementation. Method cancels existing check-in notification and re-schedules using profile's cadence/hour/weekday. Reads from DB if profile parameter is nil. 5 new tests covering daily/weekly cadence, DB fallback, and suppression rules.
- **Task 2:** Added 50% intermediate milestone detection in `SprintDetailViewModel.toggleStep()`. Uses in-memory `notifiedMilestones` set for duplicate prevention per ViewModel lifecycle. Existing 100% milestone path unchanged. 5 new tests covering threshold detection, duplicate prevention, odd step counts.
- **Task 3:** Refactored `SettingsViewModel.updateCheckInCadence()` and `updateCheckInTime()` to use `rescheduleCheckIn()` instead of manual `scheduleCheckInNotification()` calls. Updated existing tests and added 2 new tests verifying profile save triggers reschedule.
- **Task 4:** Added 14 comprehensive scenario tests to `NotificationSchedulerTests.swift`: pause suggestion type verification, re-engagement emotion-safe copy verification, DriftDetectionService cancellation, cross-type calm budget with 2/day hard cap, priority displacement across types, Pause Mode suppression for all 4 types individually, and notification content verification for all 4 types.

### Change Log
- Story 9.2 implementation completed (Date: 2026-04-03)

### File List
- `ios/sprinty/Services/Notifications/CheckInNotificationService.swift` — Added `rescheduleCheckIn(profile:)` method to protocol and implementation
- `ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift` — Added 50% milestone detection via `checkIntermediateMilestone()` and `notifiedMilestones` tracking set
- `ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift` — Refactored `updateCheckInCadence/Time` to use `rescheduleCheckIn()`
- `ios/Tests/Services/CheckInNotificationServiceTests.swift` — Added 5 reschedule tests (Story 9.2)
- `ios/Tests/Services/NotificationSchedulerTests.swift` — Added 14 cross-type scenario tests (Story 9.2)
- `ios/Tests/Features/Sprint/SprintDetailViewModelTests.swift` — Added 5 milestone notification tests (Story 9.2)
- `ios/Tests/Features/Settings/SettingsViewModelCheckInTests.swift` — Updated 2 existing tests, added 3 new tests: 2 reschedule verification + 1 nil-service safety test (Story 9.2)
- `ios/Tests/Mocks/MockCheckInNotificationService.swift` — Added `rescheduleCheckIn` mock recording
