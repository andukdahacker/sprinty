# Story 7.3: Autonomy Throttle & Engagement Tracking

Status: done

## Story

As a user growing more self-reliant,
I want my coach to gradually step back — fewer nudges, fewer prompts, more trust in my own judgment,
so that the app helps me outgrow it rather than creating dependency.

## Acceptance Criteria

### AC 1: Engagement Source Tracking from Day One (FR78)

```
Given every user interaction from day one
When a coaching session is created
Then the engagement source is tracked: organic (user opened app), notification-triggered (tapped check-in or re-engagement notification)
And this data is persisted on ConversationSession for Autonomy Throttle analysis
```

### AC 2: Autonomy Throttle Reduces AI-Initiated Interactions (FR77)

```
Given a user demonstrates increasing self-reliance over time
When the Autonomy Throttle analyzes engagement patterns
Then AI-initiated coaching interactions gradually reduce:
  - Check-in notification frequency decreases (daily → every-other-day → weekly)
  - Drift detection threshold increases (72h → 120h → 168h)
  - Server prompt receives autonomy level so coach language adapts
And the reduction is gradual and natural — not an abrupt cutoff
```

### AC 3: User-Initiated Engagement Never Limited

```
Given the throttle is active at any level
When the user initiates interactions themselves (organic sessions)
Then the coach responds fully — throttle only affects AI-initiated interactions
And user-initiated engagement is never limited, reduced, or penalized by the throttle
```

### AC 4: Autonomy Metrics in Server Context

```
Given autonomy data is computed on-device
When a chat request is sent to the server
Then userState includes voluntarySessionRate and autonomyLevel
And the autonomy.md prompt section adapts coaching behavior based on autonomy level
```

### AC 5: Graceful Degradation for New Users

```
Given a new user with insufficient engagement history (< 14 days or < 5 sessions)
When the Autonomy Throttle evaluates
Then the throttle level is .none (no reduction)
And all AI-initiated interactions operate at full frequency
And engagement source tracking still records every session
```

## Tasks / Subtasks

- [x] Task 1: EngagementSource model and database migration (AC: 1, 5)
  - [x] 1.1 Create `EngagementSource` enum in `Models/EngagementSource.swift`: `.organic`, `.checkInNotification`, `.reEngagementNudge` — conforms to `String, Codable, DatabaseValueConvertible, Sendable`
  - [x] 1.2 Add `engagementSource` column (TEXT, default "organic") to `ConversationSession` via new append-only migration `v15_engagementSource` in `Services/Database/Migrations.swift` (current latest is `v14_pauseMode`)
  - [x] 1.3 Add `engagementSource: EngagementSource` property to `ConversationSession` model with default `.organic`
  - [x] 1.4 Verify existing session creation paths default to `.organic` (backward compatible)

- [x] Task 2: Notification tap attribution (AC: 1)
  - [x] 2.1 Add `pendingEngagementSource: EngagementSource?` to `AppState` — set when notification tap is detected, consumed when session is created
  - [x] 2.2 In `SprintyApp.swift`, extend the existing `CheckInNotificationDelegate.userNotificationCenter(_:didReceive:)` method (lines 58-67) — it currently only handles check-in identifier. Add a case for `DriftDetectionService.reEngagementIdentifier` → set `.reEngagementNudge`, and change the existing check-in case to also set `.checkInNotification` (in addition to existing `pendingCheckIn = true`)
  - [x] 2.3 In `CoachingViewModel.createNewSession()`: read `appState.pendingEngagementSource ?? .organic`, pass to `ConversationSession` creation, then clear `pendingEngagementSource` to nil

