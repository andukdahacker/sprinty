# Story 10.2: Offline Mode

Status: done

## Story

As a user without internet,
I want to browse my home screen, sprint progress, conversation history, and even write messages,
So that the app remains useful even when I'm offline.

## Acceptance Criteria

1. **Given** the device loses connectivity, **When** the user is on the home screen, **Then** the home screen, avatar, sprint progress, and past conversation summaries are 100% available (NFR32), and no spinners or loading indicators appear (UX-DR70).

2. **Given** the user is offline, **When** they tap "Talk to your coach", **Then** the conversation view opens with the coach in welcoming expression, a subtle OfflineIndicator appears near the coach status (same visual weight as "Thinking..." per UX-DR40), the placeholder text changes to "Write a message..." (UX-DR53), and the coach message explains: "Your coach needs a connection to respond, but you can still write. Your message will be waiting."

3. **Given** the user writes a message while offline, **When** the message is sent, **Then** it appears as a user turn with a PendingMessageIndicator (subtle icon per UX-DR41), and the message is queued locally.

4. **Given** connectivity returns, **When** the device reconnects, **Then** pending messages are sent automatically, the coach responds normally, PendingMessageIndicators fade (slow disappear per UX-DR75), and the OfflineIndicator transitions through reconnecting → reconnected → invisible.

5. **Given** network transitions (WiFi → cellular, loss/recovery per NFR33), **When** they occur, **Then** no conversation state is lost and no app restart is required.

6. **Given** the app is backgrounded while offline messages are queued, **When** iOS terminates the app, **Then** pending messages survive app termination (persisted in SQLite, not just in-memory), and on next app launch, pending messages are displayed with PendingMessageIndicator, and they are sent automatically when connectivity is available.

7. **Given** a user writes a message while offline that indicates crisis, **When** the message is composed, **Then** the on-device Apple Foundation Models classify the user's outbound message pre-emptively, and if classified Orange/Red, crisis resources are displayed immediately even without connectivity, and the SafetyStateManager applies theme transformations based on the on-device classification, and when connectivity returns and the server response arrives with its own classification, the more cautious of the two wins.

## Tasks / Subtasks

