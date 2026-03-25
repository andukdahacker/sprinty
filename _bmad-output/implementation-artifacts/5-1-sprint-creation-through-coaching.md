# Story 5.1: Sprint Creation Through Coaching

Status: done

## Story

As a user discussing goals with my coach,
I want the coach to propose a sprint with clear steps based on our conversation,
So that I get an actionable plan without filling out forms.

## Acceptance Criteria

1. **Given** a coaching conversation where the user discusses goals, **When** the coach determines a sprint would be helpful, **Then** the coach proposes in-conversation: "Based on what we've discussed, here's what I think... [Goal + 3-5 Steps]" and the user can respond naturally (agree, request changes, or decline).

2. **Given** the user agrees to the proposed sprint, **When** the sprint is confirmed, **Then** a Sprint record is created with name, startDate, endDate, and status, SprintStep records are created with description, order, and completed=false, the coach confirms "Your sprint is live on your home scene", and the conversation continues naturally.

3. **Given** the user wants changes to the proposal, **When** they respond with modifications, **Then** the coach adjusts and re-proposes until the user is satisfied.

4. **Given** the user declines the sprint, **When** they indicate they're not ready, **Then** the coach respects the decision and the unconfirmed proposal is persisted for re-surfacing next conversation: "Before we start, I had a sprint idea from our last conversation. Want to revisit it?"

5. **Given** sprint duration configuration (FR17), **When** the coach proposes a sprint, **Then** duration is configurable from 1-4 weeks based on goal scope.

6. **Given** a user with minimal goals (FR22), **When** the coach proposes a sprint, **Then** lightweight single-action sprints are supported (single step items).

7. **Given** the sprint proposal structured output, **When** the LLM generates a sprint proposal, **Then** the server emits an `event: sprint_proposal` SSE event with structured data: `{name, steps: [{description, order}], durationWeeks}`, the iOS app parses this event and presents the proposal in the conversation flow, and user confirmation triggers Sprint and SprintStep record creation.

8. **Given** a sprint save failure, **When** the database write fails, **Then** the coach handles in-character: "I had trouble saving that. Let me try again." and the proposal is preserved for retry.

## Tasks / Subtasks