- [x] Task 3: AutonomyCalculator service (AC: 2, 3, 5)
  - [x] 3.1 Create `AutonomyLevel` enum: `.none`, `.light`, `.moderate`, `.high` — in `Models/AutonomyLevel.swift`, conforms to `String, Codable, Sendable`
  - [x] 3.2 Create `AutonomyCalculatorProtocol` and `AutonomyCalculator` in `Services/AutonomyCalculator.swift`
  - [x] 3.3 Implement `computeAutonomySnapshot(db:) -> AutonomySnapshot` — queries ConversationSession for last 30 days, computes:
    - `voluntarySessionRate`: Float = organic sessions / total sessions (0.0–1.0)
    - `totalSessions`: Int
    - `organicSessions`: Int
    - `notificationTriggeredSessions`: Int
    - `autonomyLevel`: AutonomyLevel (derived from voluntarySessionRate + session count threshold)
  - [x] 3.4 Autonomy level thresholds: `.none` if < 5 sessions or < 14 days of data; `.light` if voluntaryRate >= 0.6; `.moderate` if voluntaryRate >= 0.75; `.high` if voluntaryRate >= 0.9 AND sessions >= 20
  - [x] 3.5 Create `AutonomySnapshot` struct: `voluntarySessionRate`, `totalSessions`, `organicSessions`, `notificationTriggeredSessions`, `autonomyLevel` — conforms to `Codable, Sendable`

- [x] Task 4: Apply throttle to notification services (AC: 2)
  - [x] 4.1 **CheckInNotificationService throttle:** The service uses `UNCalendarNotificationTrigger(dateMatching:, repeats: true)` with DateComponents. It has no runtime adjustment API — cadence is passed as a parameter to `scheduleCheckInNotification()`. To throttle: in `RootView.rescheduleCheckInNotifications()`, compute autonomy level first, then override the cadence parameter before calling schedule: `.none`/`.light` = use profile's chosen cadence as-is, `.moderate` = force cadence to "weekly" if user chose daily, `.high` = force cadence to "weekly" regardless. If user already chose weekly, no further reduction.
  - [x] 4.2 **DriftDetectionService throttle:** `DriftDetectionConfig` is an immutable `let` set at init. To apply autonomy-adjusted thresholds: pass autonomy level to `evaluateAndSchedule()` as a parameter (or recreate the service with adjusted config). Recommended approach: add `autonomyLevel: AutonomyLevel = .none` parameter to `evaluateAndSchedule()`, compute adjusted threshold internally: `.none` = base config, `.light` = 96h, `.moderate` = 120h, `.high` = 168h. This avoids mutating frozen config.
  - [x] 4.3 In `RootView` authenticated `.task`: compute autonomy snapshot FIRST, then pass level to `driftDetectionService.evaluateAndSchedule(autonomyLevel:)` and use level to override check-in cadence in `rescheduleCheckInNotifications()`
  - [x] 4.4 Store computed `AutonomySnapshot` as `@State` in RootView for use in chat requests (Task 5) — pass to CoachingViewModel via closure-based snapshot provider

- [x] Task 5: API contract and server prompt adaptation (AC: 4)
  - [x] 5.1 Add `voluntarySessionRate: Float?` and `autonomyLevel: String?` to `UserState` in `ChatRequest.swift` (iOS)
  - [x] 5.2 Update `CoachingViewModel.sendMessage()` (around lines 206-211) to include autonomy data in `UserState` — follow the existing `isReturningFromCrisis` injection pattern: after `UserState(from: snapshot)`, set `userState.voluntarySessionRate` and `userState.autonomyLevel` from cached `AutonomySnapshot`
  - [x] 5.3 Update Go server `UserState` struct in `server/providers/provider.go` (lines 27-35, NOT handlers/chat.go) to accept `VoluntarySessionRate *float64` and `AutonomyLevel *string` fields with `json:"voluntarySessionRate,omitempty"` and `json:"autonomyLevel,omitempty"` tags
  - [x] 5.4 Update `server/prompts/sections/context-injection.md` to include `{{voluntary_session_rate}}` and `{{autonomy_level}}` template variables
  - [x] 5.5 Update `server/prompts/builder.go` to inject autonomy values from UserState into prompt template
  - [x] 5.6 Update `server/prompts/sections/autonomy.md` to incorporate autonomy level — at `.moderate`/`.high`: coach uses language that reinforces self-reliance, reduces unsolicited suggestions, trusts user judgment more
  - [x] 5.7 Update `docs/api-contract.md` with new UserState fields

