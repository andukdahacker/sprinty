# Story 3.2: Embedding Pipeline & Vector Storage

Status: done

## Story

As a user,
I want my past conversations to be semantically searchable,
So that the coach can find relevant context even when I don't use the exact same words.

## Acceptance Criteria (BDD)

### AC1: Summary Embedding Generation

```
Given a ConversationSummary is created (by Story 3.1 pipeline)
When the embedding pipeline processes it
Then the summary text is embedded using the all-MiniLM-L6-v2 Core ML model (384 dimensions)
And the embedding vector is stored in sqlite-vec alongside the summary
And the ConversationSummary.embedding field (Data?) is populated with the raw float bytes
And the embedding is generated on-device (no network, offline-capable)
```

### AC2: Vector Similarity Search

```
Given summaries with embeddings exist in sqlite-vec
When querying for similar past conversations with a text query
Then the query text is embedded using the same all-MiniLM-L6-v2 model
And vector similarity search returns ranked VectorSearchResult items
And retrieval completes within 500ms (NFR5) at up to 10,000 embeddings
And GRDB + sqlite-vec handle thread safety via existing lock patterns
```

### AC3: Failure Handling & Graceful Degradation

```
Given the embedding pipeline fails (Core ML error, dimension mismatch, etc.)
When processing a summary
Then the failure is logged at Error level via os.Logger
And the summary remains stored without an embedding (embedding field stays nil)
And the coach can still function using recency-based retrieval as fallback
And the failed summary is retried on next app launch
```

## Tasks / Subtasks

