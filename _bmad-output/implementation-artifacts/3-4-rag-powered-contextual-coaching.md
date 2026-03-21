# Story 3.4: RAG-Powered Contextual Coaching

Status: done

## Story

As a user returning for a new conversation,
I want my coach to recall relevant past discussions and surface patterns I might not see,
So that every session builds on everything that came before.

## Acceptance Criteria

1. **RAG Context Retrieval** — Given a user starts a new conversation, when the system prepares the chat request, then the most relevant past conversation summaries are retrieved via embedding similarity search with recency weighting (top 5, using EmbeddingPipeline.search()), formatted into a ragContext string (under ~1000 tokens, truncating least-relevant if over budget), included in the chat request, and the coach naturally references past conversations when relevant.

2. **Memory Reference Rendering** — Given the coach references a past conversation, when the LLM structured output includes `memoryReferenced: true` in the done event, then DialogueTurnView renders the coach turn in italic at 0.7 opacity (UX-DR51), with `accessibilityLabel: "Coach says: [content]"` and `accessibilityHint: "Referencing a past conversation."`.

3. **Long-Gap Retrieval** — Given a user with irregular engagement (days to weeks between conversations, FR15), when they return after a long gap (lastSessionGapHours > 72), then the system retrieves relevant context from before the gap (not just most recent), includes the gap duration in ragContext so the LLM can reference it, and the coach acknowledges the passage of time naturally.

4. **Memory Gap Handling** — Given the coach cannot find relevant context, when the user references something not in memory, then the coach responds honestly: "I don't have that front of mind — can you remind me?" (UX-DR55). The context-injection prompt includes explicit instructions for this honest response pattern.

5. **Cross-Session Pattern Surfacing** — Given patterns exist across multiple conversations (FR6), when the coach detects cross-session connections via RAG context, then it surfaces those patterns naturally ("I've noticed a theme across our last few conversations...").

6. **Daily Context-Aware Greeting** — Given a new day begins and the user opens the conversation (UX-DR54), when the conversation view loads (before any user message), then the coach's context-aware greeting is already visible as the first turn of the new day, with a "Today" date separator, pre-generated from recent summary data (no full LLM call, completes within 500ms on HomeSceneView appear), with fallback "What's on your mind?" if RAG unavailable or generation exceeds 500ms. Greeting templates vary by context: topic-based ("Last time we discussed [X]..."), emotion-based ("You seemed energized last time..."), or gap-aware ("It's been a few days...").

7. **Graceful Degradation** — Given the RAG retrieval fails or no embeddings exist, when the user starts a conversation, then the system falls back to non-RAG coaching (no ragContext in request), the failure is logged via os.Logger at Error level, and the user experience is unaffected.

8. **Token Budget Enforcement** — Given retrieved summaries are formatted into ragContext, when the total formatted text exceeds ~1000 tokens (~4000 characters), then least-relevant entries are dropped until under budget, ensuring the prompt context window is not wasted on low-value retrievals.

## Tasks / Subtasks

- [x] **Task 1: Add ragContext to ChatRequest and API contract** (AC: 1)
  - [x] 1.1 Add `ragContext: String?` field to `ChatRequest` in `ios/sprinty/Features/Coaching/Models/ChatRequest.swift`
  - [x] 1.2 Add `ragContext` field to server's `ChatRequest` struct in `server/providers/provider.go`
  - [x] 1.3 Update `docs/api-contract.md` with ragContext field specification
  - [x] 1.4 Add tests for ChatRequest encoding with/without ragContext

