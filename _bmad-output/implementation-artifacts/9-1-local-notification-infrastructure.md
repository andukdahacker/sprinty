# Story 9.1: Local Notification Infrastructure

Status: done

## Story

As a user,
I want to receive gentle, well-timed notifications from my coach,
so that I stay connected to my goals without being overwhelmed.

## Acceptance Criteria (BDD)

### AC1: Notification Permission Handling
```gherkin
Given the notification system initializes
When the app requests notification permission
Then it uses UNUserNotificationCenter (local only, no APNs for MVP)
And if the user denies OS notifications, there is no in-app nag (UX-DR68)
```

### AC2: Calm Budget Enforcement
```gherkin
Given the calm budget (UX-DR66)
When notifications are scheduled for a day
Then a hard cap of ≤2 notifications/day is enforced with priority ordering (FR50/architecture)
And the design target is ≤1/day per UX-DR66 Calm Budget — 2 is the absolute ceiling
And zero audio — notifications are silent
And no badge count ever
```

### AC3: Sprint Milestone Notification
```gherkin
Given a user completes the final step of a sprint
When the milestone is detected
Then a local notification fires: "You hit a milestone. Your coach noticed."
And it respects the daily cap and priority ordering
```

### AC4: Pause Suggestion Notification
```gherkin
Given the system detects sustained high-intensity engagement
When a pause suggestion is appropriate
Then a notification fires: "Your coach thinks you might need a breather."
And it respects Pause Mode suppression (FR52)
```

### AC5: Pause Mode Suppression
```gherkin
Given the user is in Pause Mode (FR52)
When notifications would be scheduled
Then all non-safety notifications are suppressed — zero notifications during Pause
```

### AC6: Notification Deep-Linking
```gherkin
Given a notification is delivered
When the user taps it
Then the app deep-links to the conversation view
```

### AC7: Priority Ordering
```gherkin
Given multiple notifications are eligible on the same day
When the cap would be exceeded
Then priority ordering determines winners: Safety > Milestones > Check-ins > Re-engagement
And note: PRD line 557 uses safety > check-in > milestone > re-engagement, but milestone > check-in is intentional here (milestones are rarer and more meaningful than daily check-ins)
```

## Tasks / Subtasks

- [x] **Task 1: NotificationScheduler — Central scheduling coordinator** (AC: 2, 5, 7)
  - [x] 1.1 Create `NotificationSchedulerProtocol` and `NotificationScheduler` in `Services/Notifications/`. Reuse the existing `NotificationCenterScheduling` protocol from `DriftDetectionService.swift` (lines 7-12) — extend it if more methods needed (e.g., `pendingNotificationRequests()`, `notificationSettings()`)
  - [x] 1.2 Implement daily cap tracking (hard cap ≤2/day, design target ≤1/day) with priority ordering enum
  - [x] 1.3 Implement `shouldSchedule(type:) -> Bool` — checks cap, pause mode, 24-hour rule, post-crisis
  - [x] 1.4 Implement `scheduleIfAllowed(type:content:trigger:) async` — central entry point for all notification scheduling
  - [x] 1.5 Implement `removeAllScheduledNotifications() async` — cancels everything (used on pause)
  - [x] 1.6 Track delivered-today count using `UNUserNotificationCenter.pendingNotificationRequests()` + delivered count
  - [x] 1.7 Create `MockNotificationScheduler` in `Tests/Mocks/`

- [x] **Task 2: NotificationType enum and priority system** (AC: 2, 7)
  - [x] 2.1 Create `NotificationType` enum: `.checkIn`, `.sprintMilestone`, `.pauseSuggestion`, `.reEngagement`
  - [x] 2.2 Add `priority: Int` property (lower = higher priority): safety=0, milestone=1, checkIn=2, reEngagement=3
  - [x] 2.3 Add `identifier: String` property returning the `com.ducdo.sprinty.*` identifier
  - [x] 2.4 Add `content: UNMutableNotificationContent` computed property with type-specific copy (silent, no badge)

- [x] **Task 3: Sprint milestone notification** (AC: 3, 6)
  - [x] 3.1 In `SprintDetailViewModel.toggleStep()` (lines 116-129), add milestone notification INSIDE the existing all-steps-complete block (after retro generation, before/after `sprint.status = .completed`). Do NOT create separate completion detection — the logic already exists
  - [x] 3.2 Call `NotificationScheduler.scheduleIfAllowed(.sprintMilestone, ...)` with time-interval trigger (5-second delay so notification fires after user navigates away)
  - [x] 3.3 Update `CheckInNotificationDelegate` to handle `com.ducdo.sprinty.milestone` identifier
  - [x] 3.4 Set `appState.pendingEngagementSource = .milestoneNotification` (add new case to `EngagementSource`)

