# Story 3.7: Memory View & Profile Editing

Status: done

## Story

As a user,
I want to see what my coach knows about me and correct anything that's wrong,
So that I maintain control over how I'm understood and coaching stays accurate.

## Acceptance Criteria

1. **Given** the user navigates to "What Your Coach Knows" (via Settings)
   **When** the MemoryView loads
   **Then** it displays three sections: Profile Facts, Key Memories, and Domain Tags
   **And** all data is displayed in natural language, not raw data

2. **Given** the Profile Facts section
   **When** the user taps a fact
   **Then** they can edit it inline
   **And** a "Forget this?" option allows warm deletion (irreversible)
   **And** edits take effect on the next coaching turn
   **And** the coach may naturally acknowledge: "I noticed you updated your priorities" (UX-DR84)

3. **Given** the Key Memories section
   **When** the user browses memories
   **Then** they can delete individual memories
   **And** deletion immediately removes the memory from RAG retrieval

4. **Given** the Domain Tags section
   **When** the user views tags
   **Then** they can remove individual tags

5. **Given** VoiceOver is enabled
   **When** navigating the MemoryView
   **Then** section headers are VoiceOver headings
   **And** edit hints say "Double tap to edit"

6. **Given** the footer of the MemoryView
   **When** displayed
   **Then** it reads "Your data stays on your phone. You can export or delete everything anytime."

## Tasks / Subtasks

