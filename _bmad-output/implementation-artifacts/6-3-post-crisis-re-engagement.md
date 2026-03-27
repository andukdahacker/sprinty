# Story 6.3: Post-Crisis Re-engagement

Status: done

## Story

As a user returning after a safety boundary event,
I want a gentle, warm re-engagement experience,
So that I feel safe coming back without being reminded of the crisis or treated differently.

## Acceptance Criteria

1. **Given** a user returns after an Orange/Red boundary event **When** they open the app **Then** a post-crisis re-engagement flow activates **And** the coach greets warmly without referencing the crisis explicitly **And** coaching resumes gradually — starting in Discovery Mode regardless of previous mode

2. **Given** the re-engagement flow **When** the first conversation turn occurs **Then** safety classification continues normally (no forced Yellow/Orange state) **And** the sticky minimum from the previous session has cleared

## Tasks / Subtasks

- [x] Task 1: Add `lastSafetyBoundaryAt` column to UserProfile (AC: #1, #2)
  - [x] 1.1 Add migration v12 to `Migrations.swift`: `ALTER TABLE UserProfile ADD COLUMN lastSafetyBoundaryAt TEXT`
  - [x] 1.2 Add `lastSafetyBoundaryAt: Date?` property to `UserProfile` model
  - [x] 1.3 Write migration test in `MigrationTests.swift`

- [x] Task 2: Persist safety boundary events from CoachingViewModel (AC: #1)
  - [x] 2.1 In `CoachingViewModel.sendMessage`, after `updateSessionSafetyLevel`, if processedLevel is `.orange` or `.red`, write `lastSafetyBoundaryAt = Date()` to UserProfile via DatabaseManager
  - [x] 2.2 Unit test: verify UserProfile.lastSafetyBoundaryAt is written on orange/red classification

- [x] Task 3: Detect returning-from-crisis state on session creation (AC: #1, #2)
  - [x] 3.1 In `CoachingViewModel.createNewSession()`, before creating the session, read UserProfile and check `lastSafetyBoundaryAt != nil`
  - [x] 3.2 If returning from crisis: force `mode: .discovery` on the new session (already the default, but be explicit)
  - [x] 3.3 If returning from crisis: set a new `isReturningFromCrisis: Bool` flag on CoachingViewModel (not persisted — session-scoped)
  - [x] 3.4 `safetyStateManager.resetSession()` already called in `createNewSession()` — confirms sticky minimum is cleared (AC: #2)
  - [x] 3.5 Clear re-engagement state: In `sendMessage()`, after `updateSessionSafetyLevel(processedLevel)` returns (line ~263), if `isReturningFromCrisis == true` AND `processedLevel == .green` AND `source == .genuine` (not `.failsafe`), then: clear `isReturningFromCrisis = false` and nil out `lastSafetyBoundaryAt` in UserProfile. Also clear on any `.genuine` classification ≤ `.yellow` to prevent the flag getting stuck if the first turn classifies Yellow
  - [x] 3.6 Unit test: createNewSession detects lastSafetyBoundaryAt and sets isReturningFromCrisis
  - [x] 3.7 Unit test: first genuine green classification clears isReturningFromCrisis and nils lastSafetyBoundaryAt
  - [x] 3.8 Unit test: genuine yellow classification also clears isReturningFromCrisis (prevents stuck state)
  - [x] 3.9 Unit test: failsafe classification does NOT clear isReturningFromCrisis (wait for genuine signal)
  - [x] 3.10 Unit test: new orange/red during re-engagement overrides — safety wins, isReturningFromCrisis stays true but new lastSafetyBoundaryAt is written

- [x] Task 4: Send `isReturningFromCrisis` flag to server via UserState (AC: #1)
  - [x] 4.1 Add `var isReturningFromCrisis: Bool?` to iOS `UserState` struct as a mutable property (all other fields are `let` from `init(from: EngagementSnapshot)` — make this one a `var` set after construction, since EngagementSnapshot doesn't know about crisis state)
  - [x] 4.2 Add `IsReturningFromCrisis *bool \`json:"isReturningFromCrisis,omitempty"\`` to Go `UserState` struct in `providers/provider.go`
  - [x] 4.3 In `CoachingViewModel.sendMessage()`, after `let userState = snapshot.map { UserState(from: $0) }` (line ~204), set `userState?.isReturningFromCrisis = self.isReturningFromCrisis ? true : nil`
  - [x] 4.4 Unit test: UserState encodes isReturningFromCrisis when true, omits when nil

- [x] Task 5: Server prompt injection for re-engagement (AC: #1)
  - [x] 5.1 Add `{{re_engagement_context}}` slot at the **top** of `context-injection.md`, before existing context slots (so re-engagement framing takes priority in the prompt)
  - [x] 5.2 In `builder.go Build()`, follow the existing pattern at lines 199-209 (where `userState.EngagementLevel` replaces `{{engagement_level}}`). Add conditional: if `userState != nil && userState.IsReturningFromCrisis != nil && *userState.IsReturningFromCrisis`, replace `{{re_engagement_context}}` with re-engagement text; otherwise replace with empty string
  - [x] 5.3 Re-engagement prompt text: instruct the coach to greet warmly and forward-looking, never reference the crisis or previous difficult moment, start in Discovery Mode with gentle open-ended questions, focus on what the user wants to talk about today
  - [x] 5.4 Unit test: builder injects re-engagement context when flag is true, omits when false/nil
  - [x] 5.5 **IMPORTANT:** `builder_test.go` hardcodes `context-injection.md` content in test fixtures. You MUST add `{{re_engagement_context}}` to those fixture strings or existing tests will break

- [x] Task 6: Warm re-engagement greeting in daily greeting logic (AC: #1)
  - [x] 6.1 In `CoachingViewModel.generateDailyGreeting()`, add an early check **before** the `withThrowingTaskGroup` call (line ~595): if `isReturningFromCrisis`, set `dailyGreeting` directly to a warm re-engagement greeting and return early. Do NOT put this check in `buildGreetingFromSummaries()` — that method is `nonisolated` and cannot access `@MainActor`-isolated properties
  - [x] 6.2 Unit test: greeting returns re-engagement text when isReturningFromCrisis is true

- [x] Task 7: Home screen quiet state for post-crisis return (AC: #1)
  - [x] 7.1 In `HomeViewModel`, on load check UserProfile.lastSafetyBoundaryAt; if non-nil, set avatar to `.resting` state and suppress sprint/gamification nudges
  - [x] 7.2 This is a lightweight check — no new views needed, just drive existing AvatarState and suppress existing nudge logic
  - [x] 7.3 Unit test: HomeViewModel sets resting avatar when lastSafetyBoundaryAt is present

- [x] Task 8: Suppress notifications during post-crisis period (AC: #1)
  - [x] 8.1 In notification scheduling logic (CheckInNotificationService and any drift-detection nudge code), check UserProfile.lastSafetyBoundaryAt; if non-nil, suppress ALL non-safety notifications — a generic "Your coach has a thought for you" nudge sent to a post-crisis user could cause harm
  - [x] 8.2 This mirrors Pause Mode notification suppression behavior — post-crisis users get zero nudges until they return and the flag clears
  - [x] 8.3 Unit test: notifications are suppressed when lastSafetyBoundaryAt is present

## Dev Notes

### Architecture Patterns & Constraints

- **Safety is tier-agnostic (FR58):** Re-engagement flow must work identically for free and paid users
- **Server is stateless:** All crisis state lives on iOS in UserProfile.lastSafetyBoundaryAt. Server only receives `isReturningFromCrisis` flag per-request
- **Safety always wins (UX-DR94):** If a new safety event occurs during re-engagement, it overrides re-engagement behavior immediately
- **No explicit crisis reference:** The PRD is emphatic — the coach must NEVER reference the crisis, what happened, or treat the user differently in a way that feels clinical. It should feel like a warm friend greeting you
- **Session-scoped clearing:** `isReturningFromCrisis` is a transient ViewModel flag. `lastSafetyBoundaryAt` persists in DB until first genuine green/yellow classification in re-engagement session
- **Notification suppression during post-crisis:** Suppress ALL non-safety notifications while `lastSafetyBoundaryAt` is set, matching Pause Mode behavior. Sending a drift-detection nudge to a post-crisis user could cause harm
- **`SafetyClassificationSource` matters:** Only `.genuine` classifications should clear re-engagement state. `.failsafe` classifications (from on-device fallback failures) should NOT clear the flag — wait for a real signal
- **Fail-silent DB writes:** Writing `lastSafetyBoundaryAt` in the classification pipeline (Task 2) must not block or disrupt safety processing. Use fire-and-forget pattern if DB write fails

### Key Existing Code to Reuse (DO NOT Recreate)

| Component | Location | What It Does |
|-----------|----------|-------------|
| `SafetyStateManager.resetSession()` | `Services/Safety/SafetyStateManager.swift:58-61` | Already clears sticky minimum on new session — AC #2 is partially satisfied |
| `SafetyLevel` Comparable | `Models/ConversationSession.swift:14-34` | Use `processedLevel >= .orange` to detect boundary events |
| `CoachingViewModel.createNewSession()` | `Features/Coaching/ViewModels/CoachingViewModel.swift:520-538` | Entry point for detecting crisis return — add profile read here |
| `UserProfile.current()` | `Models/UserProfile.swift:77-79` | Query helper to load current profile |
| `AvatarState.resting` | `Core/State/AvatarState.swift` | Already exists — use for quiet home state |
| `HomeViewModel` | `Features/Home/ViewModels/HomeViewModel.swift` | Already loads UserProfile on init — extend with lastSafetyBoundaryAt check |
| `EngagementCalculator` / `UserState` | `Features/Coaching/Models/ChatRequest.swift:16-32` | Add isReturningFromCrisis field here |
| `SafetyClassificationSource` | `Services/Safety/SafetyClassificationSource.swift` | `.genuine` vs `.failsafe` — only genuine clears re-engagement |
| `MockSafetyStateManager` | `Tests/Mocks/MockSafetyStateManager.swift` | Needed for CoachingViewModelCrisisTests |
| `MockSafetyHandler` | `Tests/Mocks/MockSafetyHandler.swift` | Needed for CoachingViewModelCrisisTests |

### What Does NOT Exist Yet (Must Create)

- `UserProfile.lastSafetyBoundaryAt` — new DB column + model property
- `UserState.isReturningFromCrisis` — new field on iOS and Go structs
- `{{re_engagement_context}}` — new template slot in context-injection.md
- Re-engagement prompt text in builder.go
- `CoachingViewModel.isReturningFromCrisis` — new transient Bool property

### Critical Gotchas from Previous Stories

- **SafetyStateManagerProtocol is `@MainActor`**, not `Sendable` (from Story 6.2 fix)
- **`buildGreetingFromSummaries()` is `nonisolated`** — cannot access `@MainActor`-isolated properties. Put re-engagement check in `generateDailyGreeting()` instead
- **`UserState` has all `let` fields** with `init(from: EngagementSnapshot)` — make `isReturningFromCrisis` a `var` set after construction
- **Never use `DispatchQueue.main.async`** — use `@MainActor` (project convention)
- **Never use Combine** — use `@Observable` + async/await (project convention)
- **Swift Testing framework** (`@Test`, `#expect`, `@Suite`) — NOT XCTest
- **Project file:** Regenerate via xcodegen after adding new source files — includes `project.pbxproj`
- **`builder_test.go` hardcodes `context-injection.md` content** — must update fixtures when adding `{{re_engagement_context}}` slot
- **Check latest migration number at implementation time** — if another story lands before 6.3, the v12 slot could be taken

### Database Migration Pattern

Follow existing convention in `Migrations.swift`:
```swift
migrator.registerMigration("v12_safetyBoundary") { db in
    try db.alter(table: "UserProfile") { t in
        t.add(column: "lastSafetyBoundaryAt", .text)  // nullable Date
    }
}
```

### Server-Side Changes

**Files to modify:**
- `server/providers/provider.go` — Add `IsReturningFromCrisis *bool` to UserState
- `server/prompts/sections/context-injection.md` — Add `{{re_engagement_context}}` slot
- `server/prompts/builder.go` — Inject re-engagement text when flag is true
- `server/prompts/builder_test.go` — Test re-engagement injection

**Re-engagement prompt content (for builder.go injection):**
```
## Re-engagement Context
The user is returning after a difficult moment. This is important:
- Greet them warmly and with genuine care — "I'm glad you're here"
- Do NOT reference what happened, the crisis, or any previous difficult conversation
- Do NOT ask "how are you feeling about what happened" or anything that resurfaces the event
- Start with gentle, open-ended Discovery Mode questions about what's on their mind today
- Let the user lead — they'll share if and when they're ready
- Focus on the present and future, not the past
- Keep the energy warm, unhurried, and low-pressure
```

### Testing Standards

- **Swift Testing framework:** `@Suite`, `@Test`, `#expect` macros
- **In-memory GRDB** for database tests
- **Protocol-based mocks** with recorded call tracking (see `MockSafetyHandler`, `MockSafetyStateManager`)
- **Test naming:** `test_methodName_condition_expectedResult`
- **Go tests:** `TestHandlerName_Condition_Expected` pattern

### File Structure for New Code

```
ios/sprinty/
├── Models/
│   └── UserProfile.swift               # ADD lastSafetyBoundaryAt property
├── Services/Database/
│   └── Migrations.swift                # ADD v12_safetyBoundary migration
├── Services/Notifications/
│   └── CheckInNotificationService.swift # ADD lastSafetyBoundaryAt suppression check
├── Features/Coaching/
│   ├── ViewModels/
│   │   └── CoachingViewModel.swift      # ADD isReturningFromCrisis logic
│   └── Models/
│       └── ChatRequest.swift            # ADD isReturningFromCrisis to UserState
├── sprinty.xcodeproj/
│   └── project.pbxproj                 # REGENERATE via xcodegen

server/
├── providers/
│   └── provider.go                # ADD IsReturningFromCrisis to UserState
├── prompts/
│   ├── sections/
│   │   └── context-injection.md   # ADD {{re_engagement_context}} slot at TOP
│   ├── builder.go                 # ADD re-engagement injection logic
│   └── builder_test.go            # ADD re-engagement test + UPDATE existing fixtures

ios/Tests/
├── Features/
│   └── CoachingViewModelCrisisTests.swift  # NEW: re-engagement tests (uses MockSafetyStateManager, MockSafetyHandler)
├── Database/
│   └── MigrationTests.swift       # ADD v12 migration test
└── Models/
    └── UserProfileTests.swift     # ADD lastSafetyBoundaryAt tests
```

### UX Design Constraints

- **Post-crisis home screen:** Avatar in calm resting state, no nudges, no sprint reminders
- **Zero "you've been away" messaging** — no guilt, no time references, no date-gap separators that highlight absence
- **Comfortable silence:** No idle timeout, no auto-prompts, no "are you still there?" during re-engagement
- **Trust gradient:** One misstep resets weeks of trust-building — re-engagement must be flawless
- **Vulnerability-to-action pacing:** Even after re-engagement clears, maintain 2-3 turns of warm acknowledgment before any goal/sprint suggestions resurface

### Cross-Story Dependencies

- **Story 6.4 (Compliance Logging):** Re-engagement activation and clearing of `lastSafetyBoundaryAt` are boundary response events that 6.4's logging should capture. Ensure write points are identifiable for future instrumentation
- **Story 6.5 (Safety Regression Suite):** Should include test prompts for re-engagement scenarios (isReturningFromCrisis=true). Note for future suite expansion
- **Story 7.1 (Pause Mode):** If user is in Pause Mode when crisis occurs, re-engagement should override Pause on return (safety always wins, UX-DR94)
- **Story 7.2 (Drift Detection):** Drift-detection nudges must check `lastSafetyBoundaryAt` — sending a generic re-engagement nudge to a post-crisis user could cause harm. Task 8 handles notification suppression for this story; 7.2 must also check

### Project Structure Notes

No new service classes or views needed — extend existing CoachingViewModel, HomeViewModel, and CheckInNotificationService. All changes align with monorepo structure.

## Dev Agent Record

### Implementation Plan
- Task 1: DB migration v12 + model property for `lastSafetyBoundaryAt`
- Task 2: Fire-and-forget DB write on orange/red classification in sendMessage
- Task 3: Crisis detection in createNewSession + clearing on genuine green/yellow
- Task 4: `isReturningFromCrisis` var field on UserState (iOS + Go)
- Task 5: `{{re_engagement_context}}` template slot + builder injection
- Task 6: Early return in generateDailyGreeting with warm re-engagement text
- Task 7: HomeViewModel sets `.resting` avatar when lastSafetyBoundaryAt present
- Task 8: CheckInNotificationService suppresses notifications when post-crisis

### Completion Notes
- All 8 tasks implemented and tested
- 575 iOS tests pass (56 suites), 0 regressions
- All Go tests pass (prompts, providers, integration)
- New tests: 3 migration tests, 8 crisis re-engagement tests, 3 HomeViewModel crisis tests, 1 notification suppression test, 3 Go builder tests
- Re-engagement state clears on genuine green OR yellow classification (prevents stuck state)
- Failsafe classifications correctly do NOT clear re-engagement (waits for real signal)
- Safety always wins: new orange/red during re-engagement writes new timestamp, keeps flag true
- `builder_test.go` fixtures updated with `{{re_engagement_context}}` — no existing test breakage

### Code Review Fixes (2026-03-27)
- **H1 Fixed:** `HomeViewModel.homeStage` and `insightDisplayText` now check `isPostCrisis` to suppress sprint/gamification nudges — previously the flag was set but never consumed
- **M1 Fixed:** `CheckInNotificationService` combined `isInstallOlderThan24Hours()` and `isPostCrisis()` into single `shouldAllowNotifications()` DB read
- Added test: `test_load_postCrisis_suppressesSprintNudges` verifying homeStage returns `.welcome` and insightDisplayText returns nil when post-crisis with active sprint

### Debug Log
- No issues encountered during implementation

### Change Log
- Story 6.3 implementation complete (Date: 2026-03-27)

## File List

### iOS — Modified
- `ios/sprinty/Models/UserProfile.swift` — Added `lastSafetyBoundaryAt: Date?` property
- `ios/sprinty/Services/Database/Migrations.swift` — Added v12_safetyBoundary migration
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — Added `isReturningFromCrisis` flag, crisis detection in createNewSession, boundary event persistence, re-engagement clearing logic, warm greeting
- `ios/sprinty/Features/Coaching/Models/ChatRequest.swift` — Added `isReturningFromCrisis: Bool?` to UserState
- `ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift` — Added `isPostCrisis` flag, resting avatar on post-crisis load
- `ios/sprinty/Services/Notifications/CheckInNotificationService.swift` — Added post-crisis notification suppression
- `ios/sprinty.xcodeproj/project.pbxproj` — Regenerated via xcodegen

### iOS — New
- `ios/Tests/Features/CoachingViewModelCrisisTests.swift` — 8 crisis re-engagement unit tests

### iOS — Test Files Modified
- `ios/Tests/Database/MigrationTests.swift` — Added 3 v12 migration tests
- `ios/Tests/Features/Home/HomeViewModelTests.swift` — Added 2 post-crisis avatar tests
- `ios/Tests/Services/CheckInNotificationServiceTests.swift` — Added 1 notification suppression test

### Server — Modified
- `server/providers/provider.go` — Added `IsReturningFromCrisis *bool` to UserState
- `server/prompts/sections/context-injection.md` — Added `{{re_engagement_context}}` slot at top
- `server/prompts/builder.go` — Added re-engagement context injection logic
- `server/prompts/builder_test.go` — Updated fixture + added 3 re-engagement tests
