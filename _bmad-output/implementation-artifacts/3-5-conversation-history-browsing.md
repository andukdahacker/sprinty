# Story 3.5: Conversation History Browsing

Status: done

## Story

As a user,
I want to scroll through my past conversations and see summaries and key moments,
So that I can revisit important coaching exchanges anytime.

## Acceptance Criteria

1. **Continuous Scroll History** — Given a user is in the conversation view, when they scroll up past today's messages, then previous conversation sessions load with date separators marking passage of time, loading uses LazyVStack pagination (imperceptible loading), and the continuous conversation model is maintained — no inbox, no thread list, one continuous thread (UX-DR46).

2. **Summary & Key Moments Access** — Given past conversations in the history, when viewing them, then summaries and key moments are accessible inline (displayed between conversation sessions as collapsible summary cards showing summary text, key moments, and domain tags from ConversationSummary records).

3. **Offline History** — Given no network connectivity, when the user browses conversation history, then all history is stored locally and works fully offline (NFR32). No degradation in browsing experience.

4. **Date Separators** — Given conversations span multiple days or sessions, when viewing the continuous thread, then DateSeparatorView displays "Today", "Yesterday", or absolute date between turns from different days (UX-DR42), announced as VoiceOver landmarks. A date separator also appears at every session boundary even if two sessions occurred on the same day.

5. **Pagination Performance** — Given a user with 10,000+ conversation summaries (~2 years daily use), when scrolling through history, then pagination is imperceptible — query performance under 500ms (NFR18), LazyVStack loads pages on demand, NO loading spinner, NO progress bar, NO "loading more..." text. Pagination must be completely invisible to the user.

6. **First Conversation Reachable** — Given the continuous conversation model, when scrolling to the very top of history, then the first-ever onboarding conversation is reachable (UX-DR46: "onboarding conversation is turn one forever").

7. **Scroll-to-Bottom on Open** — Given the user taps "Talk to your coach" from home, when the conversation view opens, then it scrolls to the bottom showing today's date separator and coach greeting (UX-DR43), not the top of history.

8. **Accessibility** — Given VoiceOver is enabled, when navigating the conversation history, then navigation order is coach character -> dialogue turns (chronological) -> input field (UX-DR60), date separators announce as landmarks ("Conversation from [date]"), and all text supports Dynamic Type (NFR22).

## Tasks / Subtasks

- [x] **Task 0: Database migration for history performance** (AC: 5)
  - [x] 0.1 Add migration "v6" to `ios/sprinty/Services/Database/Migrations.swift` — create index `idx_message_timestamp` on `Message(timestamp)` for cross-session ORDER BY performance. Current migrations end at v5. Append-only, never modify existing migrations
  - [x] 0.2 In the same v6 migration, create FTS5 virtual table for Message content: `CREATE VIRTUAL TABLE IF NOT EXISTS MessageFTS USING fts5(content, content='Message', content_rowid='rowid')` — prepares schema foundation for Story 3.6 (In-Conversation Search) which needs FTS5. Also add triggers to keep FTS in sync on INSERT/DELETE
  - [x] 0.3 Add migration tests: verify v6 runs cleanly on fresh DB and on DB with existing data. Verify timestamp index exists. Verify FTS5 table created and populated from existing messages

- [x] **Task 1: Cross-session message loading with pagination** (AC: 1, 5, 6)
  - [x] 1.1 Add `Message.allConversations(limit:offset:)` query extension to `ios/sprinty/Models/Message.swift` — fetches messages across ALL sessions ordered by timestamp DESC (newest first for reverse pagination), with limit and offset parameters
  - [x] 1.2 Add `ConversationSession.allOrdered()` query extension to `ios/sprinty/Models/ConversationSession.swift` — fetches all sessions ordered by startedAt ASC for session boundary detection
  - [x] 1.3 Add pagination state to `CoachingViewModel.swift`: `private var historyPageSize: Int = 50`, `private var historyOffset: Int = 0`, `private var hasMoreHistory: Bool = true`, `private var isLoadingHistory: Bool = false`
  - [x] 1.4 Add `loadHistoryPage() async` method to CoachingViewModel — loads next page of older messages via `Message.allConversations(limit:offset:)`, prepends to `messages` array (maintaining chronological order), updates offset and hasMoreHistory flag. Uses `databaseManager.dbPool.read { db in }` pattern
  - [x] 1.5 Modify existing `loadMessagesAsync()` to load initial messages (current session + most recent N messages) — this is the entry point, `loadHistoryPage()` loads older pages on scroll
  - [x] 1.6 Add tests: pagination loads correct pages, offset increments, hasMoreHistory becomes false at end, messages maintain chronological order across sessions