- [x] Task 6: Tests (AC: all)
  - [x] 6.1 Unit test: `EngagementSource` enum encoding/decoding and database round-trip
  - [x] 6.2 Unit test: ConversationSession creation with engagement source persists correctly
  - [x] 6.3 Unit test: AutonomyCalculator returns `.none` for new users (< 5 sessions)
  - [x] 6.4 Unit test: AutonomyCalculator returns `.none` for users with < 14 days of data
  - [x] 6.5 Unit test: AutonomyCalculator computes correct voluntarySessionRate from mixed sessions
  - [x] 6.6 Unit test: AutonomyCalculator returns `.light` when voluntaryRate >= 0.6 with sufficient data
  - [x] 6.7 Unit test: AutonomyCalculator returns `.moderate` when voluntaryRate >= 0.75
  - [x] 6.8 Unit test: AutonomyCalculator returns `.high` when voluntaryRate >= 0.9 AND >= 20 sessions
  - [x] 6.9 Unit test: `autonomyAdjustedCadence()` returns weekly for daily users at `.moderate`/`.high`, unchanged for `.none`/`.light`
  - [x] 6.10 Unit test: `DriftDetectionService.evaluateAndSchedule(autonomyLevel:)` uses correct threshold per level (base/96h/120h/168h)
  - [x] 6.11 Unit test: AutonomySnapshot includes correct counts of organic vs notification-triggered sessions
  - [x] 6.12 Go test: UserState with autonomy fields parsed correctly in chat handler
  - [x] 6.13 Go test: Prompt builder injects autonomy template variables

## Dev Notes

### What Already Exists (DO NOT Recreate)

