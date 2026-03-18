# Story 1.4: Conversation View with Mock Streaming

Status: done

## Story

As a user,
I want to type a message and see a streaming response from my coach,
So that the conversation feels natural and immediate.

## Acceptance Criteria

1. **Given** a user is on the conversation view, **When** they type a message and tap send, **Then** the message appears as a user turn (12pt indent + left-border accent), **And** the coach character shifts to thinking expression, **And** an SSE connection opens to `POST /v1/chat` with valid JWT, **And** streaming tokens render incrementally as coach dialogue (unmarked prose), **And** the coach character shifts to welcoming expression on response completion.

2. **Given** an unauthenticated request to `/v1/chat`, **When** sent without a valid JWT, **Then** the server returns 401 and the app handles gracefully (routes through `AppError.authExpired` → `appState.needsReauth = true`).

3. **Given** a conversation with multiple turns, **When** viewing the conversation, **Then** turns are spaced 24pt apart (`Spacing.dialogueTurn`) with 8pt within multi-paragraph turns (`Spacing.dialogueBreath`), **And** a date separator appears at each date boundary in the conversation thread (e.g., "Today", "Yesterday"), **And** the view scrolls to the latest message.

4. **Given** VoiceOver is enabled, **When** navigating conversation turns, **Then** coach turns announce "Coach says: [content]", **And** user turns announce "You said: [content]", **And** the text input announces "Message your coach", **And** the send button announces "Send message".

5. **Given** the user force-quits and reopens the app, **When** they return to the conversation, **Then** all previous messages are loaded from SQLite via GRDB.

## Tasks / Subtasks

- [x] **Task 1: Server — Add `mood` field to ChatEvent and MockProvider** (AC: 1)
  - [x] 1.1 Add `Mood string` field to `ChatEvent` in `providers/provider.go`
  - [x] 1.2 Update `MockProvider.StreamChat()` to include `mood: "welcoming"` in done event
  - [x] 1.3 Update `ChatHandler` in `handlers/chat.go` to emit `mood` in SSE done event JSON
  - [x] 1.4 Update `docs/api-contract.md` SSE Done Event section to document `mood` field
  - [x] 1.5 Update `docs/fixtures/sse-done-event.txt` to include `mood` field
  - [x] 1.6 Add/update handler tests for mood field in done event

- [x] **Task 2: iOS — SSE Parser (`SSEParser.swift`)** (AC: 1, 2)
  - [x] 2.1 Create `Services/Networking/SSEParser.swift` — parses `text/event-stream` bytes into typed events
  - [x] 2.2 Returns `AsyncThrowingStream<ChatEvent, Error>` from a `URLSession` bytes stream
  - [x] 2.3 Parse `event: token\ndata: {"text": "..."}` → `ChatEvent.token(text:)`
  - [x] 2.4 Parse `event: done\ndata: {...}` → `ChatEvent.done(safetyLevel:domainTags:mood:usage:)`
  - [x] 2.5 Handle connection drops and partial reads gracefully
  - [x] 2.6 Create `Tests/Services/SSEParserTests.swift` — test with `docs/fixtures/` SSE samples

- [x] **Task 3: iOS — Chat Models (`ChatRequest.swift`, `ChatEvent.swift`, `CoachingMode.swift` transient models)** (AC: 1)
  - [x] 3.1 Create `Features/Coaching/Models/ChatRequest.swift` — `Codable`, `Sendable`, explicit `CodingKeys`
  - [x] 3.2 Create `Features/Coaching/Models/ChatEvent.swift` — enum with `.token(text:)` and `.done(safetyLevel:domainTags:mood:usage:)` cases
  - [x] 3.3 Create `Features/Coaching/Models/CoachExpression.swift` — enum: `welcoming`, `thinking`, `warm`, `focused`, `gentle`
  - [x] 3.4 Create `Tests/Models/ChatEventCodableTests.swift` — roundtrip against `docs/fixtures/`

