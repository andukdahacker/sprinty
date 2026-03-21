# Story 3.6: In-Conversation Search

Status: done

## Story

As a user looking for a specific past exchange,
I want to search my conversation history by keyword,
So that I can quickly find what my coach and I discussed about a specific topic.

## Acceptance Criteria

1. **AC1 — Search UI Trigger:** Given a user is in the conversation view, when they tap the search icon in the coach character area, then the SearchOverlayView expands with a text field, results count, up/down navigation, and dismiss button.

2. **AC2 — Search Query Execution & Results Display:** Given the user types a search query, when FTS5 full-text search executes on local SQLite, then results are highlighted inline in the conversation, and tapping up/down scrolls to the next/previous match, and results count displays "Result [n] of [total]", and search completes in under 200ms.

3. **AC3 — Accessibility (VoiceOver):** Given the search is active, when VoiceOver is enabled, then the field announces "Search conversation history" and results announce "Result [n] of [total]".

4. **AC4 — Empty State:** Given no results match, when the search completes, then the empty state shows "No matches. Try asking your coach." (UX-DR72).

5. **AC5 — Offline Capability:** Given the device is offline, when the user searches, then search works fully offline (FTS5 on local SQLite).

## Tasks / Subtasks

- [x] Task 1: FTS5 Search Service (AC: #2, #5)
  - [x] 1.1 Create `SearchService` protocol + implementation in `Services/Database/`
  - [x] 1.2 FTS5 query via GRDB: `SELECT rowid, snippet(MessageFTS, ...) FROM MessageFTS WHERE MessageFTS MATCH ?`
  - [x] 1.3 Map FTS results back to Message records (rowid → Message with sessionId, timestamp)
  - [x] 1.4 Return results ordered by relevance (FTS5 rank) with match snippets
  - [x] 1.5 Unit tests: query with matches, no matches, special characters, empty query

- [x] Task 2: Search State in CoachingViewModel (AC: #1, #2)
  - [x] 2.1 Add search state properties: `isSearchActive`, `searchQuery`, `searchResults: [SearchResult]`, `currentResultIndex`
  - [x] 2.2 Add `SearchResult` struct: messageId (UUID), sessionId (UUID), snippet (String)
  - [x] 2.3 Add `performSearch(_ query: String) async` method — debounce 300ms, call SearchService
  - [x] 2.4 Add `navigateToResult(direction: .next | .previous)` — updates `currentResultIndex`, triggers scroll
  - [x] 2.5 Add `dismissSearch()` — clears state, preserves scroll position
  - [x] 2.6 Unit tests: search lifecycle, navigation wrap-around, empty results, debounce

- [x] Task 3: SearchOverlayView Component (AC: #1, #3, #4)
  - [x] 3.1 Create `SearchOverlayView.swift` in `Features/Coaching/Views/`
  - [x] 3.2 Collapsed state: search icon only (positioned below CoachCharacterView in CoachingView)
  - [x] 3.3 Expanded state: text field + "Result [n] of [total]" + up/down chevrons + dismiss (X) button
  - [x] 3.4 Empty state: "No matches. Try asking your coach."
  - [x] 3.5 Style with CoachingTheme tokens, animate expand/collapse respecting `accessibilityReduceMotion`
  - [x] 3.6 VoiceOver: field label "Search conversation history", results label "Result [n] of [total]"
  - [x] 3.7 SwiftUI previews: collapsed, expanded with results, expanded empty, accessibility XL

- [x] Task 4: Inline Result Highlighting in Conversation (AC: #2)
  - [x] 4.1 Extend DialogueTurnView to accept optional `highlightQuery: String?` parameter
  - [x] 4.2 When highlightQuery is set, build `AttributedString` from content: find all case-insensitive occurrences of query in text, apply `.backgroundColor` attribute with CoachingTheme accent color on matched ranges
  - [x] 4.3 Add `isCurrentResult: Bool` parameter — current result uses stronger highlight (full accent opacity), other matches use subtle highlight (0.3 opacity)
  - [x] 4.4 Clear highlights when search dismissed (pass nil for highlightQuery)

- [x] Task 5: Integration — CoachingView Wiring (AC: #1, #2)
  - [x] 5.1 Add SearchOverlayView to CoachingView's VStack, positioned between CoachCharacterView and ScrollView — the search icon appears below the coach portrait, expanding inline when tapped
  - [x] 5.2 On search result navigation: `scrollProxy.scrollTo(messageId)` to jump to match
  - [x] 5.3 Ensure pagination loads additional history if result is in unloaded page
  - [x] 5.4 Save pre-search position: record the message ID currently visible (track via .onAppear on each DialogueTurnView, store as `lastVisibleMessageId`), then on dismiss: `scrollProxy.scrollTo(lastVisibleMessageId)`
  - [x] 5.5 Hide search icon while `isStreaming == true` — searching during streaming causes scroll conflicts and confuses the user. Re-show when streaming completes

- [x] Task 6: Accessibility & Edge Cases (AC: #3, #5)
  - [x] 6.1 VoiceOver announcements for result count changes, navigation between results
  - [x] 6.2 Dynamic Type: all search UI text uses semantic fonts
  - [x] 6.3 Reduce Motion: instant transitions when enabled
  - [x] 6.4 Keyboard dismiss on scroll, re-show on tap in search field
  - [x] 6.5 Edge cases: search with pagination boundary, minimum 2-character query threshold

- [x] Task 7: Integration Tests (AC: #1-5)
  - [x] 7.1 Search finds messages across multiple sessions
  - [x] 7.2 Up/down navigation cycles through results correctly
  - [x] 7.3 Empty query returns no results (no crash)
  - [x] 7.4 Special characters in query handled safely
  - [x] 7.5 Offline search works (no network calls)
  - [x] 7.6 Search + pagination interaction (result in unloaded page)

## Dev Notes

### What Already Exists — DO NOT Recreate

- **MessageFTS virtual table** — Created in v6 migration (Story 3.5). FTS5 table with INSERT/UPDATE/DELETE triggers already syncing with Message table. [Source: ios/sprinty/Services/Database/Migrations.swift]
- **idx_message_timestamp index** — Cross-session ORDER BY performance index on Message.timestamp. [Source: ios/sprinty/Services/Database/Migrations.swift]
- **CoachCharacterView** — Simple view taking `expression: CoachExpression`, renders portrait circle + name + status text. Has NO search hook slot — SearchOverlayView must be placed adjacent in CoachingView's VStack (between CoachCharacterView and ScrollView). [Source: ios/sprinty/Features/Coaching/Views/CoachCharacterView.swift]
- **DialogueTurnView** — Renders message content as plain `Text(paragraph)` split by `"\n\n"`. Has coach/user/memoryReference variants. Currently NO attributed text or highlighting support — must be extended with `AttributedString` for search highlights. [Source: ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift]
- **CoachingViewModel pagination** — historyPageSize=50, historyOffset, hasMoreHistory, loadHistoryPage(). Search must work alongside this. [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift]
- **DateSeparatorView, SessionSummaryCardView** — Existing conversation UI components. Search highlights should appear within existing layout. [Source: ios/sprinty/Features/Coaching/Views/]
- **ScrollViewReader** — Already used for scroll position preservation during pagination. Reuse for search result navigation. [Source: ios/sprinty/Features/Coaching/Views/CoachingView.swift]
- **GRDB DatabasePool** — Thread-safe reads via `.read { db in }`. Use same pattern for FTS queries. [Source: ios/sprinty/Services/Database/DatabaseManager.swift]

### Architecture Compliance

**Database:**
- FTS5 queries go through GRDB DatabasePool.read — same pattern as all other queries
- Query must use `MessageFTS MATCH ?` syntax (FTS5 match expression)
- **CRITICAL: MessageFTS is an external content table** (`content='Message'`) — it stores only the search index, NOT the actual content. Direct `SELECT content FROM MessageFTS` returns empty strings. You MUST JOIN back to the Message table to get actual message content: `INNER JOIN MessageFTS fts ON fts.rowid = m.rowid`
- Map FTS rowid back to Message via the JOIN (see FTS5 Query Pattern below)
- DO NOT create new tables or migrations — MessageFTS already exists
- Table names: PascalCase singular. Column names: camelCase

**Swift Concurrency:**
- SearchService: NOT `@MainActor`, marked `Sendable` (it's a service, not a ViewModel)
- Search state on CoachingViewModel: `@MainActor` (it updates UI)
- Debounce with `Task` + cancel previous task pattern (no Combine)
- NEVER use Combine, DispatchQueue, or ObservableObject

**MVVM Pattern:**
- SearchOverlayView reads from CoachingViewModel search state
- CoachingViewModel owns search logic and delegates to SearchService
- SearchService is injected via protocol for testability

**Error Handling:**
- FTS query failures: local error on ViewModel (not global AppState error)
- Graceful degradation: if FTS query fails, show empty state, log at Error level via os.Logger

### Library/Framework Requirements

- **GRDB.swift** — FTS5 query support via raw SQL or GRDB's FTS5 API. Use `db.execute(sql:)` for FTS MATCH queries
- **sqlite-vec** — NOT needed for this story (FTS5 is keyword search, not vector search)
- **No new dependencies** — Everything needed is already in the project

### File Structure Requirements

**New Files:**
```
ios/sprinty/Services/Database/SearchService.swift          # SearchServiceProtocol + implementation
ios/sprinty/Features/Coaching/Views/SearchOverlayView.swift # Search UI component
ios/Tests/Database/SearchServiceTests.swift                 # FTS5 query tests
ios/Tests/Features/SearchIntegrationTests.swift             # End-to-end search tests
```

**Modified Files:**
```
ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift  # Search state + methods
ios/sprinty/Features/Coaching/Views/CoachingView.swift            # Wire SearchOverlayView + scroll-to-result
ios/sprinty/Features/Coaching/Views/CoachCharacterView.swift      # No changes needed — search lives in CoachingView
ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift        # Add highlight support
ios/Tests/Features/CoachingViewModelTests.swift                    # Search state tests
ios/Tests/Mocks/MockSearchService.swift                            # Test mock (if needed)
```

### Testing Requirements

- **Framework:** Swift Testing (`@Test` macro). NEVER use XCTest
- **Database tests:** Use `makeTestDB()` for in-memory GRDB with real migrations. NEVER mock the database
- **Async tests:** `@Test @MainActor func test_something() async { }` for ViewModel tests
- **Test naming:** `test_methodName_condition_expectedResult`
- **Current baseline: 282 tests** — maintain or increase
- **Mock pattern:** Hand-written protocol mocks, no frameworks

**Key test scenarios:**
- FTS5 MATCH query returns correct messages
- FTS5 handles special characters (quotes, asterisks) without crash
- Search debounce cancels previous in-flight query
- Navigation wraps from last result to first
- Search during active streaming doesn't corrupt state
- Pagination loads missing history when navigating to old result
- Empty query returns empty results (not all messages)

### FTS5 Query Pattern

```swift
// GRDB FTS5 query pattern for MessageFTS
func search(query: String, limit: Int = 50) throws -> [SearchResult] {
    try dbPool.read { db in
        let sanitized = sanitizeFTSQuery(query)
        let rows = try Row.fetchAll(db, sql: """
            SELECT m.id, m.sessionId, m.content, m.timestamp
            FROM Message m
            INNER JOIN MessageFTS fts ON fts.rowid = m.rowid
            WHERE MessageFTS MATCH ?
            ORDER BY fts.rank
            LIMIT ?
            """, arguments: [sanitized, limit])
        return rows.map { row in
            SearchResult(
                messageId: row["id"],
                sessionId: row["sessionId"],
                content: row["content"],
                timestamp: row["timestamp"]
            )
        }
    }
}
```

**FTS5 Query Sanitization — CRITICAL:**
- User input must be sanitized before FTS5 MATCH
- Empty/whitespace-only query → return empty results immediately
- Queries shorter than 2 characters → return empty results (single-char queries return massive result sets and hurt performance)
- Sanitization function: strip FTS5 operators (`AND`, `OR`, `NOT`, `NEAR`), escape double quotes by doubling them (`"` → `""`), then wrap each word in double quotes for exact term matching
- Example: `"job offer"` → `"\"job\"" "\"offer\""`

```swift
func sanitizeFTSQuery(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else { return nil }
    let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .filter { !["AND", "OR", "NOT", "NEAR"].contains($0.uppercased()) }
    guard !words.isEmpty else { return nil }
    return words.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        .joined(separator: " ")
}
```

### Debounce Pattern (No Combine)

```swift
// Task-based debounce pattern
private var searchTask: Task<Void, Never>?

func updateSearchQuery(_ query: String) {
    searchQuery = query
    searchTask?.cancel()
    searchTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await performSearch(query)
    }
}
```

### Inline Highlight Technique

DialogueTurnView currently renders each paragraph as plain `Text(paragraph)`. To add search highlighting:

1. Add `highlightQuery: String?` and `isCurrentResult: Bool = false` parameters to DialogueTurnView
2. When `highlightQuery` is non-nil, convert each paragraph to `AttributedString` instead of plain `Text`
3. Find all case-insensitive occurrences of the query in the paragraph text
4. Apply `.backgroundColor` attribute on matched ranges using CoachingTheme accent color
5. Current result message uses full opacity highlight; other matches use 0.3 opacity

```swift
// Inside DialogueTurnView paragraph rendering
if let query = highlightQuery, !query.isEmpty {
    var attributed = AttributedString(paragraph)
    let searchStr = paragraph.lowercased()
    let queryLower = query.lowercased()
    var searchStart = searchStr.startIndex
    while let range = searchStr.range(of: queryLower, range: searchStart..<searchStr.endIndex) {
        let attrRange = AttributedString.Index(range.lowerBound, within: attributed)!
            ..< AttributedString.Index(range.upperBound, within: attributed)!
        attributed[attrRange].backgroundColor = isCurrentResult
            ? theme.palette.userAccent.opacity(0.4)
            : theme.palette.userAccent.opacity(0.15)
        searchStart = range.upperBound
    }
    Text(attributed)
} else {
    Text(paragraph)
}
```

This approach preserves existing memoryReferenced italic/opacity styling and works with Dynamic Type.

### Scroll Position Save/Restore

ScrollViewReader does not expose current scroll offset. To restore position on search dismiss:

1. Track `lastVisibleMessageId: UUID?` on CoachingViewModel
2. On each DialogueTurnView `.onAppear`, update `lastVisibleMessageId = message.id`
3. When search activates (`isSearchActive` becomes true), snapshot `preSearchMessageId = lastVisibleMessageId`
4. On search dismiss: `scrollProxy.scrollTo(preSearchMessageId, anchor: .center)`

### Scroll-to-Result with Pagination

When user navigates to a result that's in an unloaded page:
1. Check if `messageId` exists in current `messages` array
2. If not, call `loadHistoryPage()` repeatedly until found or `hasMoreHistory == false`
3. Then `scrollProxy.scrollTo(messageId)`
4. Same anchor strategy as Story 3.5 pagination

### Previous Story Intelligence

**From Story 3.5 (Conversation History Browsing):**
- **sendMessage() session filtering** — After pagination, messages array contains cross-session history. MUST filter to currentSession.id before building API chatMessages. This bug was caught in code review — don't regress
- **Pagination trigger at index == 0 only** — .onAppear on first 5 items caused race conditions. Fixed to trigger only at index 0
- **Batch loading pattern** — Collect sessionIds, single batch query via `ConversationSummary.forSessionIds()`. Apply same batch thinking to search
- **ScrollViewReader anchor strategy** — Record anchorId before mutation, scroll back after. Use same pattern for search result navigation
- **FTS5 UPDATE trigger** — Already handles message content edits. No additional trigger work needed
- **282 tests passing** — Maintain this baseline

**From Story 3.4 (RAG-Powered Contextual Coaching):**
- memoryReferencedMessages is a transient `[UUID: Bool]` dictionary — search highlights should use a similar transient dictionary pattern for highlighted message IDs

### UX Design References

- **UX-DR32:** SearchOverlayView — search icon in coach area, expands to text field + results count + navigation, FTS5 search, results highlighted inline, fully offline
- **UX-DR50:** Dual search — "ask coach" (RAG/semantic) and "direct search" (FTS5/keyword). This story implements the FTS5 direct search path only
- **UX-DR72:** Empty state message: "No matches. Try asking your coach."
- **Search icon placement:** UX spec says "tucked into coach character area." Implementation: place SearchOverlayView between CoachCharacterView and ScrollView in CoachingView's VStack — visually adjacent to the coach portrait, accessible but not prominent

### Project Structure Notes

- All new files follow existing feature-based organization
- SearchService lives in `Services/Database/` alongside VectorSearch and DatabaseManager
- SearchOverlayView lives in `Features/Coaching/Views/` alongside existing conversation views
- No new folders needed
- XcodeGen globs auto-include new files — no manual project file edits

### Anti-Patterns to Avoid

- DO NOT use Combine (no `@Published`, no `ObservableObject`, no `.debounce`)
- DO NOT use XCTest (use Swift Testing `@Test` macro)
- DO NOT edit `.xcodeproj/project.pbxproj` directly
- DO NOT create orphan messages or sessions during search
- DO NOT make network calls during search — this is 100% local/offline
- DO NOT add new database migrations — FTS5 infrastructure already exists
- DO NOT re-implement FTS5 triggers — they're already in v6 migration
- DO NOT use sqlite-vec for keyword search — FTS5 is the correct tool

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic-3, Story 3.6]
- [Source: _bmad-output/planning-artifacts/architecture.md#Database-Schema, #Memory-Pipeline]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR32, #UX-DR50, #UX-DR72]
- [Source: _bmad-output/planning-artifacts/prd.md#FR75, #NFR5, #NFR9]
- [Source: _bmad-output/project-context.md#Database-Testing, #Anti-Patterns]
- [Source: _bmad-output/implementation-artifacts/3-5-conversation-history-browsing.md#Dev-Notes]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- FTS5 row mapping fix: GRDB stores UUID as binary Data(16 bytes), not String — fixed Row column decoding to use `row["id"] as UUID`
- Pre-existing test failure: `getOrCreateSession creates new session after previous was ended` fails on main branch — not introduced by this story

### Completion Notes List
- ✅ Task 1: Created `SearchService` with `SearchServiceProtocol`, FTS5 MATCH query via GRDB, sanitization of user input (strip FTS operators, escape quotes, 2-char minimum), result ordering by FTS5 rank. 17 unit tests.
- ✅ Task 2: Added search state to `CoachingViewModel` — `isSearchActive`, `searchQuery`, `searchResults`, `currentResultIndex`, `hasSearched`, debounce via Task cancellation (300ms), navigation with wrap-around, pre-search position tracking. 8 unit tests.
- ✅ Task 3: Created `SearchOverlayView` — collapsed (search icon), expanded (text field + result count + up/down navigation + dismiss), empty state gated on `hasSearched` ("No matches. Try asking your coach."), VoiceOver labels, reduce motion support, 4 SwiftUI previews (including Accessibility XL).
- ✅ Task 4: Extended `DialogueTurnView` with `highlightQuery` and `isCurrentResult` parameters. Uses `AttributedString` with `.backgroundColor` — current result at 0.4 opacity, other matches at 0.15 opacity.
- ✅ Task 5: Wired `SearchOverlayView` into `CoachingView` between CoachCharacterView and ScrollView. Scroll-to-result on navigation, pagination loading for unloaded results, pre-search position save/restore on dismiss, search icon hidden during streaming.
- ✅ Task 6: VoiceOver announcements via `AccessibilityNotification.Announcement` for result count changes and navigation. Dynamic Type with semantic fonts. Keyboard dismiss on scroll via `.scrollDismissesKeyboard(.interactively)`.
- ✅ Task 7: 6 integration tests covering cross-session search, navigation cycling, empty/special character queries, offline operation, pagination interaction.

### Change Log
- 2026-03-21: Story 3.6 implemented — FTS5 in-conversation search with SearchService, SearchOverlayView, inline highlighting, CoachingView integration, accessibility, 31 new tests (314 total)
- 2026-03-21: Code review fixes — removed redundant SearchResult.id field (computed property), added `hasSearched` flag to gate empty state display during debounce, fixed weak self capture after Task.sleep, added 4th SwiftUI preview (Accessibility XL), regenerated pbxproj via XcodeGen

### File List
- ios/sprinty/Services/Database/SearchService.swift (new)
- ios/sprinty/Features/Coaching/Views/SearchOverlayView.swift (new)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified)
- ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift (modified)
- ios/Tests/Database/SearchServiceTests.swift (new)
- ios/Tests/Features/SearchIntegrationTests.swift (new)
- ios/Tests/Features/CoachingViewModelTests.swift (modified)
- ios/Tests/Mocks/MockSearchService.swift (new)
