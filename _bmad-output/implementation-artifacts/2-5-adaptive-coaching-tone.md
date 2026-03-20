# Story 2.5: Adaptive Coaching Tone

Status: done

## Story

As a user in different emotional and engagement states,
I want my coach to adapt its tone and intensity,
So that the coaching meets me where I am rather than using a one-size-fits-all approach.

## Acceptance Criteria

1. **Given** a user's engagement patterns and emotional state, **When** the system detects changes in user state, **Then** the coaching tone adjusts accordingly (more gentle when struggling, more direct when energized) **And** intensity scales based on engagement patterns: low engagement = shorter responses (~100-150 words), max 1 suggestion, prefer `welcoming`/`warm` mood; high engagement = fuller responses (~200-400 words), multiple suggestions appropriate, `focused` mood available.

2. **Given** the system prompt is assembled for a conversation, **When** user state data is available, **Then** the context-injection section includes the current user state data (engagement level, emotional markers, recent session intensity) **And** tone adaptation is driven by the context-injection section content.

3. **Given** the transition rhythm rules (UX-DR78), **When** transitioning between emotional states, **Then** Vulnerability -> Action includes 2-3 beats of acknowledgment before goals **And** Celebration -> Challenge waits for a full session boundary **And** Compassion -> Resilience waits for user to signal readiness.

## Tasks / Subtasks