- [x] **Task 4: iOS — ChatService with SSE streaming** (AC: 1, 2)
  - [x] 4.1 Create `Services/Networking/ChatServiceProtocol.swift` — `protocol ChatServiceProtocol: Sendable`
  - [x] 4.2 Create `Services/Networking/ChatService.swift` — `final class ChatService: ChatServiceProtocol, Sendable`
  - [x] 4.3 `func streamChat(messages:mode:) -> AsyncThrowingStream<ChatEvent, Error>`
  - [x] 4.4 Opens `URLSession` streaming request to `POST /v1/chat` with JWT from AuthService
  - [x] 4.5 Pipes response bytes through `SSEParser`
  - [x] 4.6 Create `Tests/Mocks/MockChatService.swift` — returns canned `AsyncThrowingStream` for tests

- [x] **Task 5: iOS — CoachingViewModel** (AC: 1, 2, 3, 5)
  - [x] 5.1 Create `Features/Coaching/ViewModels/CoachingViewModel.swift`
  - [x] 5.2 `@MainActor @Observable final class CoachingViewModel`
  - [x] 5.3 Properties: `messages: [Message]`, `streamingText: String`, `isStreaming: Bool`, `coachExpression: CoachExpression`, `localError: AppError?`
  - [x] 5.4 Init with dependency injection: `init(appState: AppState, chatService: ChatServiceProtocol, databaseManager: DatabaseManager)`
  - [x] 5.5 `func loadMessages()` — loads from GRDB for current session, ordered by timestamp
  - [x] 5.6 `func sendMessage(_ text: String) async` — saves user message to DB, sets expression to `.thinking`, starts SSE stream, accumulates tokens into `streamingText`, on done: saves assistant message to DB, updates expression from mood, updates session safetyLevel
  - [x] 5.7 `func getOrCreateSession() async throws -> ConversationSession` — finds active session or creates new one
  - [x] 5.8 Error routing: `.authExpired` → `appState.needsReauth = true`; `.providerError` → `self.localError`; `.networkUnavailable` → `appState.isOnline = false`
  - [x] 5.9 Store streaming `Task` reference, cancel on deinit/view disappear
  - [x] 5.10 Create `Tests/Features/CoachingViewModelTests.swift` — test send flow, error routing, message persistence, expression state transitions

- [x] **Task 6: iOS — CoachCharacterView** (AC: 1, 4)
  - [x] 6.1 Create `Features/Coaching/Views/CoachCharacterView.swift`
  - [x] 6.2 Portrait circle (100pt default, 80pt at Accessibility XL+) + name label + status text, vertically stacked, centered
  - [x] 6.3 Expression state drives asset (placeholder SF Symbols for MVP — real art in Story 4.6)
  - [x] 6.4 Crossfade transition between expressions (`.easeInOut(duration: 0.4)`, instant if Reduce Motion via `@Environment(\.accessibilityReduceMotion)` → `.animation(.none)`)
  - [x] 6.5 Accessibility: `accessibilityLabel: "Your coach"`, `accessibilityValue` updates with expression state
  - [x] 6.6 Portrait background gradient: `LinearGradient(colors: [palette.coachPortraitGradientStart, palette.coachPortraitGradientEnd], ...)`. Use `coachNameText`, `coachStatusText` color tokens
  - [x] 6.7 Read `@Environment(\.dynamicTypeSize)` for portrait scaling
  - [x] 6.8 Status text updates with expression: `.thinking` → "Thinking about what you said...", `.welcoming` → "" (empty), `.warm`/`.focused`/`.gentle` → "" (empty for MVP). Uses `.coachStatusStyle()` modifier and `coachStatusText` color

- [x] **Task 7: iOS — DialogueTurnView** (AC: 1, 3, 4)
  - [x] 7.1 Create `Features/Coaching/Views/DialogueTurnView.swift`
  - [x] 7.2 Coach variant: unmarked prose, `Font.coachVoice` style (`.coachVoiceStyle()`), `coachDialogue` color
  - [x] 7.3 User variant: 12pt left indent + `userAccent` left-border (3pt width), `Font.userVoice` style (`.userVoiceStyle()`), `userDialogue` color
  - [x] 7.4 Spacing: `Spacing.dialogueTurn` (24pt) between turns, `Spacing.dialogueBreath` (8pt) within multi-paragraph
  - [x] 7.5 Accessibility: `accessibilityLabel` prefixed "Coach says:" or "You said:"