- [x] **Task 2: Build RAG context retrieval in CoachingViewModel** (AC: 1, 3, 7, 8)
  - [x] 2.1 Add `retrieveRAGContext(for:)` method to CoachingViewModel that calls `embeddingPipeline.search(query:limit:5)`
  - [x] 2.2 Add recency weighting: after vector search, re-rank results by combining similarity distance with a recency bonus (more recent summaries rank higher at equal relevance)
  - [x] 2.3 Format retrieved ConversationSummary array into a prompt-friendly string (date + domain tags + summary text + key moments per entry)
  - [x] 2.4 Add token budget enforcement: if formatted ragContext exceeds ~4000 characters (~1000 tokens), drop least-relevant entries until under budget
  - [x] 2.5 When `lastSessionGapHours > 72`, prepend gap duration to ragContext (e.g., "User returning after 5 days away.")
  - [x] 2.6 Inject formatted ragContext into ChatRequest before sending
  - [x] 2.7 Handle retrieval errors gracefully — log via os.Logger and send request without ragContext
  - [x] 2.8 Add tests for RAG retrieval, recency weighting, token budget truncation, gap detection, and error fallback

- [x] **Task 3: Server prompt injection for RAG context** (AC: 1, 4, 5)
  - [x] 3.1 Modify existing `server/prompts/sections/context-injection.md` — add `{{retrieved_memories}}` template variable with LLM instructions: reference past conversations naturally when relevant; surface cross-session patterns ("I've noticed a theme..."); if user references something not in retrieved memories, respond honestly ("I don't have that front of mind — can you remind me?"); set memoryReferenced to true when referencing retrieved context
  - [x] 3.2 Update `server/prompts/builder.go` — add `ragContext string` parameter to `Build()` signature (current: `Build(mode, coachName, profile, userState)` → new: `Build(mode, coachName, profile, userState, ragContext)`), substitute `{{retrieved_memories}}` with ragContext value (empty string if not provided)
  - [x] 3.3 Update `server/handlers/chat.go` line ~55 — parse ragContext from request body, pass to updated `builder.Build()` call
  - [x] 3.4 Add builder tests for ragContext template substitution (with content, empty, nil)
  - [x] 3.5 Add handler tests for ragContext parsing (present, absent, empty)

- [x] **Task 4: Memory reference UI rendering** (AC: 2)
  - [x] 4.1 Add `memoryReferenced: Bool` parameter to `ChatEvent.done` case in `ios/sprinty/Features/Coaching/Models/ChatEvent.swift` (currently missing — server sends it via anthropic.go line ~270 but iOS discards it)
  - [x] 4.2 Update SSE parser (`ios/sprinty/Services/Networking/SSEParser.swift`) to extract `memoryReferenced` from the done event JSON payload
  - [x] 4.3 Store memoryReferenced flag per assistant message in CoachingViewModel — use a transient dictionary `[UUID: Bool]` mapping message ID to flag (display state only, not persisted to DB)
  - [x] 4.4 Add `memoryReferenced: Bool` parameter to `DialogueTurnView` (`ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift`) — currently accepts only `content: String` and `role: MessageRole`
  - [x] 4.5 Render coach turns with `.italic()` + `.opacity(0.7)` when memoryReferenced is true
  - [x] 4.6 Add `accessibilityLabel("Coach says: \(content)")` and `accessibilityHint("Referencing a past conversation.")` for memory-referenced turns
  - [x] 4.7 Add tests for SSE parsing of memoryReferenced, ViewModel flag storage, and view rendering/accessibility

- [x] **Task 5: Daily context-aware greeting** (AC: 6)
  - [x] 5.1 Add `generateDailyGreeting()` async method that queries recent summaries (last 7 days) via direct GRDB query (`ConversationSummary.recent()`)
  - [x] 5.2 Build lightweight greeting using template variants — topic-based ("Last time we discussed [X]. How's that going?"), emotion-based ("You seemed [positive/stressed] last time — how are things now?"), gap-aware ("It's been a few days — what's been on your mind?") — selected based on most recent summary content and session gap
  - [x] 5.3 Pre-generate greeting on conversation view load (not user-triggered) — greeting is already visible when conversation view appears, with "Today" date separator above it
  - [x] 5.4 Handle greeting concurrency: if user taps "Talk to coach" before greeting pre-fetch completes, use 500ms timeout then show fallback
  - [x] 5.5 Fallback to "What's on your mind?" if: no recent summaries, cold start (no conversations ever), generation fails, or exceeds 500ms timeout
  - [x] 5.6 Add tests for greeting generation (each template variant), fallback scenarios, cold start, timeout behavior, and performance

