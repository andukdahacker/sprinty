# Story 10.3: Offline Sprint Step Completion

Status: done

## Story

As a user working on sprint steps without internet,
I want to mark steps as complete and have them sync when I'm back online,
So that my progress is never blocked by connectivity.

## Acceptance Criteria

1. **Given** the user is offline, **When** they mark a sprint step as complete, **Then** the completion is saved locally (SprintStep updated in SQLite), and the haptic and avatar celebration still fire, and the SprintPathView updates immediately.

2. **Given** connectivity returns (NFR34), **When** the sync queue processes, **Then** offline completions are synced automatically (deferred narrative retro generation retries), and conflict resolution handles any discrepancies.

3. **Given** the user completes all sprint steps while offline, **When** the sprint transitions to complete, **Then** narrative retro generation is deferred (not attempted while offline), and a "Retro pending" indicator shows instead of the retro text, and the retro auto-generates when connectivity returns.

4. **Given** a sprint step was completed offline and connectivity returns, **When** the SprintDetailView is visible, **Then** synced steps show a brief subtle color pulse (0.25s per UX spec) as visual sync confirmation.

## Tasks / Subtasks

- [x] Task 1: Add sync status tracking to SprintStep (AC: #1, #2, #4)
  - [x] 1.1 Add migration `v19_sprintStepSyncStatus`: add `syncStatus` TEXT column to `SprintStep` table. Use exact pattern from v18: `t.add(column: "syncStatus", .text).notNull().defaults(to: "synced")`. Existing steps get `'synced'` — they don't need sync.
  - [x] 1.2 Add `SprintStepSyncStatus` enum in `SprintStep.swift` (same file as the model, matching `MessageDeliveryStatus` in `Message.swift`): `.synced`, `.pendingSync` — conforms to `Codable, Sendable, DatabaseValueConvertible`
  - [x] 1.3 Add `syncStatus: SprintStepSyncStatus` property to `SprintStep` model with default `.synced`
  - [x] 1.4 Add `SprintStep.pendingSync()` query: `filter(Column("syncStatus") == "pendingSync").order(Column("completedAt").asc)` — returns steps completed offline awaiting acknowledgment
  - [x] 1.5 Write tests: `test_sprintStep_defaultSyncStatus_isSynced`, `test_sprintStep_pendingSyncQuery_returnsPendingSyncOnly`, `test_migration_existingSteps_haveSyncedStatus`

- [x] Task 2: Offline-aware step completion in SprintDetailViewModel (AC: #1, #3)
  - [x] 2.1 Modify `toggleStep()` — when `!appState.isOnline` and completing a step: set `syncStatus = .pendingSync` on the SprintStep before writing to DB. When online, keep `syncStatus = .synced` (current behavior, no change).
  - [x] 2.2 Modify `toggleStep()` sprint completion path — when `allDone && !appState.isOnline`: skip `generateNarrativeRetro()` call entirely (it needs network). Still mark sprint as `.complete`, still trigger `triggerSprintCompletion()` haptic/celebration. Set a `retroPending = true` flag on the ViewModel.
  - [x] 2.3 When uncompleting a step: always set `syncStatus = .synced` regardless of connectivity (uncomplete is a reversal, no sync needed).
  - [x] 2.4 Write tests: `test_toggleStep_whenOffline_setsPendingSyncStatus`, `test_toggleStep_whenOnline_keepsSyncedStatus`, `test_toggleStep_allDoneOffline_skipsRetroGeneration`, `test_toggleStep_allDoneOffline_stillMarksSprintComplete`, `test_toggleStep_allDoneOffline_stillFiresCelebration`

- [x] Task 3: Auto-sync on reconnect (AC: #2, #3)
  - [x] 3.1 Add `syncOnReconnect()` method to SprintDetailViewModel — triggered when `appState.isOnline` transitions from `false` to `true` while the view is visible
  - [x] 3.2 `syncOnReconnect()` logic — two INDEPENDENT operations: (a) **Step sync (always):** Query `SprintStep.pendingSync()`, update ALL to `.synced` in a single DB write, populate `recentlySyncedStepIds` for visual pulse. This runs regardless of sprint status — even if the sprint is still active with partial completion. (b) **Retro retry (conditional):** If `sprint?.status == .complete && sprint?.narrativeRetro == nil`, retry `generateNarrativeRetro()`. On success, set `retroPending = false`.
  - [x] 3.3 Handle sync errors gracefully — step sync (DB-only) should always succeed. If retro generation fails (provider error), leave `retroPending = true`. Steps are STILL marked `.synced` (they don't depend on retro). Will retry retro on next reconnect or next `load()`.
  - [x] 3.4 The existing `load()` method already retries retro when `sprint.narrativeRetro == nil` — this covers the case where the user leaves and returns to SprintDetailView after reconnecting. No change needed in `load()`.
  - [x] 3.5 Connectivity observation: SprintDetailView currently has NO `.onChange` modifier and NO direct `appState` access. Add `@Environment(AppState.self) private var appState` to SprintDetailView (alongside existing `@Environment(\.coachingTheme)` and `@Environment(\.dismiss)`). Then add `.onChange(of: appState.isOnline) { oldValue, newValue in if !oldValue && newValue { Task { await viewModel.syncOnReconnect() } } }` — only fires on false→true transition. This matches the pattern from Story 10.2 (CoachingView uses `.onChange` for connectivity-driven sync).
  - [x] 3.6 Write tests: `test_syncOnReconnect_updatesStepsToSynced_evenWhenSprintActive`, `test_syncOnReconnect_retriesRetroGeneration_whenSprintComplete`, `test_syncOnReconnect_stepsSync_independentOfRetroFailure`, `test_syncOnReconnect_whenNoPendingSteps_noOp`

- [x] Task 4: Retro pending indicator in SprintDetailView (AC: #3)
  - [x] 4.1 Add `retroPending: Bool` property to SprintDetailViewModel — set `true` when sprint completes offline without retro, set `false` after successful retro generation
  - [x] 4.2 Initialize `retroPending` in `load()`: if `sprint?.status == .complete && sprint?.narrativeRetro == nil`, set `retroPending = true`
  - [x] 4.3 The retro section in `SprintDetailView.swift:111-138` (`retroSection` computed property) now has THREE rendering states in priority order: (1) `sprint.narrativeRetro != nil` → show retro text (existing, no change). (2) `viewModel.isGeneratingRetro` → show existing pulsing placeholder "Here's the chapter we just finished..." with opacity animation (existing at lines 118-132, no change). (3) `viewModel.retroPending && !viewModel.isGeneratingRetro` → show NEW text: "Your sprint story will appear when you're back online." in `.coachVoiceStyle()` + `.italic()`, same `foregroundStyle(theme.palette.textSecondary)` as existing placeholder. No pulse animation on this state.
  - [x] 4.4 When `viewModel.isGeneratingRetro`, show the existing generating indicator (already exists — no change needed)
  - [x] 4.5 Write test: `test_retroPending_setOnOfflineSprintCompletion`, `test_retroPending_clearedAfterRetroGeneration`

- [x] Task 5: Sync confirmation visual — subtle color pulse (AC: #4)
  - [x] 5.1 Create `SyncPulseModifier` ViewModifier in `Features/Sprint/Views/SyncPulseModifier.swift` — applies a brief background color pulse (accent color at 20% opacity, 0.25s duration per UX AnimationTiming.quick) when triggered
  - [x] 5.2 Add `recentlySyncedStepIds: Set<UUID>` property to SprintDetailViewModel — populated during `syncOnReconnect()` with the IDs of steps that transitioned from `.pendingSync` to `.synced`
  - [x] 5.3 In SprintDetailView's `stepsSection` (lines 94-109), apply `.modifier(SyncPulseModifier(isActive: viewModel.recentlySyncedStepIds.contains(step.id)))` to each `SprintStepRow` call site in the ForEach — NOT inside SprintStepRow itself. This matches the PendingMessageIndicator pattern (applied at call site in CoachingView, not inside DialogueTurnView).
  - [x] 5.4 Clear `recentlySyncedStepIds` after a delay (1.5s) so the pulse is transient
  - [x] 5.5 Respect `@Environment(\.accessibilityReduceMotion)` — skip animation when reduce motion enabled, just clear instantly
  - [x] 5.6 VoiceOver: add `.accessibilityLabel("Step synced")` announcement when pulse fires
  - [x] 5.7 Add Light and Dark #Preview variants for SyncPulseModifier

- [x] Task 6: Integration testing (AC: all)
  - [x] 6.1 Test: go offline → complete step → haptic fires → SprintPathView updates → step saved with .pendingSync
  - [x] 6.2 Test: go offline → complete all steps → sprint marked complete → retro NOT generated → retroPending true
  - [x] 6.3 Test: complete all steps offline → go online → retro generates → steps updated to .synced → sync pulse shows
  - [x] 6.4 Test: complete step offline → app terminated → relaunch → step still completed with .pendingSync → reconnect → syncs
  - [x] 6.5 Test: rapid online/offline toggling during step completion doesn't corrupt state

## Dev Notes

### Current State of the Codebase

**SprintDetailViewModel** (`Features/Sprint/ViewModels/SprintDetailViewModel.swift`, 293 lines):
- `toggleStep()` (lines 87-157) — handles step completion entirely locally via GRDB write transaction. Updates SprintStep, Sprint.lastStepCompletedAt, detects allDone, triggers retro generation, schedules milestone notifications, fires haptic/celebration.
- `generateNarrativeRetro()` (lines 159-217) — calls `chatService.streamChat()` with `mode: "sprint_retro"`. **This is the ONLY network-dependent operation in step completion.** Catches errors silently (retro is non-critical).
- `load()` (lines 49-85) — already retries retro if `sprint.narrativeRetro == nil`. This provides passive retry on view reappearance.
- `triggerCelebration()` (lines 235-253) — purely local: `UIImpactFeedbackGenerator` + `appState.avatarState = .celebrating` with 800ms auto-revert. **Works offline — no network dependency.**
- `triggerSprintCompletion()` (lines 255-273) — same pattern, medium impact, 1200ms celebration. **Works offline.**
- `checkIntermediateMilestone()` (lines 219-233) — schedules local `UNTimeIntervalNotificationTrigger`. **Works offline — local notifications don't need network.**
- Init takes: `appState, databaseManager, chatService?, notificationScheduler?` — chatService is optional (nil in some contexts), notificationScheduler is optional.

**SprintStep Model** (`Models/SprintStep.swift`):
- Properties: `id: UUID`, `sprintId: UUID`, `description: String`, `completed: Bool`, `completedAt: Date?`, `order: Int`, `coachContext: String?`
- No sync status field yet — needs v19 migration to add `syncStatus`
- Conforms to: `Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable` (all four required)
- Has `forSprint(id:)` query that orders by `order` ascending

**Sprint Model** (`Models/Sprint.swift`):
- Properties: `id, name, startDate, endDate, status, narrativeRetro?, lastStepCompletedAt?`
- `SprintStatus` enum: `.active`, `.complete`, `.cancelled`
- `active()` query: filters by status == "active"

**SprintService** (`Services/Sprint/SprintService.swift`):
- Protocol: `createSprint, activeSprint, savePendingProposal, loadPendingProposal, clearPendingProposal`
- Service handles sprint CREATION only — step completion lives in SprintDetailViewModel
- **Do NOT modify SprintService** — sync logic belongs in SprintDetailViewModel

**ConnectivityMonitor** (`Services/Networking/ConnectivityMonitor.swift`):
- Already exists from Story 10.2 — wraps NWPathMonitor, updates `AppState.isOnline`
- Protocol: `ConnectivityMonitorProtocol` with `isOnline: Bool`, `connectionType: ConnectionType`
- MockConnectivityMonitor exists at `Tests/Mocks/MockConnectivityMonitor.swift`

**Migrations** (`Services/Database/Migrations.swift`):
- Currently at v18 (messageDeliveryStatus from Story 10.2). Next migration is v19.
- Migrations are append-only and sequential — NEVER modify existing migrations

**SprintDetailView** (`Features/Sprint/Views/SprintDetailView.swift`):
- Renders sprint header, SprintPathView, step list with completion toggles, narrative retro section
- Step rows call `viewModel.toggleStep(step, reduceMotion: reduceMotion)` on tap
- Current Environment properties: `@Bindable var viewModel`, `@Environment(\.dismiss)`, `@Environment(\.coachingTheme)`, `@Environment(\.accessibilityReduceMotion)` — **NO `appState` access currently**
- Must ADD `@Environment(AppState.self) private var appState` to enable `.onChange(of: appState.isOnline)` for reconnect sync
- `retroSection` computed property (lines 111-138) has the retro rendering — needs third state for `retroPending`
- `stepsSection` computed property (lines 94-109) has the ForEach — needs sync pulse modifier on `SprintStepRow` call sites
- No `.onChange` modifiers exist yet — adding one for connectivity is new to this view

**Existing test file**: `Tests/Features/Sprint/SprintDetailViewModelTests.swift` — contains tests for load, toggleStep, celebration, retro generation. Add offline-specific tests here or in a new dedicated file.

### Architecture Compliance

- **Step completion is already local-first** — SprintStep writes go directly to SQLite. No network call. This is correct per architecture: "Server is stateless — all state lives on iOS device."
- **The ONLY network dependency is narrative retro generation** — `generateNarrativeRetro()` calls `chatService.streamChat()` with `mode: "sprint_retro"`. This is what needs offline deferral and sync.
- **No server-side sprint storage** — the server doesn't know about sprints. Sprint context is sent as part of `/v1/chat` requests for coaching context. Offline step completions are automatically reflected in the next chat request.
- **No new API endpoints needed** — retro generation uses existing `/v1/chat` endpoint with `mode: "sprint_retro"`
- **ConnectivityMonitor drives `appState.isOnline`** — already wired from Story 10.2
- **Milestone notifications are local-only** — `UNTimeIntervalNotificationTrigger` fires regardless of connectivity. No change needed.
- **"Conflict resolution" in this context is minimal** — single-device, local-first architecture means no real data conflicts. "Conflict resolution" means: (a) completing an already-complete step is idempotent (toggle logic handles this), (b) uncompleting a step resets syncStatus to `.synced`, (c) retro generation is idempotent (writes to nil field, never overwrites existing retro). Do NOT build a conflict resolution system — the existing toggle logic handles edge cases.

### Key Design Decisions

1. **`syncStatus` on SprintStep, not a separate queue table**: Consistent with Story 10.2's approach of adding `deliveryStatus` to Message. A status column on the existing model is simpler than a separate sync table. Steps with `.pendingSync` are those completed offline awaiting acknowledgment on reconnect.

2. **Step sync and retro retry are INDEPENDENT operations**: On reconnect, (a) ALL pendingSync steps transition to `.synced` unconditionally — they're already persisted locally, nothing to push to a server. (b) Retro generation retries IF sprint is complete and retro is nil. Step sync must NOT depend on retro success — even if retro fails, steps should be marked synced.

3. **Connectivity observation via `.onChange` in View, not ViewModel polling**: Matches the pattern established in Story 10.2 where CoachingView uses `.onChange(of: appState.isOnline)` to trigger `syncPendingMessages()`. No polling loops.

4. **Retro retry is best-effort with multiple paths**: (a) Active retry via `syncOnReconnect()` when view is visible. (b) Passive retry via `load()` when user navigates back to sprint detail. (c) Both paths already exist or are easy to add. Retro is non-critical — sprint completion doesn't depend on it.

5. **Haptic and celebration work offline by design**: `UIImpactFeedbackGenerator` and `AppState.avatarState` are purely local. No changes needed — just needs test verification.

6. **Visual sync confirmation via subtle color pulse**: Per UX spec, synced steps get a "brief subtle color pulse (quick: 0.25s)" — similar to how PendingMessageIndicator fades on send. This is transient and unobtrusive.

### Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `ios/sprinty/Services/Database/Migrations.swift` | MODIFY | Add v19 migration for SprintStep.syncStatus |
| `ios/sprinty/Models/SprintStep.swift` | MODIFY | Add syncStatus property, SprintStepSyncStatus enum, pendingSync() query |
| `ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift` | MODIFY | Offline-aware toggleStep, syncOnReconnect(), retroPending flag, recentlySyncedStepIds |
| `ios/sprinty/Features/Sprint/Views/SprintDetailView.swift` | MODIFY | Add .onChange for connectivity, retro pending placeholder, sync pulse on steps |
| `ios/sprinty/Features/Sprint/Views/SyncPulseModifier.swift` | CREATE | ViewModifier for subtle color pulse animation on synced steps |
| `ios/sprinty.xcodeproj/project.pbxproj` | MODIFY | Add SyncPulseModifier.swift to app target, new test files to test target |
| `ios/Tests/Features/Sprint/SprintDetailViewModelOfflineTests.swift` | CREATE | Offline step completion and sync tests |
| `ios/Tests/Models/SprintStepSyncTests.swift` | CREATE | Migration and sync status query tests |

### Previous Story Intelligence

**Story 10.2 (Offline Mode)** — Established the offline infrastructure this story builds on:
- `ConnectivityMonitor` wraps NWPathMonitor, drives `AppState.isOnline`
- `Message.deliveryStatus` pattern — same approach used here for `SprintStep.syncStatus`
- `.onChange(of: appState.isOnline)` in View triggers ViewModel sync methods
- `syncPendingMessages()` pattern — sequential processing, error handling, status updates
- v18 migration added `deliveryStatus` with `DEFAULT 'sent'` — same pattern for v19
- Key learning from code review: connectivity observation should be view-driven (`.onChange`), not ViewModel polling

**Story 10.2 completion notes** (relevant):
- Migration was v18 (not v17 — v17 was already taken by notifications). Current next is v19.
- `MockConnectivityMonitor` already exists with controllable `isOnline` state.
- RootView no longer blocks when offline — main app is accessible.

### Git Intelligence

Recent commits (last 5):
- `feat: Story 10.2 — Offline mode with code review fixes`
- `feat: Story 10.1 — Multi-provider failover with code review fixes`
- `feat: Story 9.3 — Notification preferences with code review fixes`
- `feat: Story 9.2 — Check-in and sprint milestone notifications with code review fixes`
- `feat: Story 9.2 — Create story context`

Patterns: MVVM with `@Observable`, Swift Testing, GRDB, protocol-based DI with mocks. Commit format: `feat: Story X.Y — Description`.

### What NOT to Do

- **Do NOT add a server endpoint for sprint sync** — the server is stateless, has no sprint storage. "Sync" means updating local syncStatus and retrying deferred retro generation.
- **Do NOT add a separate sync queue table** — use a `syncStatus` column on SprintStep, consistent with Message.deliveryStatus pattern.
- **Do NOT modify SprintService** — step completion and sync logic live in SprintDetailViewModel. SprintService is for sprint creation/proposals only.
- **Do NOT poll for connectivity** — use `.onChange(of: appState.isOnline)` in the View, matching Story 10.2's pattern.
- **Do NOT make haptic/celebration conditional on connectivity** — they are purely local and MUST fire regardless of network state.
- **Do NOT block step completion on sync** — step completion is instant and local. Sync is async and deferred.
- **Do NOT tie step sync to retro success** — steps transition to `.synced` on reconnect regardless of whether retro generation succeeds. These are independent operations.
- **Do NOT add a full "pending step" indicator like PendingMessageIndicator** — steps are local-first and complete instantly. The sync pulse is a brief transient acknowledgment, not a persistent indicator.
- **Do NOT build a conflict resolution system** — single-device local-first means no real conflicts. The toggle logic already handles edge cases (idempotent complete, uncomplete resets syncStatus).

### Testing Strategy

- **SprintStep sync status**: Use `makeTestDB()` with real GRDB migrations against in-memory database. Test v19 migration applies correctly. Test `pendingSync()` query filters correctly.
- **Offline step completion**: Use `MockChatService` (already exists) + `MockConnectivityMonitor` (already exists from Story 10.2). Test `toggleStep()` when offline sets `.pendingSync`, test when online keeps `.synced`.
- **Deferred retro**: Mock `appState.isOnline = false`, complete all steps, verify retro NOT called. Then set `isOnline = true`, call `syncOnReconnect()`, verify retro called and steps updated.
- **Celebration offline**: Verify `appState.avatarState` changes to `.celebrating` and haptic fires regardless of `appState.isOnline`.
- **Sync pulse**: Manual testing + `#Preview` for SyncPulseModifier. Provide Light and Dark variants.
- **Integration tests**: End-to-end offline → complete → online → retro generates → sync pulse.

### Project Structure Notes

- New file `SyncPulseModifier.swift` goes in `Features/Sprint/Views/` — sprint-specific UI component
- Test files mirror source: `Tests/Features/Sprint/` for ViewModel tests, `Tests/Models/` for schema tests
- Mocks reuse existing: `MockChatService`, `MockConnectivityMonitor`, `MockNotificationScheduler`
- All new files must be added to `ios/project.yml` under correct target

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 10, Story 10.3 requirements and BDD scenarios]
- [Source: _bmad-output/planning-artifacts/architecture.md — Offline/Caching: "Sprint step completions queued offline, synced on reconnect", SprintViewModel structure with offline queue]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Sprint step completion (quick + haptic), Avatar celebration (slow, 0.8s), Sync confirmation (brief subtle color pulse, quick: 0.25s), SprintPathView spec]
- [Source: _bmad-output/planning-artifacts/prd.md — FR71 (offline sprint step completion), NFR34 (retry on connectivity restoration with conflict resolution)]
- [Source: _bmad-output/project-context.md — Project conventions, testing rules, anti-patterns]
- [Source: ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift — Current toggleStep flow, retro generation, celebration logic]
- [Source: ios/sprinty/Models/SprintStep.swift — Current model without syncStatus]
- [Source: ios/sprinty/Services/Database/Migrations.swift — Currently at v18, next is v19]
- [Source: _bmad-output/implementation-artifacts/10-2-offline-mode.md — ConnectivityMonitor pattern, .onChange connectivity observation, Message.deliveryStatus pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation with no blocking issues.

### Completion Notes List

- Task 1: Added v19 migration (`v19_sprintStepSyncStatus`), `SprintStepSyncStatus` enum (`.synced`, `.pendingSync`), `syncStatus` property on SprintStep, and `pendingSync()` query. 4 tests pass.
- Task 2: Modified `toggleStep()` to set `.pendingSync` when offline, `.synced` when online or uncompleting. Skip retro generation when offline, set `retroPending = true`. Sprint still marked `.complete` and celebration still fires offline. 6 tests pass.
- Task 3: Added `syncOnReconnect()` with independent step sync and retro retry. Steps transition to `.synced` regardless of retro success. Added `.onChange(of: appState.isOnline)` in SprintDetailView for connectivity observation. `recentlySyncedStepIds` populated for visual pulse, cleared after 1.5s. 4 tests pass.
- Task 4: Added `retroPending` property, initialized in `load()`, cleared after retro generation. RetroSection has 3 states: retro text, generating pulsing placeholder, offline pending message. 2 tests pass.
- Task 5: Created `SyncPulseModifier` ViewModifier with 0.25s accent color pulse, respects reduceMotion, VoiceOver "Step synced" label. Applied at SprintStepRow call site in stepsSection. Light and Dark previews.
- Task 6: Integration tests cover offline→complete→sync, app relaunch persistence, rapid toggling. 5 tests pass.
- Total: 48 new/modified tests pass. 775/778 full suite pass (3 pre-existing SSEParser/ChatEventCodable failures unrelated to this story).

### Change Log

- 2026-04-03: Story 10.3 — Offline sprint step completion implemented (all 6 tasks complete)
- 2026-04-03: Code review fixes — Added VoiceOver announcement via AccessibilityNotification.Announcement for sync pulse; fixed File List to include project.pbxproj; corrected project.yml reference to project.pbxproj

### File List

- ios/sprinty/Models/SprintStep.swift (MODIFIED — added SprintStepSyncStatus enum, syncStatus property, pendingSync() query)
- ios/sprinty/Services/Database/Migrations.swift (MODIFIED — added v19_sprintStepSyncStatus migration)
- ios/sprinty/Features/Sprint/ViewModels/SprintDetailViewModel.swift (MODIFIED — offline-aware toggleStep, syncOnReconnect, retroPending, recentlySyncedStepIds)
- ios/sprinty/Features/Sprint/Views/SprintDetailView.swift (MODIFIED — appState environment, .onChange connectivity, retro pending state, sync pulse modifier)
- ios/sprinty/Features/Sprint/Views/SyncPulseModifier.swift (CREATED — ViewModifier for sync confirmation pulse)
- ios/Tests/Models/SprintStepSyncTests.swift (CREATED — migration and sync status query tests)
- ios/sprinty.xcodeproj/project.pbxproj (MODIFIED — added SyncPulseModifier.swift, test files to Xcode project targets)
- ios/Tests/Features/Sprint/SprintDetailViewModelOfflineTests.swift (CREATED — offline step completion, sync, and integration tests)