- [x] **Task 8: iOS — DateSeparatorView** (AC: 3)
  - [x] 8.1 Create `Features/Coaching/Views/DateSeparatorView.swift`
  - [x] 8.2 Shows relative date ("Today", "Yesterday", or absolute date for older)
  - [x] 8.3 Uses `dateSeparator` color token, `.dateSeparatorStyle()` typography modifier
  - [x] 8.4 Centered, low visual weight — barely visible, not a visual interruption
  - [x] 8.5 Accessibility: landmark with `accessibilityLabel: "Conversation from [date]"`
  - [x] 8.6 Insert one `DateSeparatorView` per date boundary in the `LazyVStack` — compare each message's date to the previous message's date, insert separator when day changes

- [x] **Task 9: iOS — TextInputView** (AC: 1, 4)
  - [x] 9.1 Create `Features/Coaching/Views/TextInputView.swift`
  - [x] 9.2 Pill-shaped text field (20pt radius `Radius.input`) + circular send button (32pt)
  - [x] 9.3 States: empty (placeholder "What's on your mind..."), typing (send activates), disabled during streaming
  - [x] 9.4 Send on button tap. Multi-line up to 4 lines, then internal scroll
  - [x] 9.5 Keyboard avoidance via SwiftUI
  - [x] 9.6 Accessibility: field `accessibilityLabel: "Message your coach"`, send button `accessibilityLabel: "Send message"`
  - [x] 9.7 Use tokens: `inputBorder`, `userDialogue`, `sendButton`, `Radius.input`
  - [x] 9.8 Minimum 44pt touch target on send button (`minTouchTarget`)

- [x] **Task 10: iOS — CoachingView (main conversation screen)** (AC: 1, 3, 4, 5)
  - [x] 10.1 Create `Features/Coaching/Views/CoachingView.swift`
  - [x] 10.2 Layout: `CoachCharacterView` pinned at top (sticky) → `ScrollView` with `LazyVStack` of `DateSeparatorView` + `DialogueTurnView` items → `TextInputView` at bottom
  - [x] 10.3 Auto-scroll to bottom on new messages using `ScrollViewReader` + `.scrollTo()`
  - [x] 10.4 Streaming text renders as a live `DialogueTurnView` (coach variant) appended to the list
  - [x] 10.5 Empty state: coach character welcoming, empty scroll area, input field ready. No suggestion prompts
  - [x] 10.6 Conversation palette: read `@Environment(\.colorScheme)` and inject `themeFor(context: .conversation, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)` via `.environment(\.coachingTheme, conversationTheme)` for the view subtree
  - [x] 10.7 Background: `LinearGradient(colors: [theme.palette.backgroundStart, theme.palette.backgroundEnd], startPoint: .top, endPoint: .bottom)` applied via `.background()` modifier
  - [x] 10.8 Pro Max content column: cap at 390pt centered (`.contentColumn()` modifier from Story 1.3)
  - [x] 10.9 SE margins: 16pt via `SpacingScale.screenMargin(for:)` with GeometryReader
  - [x] 10.10 Load messages from DB on `.task` modifier (calls `viewModel.loadMessages()`)
  - [x] 10.11 Cancel streaming task on `.onDisappear`
  - [x] 10.12 Error display: warm inline message for `localError`, not a system alert

- [x] **Task 11: iOS — Wire into App navigation** (AC: 1, 5)
  - [x] 11.1 Update `RootView.swift` to show `CoachingView` when authenticated (temporary — HomeView replaces this in Story 1.9)
  - [x] 11.2 Create and inject `CoachingViewModel` with real `ChatService` and `DatabaseManager`
  - [x] 11.3 Ensure `CoachingView` receives conversation-palette theme via `.environment(\.coachingTheme, ...)`

- [x] **Task 12: Update Xcode project** (AC: all)
  - [x] 12.1 Add all new source files to `project.pbxproj` / `project.yml`
  - [x] 12.2 Verify build succeeds with Swift 6 strict concurrency, zero warnings
  - [x] 12.3 Run all tests (existing 89 + new) — all pass

## Dev Notes

### Architecture Compliance