- [x] **Task 6: End-to-end integration and edge cases** (AC: 3, 4, 7, 8)
  - [x] 6.1 Test cold start (no prior conversations) — no ragContext sent, greeting shows fallback "What's on your mind?"
  - [x] 6.2 Test long-gap retrieval (simulate Priya pattern: 8+ day gaps) — verify older relevant summaries surface via recency-weighted search
  - [x] 6.3 Test pattern surfacing (simulate Maya pattern: 3 sessions over a week with recurring "impact" theme) — verify ragContext contains cross-session data
  - [x] 6.4 Verify memoryReferenced flag flows end-to-end: server tool schema → done event → SSEParser → ChatEvent → CoachingViewModel → DialogueTurnView
  - [x] 6.5 NFR18 validation: generate 10K synthetic summaries with embeddings, verify end-to-end RAG retrieval (embed query + search + format) completes under 500ms
  - [x] 6.6 Test token budget enforcement: 5 long summaries that exceed ~4000 chars → verify truncation to budget
  - [x] 6.7 Update project.yml if new files added (XcodeGen source of truth)
  - [x] 6.8 Run full test suite — maintain 242+ test baseline

## Dev Notes

### Architecture Compliance

**Change Chain (7-step minimum for schema changes):**
1. `ChatRequest.swift` (iOS model) — add ragContext field
2. `provider.go` (server model) — add RagContext field to ChatRequest
3. `chat.go` (server handler) — parse ragContext, pass to builder
4. `builder.go` (server prompt) — substitute ragContext into template
5. `context-injection.md` (prompt section) — add retrieved_memories slot with instructions
6. `anthropic.go` (provider) — memoryReferenced already in tool schema, verify it flows
7. `ChatEvent.swift` (iOS) — parse memoryReferenced from done event
8. `CoachingViewModel.swift` — retrieve context, build request, handle response flag
9. `DialogueTurnView` — render memory reference styling

**Critical Patterns to Follow:**
- `@MainActor @Observable final class` for any new ViewModels
- GRDB models require: `FetchableRecord, PersistableRecord, Identifiable, Sendable`
- Swift Testing framework (`@Suite`, `@Test`, `#expect()`) — never XCTest
- StrictConcurrency: capture `let` bindings from GRDB write closures
- Fire-and-forget pattern for non-blocking async work (RAG retrieval must NOT block UI)
- Error handling: local/silent with `os.Logger`, no global AppState routing for memory errors
- DI wiring in `RootView.ensureCoachingViewModel()` — EmbeddingPipeline already injected

**Server Patterns:**
- Go 1.26.1, net/http stdlib only
- Anthropic SDK v1.27.0 for structured output
- Tool-use pattern for structured output (respond tool)
- `omitempty` on optional JSON fields
- Builder template substitution with `strings.ReplaceAll`

### What Already Exists (DO NOT Recreate)

**iOS Layer:**
- `EmbeddingPipeline` (`ios/sprinty/Services/Memory/EmbeddingPipeline.swift`) — `search(query:limit:) async throws -> [ConversationSummary]`, ranked by vector distance. Use directly.
- `VectorSearch` (`ios/sprinty/Services/Database/VectorSearch.swift`) — sqlite-vec wrapper, `query(embedding:limit:)` → rowids + distances. Integrated into EmbeddingPipeline.
- `EmbeddingService` (`ios/sprinty/Services/Memory/EmbeddingService.swift`) — Core ML all-MiniLM-L6-v2, 384-dim. Used by EmbeddingPipeline.
- `ConversationSummary` (`ios/sprinty/Models/ConversationSummary.swift`) — summary, keyMoments, domainTags, emotionalMarkers, keyDecisions, embedding. JSON-encoded arrays. Has `.recent()` query helper.
- `UserProfile` + `ProfileUpdateService` — fully wired from Story 3.3. DI in `RootView.ensureCoachingViewModel()`.
- `CoachingViewModel` (`ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift`) — embeddingPipeline already injected (optional). Calls `embeddingPipeline.embed()` post-summary. Add search call pre-chat.