- [x] Task 1: ConnectivityMonitor service (AC: #1, #5)
  - [x] 1.1 Create `ConnectivityMonitor` class in `Services/Networking/ConnectivityMonitor.swift` — wraps `NWPathMonitor`, publishes `isOnline` state via `@Observable` pattern
  - [x] 1.2 Create `ConnectivityMonitorProtocol` for DI/testing — properties: `isOnline: Bool`, `connectionType: ConnectionType` (wifi/cellular/none)
  - [x] 1.3 Wire into `AppState.isOnline` — ConnectivityMonitor updates AppState reactively on any path change
  - [x] 1.4 Initialize in `SprintyApp.swift` bootstrap, inject into `RootView` DI chain
  - [x] 1.5 Remove the one-time bootstrap offline detection in `SprintyApp.swift` (line 66 `case .networkUnavailable: appState.isOnline = false`) — ConnectivityMonitor handles this continuously now
  - [x] 1.6 Write `MockConnectivityMonitor` implementing `ConnectivityMonitorProtocol` with mutable `isOnline` for consumer tests. ConnectivityMonitor itself (NWPathMonitor wrapper) is verified via manual/integration testing — NWPathMonitor is a concrete class not mockable in unit tests.

- [x] Task 2: Message delivery status schema (AC: #3, #6)
  - [x] 2.1 Add migration `v17_messageDeliveryStatus`: add `deliveryStatus` TEXT column to `Message` table with default `'sent'` (existing messages are all sent)
  - [x] 2.2 Add `MessageDeliveryStatus` enum: `.sent`, `.pending` — conforms to `Codable, Sendable, DatabaseValueConvertible`
  - [x] 2.3 Add `deliveryStatus: MessageDeliveryStatus` property to `Message` model with default `.sent`
  - [x] 2.4 Add `Message.pending()` query: `filter(Column("deliveryStatus") == "pending").order(Column("timestamp").asc)` — returns pending messages in chronological order for sync
  - [x] 2.5 Write tests: `test_message_defaultDeliveryStatus_isSent`, `test_message_pendingQuery_returnsPendingOnly`, `test_migration_existingMessages_haveSentStatus`

- [x] Task 3: Offline message queuing in CoachingViewModel (AC: #2, #3, #6)
  - [x] 3.1 Modify `sendMessage()` — when `!appState.isOnline`: save message with `.pending` status, append to `messages` array, do NOT attempt streaming. Show the message in the UI with pending indicator.
  - [x] 3.2 When offline and conversation view opens: check for existing pending messages in current session, display them with PendingMessageIndicator
  - [x] 3.3 When offline and no session exists yet: show coach offline welcome message (AC #2 text) as a **UI-only text in CoachingView** (not saved to DB — it's ephemeral and should not pollute conversation history). Change placeholder text to "Write a message..."
  - [x] 3.4 Ensure pending messages survive app termination — they're already in SQLite with `.pending` status, so on next launch `loadMessages()` picks them up
  - [x] 3.5 Write tests: `test_sendMessage_whenOffline_savesAsPending`, `test_sendMessage_whenOffline_doesNotStream`, `test_loadMessages_includesPendingMessages`

- [x] Task 4: Auto-sync on reconnect (AC: #4, #5)
  - [x] 4.1 In CoachingViewModel, observe `appState.isOnline` — when transitions from `false` → `true`, trigger `syncPendingMessages()`
  - [x] 4.2 `syncPendingMessages()`: query `Message.pending()` from DB, for each pending message (in order): send via `chatService.streamChat()`, on success update `deliveryStatus` to `.sent` in DB, process coach response normally
  - [x] 4.3 Handle sync errors gracefully — if a pending message fails to send (provider error), stop sync and leave remaining as pending. Do NOT silently drop messages.
  - [x] 4.4 Ensure sync doesn't conflict with active user input — use `isStreaming` guard, queue sync behind any active streaming
  - [x] 4.5 Write tests: `test_syncPendingMessages_sendsInOrder`, `test_syncPendingMessages_updatesStatusToSent`, `test_syncPendingMessages_onError_stopsAndKeepsRemaining`, `test_reconnect_triggersSyncAutomatically`

- [x] Task 5: OfflineIndicator UI component (AC: #2, #4)
  - [x] 5.1 Create `OfflineIndicator` view in `Features/Coaching/Views/OfflineIndicator.swift` — small icon + text near coach status area
  - [x] 5.2 States: `.online` (invisible), `.offline` (visible — "Coach offline"), `.reconnecting` ("Reconnecting..."), `.reconnected` (briefly visible then fades)
  - [x] 5.3 Animate transitions: appear with quick animation (+50ms), disappear with slow fade (+150ms per UX spec)
  - [x] 5.4 Respect `@Environment(\.accessibilityReduceMotion)` — instant transitions when reduce motion enabled
  - [x] 5.5 Add VoiceOver label: "Coach is offline" / "Reconnecting" / "Coach is back online"
  - [x] 5.6 Integrate into CoachingView — place below the `CoachCharacterView` (line 43-45) and above the `ScrollView` (line 52). This positions it near the coach character, consistent with the "same visual weight as Thinking..." UX requirement
  - [x] 5.7 Add Light and Dark #Preview variants

- [x] Task 6: PendingMessageIndicator UI component (AC: #3, #4)
  - [x] 6.1 Create `PendingMessageIndicator` view in `Features/Coaching/Views/PendingMessageIndicator.swift` — small subtle clock/arrow icon beside user turn bubble
  - [x] 6.2 Integrate at the **call site in CoachingView.swift** (lines 90-97), NOT inside DialogueTurnView. DialogueTurnView takes `(content, role, memoryReferenced, highlightQuery, isCurrentResult)` — it has no Message or deliveryStatus parameter. Add the PendingMessageIndicator as a sibling view after the `DialogueTurnView(...)` call inside the `ForEach`, conditionally shown when `message.deliveryStatus == .pending && message.role == .user`
  - [x] 6.3 Fade out animation when status changes to `.sent` (0.25s quick fade per UX spec)
  - [x] 6.4 Respect reduce motion — instant hide when enabled
  - [x] 6.5 VoiceOver: "Message pending, will send when online"
  - [x] 6.6 Add Light and Dark #Preview variants

- [x] Task 7: Remove hard "No connection" blocker from RootView (AC: #1)
  - [x] 7.1 Remove or modify the `!appState.isOnline` check in `RootView.swift` (lines 45-52) that shows the blocking "No connection" screen — the app must remain fully navigable when offline
  - [x] 7.2 Home screen already loads from local DB — verify no network calls block home screen rendering
  - [x] 7.3 Sprint detail already loads from local DB — verify no network calls block sprint rendering
  - [x] 7.4 Conversation history already loads from local DB — verify no network calls block history browsing
  - [x] 7.5 Write tests: `test_rootView_whenOffline_showsMainApp` (not the blocking error screen)

- [x] Task 8: On-device safety classification for offline messages (AC: #7)
  - [x] 8.1 Create `OnDeviceSafetyClassifier` in `Services/Safety/OnDeviceSafetyClassifier.swift`. **iOS version constraint:** Apple Foundation Models (`import FoundationModels`) requires **iOS 26**. The project targets iOS 17. Implementation approach:
    - Gate the FoundationModels implementation behind `@available(iOS 26, *)` using a `LanguageModelSession` with a `@Generable` enum for safety categories (green/yellow/orange/red)
    - For iOS 17-25 fallback: use keyword-based heuristic matching for crisis terms (self-harm, suicide, emergency) — simple but catches obvious cases. This is the minimum viable safety net for older devices.
    - The protocol abstraction (`OnDeviceSafetyClassifierProtocol`) makes this transparent to callers
  - [x] 8.2 Create `OnDeviceSafetyClassifierProtocol` — `func classify(_ text: String) async -> SafetyLevel?` (returns nil if classification unavailable)
  - [x] 8.3 In `sendMessage()` when offline: run on-device classification on the user's outbound message BEFORE displaying
  - [x] 8.4 If classified Orange/Red: immediately call `safetyStateManager.processClassification()` with the on-device level and `.genuine` source, and show crisis resources — even without connectivity
  - [x] 8.5 When connectivity returns and server response arrives: compare on-device classification with server classification, use the MORE CAUTIOUS (higher severity) of the two via `max(serverLevel, deviceLevel)` (SafetyLevel conforms to Comparable: green < yellow < orange < red)
  - [x] 8.6 Wire into DI chain: add `onDeviceSafetyClassifier` parameter to CoachingViewModel init (line 68) AND the `ensureCoachingViewModel` factory in `RootView.swift` (lines 216-237)
  - [x] 8.7 Write tests: `test_offlineMessage_crisisContent_showsSafetyResources`, `test_reconnect_serverClassification_moreConservativeWins`, `test_reconnect_deviceClassification_moreConservativeWins`, `test_classify_nilWhenUnavailable`
  - [x] 8.8 Conditional test attribute for FoundationModels-dependent tests: `.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)`. Keyword-fallback tests run everywhere.

- [x] Task 9: Integration testing (AC: all)
  - [x] 9.1 End-to-end test: go offline → write message → go online → message sends → coach responds
  - [x] 9.2 Test: multiple pending messages sync in correct order
  - [x] 9.3 Test: app launch with pending messages from previous session → displayed with indicators → sync on connect
  - [x] 9.4 Test: rapid network transitions (online → offline → online) don't lose state

## Dev Notes

### Current State of the Codebase

**AppState** (`App/AppState.swift`):
- `isOnline` is a simple `Bool` property, currently set only at bootstrap on `networkUnavailable` error
- No continuous monitoring — this story adds `ConnectivityMonitor` with `NWPathMonitor`
- All local data (home, sprint, history) already loaded from GRDB — no network calls needed for read-only screens

**Message Model** (`Models/Message.swift`):
- GRDB record with: `id`, `sessionId`, `role`, `content`, `timestamp`
- No delivery status field — needs `v17` migration to add `deliveryStatus`
- Messages are already persisted to DB BEFORE streaming begins (CoachingViewModel line 198-200) — this pattern supports offline queuing naturally

**CoachingViewModel** (`Features/Coaching/ViewModels/CoachingViewModel.swift`, ~962 lines):
- `sendMessage()` saves user message to DB → starts streaming → saves assistant message on completion
- `handleError()` routes `AppError.networkUnavailable` → `appState.isOnline = false`
- `isStreaming` flag guards against double-sends
- `retryAfterSeconds` timer prevents sends during rate-limiting
- No offline queuing logic — messages fail immediately on network error
- Key modification point: `sendMessage()` needs an `if !appState.isOnline` branch that saves with `.pending` status and skips streaming

**RootView** (`App/RootView.swift`, ~411 lines):
- Lines 45-52: Shows hard "No connection" blocker when `!appState.isOnline` — **this MUST be removed** to allow offline navigation
- DI setup at lines 186-237 — ConnectivityMonitor and OnDeviceSafetyClassifier need to be added here

**SafetyStateManager** (`Services/Safety/SafetyStateManager.swift`):
- Tracks sticky safety levels with de-escalation rules
- `processClassification(_ level, source:)` — accepts `.genuine` and `.failsafe` sources
- For AC #7, the on-device classification should use `.genuine` source (it's a real classification, not a fallback)
- The "more cautious wins" comparison: when server response arrives, compare with on-device classification, call `processClassification()` with `max(serverLevel, deviceLevel)` using `SafetyLevel: Comparable`

**SafetyHandler** (`Services/Safety/SafetyHandler.swift`):
- `classify(serverLevel:)` defaults to `.yellow` when nil — this is the fail-safe for missing server level
- `uiState(for:)` maps level → `SafetyUIState` with hidden elements, expressions, crisis resources

**DatabaseManager** (`Services/Database/DatabaseManager.swift`):
- Creates GRDB pool in App Group container with `.complete` file protection
- Runs migrations on every launch — new `v17` migration will auto-apply

**Migrations** (`Services/Database/Migrations.swift`, ~256 lines):
- Currently at v16 (NotificationDelivery). Next migration is v17.
- Migrations are append-only and sequential — NEVER modify existing migrations

**ChatService** (`Services/Networking/ChatService.swift`):
- `streamChat()` calls API directly, throws `AppError.networkUnavailable` on failure
- No retry or queue logic — this is correct, queuing belongs in the ViewModel layer

**CoachingViewModel init** (line 68):
- Current signature has 12 parameters: `appState, chatService, databaseManager, embeddingPipeline, profileUpdateService, profileEnricher, searchService, sprintService, safetyHandler, safetyStateManager, complianceLogger, autonomySnapshotProvider`
- Must add `onDeviceSafetyClassifier: OnDeviceSafetyClassifierProtocol?` parameter
- The `ensureCoachingViewModel` factory in `RootView.swift:216-237` creates and injects all dependencies — must be updated to create and pass the classifier

**SprintyApp bootstrap** (`App/SprintyApp.swift`):
- The bootstrap calls `auth.ensureAuthenticated()` which throws `networkUnavailable` when offline
- Currently this sets `appState.isOnline = false` which triggers the blocking "No connection" screen
- With ConnectivityMonitor handling `isOnline` and the blocking screen removed (Task 7), the bootstrap must gracefully handle auth failure when offline: catch `networkUnavailable`, let ConnectivityMonitor set `isOnline = false`, but still proceed to show the main app (unauthenticated features work offline)
- The `isAuthenticated` flag may be false when offline at boot — ensure RootView can show the main app even when `!isAuthenticated && !isOnline` (user was previously authenticated, token in Keychain)

**Message constructor call sites** that need `deliveryStatus` parameter after Task 2:
- `CoachingViewModel.sendMessage()` line 190-196 — primary: set `.pending` when offline, `.sent` when online
- Any test helpers that create Message instances (e.g., `createMessage()` in test mocks) — add default `.sent`

### Architecture Compliance

- **NWPathMonitor** is the Apple-recommended way to monitor connectivity — `import Network` framework
- **ConnectivityMonitor threading**: Declare as `@MainActor @Observable final class`. Internally create `NWPathMonitor` on its own `DispatchQueue(label: "connectivity")`. In the `pathUpdateHandler` callback, dispatch state updates to MainActor via `Task { @MainActor in self.isOnline = path.status == .satisfied }`. This ensures `isOnline` is always read/written on MainActor while NWPathMonitor runs on its own queue.
- **Message.deliveryStatus** column migration must use `DEFAULT 'sent'` so existing rows get correct value
- **No server changes needed** — this is entirely iOS-side. The server already handles messages normally; it doesn't know or care if a message was queued offline
- **No new API endpoints** — offline mode uses existing `/v1/chat` endpoint for sync
- **Database in App Group container** — already set up, required for WidgetKit (Story 10.4)
- **File protection `.complete`** — already configured, means DB is encrypted at rest but accessible when device is unlocked

### Key Design Decisions

1. **Queuing at ViewModel layer, not service layer**: The ChatService stays unchanged — it's a pure network client. The CoachingViewModel owns the offline decision: "Am I online? Stream. Offline? Save as pending." This keeps the service testable and the offline logic contained.

2. **Single `deliveryStatus` column on Message table**: Rather than a separate pending_messages table, adding a status column to the existing Message table is simpler and keeps the data model unified. Pending messages are just Messages with `deliveryStatus = 'pending'`.

3. **Sequential sync on reconnect**: When connectivity returns, pending messages are sent one-at-a-time in chronological order. Each must complete (coach response received) before sending the next. This preserves conversation context — the coach sees messages in order with its own responses between them.

4. **ConnectivityMonitor replaces bootstrap-only check**: Currently `isOnline` is only set at app launch. The new ConnectivityMonitor provides continuous monitoring via NWPathMonitor, which fires on every network transition. This replaces the one-time check entirely.

5. **Remove hard "No connection" screen**: The current RootView shows a blocking error when offline. This must become a non-blocking indicator. All screens (home, sprint, history) work from local DB and should be accessible offline.

6. **On-device safety classification**: Apple Foundation Models (`import FoundationModels`, iOS 26+) provide local ML inference via `LanguageModelSession` with `@Generable` enum output. For iOS 17-25, a keyword-based heuristic fallback catches obvious crisis terms. Both paths return `SafetyLevel?`. For AC #7, the classifier runs on the user's outbound message text. If it detects crisis content, safety resources show immediately — no network needed. When the server later responds, the more cautious classification wins (using `SafetyLevel: Comparable` which orders green < yellow < orange < red).

7. **OfflineIndicator placement**: Near the coach name/status area in ConversationView, with the same visual weight as the "Thinking..." indicator. Not a banner. Not an error. A gentle status note.

8. **PendingMessageIndicator lifecycle**: Shows immediately on pending messages. Fades out (0.25s) when delivery status changes to `.sent` after sync. Uses withAnimation for smooth transition.

### Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `ios/sprinty/Services/Networking/ConnectivityMonitor.swift` | CREATE | NWPathMonitor wrapper with ConnectivityMonitorProtocol |
| `ios/sprinty/Services/Database/Migrations.swift` | MODIFY | Add v17 migration for Message.deliveryStatus |
| `ios/sprinty/Models/Message.swift` | MODIFY | Add deliveryStatus property and MessageDeliveryStatus enum, add pending() query |
| `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` | MODIFY | Offline queuing in sendMessage(), syncPendingMessages(), observe isOnline transitions |
| `ios/sprinty/Features/Coaching/Views/OfflineIndicator.swift` | CREATE | Subtle connectivity status indicator |
| `ios/sprinty/Features/Coaching/Views/PendingMessageIndicator.swift` | CREATE | Pending message icon for user turns |
| `ios/sprinty/Features/Coaching/Views/CoachingView.swift` | MODIFY | Integrate OfflineIndicator near coach status, add PendingMessageIndicator at lines 90-97 (ForEach message rendering), add offline welcome text |
| `ios/sprinty/App/RootView.swift` | MODIFY | Remove hard "No connection" blocker (lines 45-52), add ConnectivityMonitor + OnDeviceSafetyClassifier to `ensureCoachingViewModel` factory (lines 216-237) |
| `ios/sprinty/App/SprintyApp.swift` | MODIFY | Initialize ConnectivityMonitor, remove one-time offline check |
| `ios/sprinty/App/AppState.swift` | MODIFY | ConnectivityMonitor drives isOnline (may add connectivity binding) |
| `ios/sprinty/Services/Safety/OnDeviceSafetyClassifier.swift` | CREATE | iOS 26+ FoundationModels wrapper + iOS 17-25 keyword fallback, behind OnDeviceSafetyClassifierProtocol |
| `ios/project.yml` | MODIFY | Add new files to app target and test target |
| `ios/Tests/Services/Networking/ConnectivityMonitorTests.swift` | CREATE | Unit tests |
| `ios/Tests/Features/Coaching/CoachingViewModelOfflineTests.swift` | CREATE | Offline queuing and sync tests |
| `ios/Tests/Models/MessageDeliveryTests.swift` | CREATE | Migration and query tests |
| `ios/Tests/Mocks/MockConnectivityMonitor.swift` | CREATE | Mock for testing |
| `ios/Tests/Mocks/MockOnDeviceSafetyClassifier.swift` | CREATE | Mock for testing |

### Previous Story Intelligence

**Story 10.1 (Multi-Provider Failover)** — Server-only, no iOS changes. Key learnings:
- `Degraded` field already exists in ChatEvent and SSE done event — iOS handles it. When failover happens server-side, the `degraded: true` flag is set. This is orthogonal to offline mode.
- Provider failover is transparent to iOS — server handles it. This story is the iOS-side complement: what happens when the network itself is down.
- The `streamWithFailover` function in `server/handlers/chat.go` handles server-side resilience. This story handles client-side resilience.

### Git Intelligence

Recent commits (last 5):
- `feat: Story 10.1 — Multi-provider failover with code review fixes`
- `feat: Story 9.3 — Notification preferences with code review fixes`
- `feat: Story 9.2 — Check-in and sprint milestone notifications with code review fixes`
- `feat: Story 9.2 — Create story context`
- `feat: Story 9.1 — Local notification infrastructure with code review fixes`

Patterns: All iOS stories follow MVVM with `@Observable`, Swift Testing framework, GRDB for persistence, protocol-based DI with mocks. Commit format is `feat: Story X.Y — Description`.

### What NOT to Do

- **Do NOT modify server code** — offline mode is entirely iOS-side. The server handles messages normally when they arrive.
- **Do NOT create a separate pending_messages table** — use a `deliveryStatus` column on the existing Message table. Simpler schema, unified queries.
- **Do NOT use Combine** — use Observation framework (`@Observable`) and async/await for connectivity monitoring
- **Do NOT use XCTest** — use Swift Testing framework (`@Test`, `@Suite`, `#expect`)
- **Do NOT modify existing database migrations** — append v17 as a new migration
- **Do NOT add a retry loop with sleep** — use ConnectivityMonitor's state change to trigger sync, not polling
- **Do NOT show a blocking error screen when offline** — the whole point of this story is that the app remains usable offline
- **Do NOT batch pending messages into a single API call** — send them one-at-a-time sequentially so the coach can respond to each in context
- **Do NOT make ConnectivityMonitor a singleton** — inject via protocol through the DI chain in RootView.swift
- **Do NOT skip on-device safety classification** — AC #7 requires crisis detection even offline. This is a safety-critical feature.
- **Do NOT save the offline welcome message to the database** — it's a UI-only ephemeral text shown in CoachingView when offline with no session. It should disappear when the user navigates away or goes online. Use a conditional view in CoachingView, not a Message record.
- **Do NOT edit `.xcodeproj` directly** — modify `project.yml` and run `xcodegen generate`

### Testing Strategy

- **ConnectivityMonitor**: NWPathMonitor is a concrete class that cannot be mocked in unit tests. Testing strategy: (1) ConnectivityMonitor's own behavior is verified via integration/manual testing on device. (2) All **consumers** of connectivity (CoachingViewModel, etc.) test against `MockConnectivityMonitor` which implements `ConnectivityMonitorProtocol` with controllable `isOnline` state. This is where the real test value is.
- **Message delivery status**: Use `makeTestDB()` with real GRDB migrations against in-memory database. Test v17 migration applies correctly. Test `pending()` query filters correctly.
- **Offline queuing**: Use `MockChatService` (already exists in test mocks) + `MockConnectivityMonitor`. Verify `sendMessage()` when offline saves as pending, doesn't call streamChat. Verify `syncPendingMessages()` sends in order and updates status.
- **On-device safety**: Use `MockOnDeviceSafetyClassifier` for unit tests. Real Apple Foundation Models testing requires device — use `.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)` conditional.
- **UI components**: Manual testing + `#Preview` for OfflineIndicator and PendingMessageIndicator. Provide Light and Dark variants.

### Project Structure Notes

- New files follow feature-first organization: `Features/Coaching/Views/` for UI, `Services/Networking/` for ConnectivityMonitor, `Services/Safety/` for on-device classifier
- Tests mirror source structure: `Tests/Services/Networking/`, `Tests/Features/Coaching/`, `Tests/Models/`
- Mocks in `Tests/Mocks/` with `Mock` prefix and `@unchecked Sendable`
- All new files must be added to `ios/project.yml` under correct target (app vs test)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Offline/Caching Strategies, Error Recovery, ConnectivityMonitor: NWPathMonitor → AppState.isOnline]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 10, Story 10.2 requirements and BDD scenarios]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 12: Offline Conversation, OfflineIndicator/PendingMessageIndicator component specs, Error State Handling, Offline Sync Confirmation]
- [Source: _bmad-output/planning-artifacts/prd.md — FR70/FR71/FR72 offline requirements, NFR32/NFR33/NFR34 resilience requirements]
- [Source: _bmad-output/project-context.md — Project conventions, testing rules, anti-patterns]
- [Source: ios/sprinty/App/AppState.swift — Current isOnline flag]
- [Source: ios/sprinty/Models/Message.swift — Current Message model without delivery status]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — Current sendMessage() flow]
- [Source: ios/sprinty/App/RootView.swift:45-52 — Hard "No connection" blocker to remove]
- [Source: ios/sprinty/Services/Safety/SafetyStateManager.swift — Safety classification pipeline for AC #7]
- [Source: ios/sprinty/Services/Database/Migrations.swift — Current at v16, next is v17]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Migration renamed from v17 to v18 since v17_notificationsMuted already existed

### Completion Notes List

- Task 1: Created ConnectivityMonitor wrapping NWPathMonitor with ConnectivityMonitorProtocol. Updates AppState.isOnline reactively. Removed one-time bootstrap offline check. MockConnectivityMonitor for tests.
- Task 2: Added v18_messageDeliveryStatus migration with `deliveryStatus` TEXT DEFAULT 'sent'. Added MessageDeliveryStatus enum and Message.pending() query. 5 unit tests.
- Task 3: Modified sendMessage() — offline branch saves as .pending, skips streaming, runs on-device safety classification. Offline welcome message shown as UI-only ephemeral text in CoachingView.
- Task 4: Added syncPendingMessages() — sends pending messages in chronological order (including cross-session), updates status to .sent, handles errors gracefully. Connectivity observation driven by CoachingView .onChange(of: appState.isOnline).
- Task 5: Created OfflineIndicator with states: online/offline/reconnecting/reconnected. Subtle icon+text, respects reduceMotion, VoiceOver labels. Light/Dark previews.
- Task 6: Created PendingMessageIndicator with clock icon, fade-out animation. Integrated in CoachingView ForEach as sibling to DialogueTurnView.
- Task 7: Replaced hard "No connection" blocker in RootView with graceful offline navigation — shows main app if DB available (previously authenticated), shows connection needed only for first-time setup.
- Task 8: Created OnDeviceSafetyClassifier with keyword-based fallback for iOS 17-25 and @available(iOS 26, *) stub for FoundationModels. "More cautious wins" reconciliation in both sendMessage and syncPendingMessages. Crisis resources shown immediately offline.
- Task 9: Integration tests covering end-to-end offline→online flow, multiple pending message sync order, app launch with pending messages, and rapid network transitions.

### Change Log

- 2026-04-03: Story 10.2 — Offline mode implementation complete. All 9 tasks implemented with 24 new tests passing.
- 2026-04-03: Code review fixes — (H1) OfflineIndicator now transitions through reconnecting→reconnected→invisible via CoachingView .onChange; (H2) syncPendingMessages loads prior sessions from DB instead of skipping cross-session messages; (M1) removed polling loop, connectivity observation now view-driven; (M2) placeholder text changes to "Write a message..." when offline; (L1) consolidated RootView duplicated offline/authenticated logic.

### File List

- ios/sprinty/Services/Networking/ConnectivityMonitor.swift (CREATE)
- ios/sprinty/Services/Safety/OnDeviceSafetyClassifier.swift (CREATE)
- ios/sprinty/Features/Coaching/Views/OfflineIndicator.swift (CREATE)
- ios/sprinty/Features/Coaching/Views/PendingMessageIndicator.swift (CREATE)
- ios/sprinty/Models/Message.swift (MODIFY)
- ios/sprinty/Services/Database/Migrations.swift (MODIFY)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (MODIFY)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (MODIFY)
- ios/sprinty/App/RootView.swift (MODIFY)
- ios/sprinty/App/SprintyApp.swift (MODIFY)
- ios/sprinty/App/AppState.swift (MODIFY)
- ios/sprinty/Features/Coaching/Views/TextInputView.swift (MODIFY)
- ios/Tests/Mocks/MockConnectivityMonitor.swift (CREATE)
- ios/Tests/Mocks/MockOnDeviceSafetyClassifier.swift (CREATE)
- ios/Tests/Models/MessageDeliveryTests.swift (CREATE)
- ios/Tests/Features/Coaching/CoachingViewModelOfflineTests.swift (CREATE)
- ios/Tests/Services/Networking/ConnectivityMonitorTests.swift (CREATE)