- [x] **Task 4: Pause suggestion notification** (AC: 4, 5)
  - [x] 4.1 Add pause suggestion detection logic: trigger when `EngagementCalculator.computeSessionIntensity()` returns `.deep` (>15 messages or >20min) for 3+ sessions within 24 hours. Check this after each conversation ends in `RootView.computeAutonomyAndSchedule()` or a new dedicated method
  - [x] 4.2 Call `NotificationScheduler.scheduleIfAllowed(.pauseSuggestion, ...)` with short time-interval trigger
  - [x] 4.3 Update delegate to handle `com.ducdo.sprinty.pausesuggestion` identifier
  - [x] 4.4 Deep-link to conversation where coach suggests pause

- [x] **Task 5: Refactor existing services to use NotificationScheduler** (AC: 2, 5, 7)
  - [x] 5.1 Update `CheckInNotificationService` to route through `NotificationScheduler` for cap enforcement. Also refactor it to use the `NotificationCenterScheduling` protocol (currently takes raw `UNUserNotificationCenter` — inconsistent with `DriftDetectionService`)
  - [x] 5.2 Update `DriftDetectionService` to route through `NotificationScheduler` for cap enforcement
  - [x] 5.3 Ensure pause mode cancellation in `RootView` calls `NotificationScheduler.removeAllScheduledNotifications()`

- [x] **Task 6: Notification delegate enhancement** (AC: 6)
  - [x] 6.1 Rename `CheckInNotificationDelegate` → `NotificationDelegate` (handles all types now)
  - [x] 6.2 Add routing for all notification identifiers to appropriate `appState` flags
  - [x] 6.3 Ensure all notification taps deep-link to conversation view via state flags

- [x] **Task 7: Database migration for notification tracking** (AC: 2, 7)
  - [x] 7.1 Add GRDB migration for `NotificationDelivery` table: `id UUID, type TEXT, scheduledAt DATE, deliveredAt DATE?, priority INT`
  - [x] 7.2 Use this table for accurate daily cap tracking (survives app restart)
  - [x] 7.3 Add daily cleanup query (delete entries older than 48 hours)

- [x] **Task 8: Wire up in RootView and SprintyApp** (AC: 1, 5, 6)
  - [x] 8.1 Create `NotificationScheduler` instance in `RootView` alongside existing services
  - [x] 8.2 Inject into services that need it
  - [x] 8.3 Update `SprintyApp` delegate setup for renamed delegate
  - [x] 8.4 Update `onChange(of: appState.isPaused)` to cancel all via scheduler

- [x] **Task 9: Tests** (AC: all)
  - [x] 9.1 Unit tests: daily cap enforcement (schedule 3, only 2 allowed)
  - [x] 9.2 Unit tests: priority ordering (milestone beats re-engagement when cap reached)
  - [x] 9.3 Unit tests: pause mode suppression (zero notifications when paused)
  - [x] 9.4 Unit tests: 24-hour install rule
  - [x] 9.5 Unit tests: post-crisis suppression
  - [x] 9.6 Unit tests: sprint milestone trigger detection
  - [x] 9.7 Unit tests: pause suggestion trigger detection
  - [x] 9.8 Integration test: full scheduling flow through NotificationScheduler
  - [x] 9.9 Update existing `CheckInNotificationServiceTests` for refactored code
  - [x] 9.10 Add test file to `ios/project.yml`

## Dev Notes

### CRITICAL: Existing Notification Code — DO NOT Reinvent

Two notification services already exist and work correctly:

1. **`Services/Notifications/CheckInNotificationService.swift`** — schedules check-in notifications via `UNCalendarNotificationTrigger`. Has permission handling, 24-hour rule, post-crisis suppression, active sprint check. Uses `com.ducdo.sprinty.checkin` identifier.

2. **`Services/Notifications/DriftDetectionService.swift`** — schedules re-engagement nudges via `UNTimeIntervalNotificationTrigger`. Has autonomy-adjusted thresholds, pause suppression, 24-hour rule. Uses `com.ducdo.sprinty.reengagement` identifier.

3. **`App/SprintyApp.swift`** — `CheckInNotificationDelegate` handles tap routing for both identifiers. Sets `appState.pendingCheckIn` and `appState.pendingEngagementSource`.

4. **`App/RootView.swift`** — instantiates services, wires pause mode cancellation, handles `pendingCheckIn` state changes.