**Server Layer:**
- `anthropic.go` (`server/providers/anthropic.go`) — `memoryReferenced` boolean in respond tool schema (line ~41, required field, defaults false). Parsed in toolResult struct (line ~126). Passed to ChatEvent (line ~270). LLM just needs prompt instructions to set it true.
- `builder.go` (`server/prompts/builder.go`) — current signature: `Build(mode string, coachName string, profile *ChatProfile, userState *UserState) string`. Template substitution via `strings.ReplaceAll`. Must add ragContext param.
- `context-injection.md` (`server/prompts/sections/context-injection.md`) — exists with profile/engagement template slots. Modify to add `{{retrieved_memories}}`.

### What Must Be Added/Modified

**iOS — New Code:**
- RAG context formatting function (convert `[ConversationSummary]` → prompt string with token budget)
- Recency weighting logic (re-rank after vector search)
- Daily greeting generator with template variants (topic/emotion/gap-aware)
- Transient `[UUID: Bool]` dictionary in CoachingViewModel for memoryReferenced per message

**iOS — Modifications:**
- `ChatRequest.swift` (`ios/sprinty/Features/Coaching/Models/ChatRequest.swift`): Add `ragContext: String?` field
- `ChatEvent.swift` (`ios/sprinty/Features/Coaching/Models/ChatEvent.swift`): Add `memoryReferenced: Bool` to `.done` case (currently missing)
- `SSEParser.swift` (`ios/sprinty/Services/Networking/SSEParser.swift`): Parse `memoryReferenced` from done event JSON
- `CoachingViewModel.swift`: Add retrieveRAGContext(), store memoryReferenced per response, add greeting logic with 500ms timeout
- `DialogueTurnView.swift` (`ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift`): Add `memoryReferenced: Bool` parameter, italic + 0.7 opacity styling, accessibility hint

**Server — Modifications:**
- `provider.go` (`server/providers/provider.go`): Add `RagContext string \`json:"ragContext,omitempty"\`` to ChatRequest struct
- `chat.go` (`server/handlers/chat.go`): Parse ragContext from request, pass to updated builder.Build() call (line ~55)
- `builder.go` (`server/prompts/builder.go`): Add `ragContext string` param to Build() signature, add `strings.ReplaceAll(result, "{{retrieved_memories}}", ragContext)`
- `context-injection.md` (`server/prompts/sections/context-injection.md`): Add `{{retrieved_memories}}` block with LLM instructions for natural memory referencing, pattern surfacing, honest memory gap handling, and memoryReferenced flag usage

**Docs:**
- `docs/api-contract.md`: Add ragContext (string, optional) to POST /v1/chat request schema

**Note on field naming:** Epics spec uses snake_case `memory_reference` for readability in given-when-then format. Go struct uses PascalCase `MemoryReferenced`. JSON/iOS uses camelCase `memoryReferenced`. All refer to the same field. The ragContext field is a formatted String in the API, not an array (architecture diagram shows array notation for visual clarity but implementation is a prompt string).

### RAG Context Format

Format retrieved summaries for the prompt as:

```
## Past Conversations (most relevant)

[If lastSessionGapHours > 72: "User returning after [N] days away."]

**[Date]** — [Domain Tags]
Summary: [summary text]
Key moments: [key moments]

**[Date]** — [Domain Tags]
Summary: [summary text]
Key moments: [key moments]
```

Token budget: ~1000 tokens (~4000 characters). Measure via character count (rough 4:1 ratio). If over budget, drop entries from the bottom (least-relevant after recency re-ranking). If ALL entries together are under budget, include all 5.

### Recency Weighting Strategy