- **MVVM pattern**: `CoachingViewModel` owns all state and service calls. `CoachingView` never calls services directly
- **Protocol-based DI**: `ChatServiceProtocol` injected into ViewModel. `MockChatService` for tests
- **@Observable, NOT Combine**: Use `@Observable` macro for ViewModel. No `@Published`, no `ObservableObject`, no `Combine` imports
- **@MainActor on ViewModels**: `CoachingViewModel` is `@MainActor @Observable final class`
- **Services are Sendable, NOT @MainActor**: `ChatService`, `SSEParser` are `Sendable` — they do background work
- **Swift 6 strict concurrency**: Zero warnings. Use `async/await`, `AsyncThrowingStream`. No `DispatchQueue.main.async`. Check `Task.isCancelled` in streaming loops
- **No singletons, no service locators**: All dependencies via init injection
- **No force-unwrapping (`!`)**: Use `guard let` / `if let` throughout
- **No raw `print()`**: Use structured logging or omit for MVP
- **Never call services from View body**: All service calls go through ViewModel methods
- **Database queries via model static extensions**: Use `Message.forSession(id:)` pattern already established

### CoachingTheme Integration (from Story 1.3)

- **Theme is a struct, not class** — `struct CoachingTheme: Sendable`
- **Environment injection**: `@Environment(\.coachingTheme) private var theme` in views
- **Palette selection is view-level**: `CoachingView` reads `@Environment(\.colorScheme)`, calls `themeFor(context: .conversation, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)`, and sets `.environment(\.coachingTheme, conversationTheme)` for its subtree. The `ExperienceContext` enum has `.home` and `.conversation` cases (NOT `.active`)
- **Color via `Color(hex:)`**: Story 1.3 uses `Color(hex:)` initializer, NOT asset catalog color sets (dead asset catalog entries were removed in code review)
- **Typography via View modifiers**: Use `.coachVoiceStyle()`, `.userVoiceStyle()` etc. — these apply font + lineSpacing together
- **Spacing tokens**: `theme.spacing.dialogueTurn` (24pt), `theme.spacing.dialogueBreath` (8pt), `theme.spacing.screenMargin` (20pt/16pt), `theme.spacing.coachCharacterBottom` (16pt), `theme.spacing.inputAreaTop` (12pt)
- **Radius tokens**: `theme.cornerRadius.input` (20pt pill), `theme.cornerRadius.avatar` (circle)
- **Pro Max cap**: Use `.contentColumn()` View modifier (390pt centered) from Story 1.3
- **SE detection**: Use `GeometryReader` width check, NOT `UIScreen.main.bounds`
- **Gradient construction**: `ColorPalette` stores start/end colors as separate properties — always construct gradients manually:
  ```swift
  // Background gradient
  LinearGradient(colors: [theme.palette.backgroundStart, theme.palette.backgroundEnd],
                 startPoint: .top, endPoint: .bottom)
  // Coach portrait gradient
  LinearGradient(colors: [theme.palette.coachPortraitGradientStart, theme.palette.coachPortraitGradientEnd],
                 startPoint: .top, endPoint: .bottom)
  ```
- **Animation timing**: No custom `Animation` constants exist. Use `.easeInOut(duration: 0.4)` for standard transitions (coach expression crossfade). Check `@Environment(\.accessibilityReduceMotion)` — if true, use `.animation(.none)`
- **colorScheme injection**: `CoachingView` must read `@Environment(\.colorScheme)` and pass it to `themeFor()`:
  ```swift
  @Environment(\.colorScheme) private var colorScheme
  let conversationTheme = themeFor(context: .conversation, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)
  ```

### SSE Streaming Implementation

- **URLSession bytes streaming**: Use `URLSession.bytes(for:)` to get `AsyncBytes`, feed into `SSEParser`
- **SSE format**: Lines of `event: <type>\ndata: <json>\n\n` — parse line by line
- **Two event types only**: `token` (has `text` field) and `done` (has `safetyLevel`, `domainTags`, `mood`, `usage`)
- **Streaming text accumulation**: Append each token's `text` to `streamingText` property on ViewModel. The streaming DialogueTurnView binds to this
- **On done event**: Save complete assistant message to DB, clear `streamingText`, update `coachExpression` from `mood` field, update session `safetyLevel`
- **Connection auth**: Include `Authorization: Bearer <jwt>` header. JWT from `AuthService.getToken()`
- **Error on 401**: Map to `AppError.authExpired`, route to `appState.needsReauth = true`
- **Error on 502**: Map to `AppError.providerError`, show warm inline message: "Your coach needs a moment. Try again shortly."

