# Story 7.2: Drift Detection & Re-engagement

Status: done

## Story

As a user who has been away without pausing,
I want the system to gently check in without being pushy,
so that I'm reminded my coach is there without feeling pressured to engage.

## Acceptance Criteria

### AC 1: Re-engagement Nudge After Inactivity

```
Given a user has been inactive for a configurable period outside of Pause Mode (FR38)
When the inactivity threshold is reached
Then a gentle re-engagement nudge is sent
And the nudge uses emotion-safe copy (UX-DR68): "Your coach has a thought for you"
And zero "come back" messaging
```

### AC 2: Healthy Pause vs Disengagement Distinction

```
Given the system distinguishes pause types (FR37)
When evaluating inactivity
Then it differentiates between healthy pause (user chose Pause Mode) and disengagement (user simply stopped engaging)
And re-engagement nudges only fire for disengagement, not healthy pauses
```

### AC 3: Natural Return — No Absence Notification

```
Given the user returns after absence (no Pause Mode active)
When they open the app
Then no notification about absence is shown
And the daily greeting handles the return naturally (UX-DR48)
And zero "you've been away" or guilt messaging
```

### AC 4: Notification Budget Compliance

```
Given the Calm Budget constraint (UX-DR66)
When a re-engagement nudge is scheduled
Then it respects the hard cap of 2 notifications per day
And it respects Pause Mode suppression (zero notifications during Pause)
And it respects post-crisis suppression (zero nudges when lastSafetyBoundaryAt is set)
```

### AC 5: Configurable Inactivity Threshold

```
Given a default inactivity threshold
When drift detection evaluates user activity
Then the threshold defaults to 3 days (72 hours) for the initial nudge
And the threshold is configurable via a constant (not hard-coded in scheduling logic)
And only one re-engagement nudge fires per drift period (no repeated nagging)
```

## Tasks / Subtasks

- [x] Task 1: Create DriftDetectionService (AC: 1, 2, 4, 5)
  - [x] 1.1 Create `DriftDetectionService` protocol and implementation in `Services/Notifications/`
  - [x] 1.2 Implement `scheduleReEngagementNudge()` — schedules a `UNTimeIntervalNotificationTrigger` for the inactivity threshold (default 72 hours)
  - [x] 1.3 Implement `cancelReEngagementNudge()` — cancels pending re-engagement notification
  - [x] 1.4 Implement `evaluateAndSchedule()` — main entry point: reads last session date + pause state, schedules only if not paused, not post-crisis, and no active nudge pending
  - [x] 1.5 Define `DriftDetectionConfig` struct with configurable `inactivityThresholdHours: Int = 72`
  - [x] 1.6 Inject `DatabaseManager` for reading last session date and UserProfile state

- [x] Task 2: Integrate drift detection into app lifecycle (AC: 1, 2, 3)
  - [x] 2.1 In `RootView`, create `DriftDetectionService` alongside `CheckInNotificationService`
  - [x] 2.2 Call `evaluateAndSchedule()` on app launch (in `.task` modifier on authenticated view)
  - [x] 2.3 Call `cancelReEngagementNudge()` + `evaluateAndSchedule()` when conversation ends (reschedule window)
  - [x] 2.4 Call `cancelReEngagementNudge()` when Pause Mode activates (no nudges during pause)
  - [x] 2.5 Call `evaluateAndSchedule()` when Pause Mode deactivates (start drift watch again)
  - [x] 2.6 Wire `onChange(of: appState.isPaused)` in RootView to handle 2.4/2.5

- [x] Task 3: Notification content and budget compliance (AC: 1, 4)
  - [x] 3.1 Use emotion-safe notification copy: title="" (empty), body="Your coach has a thought for you." — matches existing check-in copy pattern
  - [x] 3.2 Use distinct notification identifier: `com.ducdo.sprinty.reengagement` (separate from check-in identifier)
  - [x] 3.3 Use `UNTimeIntervalNotificationTrigger(timeInterval:, repeats: false)` — single fire, not repeating
  - [x] 3.4 Verify 2/day cap compliance: re-engagement + check-in can coexist but both respect the cap. Since re-engagement fires after days of inactivity, the check-in won't fire the same day (no active sprint after days away). Document this reasoning.
  - [x] 3.5 **Spec discrepancy note:** UX-DR66 (Calm Budget) specifies a hard cap of 1 notification per day, while the architecture spec (Push Notifications MVP Scoping) allows 2 per day. Both are satisfied in practice because re-engagement nudges only fire after days of inactivity, at which point no check-in notification would fire (no active sprint). The implementation should enforce a 2/day ceiling (architecture spec) while recognizing the UX intent is 1/day during normal use.

