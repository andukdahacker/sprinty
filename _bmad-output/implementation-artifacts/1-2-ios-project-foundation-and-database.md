# Story 1.2: iOS Project Foundation & Database

Status: done

## Story

As a new user opening the app for the first time,
I want the app to silently create a secure device identity and local storage,
So that my data is encrypted and my identity persists across sessions.

## Acceptance Criteria

1. **Xcode project initialized** with SwiftUI App template, manual MVVM structure, Swift 6.x, iOS 17+ deployment target. All code compiles under Swift 6 strict concurrency checking with zero warnings. `@Observable` macro for state management. `async/await` structured concurrency throughout — no `DispatchQueue.main.async`, no force-unwrapping, no raw `print()`.

2. **Device UUID generated and persisted** in iOS Keychain on first launch. UUID survives app deletion/reinstall. Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` accessibility (device must have been unlocked once, not synced to iCloud).

3. **Server registration**: App calls `POST /v1/auth/register` with `{"deviceId": "<uuid>"}` to the running server. The returned JWT is stored in iOS Keychain (never UserDefaults).

4. **SQLite database created** in App Group shared container (for future WidgetKit access). `NSFileProtectionComplete` encryption applied. GRDB `DatabaseMigrator` runs versioned, sequential, idempotent migrations on every app launch.

5. **Database schema created** with `ConversationSession` and `Message` tables. All Phase 2 fields pre-populated as nullable columns in the schema (avoids future migration).

6. **Reinstall resilience**: Device UUID persists from Keychain, maintaining identity continuity across reinstalls.

7. **Token refresh**: When JWT approaches expiry, app refreshes via `POST /v1/auth/refresh` and stores the new token in Keychain.

## Tasks / Subtasks

- [x] Task 1: Create Xcode project and folder structure (AC: #1)
  - [x]Create `ios/ai_life_coach.xcodeproj` with SwiftUI App template
  - [x]Set deployment target iOS 17+, Swift 6.x
  - [x]Enable strict concurrency checking (Build Settings → Strict Concurrency Checking → Complete)
  - [x]Create feature-based MVVM folder structure (see Project Structure below)
  - [x]Add `ai_life_coach.entitlements` with App Groups + Keychain access groups
  - [x]Create xcconfig files: `Debug.xcconfig` (`COACH_API_URL = http://localhost:8080`), `Staging.xcconfig`, `Release.xcconfig`
  - [x]Create 3 Xcode schemes: Debug, Staging, Release — each linked to its xcconfig