### Server ChatEvent Changes

The current `ChatEvent` struct lacks the `mood` field defined in the architecture. This story adds it:
- `providers/provider.go`: Add `Mood string` to `ChatEvent`
- `providers/mock.go`: Return `Mood: "welcoming"` in done event
- `handlers/chat.go`: Include `"mood"` in SSE done event JSON marshal
- **Do NOT add `memoryReferenced` yet** — that's Story 3.4's concern
- **Do NOT add `degraded` field yet** — that's Story 10.1's multi-provider failover concern

### Scope Boundaries (Explicitly Deferred)

- **Ambient mode shifts** (Discovery/Directive/Challenger background gradient shifts) → Story 2.x
- **Memory reference styling** (italic + 0.7 opacity on memory-referenced turns) → Story 3.4
- **Safety UI transformations** (theme overrides at Yellow/Orange/Red) → Story 6.x
- **Offline/pending message queuing** (`PendingMessageIndicator`) → later story (offline mode)
- **Home screen navigation** (threshold crossing animation home ↔ conversation) → Story 1.9
- **Real AI provider integration** (Anthropic, system prompt assembly) → Story 1.6
- All parameters that would vary (safety level, coaching mode ambient shifts) are hard-coded to static values in this story

### Coach Expression State Machine

Two transitions per turn only:
1. **On message send**: Set `coachExpression = .thinking` (immediate)
2. **On `done` event received**: Set `coachExpression` to value from `mood` field (map string → `CoachExpression` enum)
- Fallback if `mood` missing: `.welcoming`
- For mock streaming, mock always returns `mood: "welcoming"`

### Placeholder Art Strategy

Story 4.6 provides real coach art. For this story, use **SF Symbols** as placeholders:
- `.welcoming` → `person.circle.fill`
- `.thinking` → `brain.head.profile`
- `.warm` → `heart.circle.fill`
- `.focused` → `eye.circle.fill`
- `.gentle` → `leaf.circle.fill`

Wrap in the portrait circle with gradient background constructed from `palette.coachPortraitGradientStart` and `palette.coachPortraitGradientEnd`. This is throwaway — the structure (CoachCharacterView, expression enum, crossfade) is the durable artifact.

### Message Persistence

- **Existing models**: `Message` and `ConversationSession` are already defined with GRDB records (Story 1.2)
- **Use existing query**: `Message.forSession(id:)` returns messages ordered by timestamp
- **Save user message immediately** on send (before starting SSE stream)
- **Save assistant message** on `done` event (complete content, not partial)
- **Session management**: Create or reuse a `ConversationSession` — for MVP, one continuous session is sufficient. Create new if none exists
- **Date format**: ISO 8601 with `Date()` — matches existing GRDB date encoding

### Existing Code to Reuse (DO NOT REINVENT)

| What | Where | How to Use |
|------|-------|------------|
| `AppState` | `App/AppState.swift` | Inject via `@Environment(AppState.self)`, read `isAuthenticated`, `needsReauth`, `isOnline`, `databaseManager` |
| `AppError` enum | `Core/Errors/AppError.swift` | Throw/catch for error routing — `.authExpired`, `.providerError`, `.networkUnavailable` |
| `APIClient` | `Services/Networking/APIClient.swift` | DO NOT use for SSE — it returns decoded JSON, not a byte stream. Create separate `URLSession` request in `ChatService` for streaming. Reuse `baseURL` config pattern |
| `AuthService` | `Services/Networking/AuthService.swift` | Call `getToken()` for JWT to include in chat request headers |
| `DatabaseManager` | `Services/Database/DatabaseManager.swift` | Use `dbPool` for reads/writes. `dbPool.read { }` and `dbPool.write { }` |
| `Message` model | `Models/Message.swift` | Save/load messages. Use `Message.forSession(id:)` for ordered fetch |
| `ConversationSession` model | `Models/ConversationSession.swift` | Create/manage sessions. Includes `CoachingMode`, `SafetyLevel`, `SessionType` enums |
| `CoachingTheme` | `Core/Theme/CoachingTheme.swift` | Environment key `\.coachingTheme` — read in views for palette, typography, spacing, radius |
| `themeFor()` function | `Core/Theme/CoachingTheme.swift` | `themeFor(context: .conversation, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)` — requires `colorScheme` from `@Environment(\.colorScheme)`. Context is `.conversation` (not `.active`). SafetyLevel param is `SafetyThemeOverride` type (`.none`), not `SafetyLevel` |
| `CopyStandards` | `Core/Utilities/CopyStandards.swift` | Use `assertCopyCompliance()` on any UI copy strings in DEBUG builds. Banned words: "user", "session", "data", "error", "failed", "invalid", "submit", "retry", "loading", "processing", etc. |
| Typography modifiers | `Core/Theme/TypographyScale.swift` | `.coachVoiceStyle()`, `.userVoiceStyle()`, `.coachVoiceEmphasisStyle()`, `.dateSeparatorStyle()`, `.coachNameStyle()`, `.coachStatusStyle()` |
| `.contentColumn()` modifier | `Core/Theme/SpacingScale.swift` | Pro Max 390pt centered column |