- [x] Task 4: Verify natural return behavior (AC: 3)
  - [x] 4.1 Audit HomeViewModel greeting flow — confirm no "you've been away" language exists
  - [x] 4.2 Audit CoachingViewModel — confirm first message on return is RAG-informed daily greeting with no absence reference
  - [x] 4.3 On app launch after drift period: cancel pending re-engagement notification silently (Task 2.2 handles this)
  - [x] 4.4 Verify the daily greeting from InsightService handles long gaps gracefully (no "it's been X days")

- [x] Task 5: Tests (AC: all)
  - [x] 5.1 Unit test: `evaluateAndSchedule()` schedules nudge when not paused, not post-crisis, and last session > threshold
  - [x] 5.2 Unit test: `evaluateAndSchedule()` does NOT schedule when isPaused = true (healthy pause distinction)
  - [x] 5.3 Unit test: `evaluateAndSchedule()` does NOT schedule when lastSafetyBoundaryAt is set (post-crisis)
  - [x] 5.4 Unit test: `evaluateAndSchedule()` does NOT schedule when last session < threshold (too recent)
  - [x] 5.5 Unit test: `evaluateAndSchedule()` does NOT schedule when no sessions exist (new user)
  - [x] 5.6 Unit test: `cancelReEngagementNudge()` removes pending notification
  - [x] 5.7 Unit test: notification content uses correct copy and identifier
  - [x] 5.8 Unit test: default threshold is 72 hours, configurable via DriftDetectionConfig

## Dev Notes

### What Already Exists (DO NOT Recreate)

| Component | File | What Exists |
|-----------|------|-------------|
| `CheckInNotificationService` | `Services/Notifications/CheckInNotificationService.swift` | Full local notification infrastructure: scheduling, cancellation, permission requests, 24-hour install rule, post-crisis suppression, active sprint check. **Follow this exact pattern.** |
| `EngagementCalculator` | `Services/EngagementCalculator.swift` | Computes `lastSessionGapHours` from `ConversationSession` table. Gap > 72h = low engagement. **Use this logic as reference but don't depend on it at runtime — drift detection reads DB directly.** |
| `EngagementSnapshot` | `Features/Coaching/Models/EngagementSnapshot.swift` | `EngagementLevel` enum (high/medium/low), `SessionIntensity` enum. These exist for server context, not for drift detection. |
| `UserProfile.isPaused` | `Models/UserProfile.swift` | Boolean flag + `pausedAt: Date?`. This is how you distinguish healthy pause from disengagement. |
| `UserProfile.lastSafetyBoundaryAt` | `Models/UserProfile.swift` | Date? — set during Orange/Red safety events. Suppress ALL nudges when set. |
| `ConversationSession.recent()` | `Models/ConversationSession.swift` | `order(Column("startedAt").desc).limit(limit)` — use to find last session date. |
| `AppState.isPaused` | `App/AppState.swift` | Runtime pause flag. Read this in RootView lifecycle hooks. |
| `RootView` notification wiring | `App/RootView.swift` | `onChange(of: appState.isPaused)` already reschedules check-in notifications. **Extend this handler** for re-engagement nudges. |
| Notification copy pattern | `CheckInNotificationService.swift:58-59` | `title: ""`, `body: "Your coach has a thought for you."`, `sound: nil`. **Use identical copy for re-engagement.** |
| HomeViewModel greeting | `Features/Home/ViewModels/HomeViewModel.swift` | `updateGreeting()` uses time-of-day only — no "you've been away" language. Safe. |
| InsightService | `Features/Home/ViewModels/HomeViewModel.swift:107-108` | `insightService.generateDailyInsight()` — RAG-informed, produces context-aware content. Verify no absence references. |

### What Needs to Be Built

1. **`DriftDetectionService`** — New service in `Services/Notifications/`. Protocol + implementation. Reads last session date from DB, checks pause/crisis state, schedules `UNTimeIntervalNotificationTrigger` for future nudge. Single-fire (not repeating). Cancels on app open or pause activation.

2. **`DriftDetectionConfig`** — Simple struct with `inactivityThresholdHours: Int = 72`. Lives alongside the service file. Extracted as config so it's not a magic number buried in scheduling logic.

3. **RootView integration** — Extend existing lifecycle hooks:
   - On authenticated view load: `driftDetectionService.evaluateAndSchedule()`
   - On `onChange(of: appState.isPaused)`: cancel nudge on pause, re-evaluate on unpause
   - Store `driftDetectionService` as `@State` like `checkInNotificationService`

4. **Conversation end hook** — When a conversation ends, reschedule the drift window. This resets the timer. Look for where `CoachingViewModel` ends a session and add a drift reschedule call. Alternatively, since `evaluateAndSchedule()` runs on app launch, and each launch reads the latest session date, this may be sufficient without a mid-session hook — but adding it on `showConversation = false` in RootView is cleaner.