- [x] **Task 2: Scroll-triggered pagination in CoachingView** (AC: 1, 5, 7)
  - [x] 2.1 Add scroll position detection to CoachingView — when user scrolls near the top of the LazyVStack (within first 5 items), trigger `viewModel.loadHistoryPage()` if `hasMoreHistory` and not `isLoadingHistory`
  - [x] 2.2 Maintain scroll position when prepending history — after loading older messages, preserve the user's current scroll position so content doesn't jump. Use `ScrollViewReader` with anchor positioning: record the ID of the topmost visible message before load, then scroll to that ID after prepend
  - [x] 2.3 Implement scroll-to-bottom on conversation open — ensure `scrollTo(lastMessageId, anchor: .bottom)` fires on initial load (already partially implemented, verify it works with pagination)
  - [x] 2.4 Add tests: scroll trigger fires loadHistoryPage, scroll position preserved after prepend

- [x] **Task 3: Cross-session date separators** (AC: 4, 8)
  - [x] 3.1 Modify `shouldShowDateSeparator()` in CoachingView to work across session boundaries — currently only checks within a single session's messages. Must compare timestamps of consecutive messages regardless of session, including the first message of a new session getting a separator
  - [x] 3.2 Add session boundary detection — when a message's sessionId differs from the previous message's sessionId, ensure a date separator appears (even if same day) to mark session transitions
  - [x] 3.3 Verify DateSeparatorView VoiceOver announcement — already exists as `accessibilityLabel("Conversation from \(formattedDate)")`, verify it works with `.accessibilityAddTraits(.isHeader)` for landmark navigation
  - [x] 3.4 Add tests: date separators appear at session boundaries, "Today"/"Yesterday"/absolute date formatting correct, VoiceOver labels correct