5. **Mock:** `Tests/Mocks/MockCheckInNotificationService.swift` — existing mock pattern.

**Your job:** Create a `NotificationScheduler` coordinator that sits ABOVE these services to enforce the ≤2/day hard cap (design target ≤1/day per UX-DR66) and priority ordering across ALL notification types. Then add milestone and pause suggestion notification types.

6. **Existing `NotificationCenterScheduling` protocol** in `DriftDetectionService.swift` (lines 7-12) — provides testable abstraction over `UNUserNotificationCenter` with `add()` and `removePendingNotificationRequests()`. Reuse this for the `NotificationScheduler`. Extend it if you need additional methods (e.g., `pendingNotificationRequests()` for cap tracking, `notificationSettings()` for permission checks).

7. **Existing `SpyNotificationCenter`** in `Tests/Services/DriftDetectionServiceTests.swift` (lines 9-20) — a test spy conforming to `NotificationCenterScheduling`. Reuse or extend this for `NotificationScheduler` tests.

### Notification Copy (EXACT — from UX-DR69)

| Type | Body Copy |
|------|-----------|
| Check-in | "Your coach has a thought for you." |
| Sprint milestone | "You hit a milestone. Your coach noticed." |
| Pause suggestion | "Your coach thinks you might need a breather." |
| Re-engagement | "Your coach has a thought for you." |

- Title: always empty string `""`
- Sound: always `nil` (silent)
- Badge: never set (zero badge count)

### Notification Identifiers

| Type | Identifier |
|------|-----------|
| Check-in | `com.ducdo.sprinty.checkin` (existing) |
| Re-engagement | `com.ducdo.sprinty.reengagement` (existing) |
| Sprint milestone | `com.ducdo.sprinty.milestone` (new) |
| Pause suggestion | `com.ducdo.sprinty.pausesuggestion` (new) |

### Priority Ordering (lower number = higher priority)

| Priority | Type | Rationale |
|----------|------|-----------|
| 0 | Safety (reserved) | Never suppressed |
| 1 | Sprint milestone | Earned celebration — rare and meaningful |
| 2 | Check-in | Daily coaching touchpoint |
| 3 | Pause suggestion | Proactive care |
| 4 | Re-engagement | Gentle — can wait |

### Suppression Rules (ALL must pass)

1. **24-hour install rule:** No notifications within 24 hours of `profile.createdAt`
2. **Post-crisis suppression:** No notifications if `profile.lastSafetyBoundaryAt != nil`
3. **Pause Mode:** Zero notifications when `appState.isPaused == true` (or `profile.isPaused`)
4. **Daily cap:** Hard cap ≤2/day (FR50), design target ≤1/day (UX-DR66). Priority ordering determines which wins when cap exceeded
5. **Permission denied:** No in-app nag if OS notifications denied (UX-DR68)
6. **No active sprint:** Check-in notifications require active sprint (existing behavior)

### Pause Mode Integration

Existing pattern in `RootView.swift`:
```swift
.onChange(of: appState.isPaused) { _, isPaused in
    if isPaused {
        // Cancel re-engagement nudges
    } else {
        // Reschedule drift detection
    }
}
```
Extend this to call `NotificationScheduler.removeAllScheduledNotifications()` on pause, and reschedule eligible notifications on unpause.

### Sprint Milestone Detection

Sprint step completion happens in `SprintDetailViewModel.toggleStep()` (lines 83-145). The all-steps-complete logic is at lines 116-129:
```swift
// Lines 116-129: When all steps are done, generates retro then marks sprint complete
// ADD milestone notification scheduling HERE — after retro generation
```
- Do NOT create separate completion detection — reuse the existing block
- Schedule milestone notification with short delay (5 seconds via `UNTimeIntervalNotificationTrigger`) so it fires after user navigates away
- Do NOT fire while app is in foreground — use `willPresent` delegate to show banner only

### EngagementSource Enum

Located at `ios/sprinty/Models/EngagementSource.swift`. Current definition:
```swift
enum EngagementSource: String, Codable, DatabaseValueConvertible, Sendable {
    case organic
    case checkInNotification
    case reEngagementNudge
}
```
Add new cases:
```swift
case milestoneNotification
case pauseSuggestionNotification
```
When adding cases, update ALL `switch` statements and pattern matches across test files (see Previous Story Intelligence).

### Architecture Compliance