- [x] Task 1: EmbeddingPipeline service — orchestrates embed + store (AC: #1)
  - [x] 1.1 Create `EmbeddingPipelineProtocol` in `ios/sprinty/Services/Memory/EmbeddingPipelineProtocol.swift` with `func embed(summary: ConversationSummary, rowid: Int64) async throws` and `func search(query: String, limit: Int) async throws -> [ConversationSummary]`
  - [x] 1.2 Create `EmbeddingPipeline` in `ios/sprinty/Services/Memory/EmbeddingPipeline.swift` — accepts `EmbeddingServiceProtocol`, `VectorSearchProtocol`, `DatabaseManager`
  - [x] 1.3 Implement `embed(summary:rowid:)`: generate embedding via `EmbeddingService.generateEmbedding(for: summary.summary)`, convert `[Float]` to `Data`, update `ConversationSummary.embedding` in GRDB, insert into `VectorSearch` using the passed `rowid` (Int64)

- [x] Task 2: Integrate embedding into post-conversation pipeline (AC: #1)
  - [x] 2.1 Modify `CoachingViewModel.generateSummary(for:)`: inside the `dbPool.write` closure, after `summary.insert(db)`, capture `let rowid = db.lastInsertedRowID` and return it
  - [x] 2.2 After the write closure returns, call `try await embeddingPipeline.embed(summary: summary, rowid: rowid)` — this is OUTSIDE the GRDB write block
  - [x] 2.3 Wrap embedding call in do/catch — failure logged via os.Logger but does NOT propagate (summary is already persisted)
  - [x] 2.4 Wire `EmbeddingPipeline` (as `EmbeddingPipelineProtocol`) into `CoachingViewModel` via protocol injection (add to init params)

- [x] Task 3: DI wiring in RootView (AC: #1)
  - [x] 3.1 Create `EmbeddingService` instance in `RootView.ensureCoachingViewModel()` — load Core ML model from `Bundle.main.url(forResource:)` for `MiniLM.mlmodelc` and `vocab.txt`
  - [x] 3.2 Create `VectorSearch` instance with path `sprinty-vectors.sqlite` in the App Group container (`group.com.ducdo.sprinty`) — same container as GRDB's `sprinty.sqlite`
  - [x] 3.3 Call `vectorSearch.createTable()` during initialization to ensure `vec_items` table exists
  - [x] 3.4 Create `EmbeddingPipeline` with the above services + `databaseManager`
  - [x] 3.5 Pass `EmbeddingPipeline` to `CoachingViewModel` init

- [x] Task 4: Similarity search query method (AC: #2)
  - [x] 4.1 Implement `func search(query: String, limit: Int) async throws -> [ConversationSummary]` in `EmbeddingPipeline` (already declared on protocol in Task 1.1)
  - [x] 4.2 Embed the query text, call `VectorSearch.query()`, map rowids back to `ConversationSummary` records via GRDB raw SQL: `SELECT * FROM ConversationSummary WHERE rowid IN (?,?,...)`
  - [x] 4.3 Return summaries ordered by similarity (preserve VectorSearch distance ordering, lowest first)

- [x] Task 5: Retry missing embeddings on launch (AC: #3)
  - [x] 5.1 Add `func retryMissingEmbeddings() async` to `EmbeddingPipelineProtocol` and `EmbeddingPipeline`
  - [x] 5.2 Implementation: raw SQL `SELECT rowid, * FROM ConversationSummary WHERE embedding IS NULL` to get both the summary and its SQLite rowid in one query
  - [x] 5.3 For each result, call `embed(summary:rowid:)` — skip on failure, continue to next
  - [x] 5.4 Call from `CoachingViewModel` alongside existing `retryMissingSummaries()` on view appear

- [x] Task 6: ConversationSummary embedding helpers (AC: #1, #2)
  - [x] 6.1 Add `var decodedEmbedding: [Float]?` computed property to `ConversationSummary` — converts Data? to [Float]?
  - [x] 6.2 Add `static func encodeEmbedding(_ floats: [Float]) -> Data` helper — converts [Float] to raw Data bytes
  - [x] 6.3 Add query extension `static func withoutEmbedding()` — filters WHERE embedding IS NULL

- [x] Task 7: Tests (AC: #1, #2, #3)
  - [x] 7.1 `EmbeddingPipelineTests.swift` — test embed stores embedding in GRDB and sqlite-vec, test failure logs error and leaves embedding nil
  - [x] 7.2 `EmbeddingPipelineTests.swift` — test search returns ranked ConversationSummary results
  - [x] 7.3 `EmbeddingPipelineTests.swift` — test retryMissingEmbeddings processes only summaries with nil embedding
  - [x] 7.4 Create `MockEmbeddingService` and `MockVectorSearch` in `ios/Tests/Mocks/`
  - [x] 7.5 Create `MockEmbeddingPipeline` in `ios/Tests/Mocks/` implementing `EmbeddingPipelineProtocol`
  - [x] 7.6 Update `CoachingViewModelTests` — verify embedding pipeline called after summary generation

## Dev Notes

### Scope Boundaries

**DOES:**
- Create `EmbeddingPipeline` service to orchestrate embed + vector store
- Integrate embedding generation into the existing post-conversation pipeline (after summary creation in `CoachingViewModel.generateSummary`)
- Provide similarity search query method for downstream stories (3.4 RAG)
- Implement retry logic for failed embeddings
- Wire DI in RootView

**DOES NOT:**
- Create the embedding model or tokenizer (already exist from Story 1.7: `EmbeddingService.swift`, `WordPieceTokenizer.swift`)
- Create `VectorSearch` or `SQLiteVecKit` (already exist from Story 1.7)
- Create `ConversationSummary` model or migrations (already exist from Story 3.1, migration v5)
- Inject RAG context into chat requests (Story 3.4)
- Build any UI (Story 3.5, 3.6, 3.7)
- Add new server endpoints (no server changes needed)

### Architecture Compliance

**Existing code to REUSE (do NOT recreate):**
- `EmbeddingService` at `ios/sprinty/Services/Memory/EmbeddingService.swift` — Core ML all-MiniLM-L6-v2, returns `[Float]` (384-dim). Thread-safe via NSLock.
- `EmbeddingServiceProtocol` — already defined in same file: `func generateEmbedding(for text: String) throws -> [Float]`
- `VectorSearch` at `ios/sprinty/Services/Database/VectorSearch.swift` — sqlite-vec wrapper, `insert(rowid:embedding:)`, `query(embedding:limit:)`. Thread-safe via NSLock.
- `VectorSearchProtocol` — already defined: `createTable()`, `insert()`, `query()`, `count()`, `deleteAll()`
- `WordPieceTokenizer` at `ios/sprinty/Services/Memory/WordPieceTokenizer.swift`
- `SQLiteVecKit` local SPM package at `ios/Packages/SQLiteVecKit/`
- `ConversationSummary` model at `ios/sprinty/Models/ConversationSummary.swift` — already has `embedding: Data?` field (nullable, set to nil by Story 3.1)
- `DatabaseMigrations` at `ios/sprinty/Services/Database/Migrations.swift` — v5 already created ConversationSummary table with `embedding BLOB` column

**Dual-database architecture (CRITICAL):**
- GRDB manages `ConversationSummary` table (relational data + embedding blob) in the main SQLite database (`sprinty.sqlite`)
- `VectorSearch` (SQLiteVecKit) opens a **separate** SQLite database file for the `vec_items` virtual table — it uses `csvk_open(path)` with its own connection
- **VectorSearch database path:** `sprinty-vectors.sqlite` in the same App Group container (`group.com.ducdo.sprinty`) as the main GRDB database
- Embedding data is stored in BOTH: GRDB `ConversationSummary.embedding` (Data blob for persistence) AND sqlite-vec `vec_items` (for similarity search)
- The `vec_items` table is the search index; `ConversationSummary` is the source of truth

**Rowid mapping strategy (USE THIS APPROACH — no new migration needed):**
- `VectorSearch.insert(rowid:embedding:)` requires `Int64` rowid
- `ConversationSummary.id` is `UUID` (TEXT primary key) — not directly usable as rowid
- SQLite automatically assigns an integer `rowid` to every row, even with TEXT primary keys
- **Capture rowid on insert:** Inside `dbPool.write { db in }`, after `summary.insert(db)`, call `db.lastInsertedRowID` to get the Int64 rowid. Return it from the closure.
- **Pass rowid to VectorSearch:** `embeddingPipeline.embed(summary: summary, rowid: rowid)`
- **Retry query:** `SELECT rowid, * FROM ConversationSummary WHERE embedding IS NULL` gets both record and rowid
- **Search reverse-mapping:** After `VectorSearch.query()` returns rowids, fetch via `SELECT * FROM ConversationSummary WHERE rowid IN (?,...)`

**Post-conversation pipeline integration point:**
```swift
// In CoachingViewModel.generateSummary(for:) — REPLACE the existing dbPool.write block:
let rowid = try await databaseManager.dbPool.write { db in
    try summary.insert(db)
    return db.lastInsertedRowID  // Int64 — SQLite implicit rowid
}

// THEN embed (outside the write block, failure is non-fatal):
do {
    try await embeddingPipeline.embed(summary: summary, rowid: rowid)
} catch {
    Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory")
        .error("Embedding failed for summary \(summary.id): \(error)")
}
```

**Concurrency patterns (match existing code):**
- `generateSummary(for:)` is `nonisolated` — the `embeddingPipeline.embed()` call executes in this `nonisolated` context. `embed()` must NOT access any `@MainActor`-isolated ViewModel state — it only uses its own injected services.
- `EmbeddingPipeline`: `@unchecked Sendable` (thread-safe via internal locking of dependencies)
- All DB access via `databaseManager.dbPool.read/write { db in }`
- `EmbeddingService.generateEmbedding(for:)` is synchronous (`throws`, not `async throws`) — call from async context is fine
- Fire-and-forget embedding in existing `Task { }` block (same Task that calls `generateSummary`)

### Performance (Story 1.7 Benchmarks — Confirmed)

- Vector insert: 0.6-0.8ms per vector
- Vector query (top-5): 2.5ms at 1K vectors, 17.7ms at 10K vectors — 28x under 500ms NFR
- Memory: ~30.6MB for 10K vectors
- Core ML inference: ~100ms per text (simulator; faster on device with Neural Engine)
- **Total embed pipeline per summary: ~101ms** (inference + insert)
- **Total search query: ~118ms** (inference + vector query at 10K)

### File Structure Requirements

**New files (4 production + 3 test):**
```
ios/sprinty/Services/Memory/EmbeddingPipelineProtocol.swift    # Protocol definition
ios/sprinty/Services/Memory/EmbeddingPipeline.swift            # Implementation
ios/Tests/Services/EmbeddingPipelineTests.swift                # Pipeline tests
ios/Tests/Mocks/MockEmbeddingService.swift                     # Mock for EmbeddingServiceProtocol
ios/Tests/Mocks/MockVectorSearch.swift                         # Mock for VectorSearchProtocol
ios/Tests/Mocks/MockEmbeddingPipeline.swift                    # Mock for EmbeddingPipelineProtocol
```

**Modified files:**
```
ios/sprinty/Models/ConversationSummary.swift                   # Add embedding encode/decode helpers, withoutEmbedding() query
ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift # Add embeddingPipeline dependency, capture rowid, call embed after summary
ios/sprinty/App/RootView.swift                                 # Wire EmbeddingService, VectorSearch, EmbeddingPipeline DI
ios/Tests/Features/CoachingViewModelTests.swift                # Verify embedding pipeline integration
```

### Testing Standards

- **Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect()`) — NEVER XCTest
- **Database tests:** Use `makeTestDB()` with real GRDB in-memory migrations
- **Mock pattern:** Create mocks implementing protocols, record call arguments, allow stub injection
- **Test naming:** `func test_methodName_condition_expectedResult() async`
- **Embedding tests:** Mock `EmbeddingServiceProtocol` to return fixed [Float] arrays — do NOT load Core ML model in tests
- **Vector tests:** Mock `VectorSearchProtocol` to return fixed results — real VectorSearch tested separately in Story 1.7
- **CI note:** Core ML model loading disabled in CI via `ProcessInfo.processInfo.environment["CI"]` check
- **Existing test helpers:** Check `ios/Tests/Services/EmbeddingTestHelpers.swift` for reusable fixture patterns (created in Story 1.7)

### Previous Story Intelligence (Story 3.1)

**Key learnings to apply:**
1. `StrictConcurrency` fix: capture `var` in closures requires `let` binding before closure (e.g., `let sessionToSave = updated`)
2. `Logger.memory` doesn't exist — use `Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory")` directly
3. `ChatRequest` memberwise init can cause issues — ensure all params provided
4. All mock protocol implementations must match protocol changes exactly
5. JSON array columns use `String` type with manual `JSONEncoder`/`JSONDecoder` (not native `[String]`)
6. Migration v5 is append-only — do NOT modify it. New migration must be v6.
7. Bulk insert performance test pattern: insert 150 summaries, verify no timeout

**Code review fixes from 3.1 to carry forward:**
- [C1] When branching on mode, ensure correct schema is used (applicable to any future mode branching)
- [M1] SQL LIKE queries must escape `%` and `_` wildcards
- [M2] Use LEFT JOIN for "find missing" queries, not N+1 pattern

### Library & Framework Versions

- **GRDB.swift:** Current version in Package.resolved (via SPM)
- **SQLiteVecKit:** Local package at `ios/Packages/SQLiteVecKit/`, sqlite-vec v0.0.14
- **Core ML model:** all-MiniLM-L6-v2, float32 format (85.8MB) — float16 causes NaN (known coremltools bug)
- **Vocab:** `ios/sprinty/Resources/vocab.txt` — 30,522 tokens, max sequence length 128

### Project Structure Notes

- All files follow PascalCase naming for Swift
- Services in `Services/{Domain}/` — Memory services go in `Services/Memory/`
- Models in top-level `Models/`
- Tests mirror source structure: `Tests/Services/`, `Tests/Mocks/`, `Tests/Features/`
- DI container is `RootView.swift` — all service creation happens there
- `xcodegen generate` must pass after changes (project uses XcodeGen)

### References

- [Source: ios/sprinty/Services/Memory/EmbeddingService.swift] — Existing Core ML embedding generation
- [Source: ios/sprinty/Services/Database/VectorSearch.swift] — Existing sqlite-vec wrapper
- [Source: ios/sprinty/Models/ConversationSummary.swift] — GRDB model with embedding: Data? field
- [Source: ios/sprinty/Services/Database/Migrations.swift#v5] — ConversationSummary table creation
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift#L175-229] — Post-conversation pipeline
- [Source: ios/sprinty/App/RootView.swift#L91-99] — DI wiring point
- [Source: _bmad-output/planning-artifacts/architecture.md] — MemoryServiceProtocol, RAG pipeline architecture
- [Source: _bmad-output/planning-artifacts/epics.md#Epic3] — Story 3.2 acceptance criteria and dependencies
- [Source: _bmad-output/planning-artifacts/prd.md] — NFR5 (500ms), NFR18 (10K embeddings)
- [Source: docs/spike-results/1-7-sqlite-vec-benchmark.md] — Performance benchmarks confirming feasibility

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- StrictConcurrency fix: `var rowid1/rowid2` in test required `let` binding from `dbPool.write` return value
- StrictConcurrency fix: `var updated` in `embed()` required `let toSave` copy before closure capture
- GRDB UUID encoding: UUID stored as BLOB by default, raw SQL with `uuidString` TEXT didn't match — fixed by using GRDB's `update(db, columns:)` API instead of raw SQL

### Completion Notes List

- Task 1: Created `EmbeddingPipelineProtocol` (3 methods: embed, search, retryMissingEmbeddings) and `EmbeddingPipeline` implementation with `EmbeddingServiceProtocol`, `VectorSearchProtocol`, `DatabaseManager` dependencies
- Task 2: Modified `CoachingViewModel.generateSummary` to capture `db.lastInsertedRowID` and call `embeddingPipeline.embed()` with do/catch for graceful degradation. Added optional `EmbeddingPipelineProtocol?` to init (backward compatible with nil default)
- Task 3: Added `makeEmbeddingPipeline()` to `RootView` — loads Core ML model + vocab, creates VectorSearch in App Group container, creates table, returns nil on any failure (graceful degradation)
- Task 4: Implemented `search(query:limit:)` — embeds query text, queries sqlite-vec, maps rowids back to ConversationSummary via GRDB, preserves distance ordering
- Task 5: Implemented `retryMissingEmbeddings()` — queries `SELECT rowid, * FROM ConversationSummary WHERE embedding IS NULL`, processes each with embed(), continues on individual failure. Added `retryMissingEmbeddings()` delegate method to CoachingViewModel
- Task 6: Added `decodedEmbedding` computed property, `encodeEmbedding()` static method, and `withoutEmbedding()` query extension to ConversationSummary
- Task 7: Created 9 EmbeddingPipelineTests (embed, failure, search ranked, search empty, retry nil-only, retry continues after failure, encode/decode roundtrip, nil decode, withoutEmbedding query). Created MockEmbeddingService, MockVectorSearch, MockEmbeddingPipeline. Added 3 CoachingViewModel integration tests (pipeline called, failure graceful, retry delegates). All 222 tests pass with 0 regressions.

### Change Log

- 2026-03-20: Story 3.2 implementation complete — embedding pipeline, vector storage integration, similarity search, retry logic, and comprehensive tests
- 2026-03-20: Code review fixes — [H1] replaced dead code + N+1 in search() with single batch query, [H2] swapped embed() write order (vectorSearch before GRDB) to ensure failed embeddings are retryable per AC3, [M1] added retryMissingSummaries/retryMissingEmbeddings calls to CoachingView.task, [M2] fixed test to actually inject failure via insertFailOnce, [M3] added project.pbxproj and CoachingView.swift to File List, [L1] removed unused test variables

### File List

**New files:**
- ios/sprinty/Services/Memory/EmbeddingPipelineProtocol.swift
- ios/sprinty/Services/Memory/EmbeddingPipeline.swift
- ios/Tests/Services/EmbeddingPipelineTests.swift
- ios/Tests/Mocks/MockEmbeddingService.swift
- ios/Tests/Mocks/MockVectorSearch.swift
- ios/Tests/Mocks/MockEmbeddingPipeline.swift

**Modified files:**
- ios/sprinty/Models/ConversationSummary.swift
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift
- ios/sprinty/Features/Coaching/Views/CoachingView.swift
- ios/sprinty/App/RootView.swift
- ios/Tests/Features/CoachingViewModelTests.swift
- ios/sprinty.xcodeproj/project.pbxproj
