# Story 11.2: Conversation History Export

Status: done

## Story

As a user,
I want to export my entire conversation history,
So that I own my data and can keep a personal copy outside the app.

## Acceptance Criteria

1. **Given** the user navigates to Settings → Privacy → Export, **When** the export option is presented, **Then** an informational explanation appears with warm language (UX-DR85) and the user confirms to proceed.

2. **Given** the export process, **When** the user confirms, **Then** the system generates plain text with markdown format: coach text as paragraphs, user text as blockquotes, date separators as headers (UX-DR52), a progress message shows "Preparing your conversation..." (1-5 seconds acceptable), and the iOS Share Sheet opens with the export file.

3. **Given** the export completes, **When** the user shares or saves the file, **Then** the message "Your conversation belongs to you" is displayed (UX-DR52).

4. **Given** export failure, **When** something goes wrong, **Then** warm messaging appears: "Couldn't prepare your export. Try again in a moment." (UX-DR71).

5. **Given** the export location, **When** considering UX placement, **Then** no export button exists in the conversation view (breaks private room feeling per UX-DR52) and export is only accessible from Settings → Privacy.

6. **Given** the export runs offline, **When** the device has no connectivity, **Then** the export completes successfully since all data is local SQLite (UX offline table confirms Export = Full).

7. **Given** no conversations exist, **When** the user views the export screen, **Then** the export button is disabled and warm messaging explains: "No conversations yet. Start a coaching conversation and come back when you're ready to export."

## Tasks / Subtasks