| Component | File | What Exists |
|-----------|------|-------------|
| `EngagementCalculator` | `Services/EngagementCalculator.swift` | Computes `EngagementSnapshot` from last 10 sessions: engagement level (high/medium/low), session intensity, message length, gap hours. **Do not modify** — AutonomyCalculator is a separate service that reads engagement *source* data, not engagement *level* data. |
| `EngagementSnapshot` | `Features/Coaching/Models/EngagementSnapshot.swift` | Existing model: `engagementLevel`, `recentMoods`, `avgMessageLength`, `sessionCount`, `lastSessionGapHours`, `recentSessionIntensity`. Sent in `UserState` to server. **Extend UserState, don't replace EngagementSnapshot.** |
| `CheckInNotificationService` | `Services/Notifications/CheckInNotificationService.swift` | Full local notification scheduling with identifier `com.ducdo.sprinty.checkin`. Uses `UNCalendarNotificationTrigger(dateMatching:, repeats: true)` with DateComponents for hour + optional weekday. Cadence passed as parameter to `scheduleCheckInNotification()`. **No runtime adjustment API — throttle by overriding cadence parameter in RootView before calling schedule.** |
| `DriftDetectionService` | `Services/Notifications/DriftDetectionService.swift` | Re-engagement nudges with identifier `com.ducdo.sprinty.reengagement`. `DriftDetectionConfig` is `let` (immutable after init), default `inactivityThresholdHours: Int = 72`. **Add autonomyLevel parameter to `evaluateAndSchedule()` to compute adjusted threshold internally.** |
| `CheckInNotificationDelegate` | `App/SprintyApp.swift` (lines 50-75) | Existing `UNUserNotificationCenterDelegate` implementation. `didReceive` currently handles only check-in identifier → sets `appState.pendingCheckIn = true`. **Extend to also handle re-engagement identifier and set `appState.pendingEngagementSource`.** |
| `ConversationSession` | `Models/ConversationSession.swift` | Has `type: SessionType` (coaching/checkIn), `startedAt`, `endedAt`, `mode`, `safetyLevel`. **Add `engagementSource` column via migration.** |
| `UserProfile` | `Models/UserProfile.swift` | `isPaused`, `pausedAt`, `lastSafetyBoundaryAt`, `checkInCadence`. No autonomy fields needed here — autonomy is computed from session history, not stored on profile. |
| `AppState` | `App/AppState.swift` | Global app state: `isPaused`, `pendingCheckIn`, auth status, etc. **Add `pendingEngagementSource` for notification tap attribution.** |
| `ChatRequest.UserState` | `Features/Coaching/Models/ChatRequest.swift` | Mirrors `EngagementSnapshot` for server. **Add `voluntarySessionRate` and `autonomyLevel` fields.** |
| `CoachingViewModel` | `Features/Coaching/ViewModels/CoachingViewModel.swift` | Creates sessions, builds `UserState` from `EngagementCalculator`. **Modify session creation to accept engagement source. Modify UserState building to include autonomy data.** |
| `RootView` | `App/RootView.swift` | DI container. Creates `CheckInNotificationService`, `DriftDetectionService`. `onChange(of: appState.isPaused)` handles notification lifecycle. **Add AutonomyCalculator, compute autonomy on launch, pass level to notification services.** |
| `autonomy.md` | `server/prompts/sections/autonomy.md` | Currently only covers pause suggestions (intensity detection, breather suggestion). **Expand to include autonomy-level-aware coaching behavior.** |
| `context-injection.md` | `server/prompts/sections/context-injection.md` | Template variables for engagement data. **Add `{{voluntary_session_rate}}` and `{{autonomy_level}}`.** |
| `builder.go` | `server/prompts/builder.go` | Loads prompt sections, injects template variables. **Add autonomy variable injection from UserState.** |
| Go `UserState` | `server/providers/provider.go` (lines 27-35) | Struct with `EngagementLevel`, `RecentMoods`, `AvgMessageLength`, `SessionCount`, `LastSessionGapHours`, `RecentSessionIntensity`, `IsReturningFromCrisis`. **Add `VoluntarySessionRate *float64` and `AutonomyLevel *string` fields.** |

### What Needs to Be Built

1. **`EngagementSource` enum** — New file `Models/EngagementSource.swift`. Three cases: `.organic`, `.checkInNotification`, `.reEngagementNudge`. Must conform to `String, Codable, DatabaseValueConvertible, Sendable`. Raw values used as database TEXT column values.

2. **Database migration `v15_engagementSource`** — Register in `Services/Database/Migrations.swift` after `v14_pauseMode`. Append-only migration adding `engagementSource TEXT DEFAULT 'organic'` to `conversationSession` table. All existing sessions get `organic` default (correct — before tracking existed, all sessions were user-initiated).

3. **`AutonomyCalculator` service** — New file `Services/AutonomyCalculator.swift`. Protocol + implementation. Queries last 30 days of ConversationSession, groups by engagementSource, computes voluntary rate and autonomy level. Injected in RootView like other services.

4. **`AutonomySnapshot` model** — New file `Features/Coaching/Models/AutonomySnapshot.swift`. Holds computed autonomy metrics. Used by RootView (for notification throttling) and CoachingViewModel (for UserState).

5. **`AutonomyLevel` enum** — New file `Models/AutonomyLevel.swift`. Four levels: none/light/moderate/high. Determines throttle intensity.

6. **Notification tap attribution** — Extend existing `CheckInNotificationDelegate` in `SprintyApp.swift` (lines 58-67). The `didReceive` method already handles check-in taps → add re-engagement case and set `appState.pendingEngagementSource` for both. Consumed during session creation in `CoachingViewModel.createNewSession()`.

