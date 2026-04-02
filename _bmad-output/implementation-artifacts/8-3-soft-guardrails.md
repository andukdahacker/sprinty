# Story 8.3: Soft Guardrails

Status: done

## Story

As a user,
I want the app to naturally wind down long coaching sessions without showing me usage limits,
so that I never feel metered or restricted — just gently coached to let insights settle.

## Acceptance Criteria

1. **Daily session soft limit detection (FR56):** Given a user reaches the daily session soft limit, when the server detects the threshold via per-device session count, then the server returns a coaching-style wind-down response (never an error) and the coach says something like: "We've covered a lot today. Let's let these insights settle." (FR57). No usage counter, limit indicator, or "sessions remaining" is ever shown to the user.

2. **SSE guardrail signal:** Given the guardrail signal, when the SSE `event: done` includes the `guardrail` flag (`"guardrail": true`), then the iOS app receives the signal for UI treatment and handles it gracefully (no error state, no blocking).

3. **Gentle redirect on continuation:** Given the soft guardrail is reached, when the user tries to continue, then the coach gently redirects without being repetitive.

4. **Safety exception:** Safety conversations are never guardrailed — safety is always accessible regardless of session count.

## Tasks / Subtasks

- [x] Task 1: Guardrail config and session tracker (AC: #1)
  - [x]1.1 Add env vars to `server/config/config.go`: `FREE_TIER_DAILY_SESSION_LIMIT` (default: 5), `PREMIUM_TIER_DAILY_SESSION_LIMIT` (default: 0 = unlimited)
  - [x]1.2 Create `server/middleware/guardrails.go` with in-memory `SessionTracker` — `sync.RWMutex`-protected `map[string][]time.Time` keyed by deviceID. Uses filter-on-access to only count timestamps from current UTC day (no background goroutine or midnight timer needed — stale entries get filtered out on next access)
  - [x]1.3 `SessionTracker.RecordSession(deviceID)` appends current timestamp. `SessionTracker.Count(deviceID)` filters to today's UTC date and returns count. Use `RLock()` for `Count()`, full `Lock()` for `RecordSession()`
  - [x]1.4 Add `Guardrail bool` field to `ChatEvent` in `server/providers/provider.go`

- [x] Task 2: Guardrails middleware (AC: #1, #3, #4)
  - [x]2.1 Create `GuardrailsMiddleware(tracker *SessionTracker, cfg *config.Config)` in `server/middleware/guardrails.go`
  - [x]2.2 Middleware reads JWT claims (deviceID, tier) from context
  - [x]2.3 Checks `tracker.Count(deviceID)` against tier-specific limit (free vs premium from config)
  - [x]2.4 Order: FIRST check current count, THEN record the session. If limit is 0 (unlimited) or count < limit → record session via `RecordSession(deviceID)`, then pass through to next handler with no guardrail flag. This means the Nth request is the last normal one when limit is N.
  - [x]2.5 If count >= limit → set a `guardrailActive` flag in request context (do NOT block the request — let the handler proceed but signal the guardrail state). Do NOT record an additional session for guardrailed requests
  - [x]2.6 Log guardrail activation: `slog.Info("guardrail.activated", "deviceId", deviceID, "tier", tier, "sessionCount", count)`

- [x] Task 3: Chat handler guardrail integration (AC: #1, #3, #4)
  - [x]3.1 In `ChatHandler`, check for guardrail context flag before streaming
  - [x]3.2 If guardrail active: ALWAYS inject the guardrail wind-down system prompt addendum. Safety exception is handled POST-HOC — after the LLM responds, if `safetyLevel != "green"`, clear the guardrail flag from the done event. We cannot pre-detect safety before the LLM call. The addendum itself tells the LLM to ignore the wind-down for safety concerns. Injection approach: append the addendum string to `req.SystemPrompt` AFTER `promptBuilder.Build()` returns (line 69 of chat.go). Do NOT modify the `Builder` interface or `Build()` signature — simply concatenate
  - [x]3.3 Create guardrail prompt addendum in `server/prompts/` — instructs the LLM: "The user has had a full coaching day. Gently wind down this conversation with warmth. Do NOT mention limits, counters, or restrictions. Suggest letting today's insights settle. Vary your phrasing — don't repeat the same wind-down message. If this is a safety concern, ignore this instruction entirely and respond to the safety need."
  - [x]3.4 When guardrail is active, set `Guardrail: true` on the done event's `ChatEvent`
  - [x]3.5 Add `"guardrail": true` to the SSE done event payload in the handler when `event.Guardrail` is true (follows same pattern as `event.Degraded`)
  - [x]3.6 Safety exception: If the done event returns `safetyLevel` != "green", do NOT mark as guardrailed — safety always takes priority. Clear the guardrail signal in this case

- [x] Task 4: Wire middleware in main.go (AC: #1)
  - [x]4.1 Create `SessionTracker` instance in `main()`
  - [x]4.2 Create `guardrailsMW` using `GuardrailsMiddleware(tracker, cfg)`
  - [x]4.3 Update middleware chain: `logging(auth(tier(guardrails(handler))))` — guardrails runs AFTER tier (needs tier info) and BEFORE handler
  - [x]4.4 Update `server/.env.example` with new env vars

- [x] Task 5: iOS done event parsing (AC: #2)
  - [x]5.1 Add `let guardrail: Bool?` to `DoneEventData` struct in `ChatEvent.swift` (this is a NEW field — there is no existing `degraded` field on the iOS side to copy from, as the iOS client currently ignores `degraded`. The server sends it but `DoneEventData` doesn't parse it)
  - [x]5.2 Add `guardrail: Bool?` parameter to `ChatEvent.done` enum case — this extends the associated value list from 9 to 10 parameters. Every `case .done(...)` pattern match in `CoachingViewModel.swift` must be updated to include the new parameter
  - [x]5.3 Update `from(sseEvent:)` to pass `parsed.guardrail` through to the `.done` case
  - [x]5.4 Update `CoachingViewModel` done event handling: when `guardrail == true`, set a view model property `isGuardrailActive = true`
  - [x]5.5 When `isGuardrailActive`, create a new `GuardrailBreatherView` component in `Features/Coaching/Views/` — a gentle prompt card shown below the assistant message offering "Want to take a breather?" with a button that calls `appState.isPaused = true` (reusing the existing Pause Mode infrastructure from Epic 7 — see `HomeViewModel.togglePause()` for the full activation pattern including avatar state, DB persistence, and accessibility announcements). No existing pause UI exists in CoachingView, so this is a new view. No error states, no blocking, no "limit reached" language. User can dismiss and keep chatting (next response will also be guardrailed). Register any new files in `ios/project.yml` under the correct target
  - [x]5.6 Reset `isGuardrailActive` on next day's first message (compare stored date vs current date)

- [x] Task 6: API contract update (AC: #2)
  - [x]6.1 Add `guardrail` field to the Done Event documentation in `docs/api-contract.md`: `"guardrail" (boolean, optional): Present and true when the daily session soft limit has been reached. The response contains a coaching wind-down rather than an error. Omitted when not guardrailed.`

- [x] Task 7: Tests (AC: #1, #2, #3, #4)
  - [x]7.1 Unit tests for `SessionTracker`: concurrent access, daily reset, count accuracy
  - [x]7.2 Unit tests for guardrails middleware: free tier limit hit, premium tier unlimited, safety bypass, below limit pass-through, missing claims fallback
  - [x]7.3 Integration test: full chat request that triggers guardrail → verify done event contains `"guardrail": true`
  - [x]7.4 Integration test: safety conversation when guardrail active → verify guardrail NOT set in done event
  - [x]7.5 iOS tests: `DoneEventData` decoding with guardrail field (present and absent). Note: 6 existing tests in `CoachingViewModelTests.swift` construct `.done` events with 9 parameters — ALL must be updated to include the 10th `guardrail` parameter (typically `nil` for non-guardrail tests)
  - [x]7.6 iOS tests: `CoachingViewModel` guardrail state management — test `isGuardrailActive` set on guardrail done event, test reset on new day. Add new test files to `ios/project.yml` under the test target
  - [x]7.7 Test that summarize/sprint_retro mode requests pass through guardrails middleware without triggering guardrail-related behavior in their handlers
  - [x]7.8 Update `docs/fixtures/sse-done-event.txt` if needed for cross-platform test consistency
  - [x]7.9 All existing Go tests must pass (35+), all iOS tests must pass (669+)

## Dev Notes

### Architecture: Server is Stateless — Except for Session Counting

The server has no database. For guardrails, use an **in-memory session counter** — a `sync.RWMutex`-protected `map[string][]time.Time` keyed by deviceID. This is explicitly an MVP approach:

- Resets on server restart (acceptable — user gets a fresh count, not a disaster)
- No persistence needed — Railway zero-downtime deploys mean brief reset windows
- Single-instance deployment for MVP — no distributed counting needed
- Daily reset via filter-on-access: `Count()` filters timestamps to current UTC day. No background goroutine or midnight timer needed — stale entries get lazily cleaned up

### Middleware Chain Order (CRITICAL)

Current (`main.go` line 73):
```go
mux.Handle("POST /v1/chat", authMW(tierMW(http.HandlerFunc(handlers.ChatHandler(promptBuilder)))))
```

Target — insert `guardrailsMW` between tier and handler:
```go
mux.Handle("POST /v1/chat", authMW(tierMW(guardrailsMW(http.HandlerFunc(handlers.ChatHandler(promptBuilder))))))
```

Guardrails runs after auth (needs deviceID from JWT claims) and after tier (needs tier for limit lookup). Only applies to `/v1/chat` — no impact on health/auth/prompt routes.

### Guardrail Strategy: Prompt Injection, Not Request Blocking

Do NOT block or intercept the request. Instead:
1. Middleware checks session count, sets context flag if limit reached
2. ChatHandler reads flag, appends guardrail addendum to `req.SystemPrompt` AFTER `promptBuilder.Build()` returns
3. The LLM naturally winds down using coaching language
4. Handler checks done event: if `safetyLevel != "green"`, clears guardrail flag (safety exception)
5. Done event includes `"guardrail": true` for iOS UI treatment (unless cleared by safety)

Key implications:
- The LLM generates varied wind-down phrasing (not canned responses)
- Safety: the addendum tells LLM to ignore wind-down for safety. Post-hoc, if safety detected, `guardrail` flag is cleared from done event. This is the ONLY viable approach since safety classification happens inside the LLM
- `ChatHandler` signature does NOT change — it reads guardrail state from context via `GuardrailActiveFromContext(ctx)`
- The guardrail addendum is only used by the main chat streaming path. Summarize and sprint_retro handlers never check the guardrail flag

### Request Body: Middleware Does NOT Read It

The guardrails middleware does NOT read the request body (avoiding the one-time-reader problem in Go). It only checks session count and sets a context flag. Mode filtering (skip guardrail for summarize/sprint_retro) happens naturally because those modes route to separate handler functions (`handleSummarize`, `handleSprintRetro`) that don't check `GuardrailActiveFromContext`. The middleware will still count sessions for summarize requests, but this is acceptable — summarize calls are triggered per-session and don't inflate the count beyond what real coaching sessions produce.

### Guardrail Prompt Addendum

Create a small addendum file or string constant. Keep it short to minimize token overhead:

```
[WIND-DOWN ACTIVE] The user has had a rich coaching day. Gently bring this conversation to a natural close. Suggest letting today's insights settle. Do NOT mention limits, session counts, or restrictions. Vary your language each time. If the user raises a safety concern, respond fully — safety always comes first.
```

This gets appended after the regular system prompt ONLY when guardrail is active.

### Session Counting: Middleware Counts All, Handler Filters Naturally

The middleware counts ALL `POST /v1/chat` requests regardless of mode. It does NOT read the request body (avoiding Go's one-time-reader problem). Mode filtering happens naturally at the handler level:

- `handleSummarize()` and `handleSprintRetro()` are separate handler functions (chat.go lines 52-62) that return early before checking `GuardrailActiveFromContext`. They never apply the guardrail addendum.
- Only the main streaming path in `ChatHandler` checks the guardrail context flag and appends the wind-down addendum.

Summarize calls (1 per session end) do inflate the session count slightly, but this is acceptable — at 5 coaching messages + 1 summarize = 6 total, the free tier limit of 5 still triggers after the 5th coaching interaction.

### iOS UI Treatment

Per UX design spec, the guardrail UI should feel like coach-suggested pause:

| Scenario | UX Decision | Content/Copy | Emotional Goal |
|----------|------------|--------------|----------------|
| Coach-suggested pause | Coach suggests rest after intensive session | "We covered a lot today. Want to take a breather?" + Pause Mode option | Cared for — the coach knows when to stop |

Implementation:
- When `guardrail == true` in done event, show a gentle prompt card after the assistant message
- Card offers "Take a breather" button that activates Pause Mode (existing feature from Epic 7)
- No blocking, no error, no "you've reached your limit" messaging
- User can dismiss the card and send another message (which will also be guardrailed)

### 7-Step Chain for New `guardrail` Field

Per project-context.md, adding a new field to coaching responses requires updating 7 places:

1. ~~Anthropic tool schema~~ — Not needed (guardrail is set by middleware, not by LLM)
2. ~~toolResult struct~~ — Not needed
3. ~~parseFinalResult()~~ — Not needed
4. `ChatEvent` struct in `server/providers/provider.go` — Add `Guardrail bool`
5. SSE done event data in `server/handlers/chat.go` — Add `"guardrail": true` when set
6. `DoneEventData` + `ChatEvent` enum in `ios/sprinty/Features/Coaching/Models/ChatEvent.swift` — Add `guardrail: Bool?`
7. API contract `docs/api-contract.md` — Document the field

Steps 1-3 are skipped because `guardrail` is set by server middleware, not extracted from LLM tool output.

### Tier Value Convention

Use `"premium"` (NOT `"paid"`) everywhere. Established in Story 8.1.

### Existing Code to Reuse

- **`server/middleware/auth.go`** — `ClaimsFromContext(ctx)` returns `*auth.Claims` with `.DeviceID` and `.Tier`
- **`server/middleware/tier.go`** — Follow same middleware pattern (higher-order function returning `func(http.Handler) http.Handler`)
- **`server/providers/provider.go`** — `ChatEvent` struct, add `Guardrail bool` field following `Degraded bool` pattern
- **`server/handlers/chat.go`** — Done event payload construction (lines 116-132), follow `Degraded` flag pattern for `Guardrail`
- **`server/config/config.go`** — Follow existing env var loading pattern with sensible defaults
- **`ios/sprinty/Features/Coaching/Models/ChatEvent.swift`** — `DoneEventData` struct for parsing
- **`ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift`** — Done event handling section
- **`ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift`** — `togglePause()` method (lines 176-210) is the reference for Pause Mode activation: sets `appState.isPaused`, derives avatar state, posts VoiceOver announcement, persists to DB, appends "Rest well." message
- **`ios/sprinty/App/AppState.swift`** — `isPaused: Bool` property drives global pause state
- **`ios/Tests/Features/CoachingViewModelTests.swift`** — 6 existing tests construct `.done` events that must be updated with new `guardrail` parameter

### Context Key Pattern

Reuse the existing `contextKey` type already defined in `middleware/auth.go` (`type contextKey string`). Since `guardrails.go` is in the same `middleware` package, it has direct access — do NOT redefine the type:

```go
const guardrailKey contextKey = "guardrailActive"

func GuardrailActiveFromContext(ctx context.Context) bool {
    active, _ := ctx.Value(guardrailKey).(bool)
    return active
}
```

### Config Defaults

| Env Var | Default | Description |
|---------|---------|-------------|
| `FREE_TIER_DAILY_SESSION_LIMIT` | `5` | Max coaching sessions per day for free tier |
| `PREMIUM_TIER_DAILY_SESSION_LIMIT` | `0` | 0 = unlimited for premium tier |

Cost rationale: At 5 sessions/day with Haiku 4.5, free tier stays well under $0.05/user/month ceiling. Premium users pay for unrestricted access.

### Project Structure Notes

**New Files:**
- `server/middleware/guardrails.go` — SessionTracker + GuardrailsMiddleware
- `server/middleware/guardrails_test.go` — Unit tests for tracker and middleware
- `ios/sprinty/Features/Coaching/Views/GuardrailBreatherView.swift` — Pause suggestion card UI (register in `project.yml`)

**Modified Files:**
- `server/providers/provider.go` — Add `Guardrail bool` to ChatEvent
- `server/config/config.go` — Add guardrail limit config fields
- `server/handlers/chat.go` — Check guardrail context flag, append prompt addendum, set guardrail in done event
- `server/main.go` — Create SessionTracker, wire guardrails middleware
- `server/.env.example` — Add new env vars
- `server/prompts/` — Add guardrail wind-down addendum (either new file or constant in guardrails.go)
- `ios/sprinty/Features/Coaching/Models/ChatEvent.swift` — Add guardrail field to DoneEventData and ChatEvent enum
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — Handle guardrail signal, show pause suggestion
- `docs/api-contract.md` — Document guardrail field in done event

**No changes to:**
- Auth flow, subscription service, tier routing, prompt sections, database schema
- Safety classification, compliance logging (guardrail is orthogonal to safety)

### Previous Story Intelligence (Story 8.2)

**Key learnings from 8.2:**
- Middleware chain ordering is critical — document and test the order
- Context-based data flow works well (provider from context pattern)
- `ChatEvent` struct extension is straightforward — follow `Degraded` pattern
- Provider selection via context key is established pattern — guardrail flag follows same approach
- All 35+ Go tests and 669+ iOS tests must continue passing
- Code review caught: provider logging was missing (added `Name()`) — ensure guardrail activation is logged
- OpenAI provider errors needed same handling as Anthropic — guardrail applies to all providers equally

**Code review issues to avoid from 8.2:**
- HIGH: Ensure guardrail middleware doesn't break summarize/sprint_retro modes
- MEDIUM: Thread safety on session tracker — use `sync.RWMutex`, test concurrent access
- LOW: Guardrail prompt addendum should be token-efficient — keep it under 100 tokens

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 8, Story 8.3 lines 1694-1716]
- [Source: _bmad-output/planning-artifacts/architecture.md — Soft Guardrails, Middleware Composition, Monetization Tier Architecture]
- [Source: _bmad-output/planning-artifacts/prd.md — FR56, FR57, FR65, Quality Gradient Monetization]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Coach-Suggested Pause UX pattern]
- [Source: server/middleware/tier.go — Middleware pattern, ProviderRegistry, context key pattern]
- [Source: server/middleware/auth.go — ClaimsFromContext, contextKey type]
- [Source: server/handlers/chat.go — Done event payload construction, guardrail flag integration point]
- [Source: server/providers/provider.go — ChatEvent struct, Degraded field pattern]
- [Source: server/config/config.go — Env var loading pattern]
- [Source: ios/sprinty/Features/Coaching/Models/ChatEvent.swift — DoneEventData, ChatEvent enum]
- [Source: docs/api-contract.md — SSE done event schema]
- [Source: _bmad-output/project-context.md — 7-step chain for new response fields, anti-patterns]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented in-memory `SessionTracker` with `sync.RWMutex` and filter-on-access daily reset
- Created `GuardrailsMiddleware` — checks per-device session count, sets context flag when limit reached, never blocks
- Added guardrail prompt addendum injection in `ChatHandler` — appended after `promptBuilder.Build()` returns
- Safety exception: guardrail flag cleared from done event when `safetyLevel != "green"`
- iOS `DoneEventData` extended with `guardrail: Bool?` — 10th parameter on `.done` enum case
- Created `GuardrailBreatherView` — gentle "Take a breather" card using existing Pause Mode infrastructure
- Daily reset: `isGuardrailActive` resets on next day's first message via `Calendar.current.isDateInToday()`
- All 674 iOS tests pass (5 new guardrail tests). All Go tests pass (10 middleware unit + 3 integration tests)
- Updated all existing `.done` pattern matches across 8 test files (61 occurrences) and 1 source file

### Change Log

- Story 8.3 implementation completed (Date: 2026-04-02)
- Code review fixes applied (Date: 2026-04-02): Updated `docs/fixtures/sse-done-event.txt` with guardrailed done event variant and added missing `memoryReferenced` field to baseline fixture

### File List

**New Files:**
- `server/middleware/guardrails.go` — SessionTracker + GuardrailsMiddleware + context helpers
- `server/middleware/guardrails_test.go` — 10 unit tests for tracker and middleware
- `server/prompts/guardrail.go` — GuardrailAddendum constant
- `ios/sprinty/Features/Coaching/Views/GuardrailBreatherView.swift` — Pause suggestion card UI
- `ios/Tests/Features/GuardrailTests.swift` — DoneEventData decoding + ViewModel state tests

**Modified Files:**
- `server/config/config.go` — Added `FreeTierDailySessionLimit`, `PremiumTierDailySessionLimit` fields and env var loading
- `server/providers/provider.go` — Added `Guardrail bool` to `ChatEvent` struct
- `server/handlers/chat.go` — Guardrail context check, prompt addendum injection, guardrail flag in done event with safety exception
- `server/main.go` — Created `SessionTracker`, wired `guardrailsMW` in middleware chain
- `server/.env.example` — Added `FREE_TIER_DAILY_SESSION_LIMIT` and `PREMIUM_TIER_DAILY_SESSION_LIMIT`
- `server/tests/handlers_test.go` — Added config import, guardrails middleware to `setupMuxWithBuilder`, 3 integration tests
- `ios/sprinty/Features/Coaching/Models/ChatEvent.swift` — Added `guardrail: Bool?` to `DoneEventData` and `.done` enum case
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — Added `isGuardrailActive` state, guardrail handling in done event, daily reset
- `ios/sprinty/Features/Sprint/ViewModels/CheckInViewModel.swift` — Updated `.done` pattern match (9→10 params)
- `ios/Tests/Features/CoachingViewModelTests.swift` — Updated 31 `.done` constructors with `guardrail: nil`
- `ios/Tests/Features/CoachingViewModelCrisisTests.swift` — Updated 8 `.done` constructors
- `ios/Tests/Features/CoachingViewModelSafetyTests.swift` — Updated 9 `.done` constructors
- `ios/Tests/Features/CoachingViewModelSprintTests.swift` — Updated 1 `.done` constructor
- `ios/Tests/Features/ComplianceLoggingIntegrationTests.swift` — Updated 5 `.done` constructors
- `ios/Tests/Features/Sprint/CheckInViewModelTests.swift` — Updated 3 `.done` constructors
- `ios/Tests/Features/Sprint/SprintDetailViewModelTests.swift` — Updated 4 `.done` constructors
- `ios/Tests/Models/ChatEventCodableTests.swift` — Updated 8 `.done` pattern matches (9→10 params)
- `ios/Tests/Services/SSEParserTests.swift` — Updated 1 `.done` pattern match (9→10 params)
- `docs/api-contract.md` — Documented `guardrail` field in done event
- `docs/fixtures/sse-done-event.txt` — Added guardrailed done event variant with `guardrail: true`, added missing `memoryReferenced` to baseline