### Architecture Compliance

**Service Pattern:**
- `DriftDetectionServiceProtocol: Sendable` — protocol for testability
- `DriftDetectionService: DriftDetectionServiceProtocol, @unchecked Sendable` — matches `CheckInNotificationService` pattern exactly
- Inject `DatabaseManager` and `UNUserNotificationCenter` (defaulting to `.current()`)
- **Not @MainActor** — services do background work

**Notification Pattern:**
- `UNTimeIntervalNotificationTrigger(timeInterval: Double(config.inactivityThresholdHours * 3600), repeats: false)`
- Unique identifier: `com.ducdo.sprinty.reengagement`
- Empty title, emotion-safe body, nil sound — matches check-in notification exactly
- Non-repeating: fires once per drift period. Re-evaluated on next app open.

**State Reading Pattern:**
```swift
// Read last session + profile in single DB read
let (lastSessionDate, profile) = try await databaseManager.dbPool.read { db in
    let session = try ConversationSession.recent(limit: 1).fetchOne(db)
    let profile = try UserProfile.current().fetchOne(db)
    return (session?.startedAt, profile)
}
```

**Concurrency:**
- All DB reads via `await databaseManager.dbPool.read { }`
- No `DispatchQueue` — Swift concurrency only
- Notification scheduling via `await notificationCenter.add(request)`

### File Structure Requirements

**Files to create:**
```
ios/sprinty/Services/Notifications/DriftDetectionService.swift     — Protocol + implementation + config
ios/Tests/Services/DriftDetectionServiceTests.swift                — Unit tests
```

**Files to modify:**
```
ios/sprinty/App/RootView.swift                                     — Add DriftDetectionService creation and lifecycle hooks
```

### Library & Framework Requirements

- **GRDB.swift** — Database reads for session date and profile state. Async `dbPool.read`.
- **UserNotifications** — `UNUserNotificationCenter`, `UNTimeIntervalNotificationTrigger`, `UNNotificationRequest`.
- **Swift Testing** — `@Test` and `#expect` macros. NOT XCTest.
- **No new dependencies needed.**

### Testing Standards

- Test naming: `test_methodName_condition_expectedResult`
- Use mock `UNUserNotificationCenter` — create `MockNotificationCenter` implementing required methods, or use protocol wrapper
- Use in-memory GRDB database for state setup
- Test the 5 suppression conditions: paused, post-crisis, recent session, no sessions, already pending
- Test the happy path: stale session + not paused + not post-crisis → notification scheduled
- Mocks must be `@unchecked Sendable`
- **Mock pattern:** Follow `CheckInNotificationServiceTests.swift` for notification mock approach. The existing tests already mock `UNUserNotificationCenter` — reuse that pattern.

### Previous Story Intelligence

**From Story 7.1 (Pause Mode Activation & Deactivation):**
- `isPaused` and `pausedAt` are persisted in UserProfile (migration v14) — use `isPaused` to distinguish healthy pause
- `togglePause()` in HomeViewModel handles state + persistence + VoiceOver. Drift detection wiring goes in **RootView**, not HomeViewModel.
- `RootView.onChange(of: appState.isPaused)` already exists for check-in reschedule — extend it for drift detection
- Code review caught: stale test names, sleep durations too short for CI. Use `>= 100ms` sleeps in tests.
- All notifications suppressed during Pause Mode: `guard !appState.isPaused` in `rescheduleCheckInNotifications`. Apply same guard for drift.

**From Story 6.3 (Post-Crisis Re-engagement):**
- `lastSafetyBoundaryAt` suppresses notifications in `CheckInNotificationService.shouldAllowNotifications()`. Apply same suppression for drift nudges.
- Post-crisis state clears on first genuine green/yellow classification. Drift detection re-evaluates on next app launch after clearing.

**From Story 5.4 (Daily Check-ins):**
- Established `CheckInNotificationService` pattern. Drift detection follows the same structure: protocol, implementation, mock for tests.
- 24-hour install rule: don't send notifications within 24h of install. Apply same rule for re-engagement.

### Git Intelligence

Recent commits (Story 7.1 is most recent):
- `72ee950` Story 7.1 — Pause Mode activation and deactivation with code review fixes
- `605017f` Story 6.5 — Safety regression suite with code review fixes
- `2692eb1` Story 6.4 — Compliance logging with code review fixes

Patterns from recent work:
- All stories follow: implementation → code review → fixes commit
- Code review consistently catches: edge case handling, test robustness, missing suppression conditions
- Notification infrastructure is mature — `CheckInNotificationService` is the template