7. **Server-side changes** — Add 2 fields to `UserState` in `server/providers/provider.go`, add 2 template variables to `context-injection.md`, expand `autonomy.md` prompt section (coach reinforces self-reliance at moderate/high, reduces unsolicited suggestions, trusts user judgment — but never refuses to help when asked), update `builder.go` injection following the existing `strings.ReplaceAll` pattern with "unknown" fallback when nil.

### Architecture Compliance

**Service Pattern:**
- `AutonomyCalculatorProtocol: Sendable` — protocol for testability
- `AutonomyCalculator: AutonomyCalculatorProtocol, @unchecked Sendable` — matches existing service pattern
- Inject `DatabaseManager` — reads ConversationSession table
- **Not @MainActor** — does background DB reads

**Model Pattern:**
- All new models: `Sendable`, `Codable`
- `EngagementSource`: additionally `DatabaseValueConvertible` for GRDB column mapping
- Database migration: `v15_engagementSource` in `Services/Database/Migrations.swift`, append-only after `v14_pauseMode`

**Notification Attribution Pattern:**
```swift
// In SprintyApp.swift — CheckInNotificationDelegate.userNotificationCenter(_:didReceive:)
// Extend the existing method (lines 58-67) which currently only handles check-in:
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    let identifier = response.notification.request.identifier
    if identifier == CheckInNotificationService.checkInIdentifier {
        await MainActor.run {
            appState.pendingCheckIn = true
            appState.pendingEngagementSource = .checkInNotification
        }
    } else if identifier == DriftDetectionService.reEngagementIdentifier {
        await MainActor.run {
            appState.pendingEngagementSource = .reEngagementNudge
        }
    }
}

// In CoachingViewModel.createNewSession():
let source = appState.pendingEngagementSource ?? .organic
appState.pendingEngagementSource = nil
// Pass source to ConversationSession creation
```

**Autonomy Computation Pattern:**
```swift
func computeAutonomySnapshot(db: Database) throws -> AutonomySnapshot {
    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    let sessions = try ConversationSession
        .filter(Column("startedAt") >= thirtyDaysAgo)
        .fetchAll(db)

    let total = sessions.count
    let organic = sessions.filter { $0.engagementSource == .organic }.count
    let rate = total > 0 ? Float(organic) / Float(total) : 0.0

    let level: AutonomyLevel = {
        guard total >= 5 else { return .none }
        // Check user has >= 14 days of history (earliest session is at least 14 days old)
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        guard let earliest = sessions.min(by: { $0.startedAt < $1.startedAt }),
              earliest.startedAt <= fourteenDaysAgo else { return .none }
        if rate >= 0.9 && total >= 20 { return .high }
        if rate >= 0.75 { return .moderate }
        if rate >= 0.6 { return .light }
        return .none
    }()

    return AutonomySnapshot(
        voluntarySessionRate: rate,
        totalSessions: total,
        organicSessions: organic,
        notificationTriggeredSessions: total - organic,
        autonomyLevel: level
    )
}
```

**Throttle Application Pattern:**
```swift
// In RootView .task on authenticated view:
// 1. Compute autonomy FIRST
let snapshot = try await databaseManager.dbPool.read { db in
    try autonomyCalculator.computeAutonomySnapshot(db: db)
}
autonomySnapshot = snapshot  // Cache as @State for CoachingViewModel access

// 2. Apply throttle to drift detection — pass level to evaluateAndSchedule
driftDetectionService.evaluateAndSchedule(autonomyLevel: snapshot.autonomyLevel)

// 3. Apply throttle to check-in scheduling — override cadence before scheduling
// CheckInNotificationService.scheduleCheckInNotification() takes cadence param
// At .moderate/.high: override user's chosen cadence to "weekly" if they chose daily
let effectiveCadence = autonomyAdjustedCadence(
    userCadence: profile.checkInCadence,
    autonomyLevel: snapshot.autonomyLevel
)
checkInNotificationService.scheduleCheckInNotification(cadence: effectiveCadence, ...)
```