- [x] Task 1: Create ConversationExportService (AC: #1, #2, #6, #7)
  - [x] 1.1 Create `ConversationExportServiceProtocol` in `Services/Export/ConversationExportServiceProtocol.swift`
  - [x] 1.2 Create `ConversationExportService` in `Services/Export/ConversationExportService.swift`
  - [x] 1.3 Query all ConversationSessions ordered by `startedAt` ascending
  - [x] 1.4 For each session, query Messages via `Message.forSession(id:)` (already ordered by timestamp ascending)
  - [x] 1.5 Filter out `system` role messages — only export `user` and `assistant` messages. Include messages regardless of `deliveryStatus` (pending messages are the user's words)
  - [x] 1.6 Format output as markdown: date headers (`## March 14, 2026`), coach (assistant) text as plain paragraphs, user text as blockquotes (`> user text`) per UX-DR52
  - [x] 1.7 Write formatted string to a temp file in `FileManager.default.temporaryDirectory` with `.md` extension
  - [x] 1.8 Return the temp file `URL` for share sheet
  - [x] 1.9 Add `func hasConversations() async throws -> Bool` to check if any sessions exist (for empty state)

- [x] Task 2: Add export methods to SettingsViewModel and wire DI (AC: #1, #2, #3, #4, #7)
  - [x] 2.1 Add `isExporting: Bool`, `exportError: AppError?`, `hasConversations: Bool` observable properties
  - [x] 2.2 Add `exportFileURL: URL?` observable property to trigger share sheet
  - [x] 2.3 Add `exportSuccessMessage: String?` for post-share confirmation
  - [x] 2.4 Add `exportService: ConversationExportServiceProtocol? = nil` to SettingsViewModel init (optional, matching existing DI pattern with `notificationService`)
  - [x] 2.5 Create ConversationExportService in SettingsView and pass to SettingsViewModel init alongside existing services
  - [x] 2.6 Implement `func checkHasConversations() async` — called on view appear to enable/disable export button
  - [x] 2.7 Implement `func exportConversations() async` that calls service, sets exportFileURL on success, sets exportError on failure
  - [x] 2.8 Implement `func dismissExportSuccess()` to clear success message

- [x] Task 3: Replace ExportConversationsPlaceholderView with real implementation (AC: #1, #2, #3, #4, #5, #7)
  - [x] 3.1 Replace placeholder content with export explanation screen using warm language
  - [x] 3.2 Add "Export My Conversations" button styled with coaching theme; disable when `hasConversations` is false with warm empty-state message
  - [x] 3.3 Show `ProgressView` with "Preparing your conversation..." when `isExporting` is true
  - [x] 3.4 Present iOS Share Sheet via `UIActivityViewController` wrapped in `UIViewControllerRepresentable` when `exportFileURL` is set (see Share Sheet section in Dev Notes)
  - [x] 3.5 Show "Your conversation belongs to you" confirmation after share sheet dismissal
  - [x] 3.6 Show warm error message on failure: "Couldn't prepare your export. Try again in a moment."
  - [x] 3.7 Maintain existing theme pattern: `@Environment(\.coachingTheme)`, GeometryReader, LinearGradient background
  - [x] 3.8 Add accessibility: `.accessibilityLabel("Export my conversations")` on button, VoiceOver announcements for progress/success/error state changes

- [x] Task 4: Write tests (AC: #2, #4, #6, #7)
  - [x] 4.1 Create `MockConversationExportService` implementing protocol
  - [x] 4.2 Create `Tests/Services/Export/ConversationExportServiceTests.swift` — test markdown formatting with in-memory GRDB database
  - [x] 4.3 Create `Tests/Features/Settings/SettingsViewModelExportTests.swift` — test export state transitions (idle → exporting → success/error)
  - [x] 4.4 Test empty conversation export (no sessions) — `hasConversations()` returns false
  - [x] 4.5 Test date separator formatting matches expected headers
  - [x] 4.6 Test message role attribution (user = blockquote, assistant = paragraph, system = excluded)
  - [x] 4.7 Test pending messages are included in export

## Dev Notes

### Export Format Specification

The export file must be plain text with markdown formatting. Example output:

Per UX-DR52: **coach (assistant) text as plain paragraphs, user text as blockquotes.**

```markdown
# My Coaching Conversations

## March 14, 2026

> I'm really excited to start working on my goals.

That's wonderful to hear! Let's explore what matters most to you right now. What's been on your mind lately?

> I've been feeling stuck at work. I want to make a career change but I'm scared.

It sounds like you're holding two things at once — the desire for change and the fear of uncertainty. That's completely natural. Let's sit with that for a moment...

## March 15, 2026

> I thought about what we discussed yesterday.

I'm glad you came back to it. What stood out to you?
```

**Rules:**
- File header: `# My Coaching Conversations`
- Date separators: `## {Month Day, Year}` format — use `DateFormatter` with `dateFormat = "MMMM d, yyyy"` (no `Date+Formatting.swift` exists yet — create the formatter inline in the export service)
- Coach (assistant) messages: plain paragraphs (no prefix)
- User messages: blockquotes with `> ` prefix
- System messages: **excluded entirely** — do not export system role messages
- Pending messages (offline): included in export (they are the user's words)
- Blank line between each message
- New date header when conversation date changes (compare calendar day, not session)
- File extension: `.md`
- Filename: `sprinty-conversations.md`

### Architecture Compliance

**Service Pattern:**
- `ConversationExportService` must be `Sendable`, NOT `@MainActor`
- Protocol-based: `ConversationExportServiceProtocol` in separate file
- Injected into SettingsViewModel via init as `exportService: ConversationExportServiceProtocol? = nil` (optional, matching existing DI pattern)
- Service accesses GRDB `DatabasePool` for reads — uses `dbPool.read { db in ... }`

**ViewModel Pattern:**
- SettingsViewModel is `@MainActor @Observable final class`
- Current init: `init(databaseManager:, notificationService: nil, notificationScheduler: nil)` — add `exportService: nil` as 4th optional param
- Export state properties are `@Observable`
- `exportConversations()` is `async` — called via `Task { }` from View
- Two-tier error routing: export errors are local (stay on ViewModel), not global

**View Pattern:**
- Follow existing static content view pattern from Story 11.1
- `@Environment(\.coachingTheme)` for theme access
- GeometryReader + `screenMargin(for:)` for responsive margins
- LinearGradient background with `.ignoresSafeArea()`
- `.frame(maxWidth: .infinity, maxHeight: .infinity)` BEFORE background modifier

**Share Sheet:**
- Use `UIActivityViewController` wrapped in `UIViewControllerRepresentable` — NOT `ShareLink`. Reason: `ShareLink` requires content at view construction time, but the export file is generated asynchronously. `UIActivityViewController` accepts a URL after async work completes.
- Present via `.sheet(isPresented:)` bound to `exportFileURL != nil`
- Share the temp `.md` file URL
- On sheet dismissal: set `exportSuccessMessage`, clear `exportFileURL`
- Let OS handle temp directory cleanup (files auto-purged)

### Library & Framework Requirements

- **No new dependencies required** — this feature uses only existing frameworks:
  - GRDB.swift for database reads (already imported)
  - SwiftUI for UI (already imported)
  - Foundation `FileManager` for temp file creation
- **Do NOT** use any third-party export/PDF libraries — plain text markdown only (PDF deferred to Phase 2)

### File Structure Requirements

**New Files:**
```
ios/sprinty/Services/Export/
├── ConversationExportServiceProtocol.swift
└── ConversationExportService.swift

ios/Tests/Services/Export/
└── ConversationExportServiceTests.swift

ios/Tests/Features/Settings/
└── SettingsViewModelExportTests.swift  (new file)
```

**Modified Files:**
```
ios/sprinty/Features/Settings/Views/ExportConversationsPlaceholderView.swift  → full implementation (rename optional)
ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift  → add export properties & methods
ios/sprinty.xcodeproj/project.pbxproj  → new file references (auto if folder-based)
```

### Testing Requirements

- **Framework:** Swift Testing (`@Test` macro, `#expect()`) — NOT XCTest
- **Naming:** `test_methodName_condition_expectedResult`
- **Database tests:** Use in-memory GRDB database (`DatabaseQueue()` or `DatabasePool` with `:memory:`)
- **Mocking:** Hand-written `MockConversationExportService` implementing protocol — no mock frameworks
- **What to test:**
  - Markdown format correctness (role attribution, date headers, spacing)
  - Empty database export (zero conversations) — `hasConversations()` returns false
  - Multi-session export with correct date grouping
  - System messages excluded from export
  - Pending messages included in export
  - ViewModel state transitions: idle → exporting → success, idle → exporting → error
  - Error handling: database read failure → warm error message
- **What NOT to test:** SwiftUI views — use `#Preview` for visual verification

### Previous Story Intelligence

**From Story 11.1:**
- `ExportConversationsPlaceholderView.swift` already exists at `Features/Settings/Views/` — replace its content with full implementation
- SettingsView Privacy section already has NavigationLink pointing to this view — no navigation changes needed
- SettingsViewModel already exists with DatabaseManager injection — extend it, don't create a new ViewModel
- Static content view pattern established: `@Environment(\.coachingTheme)`, GeometryReader, LinearGradient, warm tone
- Test file pattern: separate test files per feature area (e.g., `SettingsViewModelExportTests.swift`)
- Accessibility pattern: `.accessibilityLabel()` on interactive elements, Dynamic Type via theme typography
- VoiceOver: announce state changes (progress, success, error) via `AccessibilityNotification.Announcement`

**Critical from 11.1:** Two theme access patterns exist:
- SettingsView (Form container): `@Environment(\.colorScheme)` + `themeFor()` helper
- Sub-views (content views): `@Environment(\.coachingTheme)` directly
- The export view is a sub-view → use `@Environment(\.coachingTheme)` pattern

### Git Intelligence

Recent commits follow pattern: `feat: Story X.Y — Description with code review fixes`

Files from Story 11.1 that are relevant:
- `SettingsView.swift` — Privacy section with NavigationLink to export placeholder
- `SettingsViewModel.swift` — existing ViewModel to extend
- `ExportConversationsPlaceholderView.swift` — placeholder to replace

### Data Access Patterns

**Query patterns from existing codebase:**
```swift
// Load all sessions ordered chronologically
let sessions = try await databaseManager.dbPool.read { db in
    try ConversationSession.order(Column("startedAt").asc).fetchAll(db)
}

// Load messages for a session (already ordered by timestamp asc)
let messages = try await databaseManager.dbPool.read { db in
    try Message.forSession(id: sessionId).fetchAll(db)
}
```

**Date formatting:** `Date+Formatting.swift` does NOT exist yet. Create a `DateFormatter` inline in the export service with `dateFormat = "MMMM d, yyyy"` and `locale = Locale(identifier: "en_US_POSIX")` for consistent export headers like "March 14, 2026". Do NOT create a new extension file for this — keep it local to the export service.

### Anti-Patterns to Avoid

- Do NOT add an export button in CoachingView or conversation UI (breaks private room feeling — UX-DR52)
- Do NOT use PDF or any rendering library — plain text markdown only
- Do NOT create a singleton export service — inject via protocol
- Do NOT put database queries in the ViewModel — keep them in the service
- Do NOT use `print()` for logging — use `os.Logger` if logging needed
- Do NOT force-unwrap — use `guard let` / `if let`
- Do NOT create a new ViewModel for the export view — extend existing SettingsViewModel
- Do NOT stream to the file — for MVP, build the full string in memory then write once (conversation data fits in memory)
- Do NOT include ConversationSummary or embedding data in the export — only raw messages
- Do NOT include `system` role messages in the export — only `user` and `assistant`
- Do NOT filter out pending messages — include all messages regardless of `deliveryStatus`

### Project Structure Notes

- Alignment: New `Services/Export/` directory follows existing service organization pattern (`Services/Networking/`, `Services/Memory/`, `Services/Database/`)
- The export view remains in `Features/Settings/Views/` since it's accessed from Settings
- Test files mirror source structure: `Tests/Services/Export/`, `Tests/Features/Settings/`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic-11, Story 11.2]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey-11, UX-DR52, UX-DR71, UX-DR85]
- [Source: _bmad-output/planning-artifacts/architecture.md#Data-Layer, #Service-Patterns, #Testing-Standards]
- [Source: _bmad-output/planning-artifacts/prd.md#FR59-FR62, Privacy & Data]
- [Source: _bmad-output/implementation-artifacts/11-1-settings-view.md#Previous-Story-Intelligence]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Build error: SwiftUI type-checker timeout on complex view body → resolved by extracting view sections into computed properties
- Build error: `ColorPalette` has no `accent` member → replaced with `primaryActionStart` from existing palette

### Completion Notes List
- Task 1: Created `ConversationExportService` with protocol-based DI. Service is `Sendable`, queries GRDB for sessions/messages, formats markdown per UX-DR52 spec. Date headers use inline `DateFormatter` with `en_US_POSIX` locale. System messages excluded, pending messages included.
- Task 2: Extended `SettingsViewModel` with export properties (`isExporting`, `exportError`, `hasConversations`, `exportFileURL`, `exportSuccessMessage`) and methods (`checkHasConversations()`, `exportConversations()`, `dismissExportSuccess()`). DI wired through optional `exportService` parameter matching existing pattern.
- Task 3: Replaced `ExportConversationsPlaceholderView` with full `ExportConversationsView`. Warm language explanation, disabled button for empty state, progress indicator, share sheet via `UIActivityViewController` wrapped in `UIViewControllerRepresentable`, success/error messaging, full accessibility with VoiceOver announcements.
- Task 4: 19 tests total — 12 service tests (markdown formatting, date headers, role attribution, empty state, pending messages, file extension) + 7 ViewModel tests (state transitions, error handling, no-service guard). All pass. 3 pre-existing SSEParser/ChatEventCodable test failures confirmed unrelated.

### Change Log
- 2026-04-04: Story 11.2 implementation complete — conversation history export feature
- 2026-04-04: Code review fixes — (H1) Added Sendable conformance to ConversationExportService with static dateFormatter, (M2) Fixed isExporting not reset on Task cancellation via defer, (M3) ShareSheetView now reports completion vs cancellation — success message only shown when user actually shared, (L1) Added VoiceOver announcement for export progress state

### File List
- ios/sprinty/Services/Export/ConversationExportServiceProtocol.swift (new)
- ios/sprinty/Services/Export/ConversationExportService.swift (new)
- ios/sprinty/Features/Settings/Views/ExportConversationsPlaceholderView.swift (modified — replaced placeholder with full ExportConversationsView)
- ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift (modified — added export properties, methods, DI)
- ios/sprinty/Features/Settings/Views/SettingsView.swift (modified — wired ConversationExportService DI, updated NavigationLink)
- ios/Tests/Services/Export/ConversationExportServiceTests.swift (new)
- ios/Tests/Features/Settings/SettingsViewModelExportTests.swift (new)
- ios/Tests/Mocks/MockConversationExportService.swift (new)
- ios/sprinty.xcodeproj/project.pbxproj (auto-generated via xcodegen)