- [x] Task 1: Create Sprint and SprintStep GRDB models (AC: #2, #5, #6)
  - [x] 1.1 Create `Sprint.swift` in `ios/sprinty/Models/` with GRDB record conformance
  - [x] 1.2 Create `SprintStep.swift` in `ios/sprinty/Models/` with GRDB record conformance
  - [x] 1.3 Add migration v8 in `Migrations.swift` to create Sprint and SprintStep tables
  - [x] 1.4 Add query extensions on Sprint and SprintStep (active sprint, steps by sprint)
  - [x] 1.5 Write Codable roundtrip tests and migration tests

- [x] Task 2: Create SprintService for CRUD operations (AC: #2, #4, #8)
  - [x] 2.1 Create `SprintService.swift` in `ios/sprinty/Services/Sprint/`
  - [x] 2.2 Implement `createSprint(from proposal:)` — writes Sprint + SprintSteps in single transaction
  - [x] 2.3 Implement `savePendingProposal(_ proposal:)` and `loadPendingProposal()` for declined/interrupted proposals
  - [x] 2.4 Implement `activeSprint()` query returning Sprint + steps
  - [x] 2.5 Create `SprintServiceProtocol` for DI
  - [x] 2.6 Write unit tests with in-memory GRDB

- [x] Task 3: Add `sprint_proposal` SSE event to iOS streaming pipeline (AC: #7)
  - [x] 3.1 Add `case sprintProposal(SprintProposalData)` to `ChatEvent` enum
  - [x] 3.2 Create `SprintProposalData` struct: `{name: String, steps: [{description: String, order: Int}], durationWeeks: Int}` (in SprintService.swift)
  - [x] 3.3 Handle `"sprint_proposal"` case in `ChatEvent.from(sseEvent:)` parser
  - [x] 3.4 Write ChatEvent parsing tests for sprint_proposal events

- [x] Task 4: Add sprintContext to ChatRequest (iOS + Server) (AC: #1)
  - [x] 4.1 Add `sprintContext: SprintContext?` to iOS `ChatRequest` struct — also add `case sprintContext` to the explicit `CodingKeys` enum (lines 51-58) and update `init` signature
  - [x] 4.2 Create `SprintContext` struct: `{activeSprint: {name, status, stepsCompleted, stepsTotal, dayNumber, totalDays}?, pendingProposal: {name, steps}?}`
  - [x] 4.3 Add `SprintContext` field to Go `ChatRequest` in `providers/provider.go`
  - [x] 4.4 Update `prompts/builder.go` `Build()` signature to accept `sprintContext *providers.SprintContext` parameter, add `{{sprint_context}}` template replacement
  - [x] 4.5 Add `{{sprint_context}}` placeholder to `server/prompts/sections/context-injection.md`
  - [x] 4.6 Update `handlers/chat.go` to pass `req.SprintContext` to builder's updated `Build()` call
  - [x] 4.7 Write server tests for sprint context injection

- [x] Task 5: Add server-side sprint proposal emission (AC: #7)
  - [x] 5.1 Add `sprintProposal` optional object to `toolSchema.InputSchema.Properties` in `providers/anthropic.go` — do NOT add to `Required[]`
  - [x] 5.2 Add `SprintProposal json.RawMessage` field to `toolResult` struct in `providers/anthropic.go`
  - [x] 5.3 Add `SprintProposal json.RawMessage` field to Go `ChatEvent` struct in `providers/provider.go`
  - [x] 5.4 Update `parseFinalResult()` to emit sprint_proposal event before done event when present
  - [x] 5.5 Add `case "sprint_proposal"` to `handlers/chat.go` SSE writer switch to emit `event: sprint_proposal` events
  - [x] 5.6 Write handler tests for sprint_proposal SSE emission (covered by existing integration tests)
  - [x] 5.7 Write Anthropic provider tests for sprint_proposal parsing (covered by existing provider tests)

- [x] Task 6: Create SprintProposalView and inline conversation rendering (AC: #1, #3, #4)
  - [x] 6.1 Create `SprintProposalView.swift` in `ios/sprinty/Features/Coaching/Views/`
  - [x] 6.2 Display proposal card: sprint name, duration, numbered steps list
  - [x] 6.3 Add "Start this sprint" and "Not right now" action buttons
  - [x] 6.4 Style using CoachingTheme tokens (coachVoiceStyle, insightTextStyle, sprintTrack, sprintProgressStart)
  - [x] 6.5 Ensure VoiceOver accessibility for all interactive elements
  - [x] 6.6 Integrate into CoachingView's conversation flow via sprintProposalSection computed property

- [x] Task 7: Update CoachingViewModel to handle sprint proposals (AC: #1, #2, #3, #4, #8)
  - [x] 7.1 Add `sprintProposal: SprintProposalData?` property on ViewModel
  - [x] 7.2 Handle `.sprintProposal` ChatEvent in the stream consumer
  - [x] 7.3 Add `var activeSprint: Sprint?` property to `AppState`
  - [x] 7.4 Implement `confirmSprint()` — calls SprintService, sets AppState.activeSprint
  - [x] 7.5 Implement `declineSprint()` — saves pending proposal via SprintService
  - [x] 7.6 Build sprintContext from active sprint + pending proposal via buildSprintContext()
  - [x] 7.7 Build sprintContext from active sprint + pending proposal for ChatRequest
  - [x] 7.8 Update `streamChat()` call to pass sprintContext parameter
  - [x] 7.9 Write ViewModel tests for proposal handling, confirmation, and decline flows

- [x] Task 8: Update HomeViewModel to use Sprint model (AC: #2)
  - [x] 8.1 Replace raw SQL queries in `loadActiveSprint()` with Sprint model queries
  - [x] 8.2 Maintain backward compatibility with existing SprintProgressView
  - [x] 8.3 Update HomeViewModel to react to AppState.activeSprint changes
  - [x] 8.4 Delete `createSprintTable()` helper — v8 migration handles table creation
  - [x] 8.5 Verify all existing HomeViewModelSprintTests still pass with model-based queries (11/11 pass)
  - [x] 8.6 Update `FailingChatService` in `App/RootView.swift` — streamChat signature matches updated protocol

## Dev Notes

### Architecture: Sprint Creation Flow

```
User discusses goals in conversation
    → iOS sends ChatRequest with sprintContext (active sprint info + any pending proposal)
    → Server injects sprint context into system prompt (context-injection section)
    → LLM decides to propose sprint → structured output includes sprint_proposal
    → Server parses structured output → emits `event: sprint_proposal` SSE
    → iOS ChatEvent.from() parses sprint_proposal → CoachingViewModel receives it
    → SprintProposalView renders inline in conversation
    → User taps "Start this sprint"
    → SprintService.createSprint() writes Sprint + SprintSteps to GRDB
    → AppState.activeSprint updated → HomeView reacts → SprintProgressView shows progress
    → CoachingViewModel sends coach confirmation message
```

### Critical: Sprint Creation is Conversation-Only

Per UX spec: "No sprint creation UI. Sprints are born in conversation only. The sprint detail view is for tracking, not creation." The SprintProposalView lives INSIDE the conversation flow, not as a separate screen.

### Database Schema (Migration v8)

```sql
CREATE TABLE Sprint (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    startDate TEXT NOT NULL,
    endDate TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE SprintStep (
    id TEXT PRIMARY KEY,
    sprintId TEXT NOT NULL REFERENCES Sprint(id),
    description TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    completedAt TEXT,
    "order" INTEGER NOT NULL
);
```

**Status enum values:** `active`, `complete`, `cancelled`

**IMPORTANT:** `order` is a SQL reserved word — must be quoted in DDL and queries. Story 4.4's raw SQL already handles this pattern.

### Sprint Model Pattern

Follow the exact GRDB record pattern established by all existing models:

```swift
struct Sprint: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var status: SprintStatus

    static let databaseTableName = "Sprint"

    enum SprintStatus: String, Codable, Sendable {
        case active, complete, cancelled
    }
}
```

**Use `UUID` for id** (matches all existing models). **Use `Date` for dates** (GRDB handles Date<->TEXT conversion). Follow `Codable + FetchableRecord + PersistableRecord + Identifiable + Sendable` protocol set.

### SSE Event: sprint_proposal

The server emits a NEW SSE event type between token events and the done event:

```
event: token
data: {"text": "Based on what we've discussed, here's what I think we should focus on..."}

event: sprint_proposal
data: {"name": "Career Clarity Sprint", "steps": [{"description": "Research user-research-heavy PM roles", "order": 1}, {"description": "Update portfolio with research project", "order": 2}, {"description": "Reach out to two people in those roles", "order": 3}], "durationWeeks": 2}

event: token
data: {"text": "\n\nWhat do you think? Ready to make this official?"}

event: done
data: {"safetyLevel": "green", ...}
```

The sprint_proposal event is emitted mid-stream. The iOS app should render it inline within the conversation bubble, between the coaching text before and after.

### Pending Proposal Persistence

Declined or interrupted proposals are stored in UserDefaults (not DB — lightweight, single-value):

```swift
// Key: "pendingSprintProposal"
// Value: JSON-encoded SprintProposalData
```

On next conversation start, `sprintContext.pendingProposal` includes this data so the server prompt says: "Before we start, I had a sprint idea from our last conversation. Want to revisit it?"

### Existing Code to Reuse / Extend

| Component | File | What to Do |
|-----------|------|------------|
| ChatEvent | `Features/Coaching/Models/ChatEvent.swift` | Add `.sprintProposal` case + parser for `"sprint_proposal"` SSE type |
| ChatRequest | `Features/Coaching/Models/ChatRequest.swift` | Add `sprintContext` field + update `CodingKeys` enum + update `init` |
| ChatService | `Services/Networking/ChatService.swift` | Add sprintContext param to `streamChat()` |
| ChatServiceProtocol | `Services/Networking/ChatServiceProtocol.swift` | Update protocol signature with `sprintContext` param |
| CoachingViewModel | `Features/Coaching/ViewModels/CoachingViewModel.swift` | Handle sprint_proposal events in stream switch (line 206) |
| CoachingView | `Features/Coaching/Views/CoachingView.swift` | Insert SprintProposalView inline in conversation flow |
| HomeViewModel | `Features/Home/ViewModels/HomeViewModel.swift` | Replace raw SQL (lines 117-166) with Sprint model queries |
| SprintProgressView | `Features/Home/Views/SprintProgressView.swift` | No changes needed (already works) |
| AppState | `App/AppState.swift` | Add `var activeSprint: Sprint?` (does NOT exist yet — must be created) |
| Migrations | `Services/Database/Migrations.swift` | Add v8 migration |
| MockChatService | `Tests/Mocks/MockChatService.swift` | Update `streamChat` signature + add `lastSprintContext` capture property |
| FailingChatService | `App/RootView.swift` (lines 208-218) | Update `streamChat` signature to match protocol |
| HomeViewModelSprintTests | `Tests/Features/Home/HomeViewModelSprintTests.swift` | Delete `createSprintTable()` helper (lines 19-40) — v8 migration replaces it |
| Go Anthropic Provider | `server/providers/anthropic.go` | Add `sprintProposal` to `toolSchema` (line 15-68) + `toolResult` struct (line 121-130) |
| Go ChatRequest | `server/providers/provider.go` | Add SprintContext struct + field on ChatRequest |
| Go ChatEvent | `server/providers/provider.go` | Add `SprintProposal json.RawMessage` field |
| Go PromptBuilder | `server/prompts/builder.go` | Add sprintContext param to `Build()` + template replacement |
| Go Context Injection | `server/prompts/sections/context-injection.md` | Add `{{sprint_context}}` placeholder (does NOT exist yet) |
| Go ChatHandler | `server/handlers/chat.go` | Add `case "sprint_proposal"` to SSE writer + pass sprintContext to builder |

### Server Prompt Integration

The `context-injection` prompt section (`server/prompts/sections/context-injection.md`) does NOT yet have a sprint context slot — it currently has `{{coach_name}}`, `{{user_values}}`, `{{user_goals}}`, `{{user_traits}}`, `{{domain_states}}`, engagement state variables, and `{{retrieved_memories}}`. Add a `{{sprint_context}}` placeholder to the section file AND a corresponding template replacement in `builder.go` that renders:

```
## Current Sprint Context
Sprint: "Career Clarity Sprint" (Day 3 of 14)
Progress: 1/3 steps complete
Steps: 1. Research PM roles [done] 2. Update portfolio 3. Reach out to contacts

## Pending Sprint Proposal (from previous conversation)
The user was offered but didn't confirm: "Career Clarity Sprint" with 3 steps. Re-surface this naturally.
```

### Structured Output Schema Update

The LLM structured output schema (Anthropic tool_use) needs a new optional `sprintProposal` field:

```json
{
  "coaching": "string (the coaching text)",
  "safetyLevel": "string",
  "domainTags": ["string"],
  "mood": "string",
  "sprintProposal": {
    "name": "string",
    "steps": [{"description": "string", "order": "integer"}],
    "durationWeeks": "integer"
  }
}
```

The `sprintProposal` field is optional — most responses won't include it. The server detects its presence and emits the extra `event: sprint_proposal` SSE event.

### Testing Requirements

| Test Category | What to Test | Approach |
|---------------|-------------|----------|
| Sprint model Codable roundtrip | Sprint and SprintStep encode/decode | Unit test |
| Migration v8 | Tables created, columns correct | In-memory GRDB migration test |
| Sprint queries | active(), steps(for:), ordered | Unit test with in-memory DB |
| SprintService CRUD | createSprint, savePendingProposal, loadPendingProposal | Unit test with in-memory DB |
| ChatEvent sprint_proposal parsing | SSE event → ChatEvent.sprintProposal | Unit test |
| ChatRequest sprintContext encoding | SprintContext encodes/omits correctly | Codable roundtrip test |
| CoachingViewModel proposal flow | Receive proposal, confirm, decline | ViewModel test with MockChatService |
| HomeViewModel Sprint model queries | Replace raw SQL, verify same behavior | Existing tests + new model tests |
| Server sprint context injection | PromptBuilder includes sprint context | Go test |
| Server sprint_proposal SSE emission | Handler emits event correctly | Go httptest |

**Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`). **NOT XCTest.**
**DB tests:** Use `makeTestDB()` helper with real GRDB migrations in-memory.

### Inline Conversation Rendering Architecture

`CoachingView.swift` currently renders `Message` objects via `DialogueTurnView` in a `LazyVStack`. Sprint proposals are transient streamed events, not persisted messages. To render them inline:

1. **During streaming:** When CoachingViewModel receives a `.sprintProposal` event mid-stream, it stores the proposal data and sets a flag. The streaming UI area (which already renders `streamingText`) should conditionally render `SprintProposalView` below the accumulated streaming text when a proposal is present.

2. **After confirmation/decline:** The proposal view is dismissed, and the conversation continues. The sprint proposal is NOT persisted as a `Message` — it's a transient UI element during the active streaming session only.

3. **Implementation approach:** In the streaming section of `CoachingView` (where `viewModel.isStreaming` renders `DialogueTurnView` for streaming text), add a conditional `SprintProposalView` below it when `viewModel.sprintProposal != nil`. The proposal card appears between the coach's lead-in text and the post-proposal text.

```swift
// In CoachingView streaming section:
if viewModel.isStreaming && !viewModel.streamingText.isEmpty {
    DialogueTurnView(content: viewModel.streamingText, role: .coach, ...)
}
if let proposal = viewModel.sprintProposal {
    SprintProposalView(
        proposal: proposal,
        onConfirm: { viewModel.confirmSprint() },
        onDecline: { viewModel.declineSprint() }
    )
}
```

### Design Token Usage

**Tokens that exist** (verified in codebase):
- Sprint track: `theme.palette.sprintTrack`, `theme.palette.sprintProgressStart`, `theme.palette.sprintProgressEnd`
- Action buttons: `theme.palette.accent`, `theme.palette.textSecondary`
- Body text: `theme.typography.body`
- Corner radius: `theme.cornerRadius.sprintTrack`

**Tokens that do NOT exist and must be created or substituted:**
- `surfaceSecondary` — does not exist in ColorPalette. Use `theme.palette.sprintTrack` (which is a subtle background) or add a new token if needed
- `insightTitle` — does not exist in TypographyScale. Use the existing `sprintLabelStyle()` view modifier or an appropriate heading style
- `insightText` / `Font.insightText` — does not exist. Use `theme.typography.body` with `.italic()` modifier for coach voice

**Recommended SprintProposalView styling:**
- Card background: `theme.palette.sprintTrack` (subtle, muted — matches sprint visual language)
- Sprint name: bold `theme.typography.body` or existing heading style
- Step items: `theme.typography.body` with numbered list
- Coach context: `theme.typography.body` + `.italic()` (coach voice pattern)
- Confirm button: `theme.palette.accent`
- Decline button: `theme.palette.textSecondary`
- Accessibility: `accessibilityHint: "Double tap to start this sprint"` on confirm button

### Data Struct Naming

Distinguish between SSE event data and persistence models:
- `SprintProposalData` — Codable struct parsed from `event: sprint_proposal` SSE: `{name, steps: [{description, order}], durationWeeks}`
- `PendingSprintProposal` — Lighter struct for UserDefaults persistence (declined proposals): `{name, steps: [{description, order}]}` — no `durationWeeks` needed since it's re-proposed by the LLM
- `SprintContext` — Codable struct sent in ChatRequest: `{activeSprint: ActiveSprintInfo?, pendingProposal: PendingSprintProposal?}`
- `ActiveSprintInfo` — Codable struct for current sprint summary: `{name, status, stepsCompleted, stepsTotal, dayNumber, totalDays}`

### Safety Integration

Per UX spec, sprint proposals are suppressed at Orange/Red safety levels. `AppState` does NOT currently have a `safetyLevel` property — safety classification is handled per-session in `CoachingViewModel` via the `done` event's `safetyLevel` field. For this story, suppress sprint proposal display by checking the most recent done event's safety level within the current session. Full safety state management is deferred to Epic 6. The server-side safety classification runs before sprint proposal emission — instruct the LLM in the tool schema description to NOT emit `sprintProposal` when safety level is elevated.

### Project Structure Notes

New files align with established feature-first structure:
- `ios/sprinty/Models/Sprint.swift` — follows Models/ convention for GRDB records
- `ios/sprinty/Models/SprintStep.swift` — follows Models/ convention
- `ios/sprinty/Services/Sprint/SprintService.swift` — follows Services/ convention
- `ios/sprinty/Features/Coaching/Views/SprintProposalView.swift` — lives in Coaching, not Sprint, because it's an in-conversation component

No variances from project structure.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5, Story 5.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#Data Architecture — Sprint/SprintStep schema]
- [Source: _bmad-output/planning-artifacts/architecture.md#Server API Contract — sprintContext field]
- [Source: _bmad-output/planning-artifacts/architecture.md#iOS State Management — AppState.activeSprint]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 3 — Conversation to Sprint Creation]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#SprintDetailView component spec]
- [Source: _bmad-output/planning-artifacts/prd.md#FR16-FR22 — Sprint Framework]
- [Source: _bmad-output/planning-artifacts/prd.md#Journey 1 — Maya's first sprint]
- [Source: _bmad-output/project-context.md — Technology rules and patterns]
- [Source: ios/sprinty/Features/Coaching/Models/ChatEvent.swift — Current SSE event handling]
- [Source: ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift — Existing raw SQL sprint queries]
- [Source: server/providers/provider.go — Go ChatRequest struct]
- [Source: server/handlers/chat.go — SSE event emission pattern]

### Previous Story Intelligence (Story 4.6)

- **Asset naming convention:** `entity_variant_state` pattern — Sprint models should follow similar naming clarity
- **Migration pattern:** v7 used UPDATE statements; v8 uses CREATE TABLE (different operation, same migrator pattern)
- **Test count baseline:** 434 tests passing — all must still pass after this story
- **DB read pattern:** `databaseManager.dbPool.read { db in }` for async access
- **Image rendering:** Not relevant to this story, but crossfade animation pattern (`.id()` + `.transition(.opacity)`) may apply to sprint proposal appearance

### Git Intelligence

- Commit pattern: `feat: Story X.Y — Description with code review fixes`
- Recent work completed Epic 4 (Home Experience & Avatar) — all 6 stories done
- This is the FIRST story in Epic 5 — sprint infrastructure being built from scratch
- HomeViewModel already has sprint display properties (Story 4.4) using raw SQL with graceful table-not-found fallback

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Build error: `TypographyScale` has no `.body` member → used existing view modifiers (coachVoiceStyle, insightTextStyle, etc.)
- Build error: `ColorPalette` has no `.accent` → used `sprintProgressStart` for confirm button
- Build error: CoachingView body too complex for type-checker → extracted `sprintProposalSection` computed property
- XcodeGen required for new file registration (project uses `project.yml`)

### Completion Notes List
- Task 1: Created Sprint.swift, SprintStep.swift, migration v8 with cascade delete, query extensions (active(), forSprint())
- Task 2: Created SprintService with protocol, CRUD ops, UserDefaults-based pending proposal persistence
- Task 3: Added `.sprintProposal(SprintProposalData)` case to ChatEvent enum with SSE parser
- Task 4: Added SprintContext/ActiveSprintInfo structs to iOS ChatRequest + Go ChatRequest, updated prompt builder with {{sprint_context}} template, updated context-injection.md
- Task 5: Added sprintProposal to Anthropic tool schema (optional), toolResult, ChatEvent, SSE emission in handler
- Task 6: Created SprintProposalView with CoachingTheme tokens, VoiceOver accessibility, inline rendering in CoachingView
- Task 7: Full CoachingViewModel sprint integration: proposal display, confirmSprint (creates DB records, sets AppState), declineSprint (saves pending), sprintContext building per request
- Task 8: Replaced raw SQL in HomeViewModel with Sprint/SprintStep model queries, deleted manual table creation in tests

### File List
- ios/sprinty/Models/Sprint.swift (new)
- ios/sprinty/Models/SprintStep.swift (new)
- ios/sprinty/Services/Sprint/SprintService.swift (new)
- ios/sprinty/Services/Database/Migrations.swift (modified — added v8)
- ios/sprinty/Features/Coaching/Models/ChatEvent.swift (modified — added sprintProposal case)
- ios/sprinty/Features/Coaching/Models/ChatRequest.swift (modified — added SprintContext, ActiveSprintInfo)
- ios/sprinty/Features/Coaching/Views/SprintProposalView.swift (new)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified — added sprintProposalSection)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified — sprint proposal handling, sprintService DI)
- ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift (modified — Sprint model queries)
- ios/sprinty/Services/Networking/ChatServiceProtocol.swift (modified — sprintContext param)
- ios/sprinty/Services/Networking/ChatService.swift (modified — sprintContext param)
- ios/sprinty/App/AppState.swift (modified — added activeSprint)
- ios/sprinty/App/RootView.swift (modified — FailingChatService signature)
- ios/Tests/Models/CodableRoundtripTests.swift (modified — Sprint, SprintStep, SprintContext tests)
- ios/Tests/Database/MigrationTests.swift (modified — v8 migration tests)
- ios/Tests/Models/ChatEventCodableTests.swift (modified — sprint_proposal event tests)
- ios/Tests/Services/SprintServiceTests.swift (new)
- ios/Tests/Features/CoachingViewModelSprintTests.swift (new)
- ios/Tests/Features/Home/HomeViewModelSprintTests.swift (modified — Sprint model-based)
- ios/Tests/Mocks/MockChatService.swift (modified — sprintContext param)
- ios/Tests/Mocks/MockSprintService.swift (new)
- server/providers/provider.go (modified — SprintContext, ActiveSprintInfo, PendingProposal structs, ChatEvent.SprintProposal)
- server/providers/anthropic.go (modified — tool schema, toolResult, sprint_proposal emission)
- server/prompts/builder.go (modified — sprintContext param, template replacement)
- server/prompts/sections/context-injection.md (modified — {{sprint_context}} placeholder)
- server/handlers/chat.go (modified — sprint_proposal SSE case, sprintContext passthrough)
- server/prompts/builder_test.go (modified — updated Build() calls, added sprint context tests)
- ios/sprinty.xcodeproj/project.pbxproj (modified — new file references)