**Concurrency:**
- All DB reads via `await databaseManager.dbPool.read { }`
- No `DispatchQueue` — Swift concurrency only
- AutonomyCalculator is computed on app launch and cached for session duration

### File Structure Requirements

**Files to create:**
```
ios/sprinty/Models/EngagementSource.swift                          — Enum with GRDB conformance
ios/sprinty/Models/AutonomyLevel.swift                             — Enum for throttle levels
ios/sprinty/Features/Coaching/Models/AutonomySnapshot.swift        — Computed autonomy metrics
ios/sprinty/Services/AutonomyCalculator.swift                      — Protocol + implementation
ios/Tests/Services/AutonomyCalculatorTests.swift                   — Unit tests
ios/Tests/Models/EngagementSourceTests.swift                       — Enum + DB round-trip tests
ios/Tests/Mocks/MockAutonomyCalculator.swift                       — Mock for other test suites
```

**Files to modify:**
```
ios/sprinty/Models/ConversationSession.swift                       — Add engagementSource property
ios/sprinty/App/AppState.swift                                     — Add pendingEngagementSource
ios/sprinty/App/SprintyApp.swift                                   — Extend CheckInNotificationDelegate.didReceive for engagement source attribution
ios/sprinty/App/RootView.swift                                     — Add AutonomyCalculator, compute + apply throttle, cache AutonomySnapshot
ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift   — Pass engagement source on session creation, add autonomy to UserState (follow isReturningFromCrisis pattern at lines 209-211)
ios/sprinty/Features/Coaching/Models/ChatRequest.swift             — Add voluntarySessionRate and autonomyLevel to UserState
ios/sprinty/Services/Notifications/DriftDetectionService.swift     — Add autonomyLevel parameter to evaluateAndSchedule()
ios/sprinty/Services/Database/Migrations.swift                     — Add v15_engagementSource migration (after v14_pauseMode)
server/providers/provider.go                                       — Add VoluntarySessionRate and AutonomyLevel to UserState struct
server/prompts/sections/context-injection.md                       — Add autonomy template variables
server/prompts/sections/autonomy.md                                — Expand with autonomy-level coaching behavior
server/prompts/builder.go                                          — Inject autonomy variables (strings.ReplaceAll pattern, "unknown" fallback)
docs/api-contract.md                                               — Document new UserState fields
ios/project.yml                                                    — Add new files to targets
```

### Library & Framework Requirements

- **GRDB.swift** — `DatabaseValueConvertible` for EngagementSource enum, async `dbPool.read` for autonomy computation
- **UserNotifications** — `UNUserNotificationCenterDelegate` already wired in `SprintyApp.swift` via `CheckInNotificationDelegate`. Extend existing delegate — do not create a new one.
- **Swift Testing** — `@Test` and `#expect` macros for all new tests
- **No new dependencies needed — iOS or server**

### Testing Standards

- Test naming: `test_methodName_condition_expectedResult`
- Use in-memory GRDB database via `makeTestDB()` for all DB tests
- `MockAutonomyCalculator` with stub injection for `AutonomySnapshot`
- Mocks must be `@unchecked Sendable`
- New test files must be added to `ios/project.yml` under test target sources
- Go tests: `TestChatHandlerAutonomyFields` to verify parsing, `TestPromptBuilderAutonomyInjection` for template vars

### Previous Story Intelligence

**From Story 7.2 (Drift Detection & Re-engagement):**
- `DriftDetectionService` uses `DriftDetectionConfig` with `inactivityThresholdHours` as an immutable `let` property. Do NOT try to mutate config after init — instead add `autonomyLevel` parameter to `evaluateAndSchedule()` and compute adjusted threshold internally.
- `NotificationCenterScheduling` protocol + `SpyNotificationCenter` exist for testable notification injection — reuse for throttle adjustment tests.
- `evaluateAndSchedule()` reads last session + profile in single DB read. AutonomyCalculator should use a similar pattern but query 30-day session window.
- Code review caught: dead-man's-switch logic bug (always schedule with computed time), stale test names. Be precise with scheduling math.
- Notification identifiers: `com.ducdo.sprinty.checkin` and `com.ducdo.sprinty.reengagement` — use these exact strings for notification tap attribution matching.