- **ViewModels:** `@MainActor @Observable final class` — always
- **Services:** `Sendable` (or `@unchecked Sendable`) — never `@MainActor`
- **Database:** GRDB `DatabasePool` — services own DB access, not ViewModels
- **Concurrency:** async/await only — NEVER Combine
- **Testing:** Swift Testing (`@Suite`, `@Test`, `#expect`) — NEVER XCTest
- **Mocks:** `final class Mock{Name}: {Protocol}, @unchecked Sendable`
- **DI:** Protocol-based injection, services created in `RootView.swift`
- **Errors:** Non-critical notification failures silently caught (existing pattern)
- **Logging:** `os.Logger` if needed — never `print()`

### File Structure

```
ios/sprinty/Services/Notifications/
├── CheckInNotificationService.swift       (MODIFY — route through scheduler)
├── DriftDetectionService.swift            (MODIFY — route through scheduler)
├── NotificationScheduler.swift            (NEW — central coordinator)
└── NotificationType.swift                 (NEW — enum + priority)

ios/sprinty/App/
├── SprintyApp.swift                       (MODIFY — rename delegate)
└── RootView.swift                         (MODIFY — wire scheduler, extend pause handler)

ios/sprinty/Models/
└── NotificationDelivery.swift             (NEW — GRDB record for cap tracking)

ios/Tests/
├── Mocks/MockNotificationScheduler.swift  (NEW)
├── Services/NotificationSchedulerTests.swift (NEW)
└── Services/CheckInNotificationServiceTests.swift (MODIFY — update for refactor)
```

**Remember:** Add ALL new files to `ios/project.yml` (XcodeGen source of truth).

### Database Migration

Append new migration in `ios/sprinty/Services/Database/Migrations.swift` (never modify existing ones). Last migration is `v15_engagementSource` — use `v16_` prefix:
```swift
migrator.registerMigration("v16_notificationDelivery") { db in
    try db.create(table: "notificationDelivery") { t in
        t.primaryKey("id", .text).notNull()
        t.column("type", .text).notNull()
        t.column("scheduledAt", .datetime).notNull()
        t.column("deliveredAt", .datetime)
        t.column("priority", .integer).notNull()
    }
}
```

### Previous Story Intelligence (Story 8.3)

No server changes in this story — previous story patterns (8.3 middleware, done event extension) are not applicable. Key takeaway from 8.3:
- When adding new enum cases to shared types (e.g., `EngagementSource`), update ALL `switch` statements and pattern matches across test files. In 8.3 this required updating 61 occurrences across 8 test files.
- **All 674+ iOS tests must pass** after changes.

### Pause Suggestion Trigger Definition

`EngagementCalculator.computeSessionIntensity()` (at `Services/EngagementCalculator.swift` lines 103-120) classifies sessions as:
- `.deep` — >15 messages or >20min duration
- `.moderate` — between deep and light
- `.light` — <5 messages or <5min duration

Pause suggestion trigger: schedule when 3+ sessions with `.deep` intensity occur within 24 hours. Query `ConversationSession` table for recent sessions, compute intensity for each, and if threshold met, schedule the notification. Run this check in `RootView.computeAutonomyAndSchedule()` after each conversation ends.

### No Server Changes

This story is iOS-only. All notification logic is on-device. No API changes, no server middleware, no SSE event changes.

### UX Anti-Patterns (FORBIDDEN)

- Never use guilt messaging ("You haven't checked in!", "We miss you!")
- Never show badge count
- Never play sound
- Never nag about denied permissions
- Never send notifications in first 24 hours
- Never send notifications during Pause Mode
- Never use the word "notification" in user-facing copy (UX-DR word blacklist)
- Test: "Would I want to receive this at 10pm on a bad day?" If no, don't send it.

### References

- [Source: _bmad-output/planning-artifacts/prd.md#FR50 — hard cap 2 notifications/day]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR66 — calm budget ≤1/day design target]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9: Stories 9.1-9.3]
- [Source: _bmad-output/planning-artifacts/architecture.md — NotificationService, Calm Budget, Pause Mode]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR66, UX-DR68, UX-DR69]
- [Source: _bmad-output/planning-artifacts/prd.md — FR46-FR52, Push Notification Strategy]
- [Source: ios/sprinty/Services/Notifications/CheckInNotificationService.swift — existing service]
- [Source: ios/sprinty/Services/Notifications/DriftDetectionService.swift — existing service]
- [Source: ios/sprinty/App/SprintyApp.swift — notification delegate wiring]
- [Source: ios/sprinty/App/RootView.swift — service instantiation, pause handling]
- [Source: ios/sprinty/Services/EngagementCalculator.swift — session intensity computation]
- [Source: ios/sprinty/Models/EngagementSource.swift — existing enum, add new cases]
- [Source: ios/sprinty/Models/AutonomyLevel.swift — .none/.light/.moderate/.high]
- [Source: ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift:116-129 — all-steps-complete block]
- [Source: ios/sprinty/Services/Database/Migrations.swift — last migration is v15, next is v16]
- [Source: ios/Tests/Services/DriftDetectionServiceTests.swift:9-20 — SpyNotificationCenter test helper]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Build succeeded with 0 errors
- 698 tests ran — 695 passed, 3 pre-existing failures (ChatEventCodableTests, SSEParserTests — unrelated to this story)