- [x] **Task 4: Inline summary cards between sessions** (AC: 2)
  - [x] 4.1 Create `SessionSummaryCardView.swift` in `ios/sprinty/Features/Coaching/Views/` — displays ConversationSummary data between sessions: summary text (Font.insightText), key moments as bullet list, domain tags as pills/badges. Collapsible with chevron toggle (collapsed by default to keep history scannable)
  - [x] 4.2 Style per theme system — use `CoachingTheme` environment, `insightTextStyle()` for summary, `Spacing.dialogueBreath` internally, `Radius.container` corners. Subtle background using `insightBackground` color token
  - [x] 4.3 Add accessibility: `accessibilityLabel("Session summary: [summary text]. Key moments: [moments].")`, collapsible state announced via `accessibilityHint("Double tap to expand/collapse")`
  - [x] 4.4 Integrate into CoachingView LazyVStack — after the last message of each past session (before the next session's date separator), render SessionSummaryCardView if a ConversationSummary exists for that session
  - [x] 4.5 Load summaries efficiently — add `summariesBySession: [UUID: ConversationSummary]` dictionary to CoachingViewModel, populated during history loading via batch query `ConversationSummary.forSessionIds([UUID])` (avoid N+1)
  - [x] 4.6 Add `ConversationSummary.forSessionIds(_ ids: [UUID])` query extension — batch fetch summaries for multiple sessions
  - [x] 4.7 Add tests: summary cards render between sessions, collapsed by default, expand/collapse toggle works, batch query returns correct summaries, accessibility labels correct

- [x] **Task 5: Dynamic Type and Reduce Motion support** (AC: 8)
  - [x] 5.1 Verify all new views support Dynamic Type — SessionSummaryCardView must scale from small to accessibility XXXL without clipping or layout breaks
  - [x] 5.2 If any animations added (e.g., summary card expand/collapse), respect `@Environment(\.accessibilityReduceMotion)` — use `.animation(.none)` when reduced motion enabled
  - [x] 5.3 Add SwiftUI previews for new views — Light mode, Dark mode, Accessibility XL size minimum. Use `#if DEBUG` preview factory on any new ViewModel
  - [x] 5.4 Add tests: Dynamic Type at XXL renders without clipping (visual inspection via previews)

- [x] **Task 6: Integration and edge cases** (AC: 1, 2, 3, 5, 6, 7)
  - [x] 6.1 Test cold start — only onboarding conversation exists. Scrolling up shows no additional history. No summary card (no summary for onboarding conversation)
  - [x] 6.2 Test single session — user has one conversation. Scrolling up shows onboarding + one session with date separator between them
  - [x] 6.3 Test offline browsing — verify history loads entirely from GRDB, no network calls. ConnectivityMonitor offline state doesn't affect browsing
  - [x] 6.4 Test large history — generate 100 sessions with messages, verify pagination loads smoothly without memory pressure. Ensure LazyVStack doesn't load all views upfront
  - [x] 6.5 Test session without summary — if ConversationSummary not generated yet (pipeline failure), no summary card shown. No crash, no empty card
  - [x] 6.6 Verify new files are picked up by XcodeGen — `ios/project.yml` uses `sources: [{path: sprinty}]` glob so app source files are auto-included. New test files in `ios/Tests/` may need explicit addition to test target if not covered by glob. Run `xcodegen generate` to confirm
  - [x] 6.7 Run full test suite — maintain 263+ test baseline (from Story 3.4)

## Dev Notes

### Architecture Compliance

**This is NOT a separate history screen.** The UX spec (UX-DR46) mandates a continuous conversation model: no inbox, no thread management, scrolling up in the existing ConversationView shows previous sessions with date separators. The CoachingView is extended, not replaced.

**CoachCharacterView stays pinned at top during all scrolling.** The UX spec requires: "The spatial relationship of 'I'm talking to this person' persists even when scrolled deep in conversation history." The coach character is a sticky element above the ScrollView — do NOT move it inside the scroll content or hide it during history browsing.

**Critical Pattern: Reverse Pagination**
The conversation view opens scrolled to the bottom (most recent). History loads backwards — when user scrolls up, older pages load. This is reverse chronological pagination:
1. Initial load: current session messages + N most recent messages
2. Scroll up near top: load next page of older messages
3. Prepend to messages array (maintaining chronological display order)
4. Preserve scroll position (no content jump)

**Change Scope:**
- `Migrations.swift` — add v6 migration (timestamp index + FTS5 virtual table)
- `Message.swift` — add cross-session query extension
- `ConversationSession.swift` — add allOrdered query extension
- `ConversationSummary.swift` — add batch fetch by session IDs
- `CoachingViewModel.swift` — add pagination state and loadHistoryPage()
- `CoachingView.swift` — add scroll-triggered pagination, cross-session date separators, summary card rendering
- NEW: `SessionSummaryCardView.swift` — collapsible summary card component

### What Already Exists (DO NOT Recreate)

- `DateSeparatorView` (`ios/sprinty/Features/Coaching/Views/DateSeparatorView.swift`) — fully built with "Today"/"Yesterday"/absolute date formatting, VoiceOver landmark. Reuse directly.
- `DialogueTurnView` (`ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift`) — renders coach/user turns with memoryReferenced styling. No changes needed.
- `CoachingView` (`ios/sprinty/Features/Coaching/Views/CoachingView.swift`) — already has ScrollViewReader + LazyVStack + shouldShowDateSeparator(). Extend, don't rewrite.
- `CoachingViewModel` (`ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift`) — already loads messages for current session. Add pagination methods alongside existing logic.
- `ConversationSummary` model — has `.recent()`, `.forSession()`, `.forDomainTag()` queries. Add `.forSessionIds()` batch query.
- `Message` model — has `.forSession()` query. Add `.allConversations(limit:offset:)`.
- `CoachingTheme` — fully built with conversation context colors. Use `insightBackground`, `insightTextStyle()` for summary cards.
- `SpacingScale` — `dialogueTurn: 24`, `dialogueBreath: 8` for layout.
- `RadiusTokens` — `container: 16` for card corners.

### What Must Be Added/Modified

**New File:**
- `ios/sprinty/Features/Coaching/Views/SessionSummaryCardView.swift` — Collapsible card showing session summary, key moments, domain tags between past sessions

**Modified Files:**
- `ios/sprinty/Services/Database/Migrations.swift` — add v6 migration (timestamp index + FTS5 virtual table for Story 3.6 preparation)
- `ios/sprinty/Models/Message.swift` — add `allConversations(limit:offset:)` query extension
- `ios/sprinty/Models/ConversationSession.swift` — add `allOrdered()` query extension
- `ios/sprinty/Models/ConversationSummary.swift` — add `forSessionIds([UUID])` batch query
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — add pagination state, `loadHistoryPage()`, `summariesBySession` dictionary, batch summary loading
- `ios/sprinty/Features/Coaching/Views/CoachingView.swift` — add scroll-triggered pagination, cross-session date separators, summary card integration, scroll position preservation

### Scroll Position Preservation Strategy

When prepending older messages to the array, the scroll position must not jump. Strategy:

```swift
// Before loading: record ID of current topmost visible message
let anchorMessageId = messages.first?.id

// After prepending: scroll back to the anchor
if let anchorId = anchorMessageId {
    scrollProxy.scrollTo(anchorId, anchor: .top)
}
```

This is critical for imperceptible pagination. Test by scrolling up, verifying content prepends without visible jump.

### Batch Summary Loading Strategy

In `loadHistoryPage()`, collect unique sessionIds from the new page, then batch-fetch summaries via `ConversationSummary.forSessionIds()` and populate the `summariesBySession` dictionary. One query per page — never per session (avoid N+1).

### Session Boundary Detection

In the LazyVStack rendering loop, check if consecutive messages have different `sessionId` values. At each session boundary: render a `SessionSummaryCardView` for the ending session (if summary exists), then a `DateSeparatorView` for the new session. The `shouldShowDateSeparator()` function must also return `true` at session boundaries even if both sessions are on the same day.

### Performance Requirements

- Cross-session query: < 500ms even with 10K+ messages (use LIMIT/OFFSET, index on timestamp)
- LazyVStack: only renders visible + buffer views (SwiftUI built-in)
- Summary batch fetch: single query per page load, not per session
- No network calls during history browsing — all local GRDB
- Memory: older messages can be released by LazyVStack (SwiftUI manages view lifecycle)

### Previous Story Intelligence

**From Story 3.4 (RAG-Powered Contextual Coaching):**
- 263 tests baseline (21 added in 3.4)
- Daily greeting already pre-generates on conversation view load — history pagination must not interfere with greeting display
- `memoryReferenced` flag on DialogueTurnView exists but is stored in a **transient** `[UUID: Bool]` dictionary in CoachingViewModel (not persisted to DB). Historical coach turns loaded via pagination will NOT have this flag — they render as normal coach turns without memory reference styling. This is correct behavior: the styling was a real-time visual cue, not a permanent record
- CoachingViewModel already has `embeddingPipeline` and `databaseManager` injected — reuse for summary queries

**From Story 3.3 (User Profile & Domain State):**
- Fire-and-forget pattern for background enrichment — apply same pattern if any post-load processing needed
- DI wiring in `RootView.ensureCoachingViewModel()` — no new DI needed for this story

**From Story 3.2 (Embedding Pipeline):**
- GRDB DatabasePool for thread-safe reads — use `.read { db in }` for pagination queries
- Batch fetch pattern: `WHERE rowid IN (?)` — use similar for `ConversationSummary.forSessionIds()`

**From Story 3.1 (Conversation Summaries):**
- ConversationSummary model with JSON-encoded array columns — `.decodedKeyMoments`, `.decodedDomainTags` accessors exist. Use in SessionSummaryCardView.

### Git Intelligence

Recent commits follow pattern: `feat: Story X.Y — Description with code review fixes`. Files modified across Stories 3.1-3.4 established all the models, services, and view patterns this story builds on. No structural changes or refactors needed — this story is purely additive UI work on existing infrastructure.

### Project Structure Notes

- New file: `ios/sprinty/Features/Coaching/Views/SessionSummaryCardView.swift` — auto-included by `project.yml` glob (`sources: [{path: sprinty}]`)
- New test files in `ios/Tests/` — verify they're covered by test target glob or add explicitly to `project.yml`
- Run `xcodegen generate` after adding files to regenerate `.xcodeproj`
- No server changes needed — this story is entirely iOS/on-device
- No API contract changes — no new endpoints or fields
- Database migration v6 required — adds timestamp index and FTS5 virtual table (preparation for Story 3.6)

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3, Story 3.5]
- [Source: _bmad-output/planning-artifacts/architecture.md — iOS MVVM patterns, GRDB query extensions, LazyVStack pagination]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR42, UX-DR43, UX-DR46, UX-DR59, UX-DR60, UX-DR72]
- [Source: _bmad-output/planning-artifacts/prd.md — FR9, FR75, NFR18, NFR22, NFR32, NFR37]
- [Source: _bmad-output/implementation-artifacts/3-4-rag-powered-contextual-coaching.md — Previous story learnings, 263 test baseline]
- [Source: _bmad-output/project-context.md — Project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Task 0: v6 migration with timestamp index + FTS5 virtual table already implemented prior to this session. 5 migration tests covering fresh DB, existing data, INSERT/DELETE triggers.
- Task 1: Added `Message.allConversations(limit:offset:)` for reverse-chronological pagination, `ConversationSession.allOrdered()` for ASC session ordering, `ConversationSummary.forSessionIds()` for batch fetch. CoachingViewModel gains `loadHistoryPage()`, pagination state (`historyPageSize`, `historyOffset`, `hasMoreHistory`, `isLoadingHistory`), and `summariesBySession` dictionary. `loadMessagesAsync()` now uses cross-session pagination instead of single-session fetch. 5 pagination tests.
- Task 2: CoachingView LazyVStack triggers `loadHistoryPage()` when user scrolls near top (within first 5 items). Scroll position preserved via `ScrollViewReader.scrollTo(anchorId, .top)` after prepend. Scroll-to-bottom on open suppressed during history loading.
- Task 3: `shouldShowDateSeparator()` now returns true at session boundaries (different sessionId) even on same day. `isSessionBoundary()` added for summary card placement.
- Task 4: `SessionSummaryCardView` created — collapsible card showing summary text, key moments (bullet list), domain tags (flow layout pills). Collapsed by default. Styled with CoachingTheme (`insightBackground`, `insightTextStyle()`, `Radius.container`). Full accessibility: combined element with summary + moments label, expand/collapse hint. Integrated into CoachingView LazyVStack at session boundaries. 3 batch query tests.
- Task 5: SessionSummaryCardView uses `@Environment(\.accessibilityReduceMotion)` for expand/collapse animation. All text uses semantic fonts (Dynamic Type compatible). SwiftUI previews: Light, Dark, Accessibility XL.
- Task 6: Integration tests cover cold start (1 session, no history), session without summary (no crash), large history (100 sessions / 200 messages across 5 pagination pages), offline browsing (isOnline=false, loads from GRDB). XcodeGen globs auto-include new files. 282 total tests pass (14 new).

### Senior Developer Review (AI)

**Reviewer:** Code Review Workflow — 2026-03-21
**Model:** Claude Opus 4.6 (1M context)

**Findings fixed:**

1. **[HIGH] sendMessage() sent ALL history to API** — After pagination, `messages` array contained cross-session history. `sendMessage()` mapped all messages to API request, causing token blowout and session leakage. Fixed: filter to `currentSession.id` before building `chatMessages`.

2. **[HIGH] Missing FTS5 UPDATE trigger** — v6 migration had INSERT/DELETE triggers but no UPDATE trigger. If message content is ever edited, FTS index would silently diverge. Fixed: added `message_fts_update` trigger.

3. **[MEDIUM] Rapid-fire pagination from `.onAppear` on 5 items** — `.onAppear` fired for items at indices 0-4, spawning multiple concurrent pagination tasks. Fixed: trigger only at `index == 0`.

4. **[MEDIUM] `loadMessagesAsync()` created orphan sessions** — Called `getOrCreateSession()` which created new sessions just for history browsing. Fixed: read-only check for existing open session, defer creation to `sendMessage()`.

5. **[LOW] Dead code `ConversationSession.allOrdered()`** — Defined but never called. Removed along with its test.

**Tests added:** FTS5 UPDATE trigger test, sendMessage session isolation test.

### Change Log

- 2026-03-21: Story 3.5 implementation complete — all 7 tasks done, 282 tests passing (14 new)
- 2026-03-21: Code review fixes — 5 issues fixed (2 HIGH, 2 MEDIUM, 1 LOW), 2 tests added

### File List

**New Files:**
- ios/sprinty/Features/Coaching/Views/SessionSummaryCardView.swift

**Modified Files:**
- ios/sprinty/Services/Database/Migrations.swift (v6 migration + FTS UPDATE trigger fix)
- ios/sprinty/Models/Message.swift (allConversations query)
- ios/sprinty/Models/ConversationSession.swift (removed unused allOrdered query)
- ios/sprinty/Models/ConversationSummary.swift (forSessionIds batch query)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (pagination state, loadHistoryPage, summariesBySession, sendMessage session filter fix, loadMessagesAsync orphan session fix)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (scroll-triggered pagination fix, session boundary separators, summary cards)
- ios/Tests/Database/MigrationTests.swift (FTS UPDATE trigger test, removed allOrdered test)
- ios/Tests/Features/CoachingViewModelTests.swift (pagination tests, session isolation test)
- ios/Tests/Models/ConversationSummaryTests.swift (forSessionIds batch query tests)