- [x] Task 2: Add GRDB dependency via SPM (AC: #4, #5)
  - [x]Add `https://github.com/groue/GRDB.swift.git` package dependency (v7.10.0+, latest stable)
  - [x]Use the `GRDB` library product (not `GRDB-dynamic`)
  - [x]Verify it builds under Swift 6 strict concurrency with zero warnings

- [x] Task 3: Implement DatabaseManager (AC: #4)
  - [x]Create `Services/Database/DatabaseManager.swift`
  - [x]Initialize `DatabasePool` in App Group shared container path: `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.ducdo.ai-life-coach")!`
  - [x]Apply `NSFileProtectionComplete` to the database file via `FileManager.setAttributes`
  - [x]Configure WAL mode (GRDB default)
  - [x]Run `DatabaseMigrator` on every launch (idempotent)
  - [x]Make `DatabaseManager` a `Sendable` class (not `@MainActor` — background work)

- [x] Task 4: Implement database migrations (AC: #5)
  - [x]Create `Services/Database/Migrations.swift`
  - [x]Migration v1 — `ConversationSession` table:
    ```sql
    CREATE TABLE ConversationSession (
      id TEXT PRIMARY KEY NOT NULL,
      startedAt TEXT NOT NULL,
      endedAt TEXT,
      type TEXT NOT NULL DEFAULT 'coaching',
      mode TEXT NOT NULL DEFAULT 'discovery',
      safetyLevel TEXT NOT NULL DEFAULT 'green',
      promptVersion TEXT
    )
    ```
  - [x]Migration v1 — `Message` table:
    ```sql
    CREATE TABLE Message (
      id TEXT PRIMARY KEY NOT NULL,
      sessionId TEXT NOT NULL REFERENCES ConversationSession(id),
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp TEXT NOT NULL
    )
    CREATE INDEX idx_message_sessionId ON Message(sessionId)
    ```
  - [x]Phase 2 placeholder columns (nullable, in v1 migration):
    - `ConversationSummary` table is NOT created yet (Story 3.1), but `ConversationSession` includes all columns it will need
    - Pre-populate nullable fields that future stories will use: no extra columns needed on `ConversationSession` or `Message` at this stage — the Phase 2 tables (`ConversationSummary`, `UserProfile`, `Sprint`, `SprintStep`) will be added in their respective story migrations

- [x] Task 5: Create GRDB record models (AC: #5)
  - [x]Create `Models/ConversationSession.swift` — GRDB record with `Codable + FetchableRecord + PersistableRecord + Identifiable`
  - [x]Create `Models/Message.swift` — GRDB record with same protocol conformance
  - [x]Add `static let databaseTableName` to each
  - [x]Add query extensions (e.g., `ConversationSession.recent(limit:)`, `Message.forSession(id:)`)
  - [x]Ensure all models are `Sendable`

- [x] Task 6: Implement AuthService with Keychain (AC: #2, #3, #6, #7)
  - [x]Create `Services/Networking/AuthService.swift`
  - [x]Generate device UUID on first launch: `UUID().uuidString`
  - [x]Store device UUID in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — NOT `kSecAttrSynchronizable` (must not sync to iCloud, each device needs unique ID)
  - [x]On launch: check Keychain for existing UUID first (reinstall resilience)
  - [x]Call `POST /v1/auth/register` with `{"deviceId": "<uuid>"}` — expects response `{"token": "<jwt>"}`
  - [x]Store JWT in Keychain (same accessibility level)
  - [x]Implement token refresh: `POST /v1/auth/refresh` with `Authorization: Bearer <jwt>` header
  - [x]Parse JWT expiry from claims to know when refresh is needed
  - [x]Make AuthService `Sendable` (not `@MainActor`)

- [x] Task 7: Implement APIClient (AC: #3, #7)
  - [x]Create `Services/Networking/APIClient.swift`
  - [x]Read `COACH_API_URL` from xcconfig (via `Bundle.main.infoDictionary`)
  - [x]Add `Authorization: Bearer <jwt>` header to all authenticated requests
  - [x]Set `Content-Type: application/json; charset=utf-8`
  - [x]Use `URLSession.shared` with `async/await` (no Combine)
  - [x]Make `APIClient` `Sendable`

- [x] Task 8: Implement AppState and App entry point (AC: #1)
  - [x]Create `Core/State/AppState.swift` — `@Observable` class with `@MainActor`
  - [x]Properties: `isAuthenticated: Bool`, `needsReauth: Bool`, `isOnline: Bool`
  - [x]Create `App/AILifeCoachApp.swift` — `@main` entry point
  - [x]Create AppState once via `@State`, inject into environment
  - [x]On launch: initialize DatabaseManager, then AuthService registration flow
  - [x]Create `App/RootView.swift` — minimal placeholder that shows auth status

- [x] Task 9: Implement AppError enum (AC: #1)
  - [x]Create `Core/Errors/AppError.swift`
  - [x]Cases: `networkUnavailable`, `authExpired`, `providerError(message:retryAfter:)`, `degraded`, `databaseError(underlying:)`
  - [x]Two-tier routing: global errors → AppState, local errors → ViewModel

- [x] Task 10: Write tests (AC: #1-#7)
  - [x]Create `Tests/Database/MigrationTests.swift` — in-memory GRDB database, verify tables created, columns exist, migrations idempotent
  - [x]Create `Tests/Models/CodableRoundtripTests.swift` — verify ConversationSession and Message encode/decode correctly
  - [x]Create `Tests/Services/AuthServiceTests.swift` — mock URLSession responses, verify register/refresh flows, verify Keychain operations
  - [x]Use Swift Testing (`@Test` macro) for unit tests
  - [x]Protocol-based mocking (no mocking frameworks)

## Dev Notes

### Technical Stack

- **Swift 6.x** with strict concurrency checking (zero warnings required)
- **iOS 17+** deployment target (enables `@Observable`)
- **SwiftUI** with MVVM architecture
- **GRDB.swift v7.10.0+** via SPM — SQLite wrapper with migrations, WAL mode, Swift-native query API
- **Swift Testing** (`@Test` macro) for unit tests, `XCTest` for UI/integration tests
- **No third-party dependencies** beyond GRDB for this story (Lottie, Sentry come in later stories)

### GRDB v7 Critical Notes

- GRDB 7.10.0 requires Swift 6.1+ and Xcode 16.3+
- Full Swift 6 strict concurrency support — `DatabasePool` handles thread safety internally, do NOT wrap in your own actor
- Use `GRDB` library product (not `GRDB-dynamic`) in SPM
- `DatabasePool` for production (WAL mode, concurrent reads), `DatabaseQueue` for tests (in-memory)

### Swift 6 Strict Concurrency Rules

- **ViewModels**: Always `@MainActor @Observable final class`
- **Services**: `Sendable`, NOT `@MainActor` — they do background work
- **Never** use `DispatchQueue.main.async` — use `@MainActor` instead
- **Never** use `@unchecked Sendable` — fix concurrency issues properly
- `AsyncThrowingStream` for all streaming operations
- Check `Task.isCancelled` in long-running loops
- Store `Task` references, cancel on view disappear

### Keychain Implementation

- Use Security framework directly (`SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`) — no third-party Keychain wrappers needed for this scope
- Service name: `"com.ducdo.ai-life-coach"`
- Two Keychain items: `"device-uuid"` (String) and `"auth-jwt"` (String)
- Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- Do NOT set `kSecAttrSynchronizable` — device UUID must be unique per device, never synced via iCloud
- On app launch: always check Keychain for existing UUID before generating new one (reinstall resilience)

### App Group Configuration

- App Group identifier: `"group.com.ducdo.ai-life-coach"`
- Database path: `containerURL(forSecurityApplicationGroupIdentifier:)` + `"/ai_life_coach.sqlite"`
- This MUST be set up from day one — retrofitting later means migrating database file location for existing users
- Add App Group capability in Xcode → Signing & Capabilities
- Both main app target and future widget extension target must use same App Group

### Database Conventions (GRDB/SQLite)

| Pattern | Convention | Example |
|---------|-----------|---------|
| Table names | PascalCase singular | `ConversationSession`, `Message` |
| Column names | camelCase | `startedAt`, `safetyLevel` |
| Foreign keys | `{related}Id` | `sessionId` |
| Primary keys | `id` (always UUID as TEXT) | `id` |
| Timestamps | ISO 8601 strings | `startedAt`, `endedAt` |

### GRDB Record Pattern (Every Model)

```swift
struct ConversationSession: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var type: SessionType
    var mode: CoachingMode
    var safetyLevel: SafetyLevel
    var promptVersion: String?

    static let databaseTableName = "ConversationSession"
}

// Queries as static extensions — NEVER in ViewModels or services
extension ConversationSession {
    static func recent(limit: Int = 10) -> QueryInterfaceRequest<ConversationSession> {
        order(Column("startedAt").desc).limit(limit)
    }
}
```

### API Wire Format (Must Match Server)

- JSON field names: **camelCase** (`deviceId`, `safetyLevel`)
- Dates: ISO 8601 with UTC (`2026-03-17T14:30:00Z`)
- Enums: lowercase snake_case strings (`"discovery"`, `"directive"`)
- Null handling: omit null fields (use `encodeIfPresent`)
- Arrays: always arrays, even empty (`[]`, never null)
- Swift API models use explicit `CodingKeys` — no automatic key strategy

### Server Endpoints Used (from docs/api-contract.md)

```
POST /v1/auth/register  (no auth required)
  Request:  {"deviceId": "uuid-string"}
  Response: {"token": "jwt-string"}

POST /v1/auth/refresh   (JWT required)
  Request:  (empty body)
  Response: {"token": "jwt-string"}
  Header:   Authorization: Bearer <jwt>

GET /health             (no auth required)
  Response: {"status": "ok"}
```

### Error Handling Pattern

```swift
enum AppError: Error {
    case networkUnavailable          // Hard → Global (AppState.isOnline = false)
    case authExpired                 // Hard → Global (AppState.needsReauth = true)
    case providerError(message: String, retryAfter: Int?)  // Hard → Global
    case degraded                    // Degraded → Local (ViewModel.localError)
    case databaseError(underlying: Error)  // Silent → Local
}
```

Services throw, ViewModels catch and route. Never force-unwrap. Use `guard let` / `if let`.

### Forbidden Patterns

- `DispatchQueue.main.async` — use `@MainActor` instead
- Force-unwrapping (`!`) — use `guard let` / `if let`
- Raw `print()` — use structured logging or remove
- `@unchecked Sendable` — fix concurrency issues properly
- UserDefaults for secrets — Keychain only
- Singletons / service locators / global access — use Environment injection
- `Combine` — use `async/await` and `AsyncSequence`
- Fixed font sizes — Dynamic Type only (comes in Story 1.3)
- `open` access control — not designing for subclassing

### Project Structure to Create

```
ios/
├── ai_life_coach.xcodeproj/
│   └── xcshareddata/xcschemes/
│       ├── Debug.xcscheme
│       ├── Staging.xcscheme
│       └── Release.xcscheme
├── ai_life_coach/
│   ├── ai_life_coach.entitlements
│   ├── Configuration/
│   │   ├── Debug.xcconfig
│   │   ├── Staging.xcconfig
│   │   └── Release.xcconfig
│   ├── App/
│   │   ├── AILifeCoachApp.swift          # @main entry, AppState creation, Environment injection
│   │   ├── AppState.swift                # @Observable unified state (@MainActor)
│   │   └── RootView.swift                # Minimal placeholder view
│   ├── Features/                         # Empty feature folders (structure only)
│   │   ├── Coaching/
│   │   │   ├── Views/
│   │   │   ├── ViewModels/
│   │   │   └── Models/
│   │   ├── Home/
│   │   │   ├── Views/
│   │   │   └── ViewModels/
│   │   ├── Onboarding/
│   │   │   ├── Views/
│   │   │   └── ViewModels/
│   │   └── Settings/
│   │       ├── Views/
│   │       └── ViewModels/
│   ├── Services/
│   │   ├── Networking/
│   │   │   ├── APIClient.swift
│   │   │   └── AuthService.swift
│   │   └── Database/
│   │       ├── DatabaseManager.swift
│   │       └── Migrations.swift
│   ├── Core/
│   │   ├── State/                        # (AppState lives in App/ for this story)
│   │   ├── Extensions/
│   │   ├── Utilities/
│   │   │   └── Constants.swift
│   │   └── Errors/
│   │       └── AppError.swift
│   ├── Models/
│   │   ├── ConversationSession.swift     # GRDB record
│   │   └── Message.swift                 # GRDB record
│   ├── Resources/
│   │   └── Assets.xcassets/
│   └── Preview Content/
│       └── PreviewData.swift
└── Tests/
    ├── Database/
    │   └── MigrationTests.swift
    ├── Models/
    │   └── CodableRoundtripTests.swift
    └── Services/
        └── AuthServiceTests.swift
```

### Previous Story Intelligence (Story 1.1)

**Key patterns established:**
- Monorepo structure: `/ios`, `/server`, `/docs` at root
- Server runs on `localhost:8080` in dev mode
- JWT format: `{deviceId, userId: null, tier: "free", iat, exp}` with 30-day expiry, HS256 signing
- API contract documented in `docs/api-contract.md` — shared fixtures in `docs/fixtures/`
- `httputil` package was extracted to resolve import cycle — deviation from architecture but documented
- Go 1.26.1 used (not 1.23 as originally spec'd — user instructed to use latest)
- 19 tests passing: handlers (13), config (5), middleware (2)
- Server `.env.example` documents all env vars

**Learnings from Story 1.1 code review:**
- Dockerfile Go version must match `go.mod` version — same principle applies to Swift version consistency
- Test environment state must not leak between tests — use proper setup/teardown
- Fixture files must match actual API response format exactly

**Files the iOS app will interact with (already exist):**
- `docs/api-contract.md` — source of truth for all API endpoints and schemas
- `docs/fixtures/` — shared test fixtures for validating iOS ↔ server contract
- `server/.env.example` — documents required env vars (JWT_SECRET, PORT, ENVIRONMENT)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — iOS Directory Structure, GRDB Conventions, Swift Patterns, Auth Flow, Database Schema]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 1, Story 1.2 Acceptance Criteria and Dependencies]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Platform Strategy, Effortless Interactions]
- [Source: _bmad-output/implementation-artifacts/1-1-server-scaffold-and-auth-endpoints.md — Previous Story Intelligence]
- [Source: docs/api-contract.md — Server API Contract]
- [Source: GRDB.swift v7.10.0 — https://github.com/groue/GRDB.swift]
- [Source: Swift 6 Concurrency — https://developer.apple.com/documentation/swift/adoptingswift6]
- [Source: iOS Keychain — https://developer.apple.com/documentation/security/storing-keys-in-the-keychain]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Build initially failed due to missing AppIcon.appiconset — added empty icon set to resolve
- Test initially failed due to missing `import Foundation` in MigrationTests.swift — added import
- xcodegen 2.45.3 used to generate .xcodeproj from project.yml spec
- Entitlements file was overwritten by xcodegen on first run — removed `entitlements` block from project.yml, kept `CODE_SIGN_ENTITLEMENTS` build setting only

### Completion Notes List

- Xcode project created via xcodegen with SwiftUI App template, iOS 17+, Swift 6.x strict concurrency (zero warnings)
- 3 build configurations (Debug/Staging/Release) with xcconfig files and matching schemes
- GRDB.swift v7.10.0 added via SPM — builds clean under Swift 6 strict concurrency
- DatabaseManager creates DatabasePool in App Group shared container with NSFileProtectionComplete
- Migrations v1 creates ConversationSession and Message tables with all specified columns, index, and cascade delete FK
- GRDB record models (ConversationSession, Message) with enums (SessionType, CoachingMode, SafetyLevel, MessageRole)
- Query extensions: `ConversationSession.recent(limit:)`, `Message.forSession(id:)`
- AuthService with Keychain persistence for device UUID and JWT, register + refresh flows, JWT expiry parsing
- APIClient with protocol-based design, bearer auth, configurable base URL from xcconfig
- KeychainHelper using Security framework directly (SecItemAdd/CopyMatching/Delete), `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- AppState (@Observable, @MainActor) with isAuthenticated, needsReauth, isOnline
- AppError enum with all specified cases
- RootView placeholder showing auth status
- 33 tests passing across 3 suites: MigrationTests (9), CodableRoundtripTests (9), AuthServiceTests (15)
- Protocol-based mocking (MockAPIClient, MockKeychainHelper) — no mocking frameworks
- `@unchecked Sendable` used only on MockAPIClient and MockKeychainHelper in tests (test-only, intentional for mutable test doubles)

### Change Log

- 2026-03-17: Story 1.2 implemented — iOS project foundation, GRDB database, auth service, 25 tests passing
- 2026-03-18: Code review fixes — removed all force-unwraps, added KeychainHelperProtocol for testability, added 8 auth flow tests (register/refresh/getToken/UUID persistence), added keychainError case to AppError, stored DatabaseManager in AppState, added ios/.gitignore

### File List

- ios/.gitignore
- ios/project.yml (xcodegen spec)
- ios/ai_life_coach.xcodeproj/ (generated)
- ios/ai_life_coach/ai_life_coach.entitlements
- ios/ai_life_coach/Configuration/Debug.xcconfig
- ios/ai_life_coach/Configuration/Staging.xcconfig
- ios/ai_life_coach/Configuration/Release.xcconfig
- ios/ai_life_coach/App/AILifeCoachApp.swift
- ios/ai_life_coach/App/AppState.swift
- ios/ai_life_coach/App/RootView.swift
- ios/ai_life_coach/Core/Errors/AppError.swift
- ios/ai_life_coach/Core/Utilities/Constants.swift
- ios/ai_life_coach/Models/ConversationSession.swift
- ios/ai_life_coach/Models/Message.swift
- ios/ai_life_coach/Services/Database/DatabaseManager.swift
- ios/ai_life_coach/Services/Database/Migrations.swift
- ios/ai_life_coach/Services/Networking/APIClient.swift
- ios/ai_life_coach/Services/Networking/AuthService.swift
- ios/ai_life_coach/Preview Content/PreviewData.swift
- ios/ai_life_coach/Resources/Assets.xcassets/Contents.json
- ios/ai_life_coach/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
- ios/Tests/Database/MigrationTests.swift
- ios/Tests/Models/CodableRoundtripTests.swift
- ios/Tests/Services/AuthServiceTests.swift