### API Contract (from `docs/api-contract.md`)

**POST /v1/chat** — JWT required, SSE streaming response

Request:
```json
{
  "messages": [{"role": "user", "content": "..."}],
  "mode": "discovery",
  "promptVersion": "1.0"
}
```

SSE Events:
```
event: token
data: {"text": "I hear you. "}

event: done
data: {"safetyLevel": "green", "domainTags": [], "mood": "welcoming", "usage": {"inputTokens": 50, "outputTokens": 12}}
```

- JSON field names: **camelCase** throughout
- Enums: lowercase (e.g., "discovery", "green", "welcoming")
- Arrays always arrays, never null

### Testing Strategy

| Test File | Framework | What to Test |
|-----------|-----------|-------------|
| `Tests/Services/SSEParserTests.swift` | Swift Testing (`@Test`) | Parse token events, done events, malformed data, empty stream, partial reads. Use `docs/fixtures/sse-token-event.txt` and `docs/fixtures/sse-done-event.txt` |
| `Tests/Models/ChatEventCodableTests.swift` | Swift Testing | ChatRequest Codable roundtrip against `docs/fixtures/chat-request-sample.json`. ChatEvent decoding from fixture data |
| `Tests/Features/CoachingViewModelTests.swift` | Swift Testing | Send message flow (saves to DB, starts stream, accumulates text, saves on done). Error routing (auth → global, provider → local). Expression state transitions (thinking → welcoming). Message persistence (load from DB) |
| `Tests/Mocks/MockChatService.swift` | — | Hand-written mock implementing `ChatServiceProtocol`. Configurable: `stubbedEvents: [ChatEvent]`, `stubbedError: Error?` |
| `server/tests/handlers_test.go` | Go `testing` + `httptest` | Verify done event includes mood field |

- **Use Swift Testing** (`@Test` macro), NOT XCTest for unit tests
- **Use `@testable import sprinty`** to access internal types
- **In-memory GRDB** for database tests: `DatabaseQueue()` with same migrations
- **No mocking frameworks** — hand-written protocol mocks only
- **Test naming**: `test_methodName_condition_expectedResult`

### Accessibility Checklist

- [x] Each `DialogueTurnView`: `accessibilityLabel` prefixed "Coach says:" or "You said:"
- [x] `CoachCharacterView`: `accessibilityLabel: "Your coach"`, `accessibilityValue` tracks expression state, changes announced
- [x] `TextInputView` field: `accessibilityLabel: "Message your coach"`
- [x] Send button: `accessibilityLabel: "Send message"`, 44pt minimum touch target
- [x] `DateSeparatorView`: accessibility landmark, `accessibilityLabel: "Conversation from [date]"`
- [x] VoiceOver navigation order: coach character → dialogue turns (chronological) → input field
- [x] Coach expression changes announced to VoiceOver
- [x] Dynamic Type: all text scales via semantic iOS font sizes
- [x] Coach portrait: 100pt default, 80pt at Accessibility XL+
- [x] Reduce Motion: `@Environment(\.accessibilityReduceMotion)` — if true, expression crossfades become instant (`.animation(.none)`)
- [x] All text contrast ≥ 4.5:1 (already verified in Story 1.3 palette)

