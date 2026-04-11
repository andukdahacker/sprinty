# Story 11.4: Apple Privacy Manifest & iCloud Backup

Status: done

## Story

As a user submitting to the App Store,
I want the app to comply with Apple's privacy requirements and support standard backup mechanisms,
So that the app passes review and my data is handled transparently.

## Acceptance Criteria

1. **Given** the Apple Privacy Manifest requirement
   **When** the app is submitted
   **Then** all data collection is explicitly declared in the Privacy Manifest
   **And** the manifest accurately reflects what data is collected and why (for Sprinty MVP: NO data is collected — all user data is on-device)

2. **Given** iCloud backup support (NFR36)
   **When** the app is backed up via iCloud
   **Then** all on-device coaching data is included by default
   **And** a user-facing option exists in Settings → Privacy to exclude coaching data from iCloud backup

3. **Given** the user opts out of iCloud backup
   **When** they toggle the setting
   **Then** coaching data is excluded from future iCloud backups
   **And** the change is respected immediately (backup flag applied to SQLite + WAL + SHM files synchronously)
   **And** the preference persists across app launches and survives database re-creation

## Tasks / Subtasks

- [x]Task 1: Create `PrivacyInfo.xcprivacy` manifest for the main app target (AC: #1)
  - [x]1.1 Create `ios/sprinty/Resources/PrivacyInfo.xcprivacy` as an XML plist (see Dev Notes → Privacy Manifest Contents for the exact XML to write)
  - [x]1.2 Set `NSPrivacyTracking` = `false` (app does not track users across apps/websites)
  - [x]1.3 Set `NSPrivacyTrackingDomains` to an empty array
  - [x]1.4 Set `NSPrivacyCollectedDataTypes` to an empty array — Sprinty collects NO user data (all coaching data on-device, server is stateless proxy, analytics are server-side operational metrics only per Story 10.5 Task AC#2)
  - [x]1.5 Declare `NSPrivacyAccessedAPITypes` — include `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (access info from same app, group, or app extension). Used by `SprintService.pendingProposalKey` and `DataDeletionService.userDefaults` clearing.
  - [x]1.6 Ensure the manifest is picked up as a Copy Bundle Resource. **Implementation note**: xcodegen 2.45.3 silently drops `.xcprivacy` files when registered explicitly under `resources:` (with or without `type: file, buildPhase: resources`); rely on the existing `sources:` directory auto-scan to pick up `sprinty/Resources/PrivacyInfo.xcprivacy` instead, and verify it lands in `PBXResourcesBuildPhase` after `xcodegen generate`. See Debug Log References for details.
  - [x]1.7 Run `xcodegen generate` to regenerate `sprinty.xcodeproj` and verify the file is included in the `Copy Bundle Resources` build phase

- [x]Task 2: Create matching `PrivacyInfo.xcprivacy` for the widget extension (AC: #1)
  - [x]2.1 Create `ios/sprinty_widgetExtension/PrivacyInfo.xcprivacy` with the same structure as the main app manifest. Apple requires every binary (app + extensions) to ship its own manifest; at build time Xcode aggregates them.
  - [x]2.2 Widget does NOT use `UserDefaults` (verified: zero matches for `UserDefaults`, `NSUserDefaults`, `@AppStorage` across all 5 widget files + 11 shared sources compiled by the widget target). Declare an EMPTY `NSPrivacyAccessedAPITypes` array `<array/>`.
  - [x]2.3 Ensure the widget manifest is picked up as a Copy Bundle Resource. **Implementation note**: same xcodegen 2.45.3 issue as 1.6 — explicit `resources:` registration silently drops the file; the directory auto-scan from the existing `- path: sprinty_widgetExtension` source entry picks it up correctly. Verify it lands in the widget target's `PBXResourcesBuildPhase` after `xcodegen generate`.
  - [x]2.4 Regenerate the Xcode project with `xcodegen generate`

- [x]Task 3: Add `excludeFromICloudBackup` field to `UserProfile` (AC: #2, #3)
  - [x]3.1 Add GRDB migration `v20_backupExclusionPreference` in `ios/sprinty/Services/Database/Migrations.swift` (next version after the latest `v19_sprintStepSyncStatus`)
  - [x]3.2 Migration: `try db.alter(table: "UserProfile") { t in t.add(column: "excludeFromICloudBackup", .boolean).notNull().defaults(to: false) }` — default `false` satisfies NFR36's "included by default" requirement
  - [x]3.3 Add the new property to the `UserProfile` struct in `ios/sprinty/Models/UserProfile.swift` under a NEW section comment immediately after the existing `// --- Notification preferences (Story 9.3) ---` block: add `// --- Privacy preferences (Story 11.4) ---` followed by `var excludeFromICloudBackup: Bool = false`. This is conceptually a Privacy preference, NOT a notification preference — keep groupings semantically accurate so future readers don't get misled.
  - [x]3.4 Verify all existing `UserProfile` construction sites still compile. There are 47+ construction sites across 27 files (mostly in Tests/). Swift's memberwise initializer uses labeled arguments — adding a new defaulted field does NOT break existing call sites that omit it, regardless of where it's inserted in the struct. A clean build confirms this; no manual call-site edits should be needed.

- [x]Task 4: Create `BackupPreferenceService` (AC: #2, #3)
  - [x]4.1 Create `ios/sprinty/Services/Backup/BackupPreferenceServiceProtocol.swift` defining: `func setExcludedFromBackup(_ excluded: Bool) throws`, `func isExcludedFromBackup() throws -> Bool`. Protocol is `Sendable`.
  - [x]4.2 Create `ios/sprinty/Services/Backup/BackupPreferenceService.swift` as a `Sendable` service (NOT `@MainActor`). Inject the database file URL via init so it's testable with a temp URL.
  - [x]4.3 Implement `setExcludedFromBackup(_ excluded: Bool)`: compute the three file URLs — `sprinty.sqlite`, `sprinty.sqlite-wal`, `sprinty.sqlite-shm` — and call `var values = URLResourceValues(); values.isExcludedFromBackup = excluded; try fileURL.setResourceValues(values)` for each. Skip WAL/SHM if the file doesn't exist yet (checkpoint state), do NOT throw — they'll pick up the flag on next apply-on-launch pass.
  - [x]4.4 Implement `isExcludedFromBackup() throws -> Bool` by reading `try mainDbURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false`. Use the main sqlite file as source of truth.
  - [x]4.5 Static factory `BackupPreferenceService.forAppGroupContainer()` that resolves the App Group container URL via `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier)` and appends `Constants.databaseFilename` — matches `DatabaseManager.create()`'s path construction exactly
  - [x]4.6 **CRITICAL** — When the flag is set on the main `.sqlite` file, iOS does NOT automatically propagate to -wal/-shm sibling files. Both GRDB sidecar files MUST be flagged individually or backups will still contain partial data.

- [x]Task 5: Apply backup preference on app launch (AC: #3)
  - [x]5.1 In `DatabaseManager.create()` (`ios/sprinty/Services/Database/DatabaseManager.swift`), AFTER `try migrator.migrate(dbPool)`, read the persisted preference and apply the file flag only when the user opted out. `DatabaseManager.create()` is a `static` method — inline the service call directly:
    ```swift
    // After migrator.migrate(dbPool) — apply backup exclusion if user opted out
    if let profile = try? dbPool.read({ db in try UserProfile.fetchOne(db) }),
       profile.excludeFromICloudBackup {
        try? BackupPreferenceService.forAppGroupContainer()
            .setExcludedFromBackup(true)
    }
    ```
    Only call when `true` — the default `false` means files are already included in backup (filesystem default), so no I/O needed for the common case. This ensures -wal/-shm files created during runtime inherit the flag on every launch.
  - [x]5.2 Silently ignore errors during launch-time apply (log but do NOT throw) — backup flag failures must NEVER block app startup. Use the existing structured logging placeholder pattern in `DatabaseManager.create()`.
  - [x]5.3 If no `UserProfile` row exists yet (pre-onboarding first launch), skip the apply — there's no data to exclude yet and the flag will be applied when the user toggles it or when a profile is created during onboarding.

- [x]Task 6: Wire toggle into `SettingsViewModel` (AC: #2, #3)
  - [x]6.1 Add `@Observable` property: `var excludeFromICloudBackup: Bool = false`
  - [x]6.2 Add `private let backupPreferenceService: (any BackupPreferenceServiceProtocol)?` init parameter, positioned **after `dataDeletionService` and before `appState`** — the existing convention is services first, `appState` LAST (see `SettingsViewModel.swift:42`). Resulting init signature: `init(databaseManager:notificationService:notificationScheduler:exportService:dataDeletionService:backupPreferenceService:appState:)`.
  - [x]6.3 In `loadProfile()`, set `self.excludeFromICloudBackup = profile.excludeFromICloudBackup` after the existing profile field assignments
  - [x]6.4 Add `func updateExcludeFromICloudBackup(_ excluded: Bool)` — follow the exact pattern of `updateNotificationsMuted` (`SettingsViewModel.swift:114-135`): optimistically update local state, then `Task { [weak self] in }` to (a) write to `UserProfile` via `dbPool.write` and (b) call `backupPreferenceService?.setExcludedFromBackup(excluded)`. **Match the silent-catch pattern** of `updateNotificationsMuted` — wrap both operations in a single `do/catch` and silently swallow errors with a brief comment (`// Write/file flag failed — local state already updated; next launch will retry`). Do NOT surface `AppError.databaseError` for this toggle — it's a reversible setting, the apply-on-launch pass in Task 5.1 acts as the retry mechanism, and surfacing an error here would diverge from the established preference-toggle UX pattern in this view model.
  - [x]6.5 Instantiate `BackupPreferenceService.forAppGroupContainer()` in `SettingsView.init` and pass it into `SettingsViewModel.init` as the new parameter (positioned before `appState`, matching the init signature in 6.2)

- [x]Task 7: Add Settings → Privacy toggle UI (AC: #2, #3)
  - [x]7.1 In `ios/sprinty/Features/Settings/Views/SettingsView.swift`, add a new row inside the existing Privacy `Section` (between the "Your data stays on your phone" descriptive text and the `Coaching Disclaimer` NavigationLink)
  - [x]7.2 Use `Toggle("Exclude from iCloud Backup", isOn: Binding(get: { viewModel.excludeFromICloudBackup }, set: { viewModel.updateExcludeFromICloudBackup($0) }))`
  - [x]7.3 Add `.accessibilityHint("When enabled, your coaching data will not be included in iCloud device backups")`
  - [x]7.4 Add a descriptive subtitle Text below the toggle with warm tone (UX-DR34 reassuring language): `"iCloud backup keeps a copy of your coaching data so you can restore it on a new device. Turn this off if you'd rather keep it only on this phone."` — use `theme.typography.insightTextFont`, `theme.palette.textSecondary`
  - [x]7.5 Verify toggle uses home palette + coaching typography per UX-DR34

- [x]Task 8: Tests (AC: #1, #2, #3)
  - [x]8.1 Create `ios/Tests/Services/Backup/BackupPreferenceServiceTests.swift` using Swift Testing (`@Test` macro, `#expect`). Use `FileManager.default.temporaryDirectory` + `UUID().uuidString` for a real file — `URLResourceValues.isExcludedFromBackup` requires an actual on-disk file.
  - [x]8.2 Test: `setExcludedFromBackup(true)` on a real file sets `isExcludedFromBackupKey` → verify via `resourceValues(forKeys: [.isExcludedFromBackupKey])`
  - [x]8.3 Test: `setExcludedFromBackup(false)` clears the flag (starting from a flagged file)
  - [x]8.4 Test: idempotent — calling `setExcludedFromBackup(true)` twice leaves the file flagged
  - [x]8.5 Test: sidecar -wal/-shm files are also flagged when they exist (create empty files next to the main file)
  - [x]8.6 Test: sidecar -wal/-shm files that do NOT yet exist cause no error (method still returns without throwing)
  - [x]8.7 Create `MockBackupPreferenceService` in `ios/Tests/Mocks/MockBackupPreferenceService.swift` — conforms to `BackupPreferenceServiceProtocol, @unchecked Sendable` (mocks have mutable tracking properties incompatible with strict Sendable; every mock in this project uses `@unchecked Sendable` — see `MockDataDeletionService`, `MockChatService` etc.). Track `lastSetValue: Bool?`, `setCallCount: Int`, support `stubbedError: Error?`.
  - [x]8.8 Create `ios/Tests/Features/Settings/SettingsViewModelBackupTests.swift` — tests:
    - `loadProfile()` populates `excludeFromICloudBackup` from DB
    - `updateExcludeFromICloudBackup(true)` optimistically sets local state
    - `updateExcludeFromICloudBackup(true)` writes the new value to `UserProfile`
    - `updateExcludeFromICloudBackup(true)` calls `backupPreferenceService.setExcludedFromBackup(true)`
    - When `backupPreferenceService` is nil, DB still gets written (graceful nil handling)
  - [x]8.9 Add migration test in `ios/Tests/Database/MigrationTests.swift` (file already exists — extend it, do not recreate): after applying `v20_backupExclusionPreference`, verify the `excludeFromICloudBackup` column exists on `UserProfile` and defaults to `0` (false) for pre-existing rows
  - [x]8.10 Add privacy manifest validation test in `ios/Tests/Privacy/PrivacyManifestTests.swift` (new `Tests/Privacy/` folder — this is a privacy compliance test, not a generic resources test, and `Tests/Privacy/` is more discoverable than mirroring the source `Resources/` path) — load `PrivacyInfo.xcprivacy` from the main bundle via `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")`, parse as `PropertyListSerialization`, assert: `NSPrivacyTracking == false`, `NSPrivacyCollectedDataTypes` is empty array, `NSPrivacyAccessedAPITypes` contains `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. Note: `Bundle.main` works in unit tests because `sprintyTests` is a hosted test bundle — the test host IS the app, so `Bundle.main` points to `sprinty.app` and finds the xcprivacy resource. Do NOT use `Bundle.module` (that's for SPM, not xcodeproj targets).

- [x]Task 9: Regenerate Xcode project and verify submission readiness (AC: #1)
  - [x]9.1 Run `xcodegen generate` from `ios/` directory
  - [x]9.2 Verify both `PrivacyInfo.xcprivacy` files appear in the Copy Bundle Resources build phase for their respective targets (main app + widget extension). **Run a hard check** against the regenerated `ios/sprinty.xcodeproj/project.pbxproj`:
    - `grep -c "PrivacyInfo.xcprivacy" ios/sprinty.xcodeproj/project.pbxproj` — expect at least 4 hits (file ref + build file ref × 2 targets)
    - Confirm BOTH file refs appear under a `PBXResourcesBuildPhase` block, NOT under `PBXSourcesBuildPhase`. If you see them under Sources, the `excludes:` defensive measure in Task 2.3 was not applied — go back and fix.
  - [x]9.3 Build the app for Release configuration to confirm no build errors introduced by the manifest

## Dev Notes

### Context: Why This Story Exists

Per PRD decision 10 (architecture.md:85): *"App Store submission requires an Apple Privacy Manifest with explicit data collection declarations. NFR36 requires iCloud backup support with a user-facing option to exclude coaching data. Both are submission blockers if missed."*

Epic 11 (Privacy, Settings & Data Control) wraps up with this story — Stories 11.1–11.3 built the Settings UI, export, and deletion. This story is the **final App Store compliance gate** for MVP submission.

### Apple Privacy Manifest: What to Declare

Sprinty's privacy posture makes this manifest unusually simple:

| Declaration | Value | Reason |
|---|---|---|
| `NSPrivacyTracking` | `false` | No cross-app tracking, no IDFA, no SDK Network (no Sentry on iOS, no Firebase, no analytics) |
| `NSPrivacyTrackingDomains` | `[]` | No tracking domains |
| `NSPrivacyCollectedDataTypes` | `[]` | ALL coaching data lives on-device. Server is a stateless proxy with zero-retention provider agreements (PRD line 421). Server-side operational analytics (Story 10.5) log NO PII — deviceId is hashed, no message content, no profile data (verified in Story 10.5 Task 7.6). |
| `NSPrivacyAccessedAPITypes` | See below | Apple's Required Reason API list applies. |

**Required Reason APIs used by Sprinty iOS code:**

1. **`NSPrivacyAccessedAPICategoryUserDefaults`** — reason `CA92.1` ("Access info from same app, per documentation")
   - Used by `ios/sprinty/Services/Sprint/SprintService.swift:96,100,107` for `pendingSprintProposal`
   - Used by `ios/sprinty/Services/DataDeletion/DataDeletionService.swift:78` for cleanup
   - Bundle.main.infoDictionary access in `SettingsViewModel.appVersion/buildNumber` does NOT count (it's the Info.plist, not UserDefaults)

**APIs NOT used (do not declare):**
- `NSPrivacyAccessedAPICategoryFileTimestamp` — no direct `attributesOfItem` / `.contentModificationDateKey` calls
- `NSPrivacyAccessedAPICategoryDiskSpace` — no `volumeAvailableCapacity` calls
- `NSPrivacyAccessedAPICategorySystemBootTime` — no `mach_absolute_time` / `CACurrentMediaTime` at-launch
- `NSPrivacyAccessedAPICategoryActiveKeyboards` — no keyboard enumeration

**Verification before shipping**: run `grep -rn "UserDefaults\|mach_absolute_time\|volumeAvailableCapacity\|attributesOfItemAtPath\|activeKeyboardLanguages\|contentModificationDate\|systemUptime" ios/sprinty ios/sprinty_widgetExtension ios/Packages` to confirm nothing new snuck in during implementation. Note the wider scope: include `ios/Packages` to catch any local SPM targets, and `systemUptime` is an additional Required Reason API trigger to watch for. If a new match appears in code added since 11.3, add the corresponding Required Reason entry to the manifest before shipping.

### Privacy Manifest Contents (exact XML to write)

`ios/sprinty/Resources/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPIReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

`ios/sprinty_widgetExtension/PrivacyInfo.xcprivacy` — same structure but with EMPTY `NSPrivacyAccessedAPITypes` (widget has zero UserDefaults usage, verified across all compiled sources):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array/>
</dict>
</plist>
```

### iCloud Backup Exclusion: How iOS Works

**Key facts:**
1. Sprinty's SQLite DB lives in the App Group shared container: `group.com.ducdo.sprinty/sprinty.sqlite` (see `DatabaseManager.create()` + `Constants.appGroupIdentifier`, `Constants.databaseFilename`).
2. By default, files in the App Group container ARE included in iCloud device backup (this satisfies NFR36's default-included behavior — no code needed to opt in).
3. To EXCLUDE specific files from iCloud backup, set `URLResourceValues.isExcludedFromBackup = true` on the file URL via `URL.setResourceValues()`.
4. **GRDB uses WAL journal mode** (`DatabaseManager.create()` uses `DatabasePool` which requires WAL). WAL creates two sidecar files: `sprinty.sqlite-wal` and `sprinty.sqlite-shm`. These contain live data and MUST also be flagged or backups will include partial data.
5. The flag is a filesystem extended attribute (`com.apple.metadata:com_apple_backup_excludeItem`) — it persists per-file and survives app restarts. It does NOT persist if the file is deleted and recreated.
6. On reinstall, the sqlite file is recreated by GRDB migrations — the flag is lost. The **apply-on-launch pass in Task 5** re-applies the user's preference every time `DatabaseManager.create()` runs.
7. No iCloud entitlements (`com.apple.developer.icloud-container-identifiers`, `com.apple.developer.ubiquity-kvstore-identifier`) are needed or used. Sprinty relies on iOS device backup, not iCloud Drive / CloudKit. The entitlements file at `ios/sprinty/sprinty.entitlements` has only App Groups + Keychain — leave it alone.

### File URLs to Flag (exact paths)

```swift
let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
)!
let mainDbURL = containerURL.appendingPathComponent(Constants.databaseFilename)           // sprinty.sqlite
let walURL    = containerURL.appendingPathComponent("\(Constants.databaseFilename)-wal")  // sprinty.sqlite-wal
let shmURL    = containerURL.appendingPathComponent("\(Constants.databaseFilename)-shm")  // sprinty.sqlite-shm
```

### URLResourceValues Set Pattern (exact Swift)

```swift
func setExcludedFromBackup(_ excluded: Bool) throws {
    for url in [mainDbURL, walURL, shmURL] {
        guard FileManager.default.fileExists(atPath: url.path) else { continue }
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        try mutableURL.setResourceValues(values)
    }
}
```

`URL.setResourceValues` is `mutating` — `mutableURL` must be `var`. Fine for MVP; the copy is cheap.

### Patterns to Follow

**Service pattern** — mirror `DataDeletionService` exactly (`Services/DataDeletion/`):
- Protocol in a separate file
- Service is `Sendable`, NOT `@MainActor`
- Optional injection into `SettingsViewModel` via init (new param, consistent ordering — add AFTER `appState`)
- Static factory method for production wiring (`forAppGroupContainer()`)

**SettingsViewModel extension pattern** — mirror `updateNotificationsMuted` exactly (`SettingsViewModel.swift:114-135`):
- `@Observable` property
- `update*` method: optimistic local update, then `Task { [weak self] in }` for DB write + service call
- Ignore write errors silently (UX preference over error surfacing for a toggle that can be re-toggled)

**Migration pattern** — follow `v19_sprintStepSyncStatus` (latest existing migration). Use name `v20_backupExclusionPreference`. ALL migrations go in `DatabaseMigrations.registerMigrations` in `ios/sprinty/Services/Database/Migrations.swift`.

**SwiftUI Settings pattern** — the toggle goes inside the existing Privacy `Section` in `SettingsView.swift:122`. Do NOT create a new section. Follow the `updateNotificationsMuted` binding pattern used at `SettingsView.swift:78-82`.

### What NOT to Do

- Do NOT add iCloud Drive / CloudKit / CKContainer dependencies — Sprinty uses iOS standard device backup only (NFR36 says "iCloud backup", not "iCloud Drive")
- Do NOT modify `sprinty.entitlements` — no new entitlements needed
- Do NOT try to delete the sqlite file and recreate it to remove the backup flag — set the flag to `false` via `URLResourceValues` instead
- Do NOT flag the App Group container directory itself — only individual files
- Do NOT forget the -wal and -shm sidecar files (see "CRITICAL" note in Task 4.6)
- Do NOT add a "Backup Preference" feature folder — this is a `Services/Backup/` concern, not a `Features/` concern
- Do NOT declare `NSPrivacyCollectedDataTypes` entries "just to be safe" — adding data types you don't actually collect triggers App Store review rejection and creates future compliance burden. Sprinty genuinely collects nothing on the client.
- Do NOT store the backup preference in `UserDefaults` — it lives in `UserProfile` (same persistence tier as other user preferences, survives deletion-recreation sanely via migration)
- Do NOT add a confirmation dialog for the toggle — it's a reversible setting, not a destructive action (Story 11.3 uses dialogs for DELETE; this is opt-out of backup, fully reversible)
- Do NOT reference `Sentry` or any client-side analytics SDK in the privacy manifest — per Story 10.5 Task AC confirmation, Sentry is backend-only; there is NO client-side analytics SDK

### Previous Story Intelligence (11.3 — Data Deletion)

Lessons from 11.3 directly applicable here:

- **`SettingsView.init` takes required services as init parameters** — SwiftUI `@Environment` cannot be read from `init`. The `BackupPreferenceService` should be instantiated inside `SettingsView.init` (mirroring the current `ConversationExportService` and `DataDeletionService` creation at `SettingsView.swift:10-14`) and passed into `SettingsViewModel.init`.
- **`MockKeychainHelper` pattern**: `ios/Tests/Mocks/MockBackupPreferenceService.swift` should be created as a reusable test double, NOT inlined in the test file. Follow the exact shape of `MockDataDeletionService` for consistency.
- **`:memory:` does NOT work with `DatabasePool`** — WAL mode requires a real file. For tests that need a `DatabasePool`, use a temp-file path. For pure schema/row tests, use `DatabaseQueue()` (supports `:memory:`). See `DataDeletionServiceTests` debug log note for precedent.
- **GRDB sidecar files are real** — WAL and SHM files are not theoretical. When the app runs, they exist. When tests run on a `DatabaseQueue` with `:memory:`, they don't. Tests for `BackupPreferenceService` should use real temp files and manually create empty `-wal`/`-shm` companions to test sidecar handling.
- **`UserProfile` struct has a default value per field** — adding `var excludeFromICloudBackup: Bool = false` is non-breaking for all 47+ existing call sites across 27 files. Swift memberwise initializers use labeled arguments; existing call sites that omit the new field compile unchanged because the default value fills the gap. A clean build confirms — no manual edits needed.
- **`AppState` already fully reset on data deletion** — no changes needed to `resetAppStateToOnboarding()` for this story. Backup preference is a `UserProfile` field, so it's cleared when `UserProfile.deleteAll(db)` runs inside `DataDeletionService`.

### Interaction with Story 11.3 (Data Deletion)

When a user triggers data deletion, `DataDeletionService` wipes `UserProfile` along with all other tables. The backup exclusion preference is gone too, which is correct — the user's re-onboarded state will start fresh with the default (included in backup). However, the **file-level backup flag** is NOT cleared by `DataDeletionService` because deletion only clears rows, not file metadata. This is acceptable:
- If `excludeFromICloudBackup` was `true` before deletion, the file flag remains `true` until the next `DatabaseManager.create()` call
- On re-onboarding, a new `UserProfile` row is inserted with default `excludeFromICloudBackup = false`
- On next app launch (or immediately if the user navigates to Settings and the Privacy section loads), the apply-on-launch pass in Task 5.1 will see `false` and clear the file flag

Phase 2 hardening: eager file-flag reset in `DataDeletionService` is possible but NOT needed — the launch-time apply handles it.

### Architecture Alignment

- **Privacy & Data (FR59-FR62)** iOS location per architecture.md:1510 is `Services/Database/DatabaseManager.swift`, `Resources/PrivacyInfo.xcprivacy`. This story creates the manifest file in the architected location and adds a new sibling service at `Services/Backup/`.
- **NFR36** (architecture.md:1610): "Failover, offline, network transitions, iCloud backup ✅" — marked complete in architecture doc but implementation lives in THIS story. The ✅ reflects planning, not code.
- **File Protection**: `DatabaseManager.create()` already sets `FileProtectionType.complete` on the sqlite file. This is orthogonal to backup exclusion — both can be set independently.

### Project Structure

**New files:**
```
ios/sprinty/Resources/PrivacyInfo.xcprivacy
ios/sprinty_widgetExtension/PrivacyInfo.xcprivacy
ios/sprinty/Services/Backup/
├── BackupPreferenceServiceProtocol.swift
└── BackupPreferenceService.swift

ios/Tests/Services/Backup/
└── BackupPreferenceServiceTests.swift
ios/Tests/Features/Settings/
└── SettingsViewModelBackupTests.swift
ios/Tests/Resources/
└── PrivacyManifestTests.swift
ios/Tests/Mocks/
└── MockBackupPreferenceService.swift
```

**Modified files:**
```
ios/project.yml                                              # Register both PrivacyInfo.xcprivacy files as resources
ios/sprinty.xcodeproj/project.pbxproj                        # Regenerate via xcodegen (do NOT edit by hand)
ios/sprinty/Services/Database/Migrations.swift               # Add v20_backupExclusionPreference
ios/sprinty/Services/Database/DatabaseManager.swift          # Apply backup preference on launch after migrations
ios/sprinty/Models/UserProfile.swift                         # Add excludeFromICloudBackup field (default false)
ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift  # Add property, init param, update method
ios/sprinty/Features/Settings/Views/SettingsView.swift       # Add toggle to Privacy section, wire service in init
ios/Tests/Database/MigrationTests.swift                      # Add v20 migration test (if file exists; create if not)
```

### Testing Standards

- **Framework**: Swift Testing (`@Test` macro, `#expect()`) — NOT XCTest (follow 11.3 convention)
- **Naming**: `test_methodName_condition_expectedResult`
- **Database**: Use `DatabaseQueue()` for pure row/migration tests (fast, `:memory:`). Use temp-file `DatabasePool` for anything that touches WAL.
- **File tests for BackupPreferenceService**: use `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)` — create real files, clean up in test cleanup (teardown per test or `defer` inside the `@Test` function).
- **Mocks**: `MockBackupPreferenceService` conforms to `BackupPreferenceServiceProtocol, @unchecked Sendable` (mocks have mutable tracking properties — `@unchecked Sendable` is the standard pattern for all mocks in this project under Swift 6 strict concurrency). Place in `ios/Tests/Mocks/`.
- **Privacy manifest test**: load from `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")`. This works because `sprintyTests` is a hosted unit test bundle (`bundle.unit-test` with `target: sprinty` dependency) — during test execution, `Bundle.main` IS the app bundle. Do NOT use `Bundle.module` (SPM-only). This test doubles as a project.yml wiring verification — if the xcprivacy file is missing from Copy Bundle Resources, the URL will be `nil`.

**Test cases to cover:**
- `BackupPreferenceService.setExcludedFromBackup(true)` sets the flag on the main file
- `setExcludedFromBackup(true)` sets the flag on existing -wal and -shm sidecars
- `setExcludedFromBackup(true)` silently skips missing sidecars (no throw)
- `setExcludedFromBackup(false)` clears a previously-set flag
- `isExcludedFromBackup()` returns the current state from the main file
- Idempotent: calling twice with the same value is a no-op
- `SettingsViewModel.loadProfile()` populates `excludeFromICloudBackup` from `UserProfile`
- `updateExcludeFromICloudBackup(true)` optimistically updates local state
- `updateExcludeFromICloudBackup(true)` writes to `UserProfile` row
- `updateExcludeFromICloudBackup(true)` calls `backupPreferenceService.setExcludedFromBackup(true)`
- `updateExcludeFromICloudBackup` is a no-op safely when `backupPreferenceService == nil`
- Migration `v20_backupExclusionPreference` adds the column with default `false`
- Migration preserves existing `UserProfile` row data
- `PrivacyInfo.xcprivacy` loads from bundle
- Manifest declares `NSPrivacyTracking = false`
- Manifest declares empty `NSPrivacyCollectedDataTypes`
- Manifest declares `UserDefaults` Required Reason API with reason `CA92.1`

### Project Structure Notes

- New `Services/Backup/` folder introduced — follows the pattern of `Services/DataDeletion/`, `Services/Memory/`, etc. The iOS `Services/` tree is flat-by-concern; each service gets its own folder when it has both a protocol and an impl.
- Privacy manifest lives in `Resources/` per architecture.md:1354 (main app) and in the widget target root per standard iOS convention (widget extensions are small and don't typically have a `Resources/` subfolder).
- `xcodegen` is the source of truth for the Xcode project — `project.pbxproj` is regenerated. Do NOT hand-edit `project.pbxproj`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic-11-Story-11.4 — Story 11.4 acceptance criteria, lines 2032-2053]
- [Source: _bmad-output/planning-artifacts/epics.md#NFR36 — iCloud backup requirement, line 137]
- [Source: _bmad-output/planning-artifacts/architecture.md — Privacy Manifest architectural decision, lines 85, 1354, 1510]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR36 — "iOS standard backup/restore mechanisms... with a user-facing option to exclude", line 964]
- [Source: _bmad-output/planning-artifacts/prd.md#GDPR-Privacy — Apple Privacy Manifest requirement, line 405]
- [Source: _bmad-output/implementation-artifacts/11-3-data-deletion.md — Service pattern, SettingsView init pattern, test standards]
- [Source: _bmad-output/implementation-artifacts/10-5-usage-analytics-and-monitoring.md — confirmation that no iOS client analytics exist (Task 7.6 PII verification)]
- [Source: ios/sprinty/Services/Database/DatabaseManager.swift — App Group container URL + database filename construction]
- [Source: ios/sprinty/Core/Utilities/Constants.swift — `appGroupIdentifier`, `databaseFilename`]
- [Source: ios/sprinty/Services/Database/Migrations.swift — latest migration is `v19_sprintStepSyncStatus`; next is `v20_backupExclusionPreference`]
- [Source: ios/sprinty/Models/UserProfile.swift — struct layout + GRDB conformance pattern]
- [Source: ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift:114-135 — `updateNotificationsMuted` pattern to mirror]
- [Source: ios/sprinty/Features/Settings/Views/SettingsView.swift:122-156 — Privacy Section placement]
- [Source: ios/project.yml — xcodegen target config for `sprinty` + `sprinty_widgetExtension`]
- [Apple Docs: Describing data use in privacy manifests — https://developer.apple.com/documentation/bundleresources/privacy_manifest_files]
- [Apple Docs: Describing use of required reason API — https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api]
- [Apple Docs: URL.setResourceValues + isExcludedFromBackupKey — https://developer.apple.com/documentation/foundation/nsurl/1408346-isexcludedfrombackupkey]

## Dev Agent Record

### Agent Model Used

claude-opus-4-6 (Amelia / bmad-dev)

### Debug Log References

- xcodegen 2.45.3 silently dropped `PrivacyInfo.xcprivacy` when it was registered as an explicit `resources:` entry (with or without `type: file, buildPhase: resources`). Removing the explicit entries and letting xcodegen auto-scan via the existing `sources:` directory walk picked up both files correctly and placed them in `PBXResourcesBuildPhase`. Verified via `grep "PrivacyInfo.xcprivacy" project.pbxproj` (8 hits — file ref + build file ref × 2 targets) and `find ...Release-iphonesimulator -name PrivacyInfo.xcprivacy` (both `sprinty.app/PrivacyInfo.xcprivacy` and `sprinty_widgetExtension.appex/PrivacyInfo.xcprivacy` present in the Release product).
- The widget extension target compiles a shared copy of `DatabaseManager.swift`. After adding the launch-time backup-flag apply, the widget build failed with `cannot find 'BackupPreferenceService' in scope`. Resolved by adding `BackupPreferenceServiceProtocol.swift` and `BackupPreferenceService.swift` to the widget target's `sources:` list in `ios/project.yml` so both targets compile the same set.

### Completion Notes List

- **Privacy manifest (AC #1)**: `ios/sprinty/Resources/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking=false`, empty `NSPrivacyTrackingDomains` and `NSPrivacyCollectedDataTypes`, and a single Required Reason entry for `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (used by `SprintService` and `DataDeletionService`). A matching widget manifest at `ios/sprinty_widgetExtension/PrivacyInfo.xcprivacy` declares an empty `NSPrivacyAccessedAPITypes` array (widget has zero `UserDefaults`/`@AppStorage` usage). Both ship in their respective binaries — verified by inspecting the Release-iphonesimulator product.
- **iCloud backup default (AC #2)**: `UserProfile.excludeFromICloudBackup` defaults to `false` via `v20_backupExclusionPreference` migration → coaching data is included in iCloud device backup by default, satisfying NFR36.
- **Opt-out toggle (AC #2, #3)**: `BackupPreferenceService` flips `URLResourceValues.isExcludedFromBackup` on the SQLite main file plus the GRDB `-wal`/`-shm` sidecars (skipping any sidecar that doesn't yet exist). `SettingsViewModel.updateExcludeFromICloudBackup` mirrors `updateNotificationsMuted` exactly: optimistic local state, detached `Task` writes the new `UserProfile` value AND calls the file-flag service in a single `do/catch` with silent error swallow. `DatabaseManager.create()` re-applies the persisted preference on every launch (only when `true` to avoid no-op I/O), so newly-created `-wal`/`-shm` files inherit the flag.
- **Settings UI (AC #2)**: `SettingsView.swift` Privacy section now contains an `"Exclude from iCloud Backup"` toggle wired through the view model, with reassuring UX-DR34 subtitle copy and an `accessibilityHint`. The toggle is placed between the existing descriptive text and the Coaching Disclaimer link as specified.
- **Tests**: 18 new tests across `BackupPreferenceServiceTests` (7 — file flag round-trip, sidecar handling, idempotency, missing-sidecar tolerance), `SettingsViewModelBackupTests` (6 — load + 4 update paths + nil-service handling), `MigrationTests` (3 — v20 column existence + default + round-trip), and `PrivacyManifestTests` (5 — bundle load + 4 manifest assertions). `MockBackupPreferenceService` placed in `ios/Tests/Mocks/` matching the project mock convention. **All 852 project tests pass** under iPhone 17 Simulator, including all 18 new tests. Both Debug and Release configurations build clean.
- **xcodegen wiring**: `ios/project.yml` adds the two new service files to the widget target's source list (so the shared `DatabaseManager.swift` compiles in both targets) and lets the auto-scan pick up the two `.xcprivacy` files (no explicit `resources:` entry — see Debug Log References for the dropped-by-xcodegen issue).
- **Code review fixes (2026-04-11)**: Adversarial review surfaced an asymmetric reconcile bug — the launch-time apply-on-launch pass only ran when `excludeFromICloudBackup == true`, leaving the file flag stuck-on after a failed toggle-off or post-deletion re-onboarding (contradicting the Dev Notes "Interaction with Story 11.3"). Fixed by removing the `true`-only guard and always passing `profile.excludeFromICloudBackup` to `setExcludedFromBackup`. Switched the launch-time call to use `BackupPreferenceService.forAppGroupContainer()` for consistency with the Settings wiring path. `SettingsViewModel.updateExcludeFromICloudBackup` now returns `@discardableResult Task<Void, Never>` so tests can `await task.value` deterministically instead of relying on `Task.sleep(200ms)`. Sidecar URL construction switched from `mainURL.path + "-wal"` string concat to `parent.appendingPathComponent("\(baseName)-wal")`. `BackupPreferenceServiceTests` now `#expect`s the `FileManager.createFile` return value (fail-fast on test setup). `MockBackupPreferenceService` import order normalized (Foundation before `@testable`). `forAppGroupContainer()` doc comment + structured-logging placeholder added on the nil-container path. Reverted unrelated `server/main.go` gofmt drift that had snuck onto the branch. Story Tasks 1.6/2.3 wording updated to reflect the actual auto-scan approach (xcodegen 2.45.3 silently drops explicit `.xcprivacy` resource entries — already documented in Debug Log References).

### File List

**New files:**
- `ios/sprinty/Resources/PrivacyInfo.xcprivacy`
- `ios/sprinty_widgetExtension/PrivacyInfo.xcprivacy`
- `ios/sprinty/Services/Backup/BackupPreferenceServiceProtocol.swift`
- `ios/sprinty/Services/Backup/BackupPreferenceService.swift`
- `ios/Tests/Services/Backup/BackupPreferenceServiceTests.swift`
- `ios/Tests/Features/Settings/SettingsViewModelBackupTests.swift`
- `ios/Tests/Privacy/PrivacyManifestTests.swift`
- `ios/Tests/Mocks/MockBackupPreferenceService.swift`

**Modified files:**
- `ios/project.yml`
- `ios/sprinty.xcodeproj/project.pbxproj` (regenerated by xcodegen)
- `ios/sprinty/Models/UserProfile.swift`
- `ios/sprinty/Services/Database/Migrations.swift`
- `ios/sprinty/Services/Database/DatabaseManager.swift`
- `ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift`
- `ios/sprinty/Features/Settings/Views/SettingsView.swift`
- `ios/Tests/Database/MigrationTests.swift`

## Change Log

- 2026-04-11 — Story 11.4 implemented (Apple Privacy Manifest + iCloud backup exclusion). Added `PrivacyInfo.xcprivacy` for both app and widget targets, `v20_backupExclusionPreference` migration, `BackupPreferenceService` with WAL/SHM sidecar handling, launch-time apply in `DatabaseManager`, Settings → Privacy toggle, and 18 new tests. Status → review.
- 2026-04-11 — Code review fixes applied: `DatabaseManager.create()` now reconciles the backup flag in BOTH directions on every launch (was `true`-only, leaving stale state after toggle-off failures or post-deletion re-onboarding); `SettingsViewModel.updateExcludeFromICloudBackup` returns its in-flight `Task` so tests can await deterministically; sidecar URL construction switched to idiomatic `appendingPathComponent`; test setup `createFile` calls now fail-fast via `#expect`; `MockBackupPreferenceService` import order normalized; `forAppGroupContainer()` got a structured-logging placeholder + doc comment for the nil-container failure mode; reverted unrelated `server/main.go` gofmt drift; Tasks 1.6/2.3 wording updated to match the auto-scan approach. All 18 backup-related tests + 43 migration tests pass under iPhone 17 Simulator; full Debug build green.
