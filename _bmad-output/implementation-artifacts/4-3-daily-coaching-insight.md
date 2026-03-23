# Story 4.3: Daily Coaching Insight

Status: done

## Story

As a returning user,
I want to see a personalized coaching insight on my home screen each day,
So that the app feels like my coach has been thinking about me.

## Acceptance Criteria

1. **Given** a user opens the app after a completed coaching session
   **When** the home screen loads
   **Then** the InsightCard displays a context-aware insight generated from RAG pre-fetch
   **And** the insight uses `Font.insightText` (15pt Subheadline, 1.5 line height) inside a rounded container (16pt radius, `insightBackground`)

2. **Given** a new user with no conversations yet
   **When** the InsightCard would display
   **Then** it shows "Your coach is getting to know you..." (UX-DR72)

3. **Given** the RAG pre-fetch for the insight
   **When** generating the daily insight
   **Then** it completes within 500ms and does not make a network request to the LLM provider
   **And** the insight is derived from recent conversation summaries (Story 3.4 RAG pipeline)
   **And** fallback if unavailable: warm default content

4. **Given** the InsightCard content
   **When** VoiceOver reads it
   **Then** it announces "Coach insight: [content]"

## Tasks / Subtasks

- [x] Task 1: Create InsightService protocol and implementation (AC: #1, #3)
  - [x] 1.1 Create `InsightServiceProtocol` in `Services/Memory/` with `func generateDailyInsight() async -> String?` (nullable — nil means no insight available, InsightCard hidden)
  - [x] 1.2 Create `InsightService` as `final class InsightService: InsightServiceProtocol, Sendable` with dependencies: `databaseManager: DatabaseManager`, `embeddingPipeline: EmbeddingPipelineProtocol?` (nullable — gracefully degrade when Core ML model unavailable)
  - [x] 1.3 Implement insight selection logic — this is **data selection, NOT text generation**: query `ConversationSummary.recent(limit: 3)`, pick the best key moment from `decodedKeyMoments` or fall back to `.summary` text. If `embeddingPipeline` is available and already initialized, optionally use `.search(query:limit:)` for semantic retrieval of a more relevant summary
  - [x] 1.4 Implement in-memory caching inside InsightService: store `lastSessionId: UUID?` and `cachedInsight: String?` — skip regeneration if the most recent completed session ID hasn't changed since last call
  - [x] 1.5 Implement 500ms timeout guard using `Task.sleep` race — if generation exceeds 500ms, return cached value or nil
  - [x] 1.6 Implement fallback chain: key moment from recent summary → latest `ConversationSummary.summary` text → `"Your coach is getting to know you..."` (when conversations exist but no summary yet) → `nil` (Stage 1, no conversations)
  - [x] 1.7 Write unit tests for InsightService (all fallback paths, caching hit/miss, session-based invalidation, empty DB, nil embeddingPipeline)

- [x] Task 2: Integrate InsightService into HomeViewModel (AC: #1, #2, #3)
  - [x] 2.1 Add `InsightServiceProtocol` dependency to `HomeViewModel.init(appState:, databaseManager:, insightService:)`
  - [x] 2.2 Update `loadLatestInsight()` to call `insightService.generateDailyInsight()` instead of raw `ConversationSummary.recent()` query
  - [x] 2.3 Preserve existing `insightDisplayText` computed property logic — pause override and fallback chain remain in the ViewModel (InsightService handles data selection, ViewModel handles display logic)
  - [x] 2.4 Update `#if DEBUG` preview factory to accept optional `InsightServiceProtocol` parameter with default nil (when nil, ViewModel falls back to using `latestInsight` property directly as today)
  - [x] 2.5 Write unit tests for HomeViewModel insight loading with `MockInsightService`

- [x] Task 3: Enhance InsightCardView with label header (AC: #1, #4)
  - [x] 3.1 Add label text above content text inside a `VStack(alignment: .leading, spacing: 4)` — label uses `Font.sprintLabel` (`theme.typography.sprintLabelFont.weight(theme.typography.sprintLabelWeight)`) + `theme.palette.textSecondary`
  - [x] 3.2 Verify VoiceOver announces "Coach insight: [content]" (already implemented via `.accessibilityLabel`)
  - [x] 3.3 Add content change animation (0.3s ease-in-out, respects Reduce Motion via `@Environment(\.accessibilityReduceMotion)`)
  - [x] 3.4 Update `#Preview` variants for new label layout

- [x] Task 4: Wire InsightService into RootView DI (AC: #1, #3)
  - [x] 4.1 In `RootView.swift`, create InsightService in `authenticatedView()` — pass existing `databaseManager` and the already-created `embeddingPipeline` (reuse, don't create a second instance)
  - [x] 4.2 Pass InsightService to `HomeViewModel` init call (currently line ~94-97 in RootView)
  - [x] 4.3 Follow the existing Memory service pattern: direct constructor injection, no `fromConfiguration()`

- [x] Task 5: Run full test suite and verify zero regressions (AC: all)
  - [x] 5.1 Run all existing tests (378+ baseline from Story 4.2)
  - [x] 5.2 Verify HomeView progressive disclosure stages still work correctly
  - [x] 5.3 Verify Pause Mode insight override ("Your coach is here when you're ready.") unchanged
  - [x] 5.4 Verify Stage 1 (welcome) still hides InsightCard
  - [x] 5.5 Verify no network requests during insight generation (local-only pipeline)

## Dev Notes

### Architecture & Patterns

**MVVM + @Observable (iOS 17+):**
- ViewModels: `@MainActor @Observable final class`
- Services: NOT `@MainActor`, marked `Sendable`
- DI: Protocol-based injection via init, no singletons, no `fromConfiguration()` for Memory services
- AppState injected via `@Environment(AppState.self)` in Views, via init in ViewModels
- CoachingTheme via `@Environment(\.coachingTheme)`

**Error Handling — Two-Tier:**
- Global errors (network, auth) → flow through AppState
- Local errors (DB read failures, insight generation) → stay on ViewModel, log silently
- Insight generation failures are **Silent** category — retry on next launch, log gap

**Swift 6 Concurrency:**
- `Task { [weak self] in ... }` to prevent retain cycles
- Check `Task.isCancelled` before state mutations
- GRDB async: `dbPool.read { db in ... }` / `dbPool.write { db in ... }`

### Existing Components — DO NOT RECREATE

| Component | Path | Use |
|-----------|------|-----|
| `InsightCardView` | `Features/Home/Views/InsightCardView.swift` | Already renders insight text with correct tokens. Extend with label, don't replace. |
| `HomeViewModel` | `Features/Home/ViewModels/HomeViewModel.swift` | Already has `latestInsight`, `insightDisplayText`, `loadLatestInsight()`. Modify in place. |
| `HomeView` | `Features/Home/Views/HomeView.swift` | Already shows InsightCard in Stage 2+ via `.task { viewModel.load() }`. **DO NOT modify** — insight loading flows through ViewModel.load(). |
| `ConversationSummary` | `Models/ConversationSummary.swift` | Has `.recent(limit:)` query, `.summary` field, `.decodedKeyMoments`, `.decodedDomainTags`. Use as-is. |
| `EmbeddingPipeline` | `Services/Memory/EmbeddingPipeline.swift` | Has `.search(query:limit:)` for semantic search. **Nullable** — may be nil if Core ML model unavailable. Only use if already initialized; never load Core ML just for insights. |
| `HomeDisclosureStage` | `Core/State/HomeDisclosureStage.swift` | 4 stages unchanged. |
| `AvatarState` | `Core/State/AvatarState.swift` | 5 states unchanged. |
| `CoachActionButton` | `Features/Home/Views/CoachActionButton.swift` | Unchanged. |

### Insight Generation Strategy

**CRITICAL: No network request to LLM provider. No local text generation. This is DATA SELECTION, not synthesis.**

**What "generate daily insight" means:**
1. Query `ConversationSummary.recent(limit: 3)` from local SQLite
2. From the most recent summary, pick the best `decodedKeyMoments[0]` — these are already human-readable coaching moments extracted during post-conversation summarization
3. If no key moments exist, use the `.summary` text directly
4. If `embeddingPipeline` is available (non-nil, already initialized), optionally use `.search(query: latestSummary.summary, limit: 1)` to find a semantically relevant older insight for variety
5. Cache the result keyed by `lastSessionId` — skip DB queries on repeated calls until a new session completes

**What this is NOT:**
- NOT calling an LLM to generate new text
- NOT running NLP or templating logic
- NOT loading a Core ML model (EmbeddingPipeline is pre-loaded or nil)
- NOT making any network request

**Fallback chain (in order):**
1. Key moment from most recent `ConversationSummary.decodedKeyMoments` → best quality
2. Latest `ConversationSummary.summary` text verbatim → direct fallback
3. `"Your coach is getting to know you..."` → conversations exist but no summary yet
4. `nil` → Stage 1 (no conversations), InsightCard not shown

**Performance budget: 500ms max.** All operations are local SQLite reads + in-memory processing. Typical: <50ms.

### DI Wiring — RootView Pattern

HomeViewModel is instantiated in `RootView.swift` (lines ~94-97):
```swift
// CURRENT:
homeViewModel = HomeViewModel(appState: appState, databaseManager: databaseManager)

// AFTER:
let insightService = InsightService(
    databaseManager: databaseManager,
    embeddingPipeline: embeddingPipeline  // reuse existing instance, may be nil
)
homeViewModel = HomeViewModel(
    appState: appState,
    databaseManager: databaseManager,
    insightService: insightService
)
```
Follow the same pattern as `ProfileUpdateService`, `ProfileEnricher` — direct constructor injection in RootView, no factory method needed.

### Typography Pattern (3-Property)

InsightCardView already uses the correct pattern:
```swift
.font(theme.typography.insightTextFont.weight(theme.typography.insightTextWeight))
.lineSpacing(theme.typography.insightTextLineSpacing)
```
Label header uses:
```swift
.font(theme.typography.sprintLabelFont.weight(theme.typography.sprintLabelWeight))
.lineSpacing(theme.typography.sprintLabelLineSpacing)
.foregroundStyle(theme.palette.textSecondary)
```

### Animation Timings

| Animation | Duration | Curve | Reduce Motion |
|-----------|----------|-------|---------------|
| Insight content change | 0.3s | ease-in-out | instant (0s) |
| Home element fade-in | 0.2s | ease-in-out | instant (0s) |

### Testing Standards

- **Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`) — NOT XCTest
- **Naming:** `test_{function}_{scenario}_{expected}`
- **Database tests:** `makeTestDB()` helper with real GRDB migrations, in-memory DatabasePool
- **Mocks:** `final class MockInsightService: InsightServiceProtocol, @unchecked Sendable`
- **ViewModel tests:** `@Test @MainActor` for async tests
- **Baseline:** 378 tests from Story 4.2 — zero regressions allowed

### Project Structure Notes

**New files:**
```
ios/sprinty/Services/Memory/InsightServiceProtocol.swift
ios/sprinty/Services/Memory/InsightService.swift
ios/Tests/Services/Memory/InsightServiceTests.swift
ios/Tests/Features/Home/HomeViewModelInsightTests.swift
```

**Modified files:**
```
ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift  — add InsightService dependency, update loadLatestInsight()
ios/sprinty/Features/Home/Views/InsightCardView.swift     — add label header above content
ios/sprinty/App/RootView.swift                            — wire InsightService into HomeViewModel init
```

**DO NOT modify:**
- `HomeView.swift` — layout already handles InsightCard display; insight loading flows through ViewModel.load()
- `AppState.swift` — no new state properties needed
- `ConversationSummary.swift` — existing queries sufficient

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4, Story 4.3]
- [Source: _bmad-output/planning-artifacts/architecture.md#Memory Pipeline, RAG System]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#InsightCard — anatomy: Label + content]
- [Source: _bmad-output/planning-artifacts/prd.md#FR29 — coaching insight on home screen]
- [Source: _bmad-output/implementation-artifacts/4-2-home-scene-progressive-disclosure.md]

### Previous Story Intelligence (Story 4.2)

**Key learnings to apply:**
- Typography uses 3-property pattern (Font/Weight/LineSpacing), not a single `.insightText` property
- Pause Mode desaturation: container `.saturation(0.7)`, CoachActionButton counteracts with `.saturation(1/0.7)`
- Database queries use `databaseManager.dbPool.read { db in }` async pattern
- ConversationSummary.recent() already works and returns summaries ordered by createdAt desc
- Preview factory pattern: static `preview()` method with default parameters under `#if DEBUG`
- VoiceOver sort priorities: greeting(5) → avatar(4) → insight(3) → sprint(2) → button(1)
- CoachingTheme accessed via `@Environment(\.coachingTheme)` in views
- Memory services use direct constructor injection in RootView, not `fromConfiguration()`

### Git Intelligence

**Recent commits (Story 4.1 + 4.2):** 20 files changed, 1662 insertions, 24 deletions.
Key patterns: feature-first folder structure, comprehensive test suites per story, `#Preview` variants for each state, accessibility-first with VoiceOver labels on all interactive/informational elements.

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- All 396 tests passed (378 baseline + 18 new) — zero regressions

### Completion Notes List
- Task 1: Created InsightServiceProtocol and InsightService with data selection logic (not text generation), in-memory caching keyed by session ID, 500ms timeout guard via TaskGroup race, and full fallback chain (key moment → summary text → "getting to know you" → nil). 11 unit tests covering all paths.
- Task 2: Integrated InsightService into HomeViewModel via optional protocol dependency (backward-compatible nil default). Updated loadLatestInsight() to delegate to service when available, preserved insightDisplayText computed property display logic. 7 unit tests.
- Task 3: Enhanced InsightCardView with "Coach Insight" label header using VStack layout, sprintLabel typography, textSecondary color. Added 0.3s ease-in-out content change animation respecting Reduce Motion. Added Long Insight preview variant.
- Task 4: Wired InsightService into RootView DI — created in authenticatedView() with existing databaseManager and embeddingPipeline (reused, not duplicated). Direct constructor injection pattern.
- Task 5: Full regression suite passed — 396/396 tests, all progressive disclosure stages verified, pause mode override confirmed, Stage 1 InsightCard hiding confirmed, no network requests in insight pipeline.

### Change Log
- Story 4.3 implementation complete (Date: 2026-03-23)
- Code review fixes applied (Date: 2026-03-23): M1 — Added NSLock to protect mutable cache state (`lastSessionId`, `cachedInsight`) for thread safety; M2 — Added `project.pbxproj` to File List; L1 — Moved Logger to stored property

### File List
**New files:**
- ios/sprinty/Services/Memory/InsightServiceProtocol.swift
- ios/sprinty/Services/Memory/InsightService.swift
- ios/Tests/Services/Memory/InsightServiceTests.swift
- ios/Tests/Features/Home/HomeViewModelInsightTests.swift
- ios/Tests/Mocks/MockInsightService.swift

**Modified files:**
- ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift
- ios/sprinty/Features/Home/Views/InsightCardView.swift
- ios/sprinty/App/RootView.swift
- ios/sprinty.xcodeproj/project.pbxproj