### File Structure

New files to create:
```
ios/sprinty/
├── Features/
│   └── Coaching/
│       ├── Views/
│       │   ├── CoachingView.swift
│       │   ├── CoachCharacterView.swift
│       │   ├── DialogueTurnView.swift
│       │   ├── DateSeparatorView.swift
│       │   └── TextInputView.swift
│       ├── ViewModels/
│       │   └── CoachingViewModel.swift
│       └── Models/
│           ├── ChatRequest.swift
│           ├── ChatEvent.swift
│           └── CoachExpression.swift
├── Services/
│   └── Networking/
│       ├── SSEParser.swift
│       ├── ChatServiceProtocol.swift
│       └── ChatService.swift
└── Tests/
    ├── Mocks/
    │   └── MockChatService.swift
    ├── Features/
    │   └── CoachingViewModelTests.swift
    ├── Services/
    │   └── SSEParserTests.swift
    └── Models/
        └── ChatEventCodableTests.swift

server/
├── providers/
│   └── provider.go (modified — add Mood field)
│   └── mock.go (modified — add mood to done event)
├── handlers/
│   └── chat.go (modified — emit mood in SSE)
└── tests/
    └── handlers_test.go (modified — verify mood field)

docs/
├── api-contract.md (modified — document mood field)
└── fixtures/
    └── sse-done-event.txt (modified — add mood)
```

Files to modify:
```
ios/sprinty/App/RootView.swift (show CoachingView when authenticated)
ios/sprinty.xcodeproj/project.pbxproj (new source files)
```

### Project Structure Notes

- All new iOS view files follow `Features/Coaching/Views/` convention per architecture
- All new iOS ViewModel files follow `Features/Coaching/ViewModels/` convention
- Transient API models go in `Features/Coaching/Models/` (NOT `Models/` which is for GRDB records)
- Service protocols and implementations go in `Services/Networking/`
- Mock files go in `Tests/Mocks/`
- Test files mirror source structure under `Tests/`

### Previous Story Intelligence (Story 1.3)

**Key Learnings:**
- Colors use `Color(hex:)` initializer — dead `.colorset` asset catalog entries were removed. Do NOT create asset catalog color entries
- Typography modifiers (`.coachVoiceStyle()` etc.) apply both `.font()` and `.lineSpacing()` — use these instead of applying separately
- `ThemePreview.swift` is `#if DEBUG` — new preview helpers should follow same pattern
- `CopyStandards.assertCopyCompliance()` is DEBUG-only — wire into any hardcoded UI strings
- WCAG contrast ratios already verified for all palette tokens — no need to re-verify
- `SpacingScale` takes screen width for SE detection — use `GeometryReader`, not `UIScreen.main.bounds`
- `.contentColumn()` View modifier exists for Pro Max 390pt cap

**Code Review Fixes Applied:**
- Word-boundary regex for CopyStandards (not substring matching)
- `project.pbxproj` must be in file list — don't forget to include it

### Git Intelligence

