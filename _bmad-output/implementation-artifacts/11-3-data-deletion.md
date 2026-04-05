# Story 11.3: Data Deletion

Status: done

## Story

As a user,
I want to permanently delete all my data from the app,
So that I know my information is truly gone when I choose to leave.

## Acceptance Criteria

1. **Given** the user navigates to Settings → Privacy → Delete All Data (FR61)
   **When** they initiate deletion
   **Then** a serious multi-step confirmation is required, including typing "DELETE" (UX-DR85)
   **And** the consequences are explained clearly in warm language

2. **Given** the user confirms deletion
   **When** the process executes
   **Then** all data is deleted: conversation history, summaries, embeddings, user profile, sprint data, avatar state, preferences
   **And** deletion is complete and irreversible within 24 hours (NFR14)
   **And** no residual data remains in local storage, backend logs, or provider systems

3. **Given** deletion completes
   **When** the app resets
   **Then** the user is returned to the onboarding flow as a new user

## Tasks / Subtasks

- [x] Task 1: Create DataDeletionService (AC: #2)
  - [x] 1.1 Create `DataDeletionServiceProtocol` in `Services/DataDeletion/DataDeletionServiceProtocol.swift`
  - [x] 1.2 Create `DataDeletionService` in `Services/DataDeletion/DataDeletionService.swift` — `Sendable`, NOT `@MainActor`
  - [x] 1.3 Implement `deleteAllData()` that performs the full deletion sequence in a single `dbPool.write { db in }` transaction so either everything succeeds or nothing is partially deleted
  - [x] 1.4 **BEFORE clearing tables**: write a final audit entry to `SafetyComplianceLog` recording the deletion event (eventType: "data_deletion", timestamp, sessionId: nil). This preserves compliance trail per NFR15.
  - [x] 1.5 Delete all rows from 9 GRDB record tables using exact PascalCase struct names (see Dev Notes table deletion order)
  - [x] 1.6 Clear Keychain entries (`Constants.keychainDeviceUUIDKey`, `Constants.keychainAuthJWTKey`) via `KeychainHelperProtocol.delete(key:)`
  - [x] 1.7 Clear `UserDefaults.standard` pending sprint proposal: `UserDefaults.standard.removeObject(forKey: "pendingSprintProposal")` (or expose a `SprintService.clearPendingProposal()` call)
  - [x] 1.8 Remove all scheduled notifications via `NotificationSchedulerProtocol.removeAllScheduledNotifications()`
  - [x] 1.9 Reload widget timelines via `WidgetCenter.shared.reloadAllTimelines()`

- [x] Task 2: Extend SettingsViewModel with deletion state (AC: #1, #2, #3)
  - [x] 2.1 Add deletion properties: `isDeletingData: Bool`, `deletionError: AppError?`, `showDeletionConfirmation: Bool`, `deletionConfirmationText: String`, `dataDeletionCompleted: Bool`
  - [x] 2.2 Add optional `DataDeletionServiceProtocol` parameter to init (5th optional param, after `exportService`)
  - [x] 2.3 Add optional `AppState` reference to init (6th optional param) — used to trigger reset on completion
  - [x] 2.4 Add `requestDataDeletion()` method — sets `showDeletionConfirmation = true`
  - [x] 2.5 Add `confirmDataDeletion()` async method — validates `deletionConfirmationText == "DELETE"`, calls service (use `defer { isDeletingData = false }`), sets `dataDeletionCompleted = true`, then calls `resetAppStateToOnboarding()`
  - [x] 2.6 Add `resetAppStateToOnboarding()` — resets ALL mutable AppState fields (see Dev Notes)
  - [x] 2.7 Add `cancelDeletion()` method — resets confirmation state (sets `showDeletionConfirmation = false`, clears `deletionConfirmationText`)

- [x] Task 3: Wire AppState through SettingsView (AC: #3)
  - [x] 3.1 Add `@Environment(AppState.self) private var appState` to `SettingsView` — DEVIATION: used init parameter injection instead (SwiftUI `@Environment` is not readable from `init`; init-parameter is cleaner and testable). RootView reads `@Environment(AppState.self)` and passes it into `SettingsView.init`.
  - [x] 3.2 Pass `appState` to `SettingsViewModel` init in the `init` method
  - [x] 3.3 Verify `RootView` already provides AppState via `.environment(appState)` — confirmed in `SprintyApp.swift:20`

- [x] Task 4: Replace DeleteAllDataPlaceholderView with full implementation (AC: #1, #2, #3)
  - [x] 4.1 Replace placeholder with multi-step deletion flow (kept filename `DeleteAllDataPlaceholderView.swift`; struct renamed to `DeleteAllDataView`)
  - [x] 4.2 Use `@Bindable var viewModel: SettingsViewModel` pattern (same as ExportConversationsPlaceholderView)
  - [x] 4.3 Step 1: Warm explanation screen listing what will be deleted + "Continue" button
  - [x] 4.4 Step 2: TextField requiring user to type "DELETE" exactly + destructive "Delete Everything" button (disabled until match)
  - [x] 4.5 Show progress indicator while `viewModel.isDeletingData == true`
  - [x] 4.6 On `viewModel.dataDeletionCompleted == true`: display brief farewell message; app navigation will auto-route to onboarding via AppState reset
  - [x] 4.7 Display `viewModel.deletionError` with warm error message (UX-DR71 pattern) if deletion fails
  - [x] 4.8 VoiceOver: announce state changes via `AccessibilityNotification.Announcement`

- [x] Task 5: Tests (AC: #1, #2, #3)
  - [x] 5.1 Create `MockDataDeletionService` in `Tests/Mocks/MockDataDeletionService.swift` — conforms to `DataDeletionServiceProtocol`, tracks `callCount`, supports `stubbedError`
  - [x] 5.2 Create `MockKeychainHelper` in `Tests/Mocks/MockKeychainHelper.swift` — extracted from `AuthServiceTests.swift` so both test files share it (avoids duplicate top-level class)
  - [x] 5.3 Create `DataDeletionServiceTests.swift` — 8 tests: all 9 tables empty after deletion, MessageFTS auto-cleared by triggers, keychain keys deleted, UserDefaults key removed, notification scheduler called, widget reloader called, idempotent on empty database, audit entry written+wiped in same transaction
  - [x] 5.4 Create `SettingsViewModelDeletionTests.swift` — 9 tests: state transitions, confirmation rejected when text != "DELETE" (incl. lowercase and empty), no-service no-op, success path, failure path sets error + resets `isDeletingData`, AppState all 10 resettable fields verified, no-appState no-op

## Dev Notes

### Architecture & Patterns

**Service Pattern** — Follow the exact pattern from Story 11.2 (ConversationExportService):
- Protocol in separate file, service `Sendable` (NOT `@MainActor`)
- Injected into SettingsViewModel as optional parameter via init
- Database access via `dbPool.write { db in }` for deletions

**SettingsViewModel Extension** — Add deletion properties alongside existing export properties (lines 16-20 of current SettingsViewModel). Add `dataDeletionService` as 5th optional init parameter after `exportService`.

**View Pattern** — Follow the same SwiftUI patterns from Story 11.1/11.2:
- `@Environment(\.coachingTheme)` for theme access
- `GeometryReader` + `theme.spacing.screenMargin(for:)` for responsive margins
- `LinearGradient` background with `.ignoresSafeArea()`
- `.frame(maxWidth: .infinity, maxHeight: .infinity)` BEFORE background modifier

### Database Tables to Delete (9 GRDB record types + 1 FTS5 virtual table)

**CRITICAL: Use exact PascalCase GRDB struct names for `deleteAll(db)`** — struct names differ from table names for `NotificationDelivery`:

Delete in this order (within the single write transaction), AFTER the compliance log entry is written:

1. `try Message.deleteAll(db)` — FK → ConversationSession. **Note:** FTS5 delete triggers (`message_fts_delete`) auto-clear `MessageFTS` rows, so manual FTS cleanup is not needed. You may optionally run `try db.execute(sql: "DELETE FROM MessageFTS")` as a safety net, but it's redundant.
2. `try ConversationSummary.deleteAll(db)` — FK → ConversationSession, includes embeddings (Data field)
3. `try CheckIn.deleteAll(db)` — FK → ConversationSession AND Sprint (cascade delete references both)
4. `try SprintStep.deleteAll(db)` — FK → Sprint
5. `try SafetyComplianceLog.deleteAll(db)` — **Note:** No actual DB-level FK constraint exists in schema (only logical relationship to ConversationSession). Order is still safe. **Do this AFTER writing the deletion audit entry in Task 1.4 — otherwise the audit entry will be wiped too.** The deletion audit entry is written first, then the full compliance log is cleared (including the new entry — this is acceptable since on MVP the compliance log is on-device only; full audit preservation is a Phase 2 concern tied to server-side logging).
6. `try NotificationDelivery.deleteAll(db)` — **⚠️ Struct is PascalCase `NotificationDelivery` but table name is camelCase `notificationDelivery` (`static let databaseTableName = "notificationDelivery"`). Use the struct name for `.deleteAll()`.**
7. `try ConversationSession.deleteAll(db)` — parent table
8. `try Sprint.deleteAll(db)` — parent table
9. `try UserProfile.deleteAll(db)` — standalone, clears all user preferences (coach name, avatar, notification settings, etc.)

**Compliance log strategy alternative:** If preserving the deletion audit entry is required, write it to a separate location (e.g., append to a flat-file audit log outside SQLite, or skip clearing `SafetyComplianceLog` and accept that one residual record remains). For MVP, clearing the compliance log with the rest of the data is acceptable — the written-first-then-wiped pattern serves as a structural placeholder for Phase 2 server-side audit.

### Non-Database Storage to Clear

**Keychain** (`Constants.keychainService = "com.ducdo.sprinty"`):
- `Constants.keychainDeviceUUIDKey` ("device-uuid") — clears device identity, forces re-registration
- `Constants.keychainAuthJWTKey` ("auth-jwt") — clears auth token

Access via `KeychainHelperProtocol.delete(key:)`. `KeychainHelper()` has a default init, so DataDeletionService can instantiate its own or accept one via DI.

**UserDefaults** (only one known key in the app):
- `"pendingSprintProposal"` — used by `SprintService.savePendingProposal/clearPendingProposal` (see `ios/sprinty/Services/Sprint/SprintService.swift:31,96,100,107`). Must be cleared during deletion — otherwise a stale pending sprint proposal from the previous user survives.

**App Group Container:**
The SQLite database lives in the App Group shared container (`group.com.ducdo.sprinty`) per architecture. Clearing all tables via the write transaction covers BOTH the main app and widget extension views of the data — widgets just need a timeline reload to re-render empty state.

**Temp Files:**
No cleanup needed — `ConversationExportService` writes to `FileManager.default.temporaryDirectory`, which the OS auto-cleans.

### App State Reset — ALL Mutable Fields

`AppState` has 13 mutable fields (see `ios/sprinty/App/AppState.swift`). Resetting only two leaves stale state. Reset the following in `SettingsViewModel.resetAppStateToOnboarding()` on the main actor:

```swift
appState.isAuthenticated = false
appState.needsReauth = false
appState.onboardingCompleted = false
appState.tier = .free                      // CRITICAL if user was premium
appState.avatarState = .active
appState.isPaused = false
appState.pendingCheckIn = false
appState.pendingEngagementSource = nil
appState.showConversation = false
appState.activeSprint = nil
// Do NOT reset: isOnline (network state), databaseManager, connectivityMonitor
```

The existing navigation logic in RootView routes to onboarding when `onboardingCompleted == false`. No new navigation wiring needed.

**SettingsView must access AppState**: Currently `SettingsView.init` receives `databaseManager` but NOT `AppState`. Add `@Environment(AppState.self) private var appState` to `SettingsView` and pass it into `SettingsViewModel` via init. `RootView` already provides AppState via environment (see `RootView.swift`).

### UX Requirements (UX-DR85: Serious Multi-Step Confirmation)

**Step 1 — Explanation Screen:**
- Warm, reassuring language (NOT legalese)
- List what will be deleted: conversations, memories, sprints, preferences, coach relationship
- Emphasize irreversibility: "This cannot be undone"
- "Continue" button to proceed

**Step 2 — Type DELETE Confirmation:**
- TextField where user must type exactly "DELETE"
- "Delete Everything" button — only enabled when text matches
- Use destructive button styling (red)

**Tone Examples** (warm, not bureaucratic):
- "We're sorry to see you go"
- "This will remove everything — your conversations, what your coach has learned about you, your sprints, and all preferences"
- "Once deleted, there's no way to bring it back"
- "Your data, your choice — always"

**Post-Deletion:**
- Brief farewell message before resetting to onboarding
- No residual state — complete fresh start

**iCloud Backup Awareness (Optional Informational Line):**
If iCloud backup is enabled, the confirmation screen may include a subtle note: "This clears everything on this device. If you have iCloud backup enabled, any previous backup snapshots may still contain old data until iCloud refreshes them." Full iCloud exclusion is handled by Story 11.4 — do not implement backup manipulation here.

### Notification Cleanup

Call `notificationScheduler?.removeAllScheduledNotifications()` to clear any pending local notifications before deletion completes.

### Widget Cleanup

Call `WidgetCenter.shared.reloadAllTimelines()` after deletion so widgets reflect empty/default state.

### What NOT to Do

- Do NOT call any server-side deletion endpoint — server has no user data (stateless proxy). The `DELETE /v1/user/{deviceId}` endpoint is Phase 2 and doesn't exist yet.
- Do NOT delete the SQLite database file itself — just clear all rows. The app needs the schema intact for re-registration.
- Do NOT add a "soft delete" or "grace period" — deletion is immediate and complete per NFR14.
- Do NOT add export prompt before deletion — export is a separate feature already available.
- Do NOT put any deletion UI in conversation view — Settings → Privacy only.

### Testing Standards

- **Framework:** Swift Testing (`@Test` macro, `#expect()`) — NOT XCTest
- **Naming:** `test_methodName_condition_expectedResult`
- **Database:** In-memory GRDB via `DatabaseQueue()` with migrations applied
- **Mocks:** Hand-written protocol conformances, `Sendable`
- **Mock for KeychainHelper:** Create or reuse `MockKeychainHelper` implementing `KeychainHelperProtocol`

**Test Cases:**
- Service: all 9 GRDB tables empty after deletion
- Service: MessageFTS auto-cleared by triggers when Message rows deleted
- Service: deletion audit entry written to SafetyComplianceLog before wipe (verify via spy on mock, or read before clearing within same transaction in test)
- Service: keychain entries cleared (device-uuid, auth-jwt) via MockKeychainHelper
- Service: UserDefaults key `pendingSprintProposal` removed
- Service: notification scheduler `removeAllScheduledNotifications()` called
- Service: deletion is idempotent (succeeds on already-empty database)
- ViewModel: `confirmDataDeletion()` rejected when `deletionConfirmationText != "DELETE"`
- ViewModel: `confirmDataDeletion()` sets `dataDeletionCompleted = true` on success
- ViewModel: `confirmDataDeletion()` sets `deletionError` on failure
- ViewModel: `isDeletingData` true during deletion, false after (including task cancellation via `defer`)
- ViewModel: `cancelDeletion()` resets all confirmation state
- ViewModel: AppState all 10 resettable fields actually reset after successful deletion

### Project Structure Notes

New files follow existing service organization:
```
ios/sprinty/Services/DataDeletion/
├── DataDeletionServiceProtocol.swift
└── DataDeletionService.swift

ios/Tests/Services/DataDeletion/
└── DataDeletionServiceTests.swift

ios/Tests/Features/Settings/
└── SettingsViewModelDeletionTests.swift

ios/Tests/Mocks/
├── MockDataDeletionService.swift
└── MockKeychainHelper.swift          # Does not exist in codebase yet — create
```

Modified files:
- `SettingsViewModel.swift` — add deletion properties, methods, AppState reference
- `DeleteAllDataPlaceholderView.swift` → replace placeholder with full implementation (keep or rename filename to `DeleteAllDataView.swift`)
- `SettingsView.swift` — add `@Environment(AppState.self)`, wire DataDeletionService and AppState into SettingsViewModel init
- `RootView.swift` — verify (do not modify) that AppState is provided via `.environment(appState)` so SettingsView can read it

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 11, Story 11.3]
- [Source: _bmad-output/planning-artifacts/prd.md — FR61, NFR14]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR85 confirmation patterns]
- [Source: _bmad-output/planning-artifacts/architecture.md — Database schema, Security, SettingsViewModel]
- [Source: _bmad-output/implementation-artifacts/11-2-conversation-history-export.md — Service pattern, ViewModel pattern, View pattern]
- [Source: ios/sprinty/Services/Database/Migrations.swift — All 10 table definitions]
- [Source: ios/sprinty/Services/Networking/AuthService.swift — KeychainHelperProtocol, KeychainHelper]
- [Source: ios/sprinty/Core/Utilities/Constants.swift — Keychain keys, App Group identifier]
- [Source: ios/sprinty/App/AppState.swift — isAuthenticated, onboardingCompleted flags]

## Dev Agent Record

### Agent Model Used

claude-opus-4-6 (Amelia / bmad-dev)

### Debug Log References

- Initial test run used `:memory:` for `DatabasePool` which failed with "could not activate WAL Mode". Fixed by switching to a temp-file path like existing tests (GRDB `DatabasePool` requires WAL, which needs a real file; use `DatabaseQueue` for true in-memory).
- `UserDefaults` is non-`Sendable`. Marked the stored property `nonisolated(unsafe)` since `DataDeletionService` is `Sendable`. UserDefaults is internally thread-safe, so this is correct.
- `SafetyComplianceLog.sessionId` is a non-optional `UUID`, so the audit entry uses an all-zero sentinel UUID as an "orphan" session marker instead of `nil` as the story originally suggested.
- Extracted pre-existing `MockKeychainHelper` from `AuthServiceTests.swift` into `Tests/Mocks/MockKeychainHelper.swift` to avoid duplicate top-level type when reusing it in `DataDeletionServiceTests`. Existing `AuthServiceTests` continue to work since both test files share the same target.
- Pre-existing `SSEParserTests` / `ChatEventCodableTests` failures (3 tests) confirmed on main branch before my changes; unrelated to this story.

### Completion Notes List

- Created `DataDeletionService` as a `Sendable` service (NOT `@MainActor`) that performs all SQLite mutations in a single `dbPool.write` transaction. Deletion order follows FK dependencies: `Message → ConversationSummary → CheckIn → SprintStep → SafetyComplianceLog → NotificationDelivery → ConversationSession → Sprint → UserProfile`.
- Audit entry is written to `SafetyComplianceLog` inside the same transaction BEFORE the log is wiped (per NFR15 structural intent). For MVP the audit entry is wiped along with the rest; full audit preservation is deferred to Phase 2 server-side logging.
- `MessageFTS` FTS5 virtual table is auto-cleared by the existing `message_fts_delete` trigger (verified via dedicated test).
- Non-database cleanup: both Keychain keys deleted via injected `KeychainHelperProtocol`, `UserDefaults` key `pendingSprintProposal` removed, `NotificationScheduler.removeAllScheduledNotifications()` awaited, and `WidgetCenter.shared.reloadAllTimelines()` called (injected via optional closure for test observability).
- `SettingsViewModel` gained 5 new `@Observable` properties, a `DataDeletionServiceProtocol` init parameter, and a weak `AppState` reference. `confirmDataDeletion()` uses `defer { isDeletingData = false }` so the flag is reset even on error or task cancellation.
- `resetAppStateToOnboarding()` resets all 10 mutable `AppState` fields except `isOnline`, `databaseManager`, `connectivityMonitor`. Existing `RootView` navigation logic handles the route back to onboarding automatically when `onboardingCompleted == false`.
- `DeleteAllDataView` implements UX-DR85: warm explanation screen (step 1) → type-DELETE confirmation (step 2) → farewell on completion. Uses destructive red button, disabled until text exactly matches `"DELETE"`. VoiceOver announcements via `AccessibilityNotification.Announcement` for each state transition.
- `SettingsView.init` was updated to take `appState: AppState` as a required parameter (instead of `@Environment`) because SwiftUI `@Environment` cannot be read from `init`. `RootView` reads AppState from its environment and passes it in.
- All 17 new tests pass. Full test suite run: 831 tests, 3 pre-existing failures (SSEParser / ChatEventCodable) unrelated to this story.

### File List

**New:**
- `ios/sprinty/Services/DataDeletion/DataDeletionServiceProtocol.swift`
- `ios/sprinty/Services/DataDeletion/DataDeletionService.swift`
- `ios/Tests/Mocks/MockDataDeletionService.swift`
- `ios/Tests/Mocks/MockKeychainHelper.swift`
- `ios/Tests/Services/DataDeletion/DataDeletionServiceTests.swift`
- `ios/Tests/Features/Settings/SettingsViewModelDeletionTests.swift`

**Modified:**
- `ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift` — added deletion state, methods, and `dataDeletionService` + `appState` init params
- `ios/sprinty/Features/Settings/Views/SettingsView.swift` — added `appState: AppState` init param, wired `DataDeletionService`, replaced Delete All Data link destination with `DeleteAllDataView`
- `ios/sprinty/Features/Settings/Views/DeleteAllDataPlaceholderView.swift` — struct renamed to `DeleteAllDataView` with full two-step deletion flow
- `ios/sprinty/App/RootView.swift` — passes `appState` into `SettingsView.init`
- `ios/Tests/Services/AuthServiceTests.swift` — removed inline `MockKeychainHelper` (extracted to Mocks folder)
- `ios/sprinty.xcodeproj/project.pbxproj` — regenerated via `xcodegen` to include new files

### Change Log

- 2026-04-05: Implemented Story 11.3 Data Deletion. Added `DataDeletionService` with atomic transactional deletion across 9 GRDB tables + keychain, UserDefaults, notifications, and widgets. Extended `SettingsViewModel` with deletion state + AppState reset. Replaced Delete All Data placeholder with multi-step confirmation view (UX-DR85). 17 new tests added, all passing.