EmbeddingPipeline.search() returns results ranked by vector distance (pure semantic similarity). Apply a recency re-ranking step after retrieval:
- Compute a combined score: `score = (1 - normalizedDistance) * 0.7 + recencyBonus * 0.3`
- `recencyBonus` = 1.0 for today, decaying linearly to 0.0 over 30 days
- Re-sort by combined score descending
- This ensures semantically relevant AND recent summaries rank highest

### Daily Greeting Strategy

The greeting is NOT an LLM call. Pre-generated on conversation view load (before user interaction).

**Template variants** (select based on available data):

1. **Topic-based** (default, when key moments available): "Last time we talked about [first key moment]. How's that going?"
2. **Emotion-based** (when emotional markers available): "You seemed [emotional marker] last time — how are things now?"
3. **Gap-aware** (when lastSessionGapHours > 72): "It's been a few days — what's been on your mind?"
4. **Cold start** (no summaries exist): "What's on your mind?" (warm default)

**Timing:** Pre-fetch on conversation view appear. If generation exceeds 500ms, show fallback immediately. If user navigates to conversation before pre-fetch completes, use 500ms timeout then fallback. Greeting is inserted as the first coach turn with "Today" date separator above it.

### Performance Requirements

- RAG retrieval (embed query + vector search + fetch summaries + format): < 500ms total (NFR5)
- EmbeddingPipeline.search() benchmarked at ~118ms for 10K summaries (Story 3.2) — well within budget
- Recency re-ranking: negligible (in-memory sort of 5 items)
- Token budget check: negligible (character count comparison)
- Daily greeting generation: < 500ms with hard timeout (string template, no network)
- No UI blocking — RAG retrieval runs async, greeting pre-fetches on view appear
- NFR18 validation: must test at 10K synthetic embeddings to confirm end-to-end stays under 500ms

### Previous Story Intelligence

**From Story 3.3 (User Profile & Domain State):**
- ProfileUpdate model and service fully implemented
- Fire-and-forget pattern for enrichment established
- Merge logic with dedup and validation caps in place
- DI wiring pattern: create in RootView, inject to CoachingViewModel
- Code review identified: move shared models to ios/sprinty/Models/ (not feature-specific)
- 242 tests baseline (20 added in 3.3)

**From Story 3.2 (Embedding Pipeline):**
- Dual-database architecture: GRDB (main) + VectorSearch (separate sprinty-vectors.sqlite)
- Rowid mapping via `db.lastInsertedRowID` for vector↔summary correlation
- Batch fetch pattern: `WHERE rowid IN (?)` to avoid N+1
- Performance: embed ~101ms, query ~118ms at 10K — well under 500ms NFR
- StrictConcurrency: capture `let` bindings from GRDB write closures
- Write order: VectorSearch before GRDB (if vec insert fails, no orphan summary)

**From Story 3.1 (Conversation Summaries):**
- ConversationSummary model with JSON-encoded array columns
- Migration v5 pattern (append-only sequential)
- Post-conversation pipeline: fire-and-forget `Task` (not awaited)
- Summarization via `/v1/chat` with `mode: "summarize"`
- SQL LIKE escaping required for search queries

### Project Structure Notes

- iOS source of truth: `project.yml` (XcodeGen) — update if adding new files
- API contract source of truth: `docs/api-contract.md` — update with ragContext
- Server prompts: `server/prompts/sections/` — modular markdown files
- Models shared between features go in `ios/sprinty/Models/`
- Feature-specific models in `ios/sprinty/Features/{Feature}/Models/`
- Tests in `ios/Tests/` mirroring source structure
- Mocks in `ios/Tests/Mocks/`

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3, Story 3.4]
- [Source: _bmad-output/planning-artifacts/architecture.md — Persistent Intelligence Layer, Memory Pipeline, RAG Retrieval Flow]
- [Source: _bmad-output/planning-artifacts/prd.md — FR6, FR12, FR15, NFR5, NFR18]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR51, UX-DR54, UX-DR55]
- [Source: _bmad-output/implementation-artifacts/3-3-user-profile-and-domain-state.md — Previous story learnings]
- [Source: _bmad-output/implementation-artifacts/3-2-embedding-pipeline-and-vector-storage.md — Pipeline architecture and performance benchmarks]
- [Source: _bmad-output/implementation-artifacts/3-1-conversation-summaries-and-key-moments.md — Summary model and patterns]
- [Source: _bmad-output/project-context.md — Project rules and conventions]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- No blocking issues encountered during implementation