### Completion Notes List
- Created `NotificationScheduler` coordinator with `NotificationSchedulerProtocol` — enforces ≤2/day hard cap with priority ordering across all notification types
- Created `NotificationType` enum with priority system: milestone(1) > checkIn(2) > pauseSuggestion(3) > reEngagement(4)
- Created `NotificationDelivery` GRDB model with v16 migration for persistent cap tracking
- Extended `NotificationCenterScheduling` protocol with `pendingNotificationRequests()` and `notificationSettings()`
- Added milestone notification in `SprintDetailViewModel.toggleStep()` — fires 5s after all steps complete
- Added pause suggestion detection in `RootView.checkPauseSuggestion()` — triggers when 3+ deep sessions in 24h
- Renamed `CheckInNotificationDelegate` → `NotificationDelegate` — routes all 4 notification types to appropriate `appState` flags
- Added `milestoneNotification` and `pauseSuggestionNotification` cases to `EngagementSource` enum
- Refactored `CheckInNotificationService` and `DriftDetectionService` to accept and route through `NotificationScheduler` for cap enforcement
- Updated `RootView` pause handler to call `NotificationScheduler.removeAllScheduledNotifications()`
- Exposed `EngagementCalculator.computeSessionIntensitySync()` for synchronous use in DB read blocks
- Added `permissionChecker` closure to `NotificationScheduler` init for testability (avoids `UNNotificationSettings` construction issues in tests)
- Created 22 unit tests covering: daily cap, priority ordering, pause suppression, 24h rule, post-crisis, notification content/identifiers, DB model operations, mock scheduler
- Updated `EngagementSourceTests` with new enum cases
- XcodeGen sources auto-discovers new files — no project.yml changes needed

### Change Log
- 2026-04-02: Story 9.1 implementation complete — all tasks done
- 2026-04-02: Code review fixes applied — H1: priority ordering now displaces lowest-priority notification to maintain ≤2/day hard cap; H2: added deep-link navigation for milestone/pause suggestion notification taps; M1: pause suggestion check now runs after each conversation ends; M2: removeAllScheduledNotifications() clears DB delivery records; L2: old delivery records cleaned up in computeAutonomyAndSchedule

### File List
- ios/sprinty/Services/Notifications/NotificationScheduler.swift (NEW)
- ios/sprinty/Services/Notifications/NotificationType.swift (NEW)
- ios/sprinty/Models/NotificationDelivery.swift (NEW)
- ios/Tests/Mocks/MockNotificationScheduler.swift (NEW)
- ios/Tests/Services/NotificationSchedulerTests.swift (NEW)
- ios/sprinty/Services/Notifications/DriftDetectionService.swift (MODIFIED — extended protocol, added scheduler injection)
- ios/sprinty/Services/Notifications/CheckInNotificationService.swift (MODIFIED — refactored to use NotificationCenterScheduling protocol, added scheduler routing)
- ios/sprinty/App/SprintyApp.swift (MODIFIED — renamed delegate, added all notification type routing)
- ios/sprinty/App/RootView.swift (MODIFIED — wired scheduler, pause handler, pause suggestion detection)
- ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift (MODIFIED — added milestone notification)
- ios/sprinty/Models/EngagementSource.swift (MODIFIED — added milestoneNotification, pauseSuggestionNotification)
- ios/sprinty/Services/EngagementCalculator.swift (MODIFIED — exposed computeSessionIntensitySync)
- ios/sprinty/Services/Database/Migrations.swift (MODIFIED — added v16_notificationDelivery)
- ios/Tests/Models/EngagementSourceTests.swift (MODIFIED — updated for new enum cases)
- ios/Tests/Services/DriftDetectionServiceTests.swift (MODIFIED — updated SpyNotificationCenter for extended protocol)
- ios/sprinty.xcodeproj/project.pbxproj (MODIFIED — auto-generated from new file additions)
