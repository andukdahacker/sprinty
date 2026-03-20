# Story 3.1: Conversation Summaries & Key Moments

Status: done

## Story

As a user who has coaching conversations,
I want the system to automatically capture what we discussed — key moments, emotions, decisions, and topics,
So that important insights are preserved even as conversations grow long.

## Acceptance Criteria

1. **Given** a coaching conversation ends (user navigates away or session times out), **When** the system processes the conversation, **Then** a `ConversationSummary` is generated containing: summary text, key moments, emotional markers, key decisions, and domain tags. The summary is stored in SQLite (`ConversationSummary` table with all fields). Domain tags categorize the conversation by life domain (career, relationships, health, finance, etc.).

2. **Given** the summary generation process, **When** processing a conversation, **Then** the summary captures the substance of the exchange, not just a transcript reduction. Key moments identify turning points, breakthroughs, or important realizations. Emotional markers note the user's emotional trajectory during the session.

3. **Given** a user with many conversations over time, **When** summaries accumulate, **Then** query performance remains under 500ms with up to 10,000 summaries (NFR18).

## Tasks / Subtasks

- [x] Task 1: ConversationSummary GRDB model (AC: #1, #3)
  - [x] 1.1 Create `ConversationSummary.swift` in `ios/sprinty/Models/` with all fields from architecture schema
  - [x] 1.2 Add GRDB migration v5 for `ConversationSummary` table in `Migrations.swift`
  - [x] 1.3 Add query extensions: `forSession(id:)`, `recent(limit:)`, `forDomainTag(_:)`
  - [x] 1.4 Add JSON encode/decode helpers for array columns (`keyMoments`, `domainTags`, etc.)
  - [x] 1.5 Write model tests: CRUD, JSON round-trip, query extensions (use `makeTestDB()` returning `DatabaseManager`)

- [x] Task 2: Session lifecycle management (AC: #1)
  - [x] 2.1 Add `endSession()` method to `CoachingViewModel` — sets `endedAt` on `currentSession` and persists
  - [x] 2.2 Wire `endSession()` to view lifecycle: call from `CoachingView.onDisappear` (or navigation callback)
  - [x] 2.3 Guard: only end session if it has at least 2 messages (1 user + 1 assistant)
  - [x] 2.4 Ensure `getOrCreateSession()` creates a new session on next coaching view appearance after a session was ended
  - [x] 2.5 Write ViewModel tests for session end lifecycle

- [x] Task 3: SummaryGenerator service — on-device LLM call (AC: #1, #2)
  - [x] 3.1 Create `SummaryGeneratorProtocol.swift` in `ios/sprinty/Services/Memory/`
  - [x] 3.2 Create `SummaryGenerator.swift` — calls `/v1/chat` with a summarization system prompt to extract structured summary
  - [x] 3.3 Add `summarize(messages:mode:)` method to `ChatServiceProtocol`, `ChatService`, `MockChatService`, and `FailingChatService` (in `RootView.swift`)
  - [x] 3.4 The summarize method is a non-streaming POST to `/v1/chat` that returns the `done` event's structured fields (reuses existing infrastructure)
  - [x] 3.5 Build summarization system prompt (see Dev Notes for prompt spec)
  - [x] 3.6 Parse LLM structured response into ConversationSummary fields
  - [x] 3.7 Write tests with MockChatService for summary generation

- [x] Task 4: Server — summarization system prompt (AC: #2)
  - [x] 4.1 Create `server/prompts/sections/summarize.md` with summarization instructions
  - [x] 4.2 Extend `Builder` to load and expose the summarize prompt section (separate from chat assembly)
  - [x] 4.3 Modify `ChatHandler` (or add a mode flag) so when `mode: "summarize"` is received, the handler uses the summarize prompt instead of coaching prompts and returns a single non-streaming JSON response
  - [x] 4.4 Define a `summarize` tool schema in `anthropic.go` for structured summary extraction (separate from the `respond` tool schema)
  - [x] 4.5 Update `docs/api-contract.md` with the summarize mode documentation
  - [x] 4.6 Write handler tests for summarize mode and builder tests for summarize prompt loading

- [x] Task 5: Post-conversation pipeline trigger (AC: #1)
  - [x] 5.1 In `endSession()`, fire-and-forget `Task { await generateSummary(for: session) }` — not awaited on navigation
  - [x] 5.2 `generateSummary` calls SummaryGenerator → parses response → persists ConversationSummary via GRDB
  - [x] 5.3 Handle failures gracefully: log error at `Logger.memory.error`, no user-facing error
  - [x] 5.4 Retry on next launch: on app start, query for sessions with `endedAt != nil` and no matching ConversationSummary, attempt regeneration
  - [x] 5.5 Write ViewModel tests for pipeline trigger, error handling, and retry logic

- [x] Task 6: End-to-end validation (AC: #1, #2, #3)
  - [x] 6.1 Integration test: send messages → end session → verify ConversationSummary persisted with correct fields
  - [x] 6.2 Verify summary quality: key moments are turning points not transcript lines
  - [x] 6.3 Verify domain tags are from expected set (career, relationships, health, finance, personal-growth, creativity, education, family)
  - [x] 6.4 Query performance test with bulk inserts (100+ summaries)
  - [x] 6.5 Run `xcodegen generate` and verify all 185+ Swift tests and all Go tests pass

## Dev Notes

### What This Story Does vs Does NOT Do

**DOES:**
- Creates the `ConversationSummary` GRDB model with ALL fields (including Phase 2 fields as nil)
- Adds migration v5 for the ConversationSummary table
- Creates session lifecycle management (`endSession()`) — currently missing from CoachingViewModel
- Creates `SummaryGenerator` service that calls cloud LLM via existing `/v1/chat` endpoint
- Adds a `summarize` mode to the existing chat infrastructure (no new server endpoint)
- Triggers post-conversation pipeline when user ends a session
- Persists summaries to local SQLite via GRDB
- Handles pipeline failures gracefully (best-effort with retry on next launch)

**DOES NOT:**
- Generate embeddings (Story 3.2 — embedding pipeline)
- Store vectors in sqlite-vec (Story 3.2)
- Create or update UserProfile (Story 3.3)
- Retrieve summaries for RAG context injection (Story 3.4)
- Display summaries in conversation history UI (Story 3.5)
- Add search functionality (Story 3.6)
- Create MemoryView UI (Story 3.7)
- Add any new server endpoints — reuses existing `/v1/chat` with a `summarize` mode
- Add any new fields to the existing `ChatEvent` done event for coaching conversations

### Architecture Compliance

**ConversationSummary Schema (from architecture.md):**
```
ConversationSummary
  id: UUID
  sessionId: UUID (FK → ConversationSession)
  summary: String
  keyMoments: [String]           ← stored as JSON-encoded String column
  domainTags: [String]           ← stored as JSON-encoded String column
  emotionalMarkers: [String]?    ← Phase 2, nullable, JSON-encoded String?
  keyDecisions: [String]?        ← Phase 2, nullable, JSON-encoded String?
  goalReferences: [String]?      ← Phase 2, nullable, JSON-encoded String?
  embedding: Data? (384-dim)     ← NULL until Story 3.2
  createdAt: Date
```

**CRITICAL — JSON Array Column Pattern:** The codebase stores arrays as `String`/`String?` with manual JSON encoding — NOT as native `[String]`. Follow the exact pattern from `ConversationSession.modeHistory` and `moodHistory`:

```swift
struct ConversationSummary: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sessionId: UUID
    var summary: String
    var keyMoments: String            // JSON-encoded [String]
    var domainTags: String            // JSON-encoded [String]
    var emotionalMarkers: String?     // Phase 2, JSON-encoded [String]?
    var keyDecisions: String?         // Phase 2, JSON-encoded [String]?
    var goalReferences: String?       // Phase 2, JSON-encoded [String]?
    var embedding: Data?              // 384-dim float array, nullable until Story 3.2
    var createdAt: Date

    static let databaseTableName = "ConversationSummary"
}

// JSON encode/decode helpers (follow modeHistory/moodHistory pattern):
extension ConversationSummary {
    var decodedKeyMoments: [String] {
        guard let data = keyMoments.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return decoded
    }

    var decodedDomainTags: [String] {
        guard let data = domainTags.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return decoded
    }

    static func encodeArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
```

**Migration v5 (append-only, sequential — follows v4 in Migrations.swift):**
```swift
migrator.registerMigration("v5") { db in
    try db.create(table: "ConversationSummary") { t in
        t.primaryKey("id", .text).notNull()
        t.column("sessionId", .text).notNull()
            .references("ConversationSession", onDelete: .cascade)
        t.column("summary", .text).notNull()
        t.column("keyMoments", .text).notNull()      // JSON array
        t.column("domainTags", .text).notNull()       // JSON array
        t.column("emotionalMarkers", .text)           // Phase 2, nullable
        t.column("keyDecisions", .text)               // Phase 2, nullable
        t.column("goalReferences", .text)             // Phase 2, nullable
        t.column("embedding", .blob)                  // 384-dim, nullable until 3.2
        t.column("createdAt", .datetime).notNull()
    }
    try db.create(index: "ConversationSummary_sessionId",
                  on: "ConversationSummary", columns: ["sessionId"])
}
```

**Database Naming Conventions:**
- Table: `ConversationSummary` (PascalCase singular)
- Columns: camelCase (`sessionId`, `keyMoments`, `domainTags`, `emotionalMarkers`, `keyDecisions`, `goalReferences`, `createdAt`)
- Foreign key: `sessionId` → `ConversationSession.id` with cascade delete
- Primary key: `id` (UUID as text)

**File Locations:**
| File | Location | Reason |
|------|----------|--------|
| `ConversationSummary.swift` | `ios/sprinty/Models/` | GRDB record = root Models (shared resource) |
| `SummaryGeneratorProtocol.swift` | `ios/sprinty/Services/Memory/` | Alongside existing EmbeddingService |
| `SummaryGenerator.swift` | `ios/sprinty/Services/Memory/` | Alongside existing EmbeddingService |
| `summarize.md` | `server/prompts/sections/` | Prompt section for summarization |
| `ConversationSummaryTests.swift` | `ios/Tests/Models/` | Model tests |
| `SummaryGeneratorTests.swift` | `ios/Tests/Services/` | Service tests |

### SummaryGenerator — On-Device Cloud LLM Call

The architecture specifies: `SummaryGenerator → cloud LLM call for summary`. This is an **on-device initiated call** through the existing `/v1/chat` endpoint — NOT a separate server endpoint. The architecture lists exactly 5 endpoints (`/health`, `/v1/auth/register`, `/v1/auth/refresh`, `/v1/chat`, `/v1/prompt/{version}`) and no `/v1/summarize`.

**Approach:** Reuse `/v1/chat` with `mode: "summarize"`. The server detects this mode, uses the summarize prompt + a `summarize` tool schema, and returns a single non-streaming JSON response instead of SSE.

**Summarize Tool Schema (for `anthropic.go`):**
```go
var summarizeToolSchema = anthropic.ToolParam{
    Name:        "summarize_conversation",
    Description: anthropic.String("Extract a structured summary from a coaching conversation."),
    InputSchema: anthropic.ToolInputSchemaParam{
        Properties: map[string]any{
            "summary": map[string]any{
                "type":        "string",
                "description": "2-4 sentence substantive summary capturing the essence of the exchange.",
            },
            "keyMoments": map[string]any{
                "type":  "array",
                "items": map[string]any{"type": "string"},
                "description": "1-5 turning points, breakthroughs, or important realizations.",
            },
            "domainTags": map[string]any{
                "type":  "array",
                "items": map[string]any{"type": "string", "enum": []string{
                    "career", "relationships", "health", "finance",
                    "personal-growth", "creativity", "education", "family",
                }},
                "description": "1-3 life domains this conversation touches.",
            },
            "emotionalMarkers": map[string]any{
                "type":  "array",
                "items": map[string]any{"type": "string"},
                "description": "Emotional trajectory markers (e.g., frustrated, hopeful, relieved).",
            },
            "keyDecisions": map[string]any{
                "type":  "array",
                "items": map[string]any{"type": "string"},
                "description": "Decisions or commitments the user made during the session.",
            },
        },
        Required: []string{"summary", "keyMoments", "domainTags"},
    },
}
```

**Summarization Prompt (`summarize.md`) should instruct the LLM to:**
1. Write a 2-4 sentence substantive summary (not transcript reduction)
2. Identify 1-5 key moments — turning points, breakthroughs, realizations
3. Tag 1-3 life domains from the enum set
4. Note emotional trajectory markers if clearly present
5. Capture key decisions if any were made
6. Focus on the user's experience, not the coach's responses

**iOS ChatService Extension:**
```swift
// Add to ChatServiceProtocol:
func summarize(messages: [ChatRequestMessage], mode: String) async throws -> SummaryResponse

// SummaryResponse (in Features/Coaching/Models/ or Services/Memory/):
struct SummaryResponse: Codable, Sendable {
    let summary: String
    let keyMoments: [String]
    let domainTags: [String]
    let emotionalMarkers: [String]?
    let keyDecisions: [String]?
}
```

The `summarize` method sends a POST to `/v1/chat` with `mode: "summarize"`, reads a single JSON response (not SSE), and decodes into `SummaryResponse`.

**CRITICAL: Update ALL protocol conformers when adding `summarize` to ChatServiceProtocol:**
- `ChatService.swift` — real implementation
- `MockChatService.swift` in `ios/Tests/Mocks/` — add `stubbedSummaryResponse` and `stubbedSummaryError`
- `FailingChatService` in `ios/sprinty/App/RootView.swift` — add throwing stub

### Session Lifecycle (Currently Missing)

`CoachingViewModel` currently has NO `endSession()` method and NO `onDisappear` handling. Sessions are created via `getOrCreateSession()` but never explicitly closed (`endedAt` stays nil). This story must create the session end mechanism.

**Implementation Pattern:**
```swift
// In CoachingViewModel:
func endSession() async {
    guard let session = currentSession, session.endedAt == nil else { return }

    // 1. Close the session
    var updatedSession = session
    updatedSession.endedAt = Date()
    try? await databaseManager.dbPool.write { db in
        try updatedSession.update(db)
    }
    currentSession = nil

    // 2. Fire-and-forget summary generation
    let sessionId = session.id
    Task { [weak self] in
        await self?.generateSummary(for: sessionId)
    }
}

private func generateSummary(for sessionId: UUID) async {
    do {
        let messages = try await databaseManager.dbPool.read { db in
            try Message.forSession(id: sessionId).fetchAll(db)
        }
        guard messages.count >= 2 else { return }

        let chatMessages = messages.map { ChatRequestMessage(role: $0.role.rawValue, content: $0.content) }
        let response = try await chatService.summarize(messages: chatMessages, mode: "summarize")

        let summary = ConversationSummary(
            id: UUID(),
            sessionId: sessionId,
            summary: response.summary,
            keyMoments: ConversationSummary.encodeArray(response.keyMoments),
            domainTags: ConversationSummary.encodeArray(response.domainTags),
            emotionalMarkers: response.emotionalMarkers.map { ConversationSummary.encodeArray($0) },
            keyDecisions: response.keyDecisions.map { ConversationSummary.encodeArray($0) },
            goalReferences: nil,
            embedding: nil,
            createdAt: Date()
        )

        try await databaseManager.dbPool.write { db in
            try summary.insert(db)
        }
    } catch {
        Logger.memory.error("Summary generation failed for session \(sessionId): \(error)")
    }
}
```

**Retry on launch:** On app start, query for sessions with `endedAt != nil` but no matching `ConversationSummary.sessionId`. Attempt regeneration. This handles app backgrounding during generation.

**View wiring:** Call `endSession()` from `CoachingView.onDisappear` or the navigation callback that triggers when the user leaves the coaching view.

### Post-Conversation Pipeline (architecture data flow)

```
Session Ends → endSession() → set endedAt → fire-and-forget Task:
    ├── SummaryGenerator.generate() → POST /v1/chat (mode: "summarize") → LLM structured output
    ├── Parse SummaryResponse → build ConversationSummary
    └── GRDB write (best-effort, log errors, no user-facing failure)
```

Async and best-effort. If any step fails, log at Error level (`os.Logger`). The session and messages are already persisted — the summary is additive.

### Testing Standards

**Swift Tests (Swift Testing framework, NOT XCTest):**

Model tests — use `makeTestDB()` returning `DatabaseManager`:
```swift
@Suite struct ConversationSummaryTests {
    @Test func insertAndFetch() async throws {
        let dbManager = try makeTestDB()
        // Create session first (FK dependency), then insert summary
        #expect(fetched.summary == "test summary")
    }
    @Test func forSessionQuery() async throws { ... }
    @Test func jsonRoundTrip_keyMoments() async throws { ... }
}
```

Service tests — use `makeTestDB()` returning `DatabasePool` (like `EngagementCalculatorTests`):
```swift
@Suite struct SummaryGeneratorTests {
    @Test func generateSummary_success() async throws { ... }
    @Test func generateSummary_networkError_logsAndReturns() async throws { ... }
}
```

ViewModel tests — `@Test @MainActor`:
```swift
@Test @MainActor func endSession_triggersAndPersistsSummary() async throws { ... }
@Test @MainActor func endSession_fewerThan2Messages_skipsSummary() async throws { ... }
@Test @MainActor func retryOnLaunch_generatesMissingSummaries() async throws { ... }
```

**Go Tests (PascalCase naming: `Test<Component><Scenario>`):**
```go
func TestChatHandler_SummarizeMode_ReturnsJSON(t *testing.T) { ... }
func TestChatHandler_SummarizeMode_EmptyMessages(t *testing.T) { ... }
func TestBuilder_SummarizePrompt_Loads(t *testing.T) { ... }
```
Update `setupMuxWithBuilder()` in `server/tests/handlers_test.go` — no new route needed since we reuse `/v1/chat`.
Update `setupTestSections()` in `server/prompts/builder_test.go` to include `summarize.md`.

- Use `#expect()` assertions, NOT `XCTAssert`
- NEVER mock GRDB — use real in-memory test DB
- Test both success AND error paths
- Maintain 185+ Swift test baseline and all Go tests passing

### Critical: Xcodegen Requirement

After creating any new `.swift` files, regenerate the Xcode project:
```bash
cd ios && xcodegen generate
```
Never edit `.xcodeproj` directly.

### Project Structure Notes

- All new files follow existing folder conventions
- `ConversationSummary.swift` in root `Models/` (GRDB records = shared resource per architecture rule)
- `SummaryGenerator` in `Services/Memory/` alongside existing `EmbeddingService.swift` and `WordPieceTokenizer.swift`
- No new server endpoints — reuses `/v1/chat` with mode differentiation
- No new iOS dependencies — uses existing GRDB, networking stack

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Database Schema, ConversationSummary definition]
- [Source: _bmad-output/planning-artifacts/architecture.md — iOS Project Structure, Services/Memory/ and Models/]
- [Source: _bmad-output/planning-artifacts/architecture.md — Post-Conversation Pipeline: "SummaryGenerator → cloud LLM call for summary"]
- [Source: _bmad-output/planning-artifacts/architecture.md — Memory Pipeline Reliability: "best-effort with idempotent retry on next launch"]
- [Source: _bmad-output/planning-artifacts/architecture.md — 5 API Endpoints (no /v1/summarize)]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3 Story 3.1 acceptance criteria and BDD]
- [Source: _bmad-output/planning-artifacts/prd.md — FR11: conversation summaries with key moments]
- [Source: _bmad-output/planning-artifacts/prd.md — NFR18: 10K summaries query performance]
- [Source: _bmad-output/project-context.md — GRDB model conventions, migration rules, testing rules]
- [Source: ios/sprinty/Models/ConversationSession.swift — JSON array column pattern (modeHistory/moodHistory as String?)]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — no endSession() exists, must be created]
- [Source: ios/sprinty/App/RootView.swift — FailingChatService must match protocol changes]
- [Source: ios/Tests/Mocks/MockChatService.swift — must add summarize stub]

### Previous Story Intelligence (from Story 2.5)

**Critical patterns to follow:**
- `Builder.Build()` signature changes require updating ALL 3 test helpers simultaneously (2 in builder_test.go, 1 in handlers_test.go)
- GRDB migrations are append-only and sequential — next migration is v5
- When adding new files, run `xcodegen generate` to regenerate project
- ChatRequest memberwise init issues — if adding fields, provide explicit init with defaults
- All `MockChatService` / `FailingChatService` implementations must match protocol changes
- 185 Swift tests and all Go tests were passing after Story 2.5 — maintain this baseline
- JSON-encoded array columns: use `String`/`String?` with manual `JSONEncoder`/`JSONDecoder` (NOT native `[String]`)

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- StrictConcurrency fix: captured `var updatedSession` needed `let sessionToSave` binding before closure
- Logger.memory doesn't exist in project — used `Logger(subsystem:category:)` directly

### Completion Notes List
- Task 1: ConversationSummary GRDB model with v5 migration, JSON array helpers, query extensions (forSession, recent, forDomainTag), 15 tests
- Task 2: Session lifecycle — endSession() with 2-message guard, wired to CoachingView.onDisappear, 3 tests
- Task 3: SummaryGenerator service with SummaryGeneratorProtocol, SummaryResponse model, summarize() added to ChatServiceProtocol/ChatService/MockChatService/FailingChatService, 3 tests
- Task 4: Server summarize mode — summarize.md prompt, Builder.SummarizePrompt(), handleSummarize() in ChatHandler, summarizeToolSchema in anthropic.go, MockProvider summarize support, API contract updated, 3 Go tests
- Task 5: Post-conversation pipeline — fire-and-forget generateSummary(), retryMissingSummaries(), graceful error logging, 3 tests
- Task 6: Full regression pass — 209 Swift tests (24 new) and all Go tests passing

### Change Log
- Story 3.1 implemented: 2026-03-20
- Code review fixes applied: 2026-03-20
  - [C1] AnthropicProvider.StreamChat now branches on summarize mode — uses summarizeToolSchema + parseSummarizeResult
  - [H1] Added bulk insert performance test (150 summaries) to ConversationSummaryTests
  - [M1] forDomainTag escapes SQL LIKE wildcards (% and _) in tag values
  - [M2] retryMissingSummaries uses LEFT JOIN instead of N+1 query pattern

### File List
- ios/sprinty/Models/ConversationSummary.swift (new, review-fixed — LIKE escape)
- ios/sprinty/Services/Database/Migrations.swift (modified — v5 migration)
- ios/sprinty/Services/Memory/SummaryGeneratorProtocol.swift (new)
- ios/sprinty/Services/Memory/SummaryGenerator.swift (new)
- ios/sprinty/Services/Memory/SummaryResponse.swift (new)
- ios/sprinty/Services/Networking/ChatServiceProtocol.swift (modified — summarize method)
- ios/sprinty/Services/Networking/ChatService.swift (modified — summarize implementation)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified, review-fixed — LEFT JOIN for retryMissingSummaries)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified — onDisappear wiring)
- ios/sprinty/App/RootView.swift (modified — FailingChatService summarize)
- ios/Tests/Models/ConversationSummaryTests.swift (new, review-fixed — 16 tests including perf test)
- ios/Tests/Services/SummaryGeneratorTests.swift (new — 3 tests)
- ios/Tests/Features/CoachingViewModelTests.swift (modified — 6 new tests)
- ios/Tests/Mocks/MockChatService.swift (modified — summarize stub)
- server/prompts/sections/summarize.md (new)
- server/prompts/builder.go (modified — summarize section, SummarizePrompt())
- server/prompts/builder_test.go (modified — 11 sections, SummarizePrompt test)
- server/handlers/chat.go (modified — handleSummarize)
- server/providers/anthropic.go (modified, review-fixed — summarize mode branching, parseSummarizeResult)
- server/providers/provider.go (modified — SummaryData field)
- server/providers/mock.go (modified — summarize mode support)
- server/tests/handlers_test.go (modified — 2 summarize tests, section updates)
- docs/api-contract.md (modified — summarize mode documentation)