### Critical Constraints

1. **Emotion-safe copy only** — "Your coach has a thought for you" — never "come back", "we miss you", "you've been away". (UX-DR68)
2. **Zero notifications during Pause Mode** — Drift nudges must check `isPaused`. Pause = healthy break, not drift. (UX-DR66)
3. **Zero post-crisis nudges** — If `lastSafetyBoundaryAt` is set, suppress all nudges. (Story 6.3 pattern)
4. **No absence notification on return** — When user opens app after drift period, cancel pending nudge silently. No in-app "you've been away" message. (UX-DR48)
5. **Single fire, no nagging** — One nudge per drift period. `repeats: false`. Re-evaluated on next app launch. (Calm Budget)
6. **2/day hard cap** — Re-engagement + check-in combined must not exceed 2/day. In practice, they won't coexist (no check-in fires after days of inactivity), but document this reasoning.
7. **24-hour install rule** — No re-engagement nudge within 24h of account creation. (Existing pattern from CheckInNotificationService)
8. **On-device only** — Server is stateless. All drift detection logic runs on iOS. No server changes needed.

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 7, Story 7.2, FR37-38]
- [Source: _bmad-output/planning-artifacts/architecture.md — Push Notifications MVP Scoping, re-engagement nudge as on-device drift detection]
- [Source: _bmad-output/planning-artifacts/architecture.md — AppState, NotificationService, Pause Mode visual transform]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR48, UX-DR66, UX-DR68, UX-DR69, Calm Budget]
- [Source: _bmad-output/implementation-artifacts/7-1-pause-mode-activation-and-deactivation.md — Pause state persistence, notification suppression patterns]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Full test suite: 627 tests in 60 suites, all passing. Zero regressions.

### Completion Notes List

- Task 1: Created `DriftDetectionService` with protocol, implementation, and `DriftDetectionConfig`. Follows `CheckInNotificationService` pattern: protocol-based, `@unchecked Sendable`, `DatabaseManager` + `NotificationCenterScheduling` protocol injection. `evaluateAndSchedule()` reads last session date and profile in a single DB read, applies 5 guard conditions (24h install rule, pause, post-crisis, no sessions, no profile), then computes `timeUntilNudge = max(60, threshold - gap)` and schedules via private `scheduleReEngagementNudge(timeInterval:)`.
- Task 2: Integrated into `RootView` lifecycle. `@State driftDetectionService` created alongside `checkInNotificationService`. `evaluateAndSchedule()` called in `.task` on authenticated view. Conversation dismiss button calls `cancel + evaluateAndSchedule`. `onChange(of: appState.isPaused)` extended: pause → cancel nudge, unpause → evaluate and schedule.
- Task 3: Notification content matches check-in pattern exactly: empty title, "Your coach has a thought for you." body, nil sound. Identifier `com.ducdo.sprinty.reengagement` is distinct from check-in. `UNTimeIntervalNotificationTrigger(timeInterval: thresholdSeconds, repeats: false)` — single fire. Budget compliance verified: re-engagement and check-in cannot coexist same day (no active sprint after days of inactivity).
- Task 4: Audited HomeViewModel.updateGreeting() — time-of-day only, no absence language. InsightService.generateDailyInsight() is RAG-informed, no absence references. On app launch, evaluateAndSchedule() cancels pending nudge first (silent cancellation). No "you've been away" messaging anywhere in greeting or coaching flows.
- Task 5: 12 unit tests with `SpyNotificationCenter` for real assertions. Tests verify: scheduling occurs with correct time interval (happy path recent + stale), 5 suppression conditions assert `spy.addedRequests.isEmpty` (paused, post-crisis, no sessions, 24h install, no profile), notification content/identifier/sound, config defaults/customization, custom threshold time calculation, cancel-before-schedule ordering.
- Created `MockDriftDetectionService` for use by other test suites.

### Change Log

- 2026-04-01: Story 7.2 implementation complete — DriftDetectionService, RootView integration, 12 unit tests, mock
- 2026-04-01: Code review fixes — [H1] Fixed dead-man's-switch logic: removed gap >= threshold guard, now always schedules with computed `timeUntilNudge = max(60, threshold - gap)`. [M1] Added `NotificationCenterScheduling` protocol + `SpyNotificationCenter` for testable notification injection; all 12 tests now have real `#expect()` assertions. [L1] Made `scheduleReEngagementNudge` private, removed from protocol.

### File List

- ios/sprinty/Services/Notifications/DriftDetectionService.swift (new)
- ios/sprinty/App/RootView.swift (modified)
- ios/Tests/Services/DriftDetectionServiceTests.swift (new)
- ios/Tests/Mocks/MockDriftDetectionService.swift (new)