Recent commits (Stories 1.1-1.3) established:
- Go server with `net/http` + `ServeMux`, `slog` logging, JWT auth middleware
- iOS SwiftUI with `@Observable` AppState, GRDB DatabaseManager, protocol-based APIClient/AuthService
- Design system with CoachingTheme struct, 4 palettes, 12 typography tokens, spacing/radius tokens
- Swift Testing (`@Test`) for all test files
- `project.yml` (xcodegen) for Xcode project generation

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 1, Story 1.4]
- [Source: _bmad-output/planning-artifacts/architecture.md — Coaching Feature, SSE Streaming, State Management, Error Handling, Testing]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — RPG Dialogue Paradigm, CoachCharacterView, DialogueTurnView, TextInputView, Accessibility]
- [Source: docs/api-contract.md — POST /v1/chat, SSE Event Format]
- [Source: _bmad-output/implementation-artifacts/1-3-design-system-and-coaching-theme.md — Theme patterns, code review learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Swift 6 strict concurrency required `await` on all GRDB `DatabasePool.write`/`read` calls from `@MainActor` context
- `DatabasePool` cannot use `:memory:` path (requires WAL mode) — tests use temp file-based DBs
- SSEParser tests use direct line parsing rather than URLProtocol mocks (URLSession.bytes doesn't intercept well with URLProtocol)

### Completion Notes List

- Task 1: Added `Mood string` field to server `ChatEvent`, `MockProvider` returns `"welcoming"`, `ChatHandler` emits mood in SSE done JSON, api-contract.md and fixture updated, test verifies mood field
- Task 2: `SSEParser` parses `text/event-stream` bytes via `AsyncBytes.lines`, returns `AsyncThrowingStream<SSEEvent, Error>`. Handles connection drops via task cancellation
- Task 3: `ChatRequest` (Codable, explicit CodingKeys), `ChatEvent` enum (`.token`/`.done`), `CoachExpression` enum with SF Symbol mappings and mood string init
- Task 4: `ChatServiceProtocol` + `ChatService` (Sendable, URLSession bytes streaming, JWT auth, SSE parsing), `MockChatService` for tests
- Task 5: `CoachingViewModel` — @MainActor @Observable, async DB ops, streaming task management, error routing (auth→global, provider→local), expression state machine
- Task 6: `CoachCharacterView` — 100pt/80pt portrait circle with gradient, SF Symbol placeholders, crossfade animation with Reduce Motion support, dynamic type scaling
- Task 7: `DialogueTurnView` — coach (unmarked prose) and user (12pt indent + 3pt accent border) variants, multi-paragraph spacing, accessibility labels
- Task 8: `DateSeparatorView` — relative dates (Today/Yesterday/absolute), dateSeparator color token, accessibility landmark
- Task 9: `TextInputView` — pill-shaped text field (20pt radius) + 32pt send button, 44pt touch target, disabled during streaming, multi-line up to 4 lines
- Task 10: `CoachingView` — GeometryReader layout, sticky coach character, ScrollViewReader auto-scroll, streaming text live preview, conversation palette theme, gradient background, content column cap, warm inline error display
- Task 11: `RootView` updated to show `CoachingView` when authenticated with injected dependencies, `FailingChatService` fallback
- Task 12: xcodegen regenerated project, build passes with Swift 6 strict concurrency zero warnings, 111 tests pass (89 existing + 22 new)

### Change Log

- 2026-03-18: Story 1.4 implementation complete — conversation view with mock SSE streaming, all 12 tasks done, 111 tests passing
- 2026-03-18: Code review fixes applied — [H1] RootView ViewModel persisted via @State to survive re-renders, [H2] SSEParser refactored with generic `parseLines()` and tests rewritten to exercise real parser, [M1] SSEParserTests and ChatEventCodableTests now load from docs/fixtures/, [M2] ChatService URL path fixed (removed leading slash), [L1] Accessibility checklist checked off

### File List

**Server (modified):**
- server/providers/provider.go
- server/providers/mock.go
- server/handlers/chat.go
- server/tests/handlers_test.go

**Docs (modified):**
- docs/api-contract.md
- docs/fixtures/sse-done-event.txt

**iOS (new):**
- ios/sprinty/Services/Networking/SSEParser.swift
- ios/sprinty/Services/Networking/ChatServiceProtocol.swift
- ios/sprinty/Services/Networking/ChatService.swift
- ios/sprinty/Features/Coaching/Models/ChatRequest.swift
- ios/sprinty/Features/Coaching/Models/ChatEvent.swift
- ios/sprinty/Features/Coaching/Models/CoachExpression.swift
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift
- ios/sprinty/Features/Coaching/Views/CoachingView.swift
- ios/sprinty/Features/Coaching/Views/CoachCharacterView.swift
- ios/sprinty/Features/Coaching/Views/DialogueTurnView.swift
- ios/sprinty/Features/Coaching/Views/DateSeparatorView.swift
- ios/sprinty/Features/Coaching/Views/TextInputView.swift

**iOS (modified):**
- ios/sprinty/App/RootView.swift

**iOS Tests (new):**
- ios/Tests/Mocks/MockChatService.swift
- ios/Tests/Services/SSEParserTests.swift
- ios/Tests/Models/ChatEventCodableTests.swift
- ios/Tests/Features/CoachingViewModelTests.swift

**Project (modified):**
- ios/sprinty.xcodeproj/project.pbxproj