### Completion Notes List
- Task 1: Added `ragContext: String?` to ChatRequest (iOS + Go), updated API contract with ragContext field and memoryReferenced doc
- Task 2: Built RAG context retrieval with recency weighting (0.7 semantic + 0.3 recency), token budget enforcement (~4000 chars), gap detection (>72h), graceful error fallback. Updated ChatServiceProtocol to pass ragContext through
- Task 3: Added `{{retrieved_memories}}` template to context-injection.md with LLM instructions for natural memory referencing, pattern surfacing, honest gap handling. Updated builder.Build() signature and chat handler
- Task 4: Added memoryReferenced to ChatEvent.done case, DoneEventData, ViewModel transient dictionary, DialogueTurnView with italic + 0.7 opacity + accessibility hints. Added memoryReferenced to SSE done event payload in chat handler
- Task 5: Built daily greeting generator with template variants (topic/emotion/gap-aware/cold-start), 500ms timeout via TaskGroup racing, pre-generation on conversation view load
- Task 6: Full test suite 263 tests (21 new, from 242 baseline). All iOS and Go tests pass. No new files added, project.yml unchanged

### Change Log
- Story 3.4 implementation completed: 2026-03-21
- Code review fixes applied: 2026-03-21
  - Fixed greeting template priority: topic-based now default over emotion-based per spec (CoachingViewModel.swift)
  - Fixed greeting race condition: CoachingView now awaits loadMessagesAsync() before generateDailyGreeting()
  - Strengthened long-gap RAG test to assert gap duration string in ragContext (CoachingViewModelTests.swift)

### File List
- ios/sprinty/Features/Coaching/Models/ChatRequest.swift (modified — added ragContext field)
- ios/sprinty/Features/Coaching/Models/ChatEvent.swift (modified — added memoryReferenced to done case)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified — RAG retrieval, recency weighting, greeting, memoryReferenced tracking)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified — daily greeting display, memoryReferenced passthrough)
- ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift (modified — memoryReferenced param, italic/opacity styling, accessibility)
- ios/sprinty/Services/Networking/ChatServiceProtocol.swift (modified — added ragContext param)
- ios/sprinty/Services/Networking/ChatService.swift (modified — added ragContext param)
- ios/sprinty/App/RootView.swift (modified — updated FailingChatService conformance)
- ios/Tests/Models/CodableRoundtripTests.swift (modified — added ragContext encoding tests)
- ios/Tests/Models/ChatEventCodableTests.swift (modified — added memoryReferenced tests, updated pattern matching)
- ios/Tests/Services/SSEParserTests.swift (modified — updated pattern matching for new done case)
- ios/Tests/Features/CoachingViewModelTests.swift (modified — 12 new tests for RAG, greeting, memoryReferenced, integration)
- ios/Tests/Mocks/MockChatService.swift (modified — added ragContext recording)
- server/providers/provider.go (modified — added RagContext to ChatRequest)
- server/prompts/sections/context-injection.md (modified — added {{retrieved_memories}} with LLM instructions)
- server/prompts/builder.go (modified — added ragContext param to Build(), template substitution)
- server/prompts/builder_test.go (modified — updated Build() calls, added ragContext tests)
- server/handlers/chat.go (modified — pass ragContext to builder, added memoryReferenced to done event)
- server/tests/handlers_test.go (modified — added ragContext and memoryReferenced tests)
- docs/api-contract.md (modified — added ragContext and memoryReferenced docs)