- [x] Task 1: Define and compute engagement metrics on iOS (AC: #1, #2)
  - [x]1.1 Create `EngagementSnapshot` struct in `ios/sprinty/Features/Coaching/Models/` with fields: `engagementLevel` (high/medium/low), `recentMoods` ([String]), `avgMessageLength` (short/medium/long), `sessionCount` (Int), `lastSessionGapHours` (Int?), `recentSessionIntensity` (light/moderate/deep)
  - [x]1.2 Create `EngagementCalculator` in `ios/sprinty/Services/` that queries recent `ConversationSession` and `Message` records via GRDB to compute the snapshot
  - [x]1.3 Engagement level heuristic: message frequency + message length + session recency. High = active in last 24h with moderate+ messages. Low = gap > 72h or very short messages. Medium = everything else
  - [x]1.4 Recent moods: collect last 3-5 mood values from stored `moodHistory` on sessions
  - [x]1.5 Session intensity: based on message count and session duration. Light = <5 messages or <5min. Deep = >15 messages or >20min. Moderate = between

- [x] Task 2: Store mood history on ConversationSession (AC: #1, #2)
  - [x]2.1 Add `moodHistory: String?` column to `ConversationSession` — JSON-encoded `[String]` array of raw mood strings in turn order, e.g. `["warm", "focused", "gentle"]`. Simple string array (not timestamped objects) — turn order provides implicit sequencing
  - [x]2.2 Add GRDB migration `v4` in `ios/sprinty/Services/Database/Migrations.swift` — existing migrations use `v1`, `v2`, `v3` naming convention
  - [x]2.3 In `CoachingViewModel`, append each received mood to a local `[String]` array during streaming, persist to session on conversation end (same pattern as `modeSegments` → `modeHistory`)

- [x] Task 3: Extend ChatRequest with user state (AC: #2)
  - [x]3.1 Add `UserState` struct to `server/providers/provider.go`:
    ```go
    type UserState struct {
        EngagementLevel      string   `json:"engagementLevel"`      // high|medium|low
        RecentMoods          []string `json:"recentMoods"`          // last 3-5 moods
        AvgMessageLength     string   `json:"avgMessageLength"`     // short|medium|long
        SessionCount         int      `json:"sessionCount"`
        LastSessionGapHours  *int     `json:"lastSessionGapHours,omitempty"`
        RecentSessionIntensity string `json:"recentSessionIntensity"` // light|moderate|deep
    }
    ```
  - [x]3.2 Add `UserState *UserState \`json:"userState,omitempty"\`` to `ChatRequest` struct
  - [x]3.3 On iOS, add matching `UserState` Codable struct in `ios/sprinty/Features/Coaching/Models/ChatRequest.swift` alongside ChatRequest. Populate from `EngagementSnapshot` in CoachingViewModel before each `ChatService.streamChat()` call
  - [x]3.4 Update `docs/api-contract.md` with new `userState` field in request schema

- [x] Task 4: Enhance context-injection with engagement data (AC: #2)
  - [x]4.1 Extend `server/prompts/sections/context-injection.md` to include engagement context block:
    ```
    Context for this conversation:
    - Coach name: {{coach_name}}
    - User engagement: {{engagement_level}}
    - Recent mood pattern: {{recent_moods}}
    - Message style: {{avg_message_length}} messages
    - Sessions completed: {{session_count}}
    - Time since last session: {{last_session_gap}}
    - Recent session intensity: {{recent_session_intensity}}
    ```
  - [x]4.2 Update `Builder.Build()` signature: add `userState *providers.UserState` parameter
  - [x]4.3 In `Builder.Build()`, replace template variables with values from `userState` (fall back to "unknown" if nil)
  - [x]4.4 Update `handlers/chat.go` to parse `userState` from request body and pass to `Builder.Build()`

- [x] Task 5: Enhance mood.md with tone adaptation instructions (AC: #1, #3)
  - [x]5.1 Add tone adaptation guidance to `server/prompts/sections/mood.md` referencing the context-injection engagement data:
    - When `engagement_level=low` or `last_session_gap` > 72h: select `welcoming` or `warm`, keep response under ~150 words, offer max 1 action suggestion, do NOT activate Challenger
    - When `engagement_level=high` and `avg_message_length=long`: select `focused` when problem-solving, responses can be 200-400 words, multiple suggestions and Challenger are appropriate
    - When `recent_moods` contains 2+ consecutive `gentle`: maintain `gentle` or `warm`, do NOT jump to `focused` without user signaling readiness (a question, a forward-looking statement)
    - When `recent_session_intensity=light`: keep responses concise (~100 words), ask one question max, no multi-part action plans
  - [x]5.2 Add transition rhythm rules to mood.md:
    - Vulnerability -> Action: 2-3 beats of acknowledgment before goals
    - Celebration -> Challenge: Challenger does NOT activate in same session as milestone
    - Compassion -> Resilience: wait for user to signal readiness ("okay so what now?")
    - Challenge -> Support: immediate contingency, no gap

- [x] Task 6: Update test helpers and add tests (AC: #1, #2, #3)
  - [x]6.1 **Go tests**: Update ALL 3 test helpers when builder signature changes: `setupTestSections()` and `createTestPromptBuilder()` in `server/prompts/builder_test.go`, `setupMuxWithBuilder()` in `server/tests/handlers_test.go`
  - [x]6.2 Add `TestBuilder_Build_WithUserState_InjectsContext` — verify engagement data appears in assembled prompt
  - [x]6.3 Add `TestBuilder_Build_WithNilUserState_UsesDefaults` — verify graceful nil handling
  - [x]6.4 Add `TestChatHandler_ValidRequest_WithUserState` — verify userState parses from request body
  - [x]6.5 **Swift tests**: Add `test_engagementCalculator_recentActivity_returnsHighEngagement`
  - [x]6.6 Add `test_engagementCalculator_longGap_returnsLowEngagement`
  - [x]6.7 Add `test_engagementCalculator_noSessions_returnsDefaults`
  - [x]6.8 Add `test_conversationSession_moodHistory_encodesDecodes`
  - [x]6.9 Add `test_sendMessage_includesUserStateInRequest` — verify EngagementSnapshot flows to API call
  - [x]6.10 Update `docs/fixtures/sse-done-event.txt` if needed (done event unchanged for this story)

## Dev Notes

### What This Story Does vs Does NOT Do

**DOES:**
- Computes engagement metrics from local conversation history on iOS
- Passes engagement context to server in ChatRequest
- Injects engagement data into the system prompt via context-injection section
- Instructs the LLM via mood.md to adapt tone based on engagement state
- Stores mood history per session for trend analysis
- Adds transition rhythm rules to the prompt

**DOES NOT:**
- Change the structured output schema (mood enum stays: welcoming/warm/focused/gentle)
- Add new SSE done event fields
- Change the Anthropic provider tool schema
- Implement server-side engagement calculation (iOS calculates, server receives)
- Add real-time sentiment analysis (uses engagement heuristics, not NLP)
- Change CoachExpression enum or CoachCharacterView rendering

### Architecture Compliance

**Prompt System:** Modular section architecture maintained. context-injection.md extended with new template variables. mood.md extended with tone adaptation rules. No new prompt sections created.

**Structured Output Pipeline:** Unchanged. The LLM already selects mood per response — this story gives it better information to make that selection. The existing `mood` field in the done event continues to drive CoachExpression on iOS.

**API Contract:** ChatRequest gains optional `userState` field (backward compatible — omitempty). Done event format unchanged.

**Database Migrations:** One new column `moodHistory` on ConversationSession. Follow GRDB DatabaseMigrator sequential pattern established in Migrations.swift.

### Code Patterns to Follow

**Structured Output Pipeline (from Story 2.4):**
The structured output fields (mood, mode, challengerUsed, safetyLevel) flow: `toolSchema` -> `toolResult` -> `ChatEvent` -> SSE -> iOS `ChatEvent` -> ViewModel. This story does NOT add new structured output fields. It only enriches the INPUT to the LLM.

**Template Variable Replacement (from builder.go):**
builder.go currently replaces `{{coach_name}}` in context-injection.md. Extend this pattern for new variables: `{{engagement_level}}`, `{{recent_moods}}`, etc. Use `strings.ReplaceAll()` for each variable.

**GRDB Migration Pattern (from Migrations.swift):**
```swift
migrator.registerMigration("v4") { db in
    try db.alter(table: "ConversationSession") { t in
        t.add(column: "moodHistory", .text)
    }
}
```

**JSON-Encoded Array Column Pattern (from modeHistory):**
`modeHistory` stores `[ModeSegment]` as JSON string. Follow same pattern for `moodHistory` storing `[String]`.

**Test Helper Update Pattern (CRITICAL from Story 2.4):**
When `Builder.Build()` signature changes, ALL 3 test helpers must be updated simultaneously:
- `setupTestSections()` in `server/prompts/builder_test.go`
- `createTestPromptBuilder()` in `server/prompts/builder_test.go`
- `setupMuxWithBuilder()` in `server/tests/handlers_test.go`
Note: 2 helpers in builder_test.go, 1 in handlers_test.go. Failure to update all 3 causes cascading test failures.

**Observable Property Pattern (from CoachingViewModel):**
```swift
// Track mood accumulation during streaming
private var sessionMoods: [String] = []
// On done event, append mood
// On session end, persist to session.moodHistory
```

### File Locations

**Server files to modify:**
- `server/providers/provider.go` — Add UserState struct and ChatRequest field
- `server/prompts/sections/context-injection.md` — Add engagement template variables
- `server/prompts/sections/mood.md` — Add tone adaptation and transition rhythm instructions
- `server/prompts/builder.go` — Update Build() to accept and inject userState
- `server/handlers/chat.go` — Parse userState from request, pass to builder
- `server/prompts/builder_test.go` — Update test helpers, add userState tests
- `server/tests/handlers_test.go` — Update test helpers, add userState handler test
- `docs/api-contract.md` — Document userState request field

**iOS files to create:**
- `ios/sprinty/Features/Coaching/Models/EngagementSnapshot.swift` — Engagement data model
- `ios/sprinty/Services/EngagementCalculator.swift` — Computes engagement from DB

**iOS files to modify:**
- `ios/sprinty/Models/ConversationSession.swift` — Add moodHistory column
- `ios/sprinty/Services/Database/Migrations.swift` — Add migration
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — Accumulate moods, compute engagement, include in request
- `ios/sprinty/Services/Networking/ChatService.swift` — Add UserState to ChatRequest encoding (this file builds and sends the chat request with deflate compression)
- `ios/sprinty/Features/Coaching/Models/ChatRequest.swift` — Add `userState: UserState?` field and CodingKey

**Test files to modify/create:**
- `ios/Tests/Features/CoachingViewModelTests.swift` — Add engagement/mood tests
- `ios/Tests/Services/EngagementCalculatorTests.swift` — New test file
- `ios/Tests/Models/ConversationSessionTests.swift` — moodHistory encoding test (or add to existing)
- `server/prompts/builder_test.go` — userState injection tests
- `server/tests/handlers_test.go` — userState parsing tests

### Previous Story Intelligence (Story 2.4)

**Critical Learnings:**
1. When adding new params to `Builder.Build()`, update ALL 3 test helpers simultaneously or all Go tests break
2. Handler done event map at chat.go lines 88-95 is manually constructed — but this story doesn't add new done event fields
3. Context-injection template replacement uses `strings.ReplaceAll()` in builder.go
4. GRDB migrations must be sequential and idempotent (run every app launch)
5. All 177 iOS tests were passing after Story 2.4 — maintain this

**Files from 2.4 that are relevant patterns:**
- `server/prompts/builder.go` — Template replacement pattern to extend
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — Done event handling pattern
- `ios/sprinty/Models/ConversationSession.swift` — modeHistory JSON column pattern to replicate

### Git Intelligence

Recent commits show Epic 2 stories building incrementally:
- 2.1: Discovery mode + ambient warm shift
- 2.2: Directive mode + ambient cool shift + contingency plans
- 2.3: Mode transitions with LLM-driven selection
- 2.4: Challenger capability + structured output pipeline extension

Pattern: each story extends the prompt system and structured output pipeline. This story extends the INPUT side (context-injection) rather than OUTPUT side (structured output).

### Transition Rhythm Rules (UX-DR78)

These rules MUST be encoded in mood.md prompt instructions:

| Transition | Rule | Rationale |
|---|---|---|
| Vulnerability -> Action | 2-3 beats of acknowledgment before goals | Intimacy feels harvested if coach pivots too fast |
| Celebration -> Challenge | Full session boundary — no Challenger in milestone session | Earned pride needs space; challenge poisons celebration |
| Compassion -> Resilience | User signals readiness ("okay, so what now?") | Frame shift cannot be coach-initiated |
| Challenge -> Support | Immediate — contingency follows in same breath | Pushback without a net is abandonment |
| Calm -> Engagement | Gentle invitation, not snap to attention | Door opening softly, not alarm |
| Active -> Pause | 1 beat — acknowledgment, then silence | Speed of quiet communicates respect |

### What NOT To Build

- Do NOT add sentiment analysis or NLP processing — use simple heuristics
- Do NOT add new CoachExpression values — the 5 existing moods are sufficient
- Do NOT add a new prompt section file — extend existing context-injection.md and mood.md
- Do NOT change the Anthropic tool schema — mood selection stays the same, just better informed
- Do NOT add engagement tracking UI — this is invisible to the user
- Do NOT add server-side engagement calculation — iOS computes, server receives and injects
- Do NOT override engagement-based tone during elevated safety states (Yellow/Orange/Red) — safety ALWAYS wins per UX-DR94. When safetyLevel != green, the safety-driven tone (gentle) takes precedence over engagement metrics. FR40 handles safety-aware tone separately
- Do NOT use engagement metrics to disable Challenger globally — Challenger is non-negotiable per FR7. The mood.md guidance to skip Challenger at low engagement is a SOFT hint to the LLM, not a hard gate
- Do NOT adjust notification/check-in cadence based on engagement — that is FR77 (Autonomy Throttle) / Epic 9 scope, not this story
- Do NOT add engagement-dependent UI changes (avatar state, theme shifts) — this story only affects the system prompt input

### FR77 (Autonomy Throttle) Coordination

Engagement metrics computed here (sessionCount, lastSessionGapHours, recentSessionIntensity) overlap with future FR77 (Autonomy Throttle) needs. FR77 will "gradually reduce AI-initiated coaching interactions as user shows self-reliance." When FR77 is implemented, coordinate to reuse EngagementCalculator rather than creating duplicate engagement tracking. The data shapes are compatible — FR77 may extend EngagementSnapshot with additional fields like `aiInitiatedSessionRatio`.

### Project Structure Notes

- New files follow existing folder conventions: Models in Features/Coaching/Models/, Services in Services/
- EngagementCalculator is a service (not a model) because it queries the database
- UserState struct lives in provider.go alongside ChatRequest (Go convention: related types in same file)
- Swift UserState struct lives alongside EngagementSnapshot (or in the networking layer where ChatRequest is encoded)

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 2, Story 2.5]
- [Source: _bmad-output/planning-artifacts/architecture.md — System Prompt Architecture, Context-Injection, Coach Expression State Machine]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Transition Rhythms UX-DR78, Micro-Emotions, Emotional Journey Map]
- [Source: _bmad-output/planning-artifacts/prd.md — FR10 Adaptive Tone, FR40 Safety-Aware Tone, Coach Personality & Voice]
- [Source: _bmad-output/implementation-artifacts/2-4-challenger-capability.md — Test helper pattern, structured output pipeline, ambient shift pattern]
- [Source: docs/api-contract.md — ChatRequest/SSE done event format]
- [Source: server/prompts/sections/mood.md — Current mood selection instructions]
- [Source: server/prompts/sections/context-injection.md — Current template: coach_name only]
- [Source: server/prompts/builder.go — Template variable replacement pattern]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- All 185 Swift tests pass (up from 177 in Story 2.4 — 8 new tests added)
- All Go tests pass (3 packages: prompts, providers, tests)
- Fixed Swift 6 strict concurrency issues in EngagementCalculatorTests
- Fixed ChatRequest memberwise init by adding explicit init with `userState` default nil
- Updated FailingChatService in RootView.swift for new protocol signature
- Used xcodegen to regenerate project after adding new files

### Completion Notes List
- Task 1: Created EngagementSnapshot model (3 enums + struct) and EngagementCalculator service with engagement level, message length, mood history, and session intensity heuristics
- Task 2: Added moodHistory column to ConversationSession (v4 migration), accumulate moods in CoachingViewModel during streaming, persist via persistMoodHistory()
- Task 3: Added UserState struct to Go provider.go and ChatRequest, iOS UserState Codable struct with EngagementSnapshot conversion, updated ChatServiceProtocol/ChatService/MockChatService signatures, CoachingViewModel computes engagement and passes to API
- Task 4: Extended context-injection.md with 6 new template variables, updated Builder.Build() signature to accept *UserState, template replacement with nil fallback to "unknown", updated chat handler to pass userState
- Task 5: Extended mood.md with tone adaptation rules (engagement-based mood/length/suggestion constraints) and 6 transition rhythm rules (UX-DR78)
- Task 6: Updated all 3 Go test helpers (setupTestSections, createTestPromptBuilder, setupMuxWithBuilder), added TestBuilder_Build_WithUserState_InjectsContext, TestBuilder_Build_WithNilUserState_UsesDefaults, TestChatHandler_ValidRequest_WithUserState, TestChatHandler_ValidRequest_WithoutUserState. Swift: added EngagementCalculatorTests (5 tests), moodHistory roundtrip test, sendMessage userState test, sessionMoods accumulation test

### Change Log
- 2026-03-20: Story 2.5 implementation complete — adaptive coaching tone with engagement metrics, context injection, and transition rhythm rules

### File List

**New files:**
- ios/sprinty/Features/Coaching/Models/EngagementSnapshot.swift
- ios/sprinty/Services/EngagementCalculator.swift
- ios/Tests/Services/EngagementCalculatorTests.swift

**Modified files:**
- ios/sprinty/Models/ConversationSession.swift (added moodHistory field)
- ios/sprinty/Services/Database/Migrations.swift (added v4 migration)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (mood accumulation, engagement computation, userState in API calls)
- ios/sprinty/Features/Coaching/Models/ChatRequest.swift (added UserState struct, explicit init with userState default)
- ios/sprinty/Services/Networking/ChatServiceProtocol.swift (added userState parameter)
- ios/sprinty/Services/Networking/ChatService.swift (pass userState to ChatRequest)
- ios/sprinty/App/RootView.swift (updated FailingChatService protocol conformance)
- ios/Tests/Mocks/MockChatService.swift (added lastUserState capture, updated signature)
- ios/Tests/Features/CoachingViewModelTests.swift (added userState and sessionMoods tests)
- ios/Tests/Models/CodableRoundtripTests.swift (added moodHistory roundtrip test)
- server/providers/provider.go (added UserState struct, ChatRequest.UserState field)
- server/prompts/builder.go (Build() accepts *UserState, template replacement for engagement vars)
- server/prompts/sections/context-injection.md (engagement template variables)
- server/prompts/sections/mood.md (tone adaptation rules, transition rhythm rules)
- server/handlers/chat.go (pass req.UserState to builder)
- server/prompts/builder_test.go (updated all Build() calls, added 2 userState tests)
- server/tests/handlers_test.go (updated test helpers, added 2 userState handler tests)
- docs/api-contract.md (documented userState request field)
- ios/sprinty.xcodeproj/project.pbxproj (regenerated via xcodegen)
- _bmad-output/implementation-artifacts/sprint-status.yaml (sprint status sync)