- [x] Task 1: MemoryViewModel — data loading and state management (AC: #1, #2, #3, #4)
  - [x] 1.1 Create `MemoryViewModel` in `Features/Settings/ViewModels/` (`@MainActor @Observable final class`)
  - [x] 1.2 Load UserProfile via GRDB `dbPool.read` — map to display-friendly `ProfileFact` structs (natural language, not raw fields)
  - [x] 1.3 Load ConversationSummary records — extract key moments as `MemoryItem` structs with natural language display
  - [x] 1.4 Aggregate domain tags across all ConversationSummary records into unique sorted list
  - [x] 1.5 Empty state handling: if no profile/memories exist, set `isEmpty = true` for warm empty state message
  - [x] 1.6 Unit tests for all loading, editing, deleting, and empty state logic

- [x] Task 2: Profile fact editing and deletion (AC: #2)
  - [x] 2.1 Implement `updateProfileFact(_ fact: ProfileFact, newValue: String)` — writes to UserProfile via GRDB
  - [x] 2.2 Implement `deleteProfileFact(_ fact: ProfileFact)` — removes the specific field/value from UserProfile, writes via GRDB
  - [x] 2.3 Profile edits update `UserProfile.updatedAt` timestamp so next coaching turn picks up changes
  - [x] 2.4 Unit tests for edit and delete operations (write → read back → assert pattern)

- [x] Task 3: Memory deletion with RAG impact (AC: #3)
  - [x] 3.1 Extend `VectorSearch` with `func delete(rowid: Int64) throws` — currently only has `createTable`, `insert`, `query`, `count`, `deleteAll`. **Individual vector deletion does NOT exist yet and MUST be added**
  - [x] 3.2 Extend `EmbeddingPipelineProtocol` with `func deleteEmbedding(summaryRowid: Int64) async throws` and implement in `EmbeddingPipeline`
  - [x] 3.3 Implement `deleteMemory(_ memory: MemoryItem)` — in a single `dbPool.write` transaction: delete ConversationSummary record AND call VectorSearch.delete(rowid:) to remove the associated vector. Atomicity prevents phantom RAG results
  - [x] 3.4 Verify deletion removes memory from RAG retrieval by testing VectorSearch no longer returns it
  - [x] 3.5 Update `MockEmbeddingPipeline` in `ios/Tests/Mocks/` with new delete method
  - [x] 3.6 Unit tests for memory deletion, vector cleanup, and RAG removal

- [x] Task 4: Domain tag removal (AC: #4)
  - [x] 4.1 Implement `removeDomainTag(_ tag: String)` — remove tag from all ConversationSummary records that contain it
  - [x] 4.2 Unit tests for tag removal

- [x] Task 5: MemoryView — SwiftUI UI implementation (AC: #1, #2, #3, #4, #6)
  - [x] 5.1 Create `MemoryView.swift` in `Features/Settings/Views/`
  - [x] 5.2 Profile Facts section — List with tappable rows, inline TextField editing, "Forget this?" swipe action
  - [x] 5.3 Key Memories section — List with summary text in natural language, swipe-to-delete labeled "Forget" with confirmation message: "Your coach won't bring this up again."
  - [x] 5.4 Domain Tags section — Tag chips or List rows with remove action
  - [x] 5.5 Privacy footer: "Your data stays on your phone. You can export or delete everything anytime."
  - [x] 5.6 Empty state: "Your coach is still learning about you" (warm, forward-looking)
  - [x] 5.7 Use CoachingTheme tokens: `homeBackground`, `homeTextPrimary`, `homeTextSecondary`, `insightBackground`, `Font.sectionHeading`, `Font.insightText`, `Spacing.screenMargin`, `Radius.container`
  - [x] 5.8 Provide Light, Dark, Empty State, and Accessibility XL `#Preview` variants

- [x] Task 6: SettingsView shell and navigation wiring (AC: #1)
  - [x] 6.1 Create `SettingsView.swift` in `Features/Settings/Views/` — SwiftUI `Form` with "Your Coach" section containing NavigationLink("What Your Coach Knows") → MemoryView
  - [x] 6.2 Create `SettingsViewModel.swift` in `Features/Settings/ViewModels/` — minimal, just holds navigation state
  - [x] 6.3 Add settings gear button to `HomeView.swift` — use `.toolbar` modifier or closure callback pattern matching existing `onTalkToCoach: () -> Void` pattern. **HomeView currently has NO settings entry point — this must be added**
  - [x] 6.4 Add `showSettings` state toggle in `RootView.swift` — follow the same `@State` toggle pattern used for `showConversation`. Present SettingsView via sheet or fullScreenCover matching app convention
  - [x] 6.5 Instantiate MemoryViewModel lazily in RootView following the `ensureCoachingViewModel()` pattern — pass `DatabaseManager` from AppState
  - [x] 6.6 SettingsView uses home scene palette + coaching typography per UX spec

- [x] Task 7: Accessibility (AC: #5)
  - [x] 7.1 Section headers as `.accessibilityAddTraits(.isHeader)` VoiceOver headings
  - [x] 7.2 Editable facts: `.accessibilityHint("Double tap to edit")`
  - [x] 7.3 Delete actions: `.accessibilityLabel("Forget this")` on swipe actions
  - [x] 7.4 Dynamic Type support — use semantic font tokens, `ScrollView` for large text sizes
  - [x] 7.5 Respect `@Environment(\.accessibilityReduceMotion)` for any transitions

- [x] Task 8: Integration tests (All ACs)
  - [x] 8.1 Test full flow: load profile → edit fact → verify update persisted
  - [x] 8.2 Test full flow: load memories → delete memory → verify removed from DB and vector search
  - [x] 8.3 Test full flow: load tags → remove tag → verify removed from all summaries
  - [x] 8.4 Test empty state displays correctly for new user with no data
  - [x] 8.5 Test deletion confirmation flow

## Dev Notes

### What Already Exists — DO NOT Recreate

- **UserProfile model** — GRDB record at `ios/sprinty/Models/UserProfile.swift` (Story 3.3). Fields: `id`, `coachName`, `values`, `goals`, `personalityTraits`, `domainStates`, `createdAt`, `updatedAt`. **CRITICAL:** Arrays (`values`, `goals`, `personalityTraits`) are stored as JSON-encoded strings, NOT native arrays. Use `decodedValues`, `decodedGoals`, `decodedPersonalityTraits` getters to read, and `encodeArray()` helper to write. `domainStates` is a JSON-encoded `[String: DomainState]` dictionary. Has `UserProfile.current()` query extension to fetch the single profile. [Source: Models/UserProfile.swift]
- **DomainState model** — At `ios/sprinty/Models/DomainState.swift` (Story 3.3). Structured domain state data. [Source: Models/DomainState.swift]
- **ConversationSummary model** — GRDB record at `ios/sprinty/Models/ConversationSummary.swift`. Fields: `id`, `sessionId`, `summary`, `keyMoments: [String]`, `domainTags: [String]`, `emotionalMarkers: [String]?`, `keyDecisions: [String]?`, `goalReferences: [String]?`, `embedding: [Float]` (384-dim), `createdAt`. [Source: Models/ConversationSummary.swift]
- **ProfileUpdateService** — At `ios/sprinty/Services/Memory/ProfileUpdateService.swift` (Story 3.3). Handles profile updates from LLM structured output. Reuse for direct user edits. [Source: Services/Memory/ProfileUpdateService.swift]
- **ProfileEnricher** — At `ios/sprinty/Services/Memory/ProfileEnricher.swift` (Story 3.3). Enriches profile from conversation context. [Source: Services/Memory/ProfileEnricher.swift]
- **VectorSearch** — At `ios/sprinty/Services/Database/VectorSearch.swift`. sqlite-vec query wrapper. Has `createTable`, `insert`, `query`, `count`, `deleteAll` — **NO individual delete method exists, must be added** (see Vector Deletion section). [Source: Services/Database/VectorSearch.swift]
- **EmbeddingPipeline** — At `ios/sprinty/Services/Memory/EmbeddingPipeline.swift` (Story 3.2). Has `embed`, `search`, `retryMissingEmbeddings` — **NO delete method exists, must be added**. [Source: Services/Memory/EmbeddingPipeline.swift]
- **DatabaseManager** — At `ios/sprinty/Services/Database/DatabaseManager.swift`. GRDB DatabasePool setup. Use `dbPool.read` and `dbPool.write` for all database operations. [Source: Services/Database/DatabaseManager.swift]
- **Settings feature folder** — `ios/sprinty/Features/Settings/` exists with empty `Views/` and `ViewModels/` subdirectories. Ready for new files. [Source: Features/Settings/]
- **CoachingTheme** — At `ios/sprinty/Core/Theme/CoachingTheme.swift`. Use `.home` context for Settings/Memory views. Tokens: `homeBackground`, `homeTextPrimary`, `homeTextSecondary`, `insightBackground`, `Font.sectionHeading`, `Font.insightText`. [Source: Core/Theme/]
- **AppState** — At `ios/sprinty/App/AppState.swift`. Holds `DatabaseManager` reference. Injected via `.environment(appState)`. [Source: App/AppState.swift]
- **RootView** — At `ios/sprinty/App/RootView.swift`. DI container — all services created here. New ViewModels must follow this pattern. [Source: App/RootView.swift]

### Architecture Compliance

**MVVM Pattern:**
- `MemoryViewModel`: `@MainActor @Observable final class` — three required markers (`@MainActor`, `@Observable`, `final`)
- ViewModels do NOT need protocols — service protocols are what get injected INTO the ViewModel
- ViewModel accepts `AppState` and any service protocols via `init`
- Views bind via `@Bindable var viewModel: MemoryViewModel`
- Include `#if DEBUG` static preview factory — creates temp test DB, wires mock services, returns configured ViewModel. Previews must never hit the network or use real services

**Database Access:**
- All reads via `dbPool.read { db in }` — async, never synchronous
- All writes via `dbPool.write { db in }` — async
- Queries as static extensions on model types, NOT in ViewModel
- GRDB record pattern: `Codable + FetchableRecord + PersistableRecord + Identifiable + Sendable`
- Table names: PascalCase singular. Column names: camelCase

**Swift Concurrency:**
- ViewModel: `@MainActor` (updates UI state)
- Any new service: NOT `@MainActor`, marked `Sendable`
- **CRITICAL:** Use `Task { [weak self] in }` in ViewModel methods to prevent retain cycles — required for all async operations (loading profile, deleting memories, editing facts)
- **CRITICAL:** Check `Task.isCancelled` before state mutations after any `await` — prevents stale updates if user navigates away mid-operation
- NEVER use Combine (`ObservableObject`, `@Published`, `PassthroughSubject`) — project uses Observation framework exclusively
- `AsyncThrowingStream` must handle `onTermination` for cleanup if used

**Error Handling:**
- Database errors: local error on ViewModel (`self.localError = .databaseError(underlying: err)`)
- Never global AppState error for local data operations
- Use `AppError` enum exclusively

**File Locations:**
- New views: `ios/sprinty/Features/Settings/Views/`
- New ViewModels: `ios/sprinty/Features/Settings/ViewModels/`
- New display models (ProfileFact, MemoryItem): `ios/sprinty/Features/Settings/Models/` — these are transient/display-only, NOT GRDB records
- New tests: `ios/Tests/Features/`
- New mocks: `ios/Tests/Mocks/`
- **Add all new files to `ios/project.yml`** under correct target (app or test)

### Display Model Design

Create lightweight display models that translate raw database records into natural language:

**ProfileFact** (transient, in `Features/Settings/Models/`):
```swift
struct ProfileFact: Identifiable, Sendable {
    let id: String          // e.g., "coachName", "values-0", "goals-1"
    let category: String    // "Coach Name", "Values", "Goals", "Personality", "Life Situation"
    let displayLabel: String // Natural language: "Your coach's name", "A value you hold"
    let value: String       // Current value in natural language
    var isEditing: Bool = false
}
```

**MemoryItem** (transient, in `Features/Settings/Models/`):
```swift
struct MemoryItem: Identifiable, Sendable {
    let id: UUID            // ConversationSummary.id
    let summary: String     // Natural language summary text
    let keyMoments: [String]
    let date: Date          // createdAt for display
    let domainTags: [String]
}
```

Map UserProfile fields to ProfileFact array:
- `coachName` → single fact: "Your coach's name is [name]"
- `values` → one fact per value: "Something you value: [value]"
- `goals` → one fact per goal: "A goal you're working toward: [goal]"
- `personalityTraits` → one fact per trait: "A trait your coach sees: [trait]"
- `domainStates` → one fact per domain: "[Domain]: [state description]"

### UX Design Requirements

**Visual Design (Home Scene Palette):**
- Background: `homeBackground` gradient
- Primary text: `homeTextPrimary` (warm dark)
- Secondary text: `homeTextSecondary`
- Memory cards: `insightBackground` surface
- Section headings: `Font.sectionHeading` (20pt, Semibold)
- Body text: `Font.insightText` (15pt, Regular)
- Screen margins: `Spacing.screenMargin` (20pt)
- Card padding: `Spacing.insightPadding` (16pt)
- Element spacing: `Spacing.homeElement` (16pt)
- Section gaps: `Spacing.sectionGap` (32pt)
- Card corners: `Radius.container` (16pt)

**Warm Deletion Language:**
- Profile facts: "Forget this?" NOT "Delete"
- Memories: Swipe action labeled "Forget" — confirmation: "Your coach won't bring this up again."
- Domain tags: "Remove" (less emotional — tags are metadata, not personal data)

**Empty State:**
- Message: "Your coach is still learning about you"
- Tone: Forward-looking, warm — absence is potential, not failure

**SettingsView Shell:**
- SwiftUI `Form` with home scene palette and coaching typography
- Section: "Your Coach" → NavigationLink("What Your Coach Knows") → MemoryView
- Privacy section gets extra design care — reassuring, not bureaucratic
- Keep minimal — full SettingsView build-out is Story 11-1

### Navigation Integration

MemoryView is accessed via: Settings → "What Your Coach Knows"

**Current navigation architecture (verified from codebase):**
- `RootView.swift` uses `@State` toggles (e.g., `showConversation`) with closure callbacks to switch views — NOT NavigationStack or TabView
- `HomeView.swift` accepts closure callbacks (e.g., `onTalkToCoach: () -> Void`) — **currently has NO settings button or gear icon**
- Services are created lazily in RootView via `ensure*()` pattern (e.g., `ensureCoachingViewModel()`)

**Required implementation:**
1. Add `@State private var showSettings = false` to RootView
2. Add `onOpenSettings: () -> Void` closure to HomeView (matching `onTalkToCoach` pattern)
3. Add gear icon button in HomeView's `.toolbar` that calls `onOpenSettings()`
4. Present SettingsView via `.sheet(isPresented: $showSettings)` or `.fullScreenCover` — match whichever pattern CoachingView uses
5. Create MemoryViewModel lazily in RootView, passing `appState.databaseManager`

### Previous Story Intelligence

**From Story 3.6 (In-Conversation Search):**
- 314 tests passing as baseline — maintain or increase
- Test framework: Swift Testing (`@Test`, `@Suite`, `#expect`) — NEVER XCTest
- Database tests use `makeTestDB()` for in-memory GRDB — NEVER mock the database
- Async ViewModel tests: `@Test @MainActor func test_something() async { }`
- GRDB UUID handling: stored as binary Data(16 bytes), use `row["id"] as UUID`
- New files must be added to `ios/project.yml` and regenerated via `xcodegen generate`
- SwiftUI previews: provide Light, Dark, Empty State, and Accessibility XL variants minimum
- `hasSearched` pattern: gate empty states during loading to prevent flicker

**From Story 3.3 (User Profile & Domain State):**
- UserProfile is created during onboarding and updated via LLM structured output (`profile_update` field)
- ProfileUpdateService handles writes — can be reused or extended for direct user edits. It handles merging, deduplication, array capping (maxArrayItems=20), domain capping (maxDomains=10), and string truncation (maxStringLength=200)
- Profile is included in chat request `profile` field — edits take effect on next conversation turn automatically
- **Coach acknowledgment (AC #2, UX-DR84):** No new implementation needed. The updated UserProfile is already sent in the `profile` field of the next chat request. The system prompt naturally enables the coach to notice changes. This is implicit LLM behavior, not a code feature

**Git Intelligence (Recent Commits):**
- Stories 3.2-3.6 all implemented 2026-03-20 to 2026-03-21
- Consistent commit format: `feat: Story X.Y — Description with code review fixes`
- Files follow established MVVM pattern: Views/, ViewModels/, Models/ per feature
- All recent stories added tests in `ios/Tests/` mirroring source structure

### Library/Framework Requirements

- **GRDB.swift** — All database reads/writes. Already in project, no new dependency needed
- **SQLiteVecKit** — Vector deletion when removing ConversationSummary. Local SPM package at `ios/Packages/SQLiteVecKit/`
- **SwiftUI Form** — For SettingsView shell. Standard SwiftUI, no dependency
- **No new dependencies required** — everything needed exists in the project

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect()`) — NEVER XCTest

**Test files:**
- `ios/Tests/Features/MemoryViewModelTests.swift` — unit tests for all ViewModel logic
- `ios/Tests/Features/MemoryIntegrationTests.swift` — integration tests for full flows
- Add to `ios/project.yml` under test target sources

**Test patterns:**
- Database: `makeTestDB()` — in-memory GRDB with real migrations
- Write → read back → assert (never assert on write alone)
- Use existing helpers: `createSession()`, `createMessage()` if needed
- Test both success AND error paths
- Mocks: `final class MockSomething: SomeProtocol, @unchecked Sendable`

**Key test scenarios:**
- Load profile facts from UserProfile record
- Load memories from ConversationSummary records
- Aggregate domain tags across summaries
- Edit profile fact → verify UserProfile.updatedAt changed
- Delete profile fact → verify removed from UserProfile
- Delete memory → verify ConversationSummary deleted AND vector removed from sqlite-vec
- Remove domain tag → verify removed from all ConversationSummary records
- Empty state when no profile or memories exist
- VoiceOver labels and traits are set correctly

**Current test baseline: 314 tests — maintain or increase**

### Vector Deletion — CRITICAL

When deleting a ConversationSummary (memory), the associated embedding vector in sqlite-vec MUST also be deleted. Otherwise, RAG retrieval will return phantom results pointing to deleted records.

**Current state (verified from codebase):**
- `VectorSearch` has NO individual delete method — only `deleteAll()`. You MUST add `func delete(rowid: Int64) throws`
- `EmbeddingPipelineProtocol` has NO delete method — only `embed()`, `search()`, `retryMissingEmbeddings()`. You MUST add `func deleteEmbedding(summaryRowid: Int64) async throws`
- Vectors are keyed by **rowid** (from ConversationSummary table)
- `ConversationSummary` has `onDelete: .cascade` for its FK to `ConversationSession`, but NO cascade to sqlite-vec (separate virtual table)

**Implementation approach:**
1. Add `delete(rowid:)` to VectorSearch — SQL: `DELETE FROM vec_items WHERE rowid = ?`
2. Add `deleteEmbedding(summaryRowid:)` to EmbeddingPipeline — calls VectorSearch.delete
3. In MemoryViewModel's `deleteMemory()`: use a single `dbPool.write` transaction to delete ConversationSummary record, then call VectorSearch.delete with the same rowid — ensures atomicity
4. Update MockEmbeddingPipeline in tests with the new method

### Domain Tag Removal Logic

Domain tags are stored as `[String]` arrays on individual ConversationSummary records. To "remove a domain tag":
1. Query all ConversationSummary records where `domainTags` contains the target tag
2. For each record, remove the tag from the array
3. Save the updated records

This is a multi-record update. Use a single `dbPool.write` transaction for consistency.

**Note:** Removing a domain tag does NOT delete the ConversationSummary — it only removes the tag association. The memory itself remains intact.

### Project Structure Notes

All new files align with established feature-based structure:
```
ios/sprinty/Features/Settings/
├── Models/
│   ├── ProfileFact.swift          # NEW — transient display model
│   └── MemoryItem.swift           # NEW — transient display model
├── ViewModels/
│   ├── MemoryViewModel.swift      # NEW
│   └── SettingsViewModel.swift    # NEW — minimal shell
└── Views/
    ├── MemoryView.swift           # NEW
    └── SettingsView.swift         # NEW — minimal shell
```

New test files:
```
ios/Tests/
├── Features/
│   ├── MemoryViewModelTests.swift    # NEW
│   └── MemoryIntegrationTests.swift  # NEW
└── Mocks/
    (add mocks if new service protocols are created)
```

**CRITICAL:** After creating all files, update `ios/project.yml` with all new files under correct targets, then run `xcodegen generate`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-3.7] — Full acceptance criteria and user story
- [Source: _bmad-output/planning-artifacts/architecture.md#Database-Schema] — UserProfile and ConversationSummary schemas
- [Source: _bmad-output/planning-artifacts/architecture.md#MVVM-Pattern] — ViewModel pattern with protocol injection
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey-8] — Memory View flow and design
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#MemoryView-Component] — Component specification
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#SettingsView-Composition] — Settings navigation structure
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Design-Tokens] — Color, typography, spacing tokens for home palette
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Empty-States] — "Your coach is still learning about you"
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Warm-Deletion] — "Forget this?" language pattern
- [Source: _bmad-output/implementation-artifacts/3-6-in-conversation-search.md] — Previous story learnings, test patterns, file conventions
- [Source: _bmad-output/project-context.md] — Project-wide rules, anti-patterns, testing framework requirements

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- UUID storage: Used GRDB model `ConversationSession` instead of raw SQL with `uuidData` for test session creation
- Simulator: iPhone 17 (iPhone 16 not available on this machine)

### Completion Notes List
- Task 1-4: MemoryViewModel with full CRUD for profile facts, memories, and domain tags. 16 unit tests.
- Task 5: MemoryView with three sections (Profile Facts, Key Memories, Domain Tags), empty state, privacy footer, FlowLayout for tag chips.
- Task 6: SettingsView shell with NavigationLink to MemoryView. Settings gear icon added to HomeView. RootView wired with sheet presentation and lazy MemoryViewModel creation.
- Task 7: All accessibility requirements met — `.accessibilityAddTraits(.isHeader)` on section headers, `.accessibilityHint("Double tap to edit")` on facts, `.accessibilityLabel("Forget this")` on swipe actions, Dynamic Type via semantic font tokens and ScrollView, `reduceMotion` environment read.
- Task 8: 5 integration tests covering all full flows.
- Test baseline: 314 → 335 tests (21 new, 0 regressions)

### Change Log
- 2026-03-23: Implemented Story 3.7 — Memory View & Profile Editing. All 8 tasks complete with 21 new tests.
- 2026-03-23: Code review fixes applied — (H1) domain fact update/delete unreachable code path fixed, (H2) swipeActions moved into List context, (H3) memory+vector deletion reordered for safety, (M1) Task.isCancelled checks added, (M2) project.pbxproj documented in File List, (L1) unused reduceMotion removed.

### File List
- ios/sprinty/Features/Settings/Models/ProfileFact.swift (NEW)
- ios/sprinty/Features/Settings/Models/MemoryItem.swift (NEW)
- ios/sprinty/Features/Settings/ViewModels/MemoryViewModel.swift (NEW)
- ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift (NEW)
- ios/sprinty/Features/Settings/Views/MemoryView.swift (NEW)
- ios/sprinty/Features/Settings/Views/SettingsView.swift (NEW)
- ios/sprinty/Features/Home/Views/HomeView.swift (MODIFIED — added onOpenSettings callback and gear icon)
- ios/sprinty/App/RootView.swift (MODIFIED — added showSettings state, memoryViewModel, ensureMemoryViewModel, sheet presentation)
- ios/sprinty/Services/Database/VectorSearch.swift (MODIFIED — added delete(rowid:) to protocol and implementation)
- ios/sprinty/Services/Memory/EmbeddingPipelineProtocol.swift (MODIFIED — added deleteEmbedding method)
- ios/sprinty/Services/Memory/EmbeddingPipeline.swift (MODIFIED — implemented deleteEmbedding)
- ios/Tests/Features/MemoryViewModelTests.swift (NEW — 16 unit tests)
- ios/Tests/Features/MemoryIntegrationTests.swift (NEW — 5 integration tests)
- ios/Tests/Mocks/MockEmbeddingPipeline.swift (MODIFIED — added deleteEmbedding tracking)
- ios/Tests/Mocks/MockVectorSearch.swift (MODIFIED — added delete(rowid:) tracking)
- ios/sprinty.xcodeproj/project.pbxproj (MODIFIED — new files added to Xcode project)