**From Story 7.1 (Pause Mode):**
- `isPaused` and `pausedAt` on UserProfile. Pause sessions should still track engagement source (user can open app during pause = organic).
- `onChange(of: appState.isPaused)` in RootView — autonomy computation should also re-run when pause state changes, since it affects notification scheduling.

**From Story 5.4 (Daily Check-ins):**
- `CheckInNotificationService` has cadence logic: `checkInCadence` on UserProfile (daily, weekdays, custom). The autonomy throttle adjusts the *effective* frequency, not the user's chosen cadence. If user chose daily but throttle is `.high`, schedule weekly. If user chose weekly, throttle doesn't reduce further.
- 24-hour install rule applies — new users (< 24h) get no notifications regardless of autonomy level.

**From Story 4.1 (Avatar State System) — EngagementCalculator pattern:**
- EngagementCalculator was created in Story 4.1. It reads sessions and computes metrics. AutonomyCalculator follows the same structural pattern but with different query (engagement *source* grouping vs engagement *level* computation).

### Git Intelligence

Recent commits:
- `8ffa8fd` Story 7.2 — Drift detection and re-engagement with code review fixes
- `72ee950` Story 7.1 — Pause Mode activation and deactivation with code review fixes
- `605017f` Story 6.5 — Safety regression suite with code review fixes

Patterns:
- All stories follow: implementation → code review → fixes commit
- Code review consistently catches: edge case handling, test robustness, missing suppression conditions
- Notification infrastructure is mature — follow established patterns exactly
- New enum models (like EngagementSource) follow the pattern of `SafetyLevel`, `CoachingMode`, `SessionType` — all `String, Codable, Sendable` with `DatabaseValueConvertible`

### Critical Constraints

1. **Server is stateless** — All autonomy computation runs on iOS. Server only receives computed metrics in `userState` and adapts prompts. No server-side persistence.
2. **Throttle only affects AI-initiated** — User-initiated (organic) sessions are never limited. Check-in notifications and drift nudges are the only AI-initiated interactions subject to throttle.
3. **Gradual, not abrupt** — Four levels (none → light → moderate → high) with clear thresholds. Users should not notice a sudden change.
4. **Backward compatible** — Existing sessions default to `organic`. Existing notification behavior unchanged at `.none` throttle level.
5. **Engagement source tracking is separate from engagement level** — `EngagementCalculator` computes *how engaged* the user is (level). `AutonomyCalculator` computes *how they engage* (source). Both feed into `UserState` but serve different purposes.
6. **Don't over-throttle** — If user chose daily check-ins and throttle is `.light`, keep daily. Only `.moderate` and `.high` actually reduce frequency. `.light` only increases drift threshold slightly.
7. **14-day minimum data** — No throttle computation until user has at least 14 days of history AND 5+ sessions. Prevents false positives from small sample sizes.
8. **FR77 prompt behavior is benchmark-validated** — The autonomy.md prompt changes are tested via coaching conversation test suite, not automated unit tests. But the iOS-side computation and notification adjustment need full unit test coverage.
9. **Calm Budget compliance** — Even with throttle adjustments, never exceed 1 notification/day (UX spec) or 2/day (architecture spec). In practice throttle *reduces* from baseline, so this is naturally satisfied.
10. **Migration must be append-only** — New migration version. Never modify existing migrations.

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 7, Story 7.3, FR77-78]
- [Source: _bmad-output/planning-artifacts/prd.md — FR77 (Autonomy Throttle), FR78 (engagement source tracking), KPI metrics]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR77-78 architectural mapping, autonomy.md prompt section, context-injection template]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Calm Budget, voluntary session rate >50%, anti-engagement design]
- [Source: _bmad-output/planning-artifacts/prd.md — Innovation validation: 10%+ of 6mo+ users show declining AI-initiated interactions]
- [Source: _bmad-output/implementation-artifacts/7-2-drift-detection-and-re-engagement.md — DriftDetectionService patterns, notification identifiers, SpyNotificationCenter]
- [Source: _bmad-output/implementation-artifacts/7-1-pause-mode-activation-and-deactivation.md — Pause state, notification suppression]
- [Source: _bmad-output/project-context.md — Full project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- DriftDetectionService custom threshold test initially failed because `autonomyAdjustedThreshold` for `.none` hardcoded 72h instead of using the base config value. Fixed by using `baseThresholdSeconds` for `.none` and `max(base, fixed)` for other levels.

### Completion Notes List

- Task 1: Created `EngagementSource` enum with GRDB conformance, added `v15_engagementSource` migration, added `engagementSource` property to `ConversationSession` with `.organic` default
- Task 2: Added `pendingEngagementSource` to `AppState`, extended `CheckInNotificationDelegate` to handle both check-in and re-engagement notification taps, updated `CoachingViewModel.createNewSession()` to consume engagement source
- Task 3: Created `AutonomyLevel` enum, `AutonomySnapshot` model, `AutonomyCalculatorProtocol` + `AutonomyCalculator` service with 30-day session window query and 4-tier level computation
- Task 4: Added `evaluateAndSchedule(autonomyLevel:)` to `DriftDetectionService` with `autonomyAdjustedThreshold` static helper, added `autonomyAdjustedCadence` to `RootView`, integrated autonomy computation into app launch and pause state changes, cached snapshot as `@State`
- Task 5: Added `voluntarySessionRate` and `autonomyLevel` to iOS `UserState` and Go `UserState`, updated `context-injection.md` with template variables, expanded `autonomy.md` with autonomy-level coaching adaptation, updated `builder.go` injection with nil fallbacks, updated `api-contract.md`
- Task 6: 23 iOS tests (EngagementSource encoding/DB round-trip, AutonomyCalculator all threshold levels, cadence adjustment, drift threshold adjustment, snapshot counts), 3 Go tests (autonomy fields parsing, prompt builder injection, nil fallback). All 650 iOS tests + all Go tests pass.

### Change Log

- 2026-04-01: Story 7.3 implementation complete — autonomy throttle and engagement tracking
- 2026-04-01: Code review fixes — removed dead branch in autonomyAdjustedCadence, removed unused databaseManager from AutonomyCalculator, added project.pbxproj to File List

### File List

**New files:**
- ios/sprinty/Models/EngagementSource.swift
- ios/sprinty/Models/AutonomyLevel.swift
- ios/sprinty/Features/Coaching/Models/AutonomySnapshot.swift
- ios/sprinty/Services/AutonomyCalculator.swift
- ios/Tests/Models/EngagementSourceTests.swift
- ios/Tests/Services/AutonomyCalculatorTests.swift
- ios/Tests/Mocks/MockAutonomyCalculator.swift

**Modified files:**
- ios/sprinty/Models/ConversationSession.swift
- ios/sprinty/Services/Database/Migrations.swift
- ios/sprinty/App/AppState.swift
- ios/sprinty/App/SprintyApp.swift
- ios/sprinty/App/RootView.swift
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift
- ios/sprinty/Features/Coaching/Models/ChatRequest.swift
- ios/sprinty/Services/Notifications/DriftDetectionService.swift
- ios/Tests/Mocks/MockDriftDetectionService.swift
- server/providers/provider.go
- server/prompts/sections/context-injection.md
- server/prompts/sections/autonomy.md
- server/prompts/builder.go
- server/tests/handlers_test.go
- docs/api-contract.md
- ios/sprinty.xcodeproj/project.pbxproj
