# Story 6.4: Compliance Logging

Status: done

## Story

As a system operator,
I want all safety boundary events logged for compliance review,
so that there's an auditable record of how the system responded to safety situations.

## Acceptance Criteria

1. **Given** a safety classification of Yellow, Orange, or Red occurs **When** the event is processed **Then** a compliance log entry is created with: timestamp, safety level, event type, and metadata **And** the log is append-only (cannot be modified or deleted per NFR15) **And** NO conversation content is stored — only event metadata

2. **Given** compliance logs **When** reviewed for audit **Then** they provide a complete timeline of all boundary response events **And** each entry includes sufficient metadata to understand the system's response

## Tasks / Subtasks

- [x] Task 1: iOS — SafetyComplianceLog GRDB model and migration (AC: #1)
  - [x] 1.1 Create `SafetyComplianceLog` GRDB record type in `ios/sprinty/Models/SafetyComplianceLog.swift`
  - [x] 1.2 Add v13 migration in `Migrations.swift` creating the `SafetyComplianceLog` table
  - [x] 1.3 Write migration tests for v13

- [x] Task 2: iOS — ComplianceLogger service (AC: #1, #2)
  - [x] 2.1 Create `ComplianceLoggerProtocol` in `ios/sprinty/Services/Safety/ComplianceLoggerProtocol.swift`
  - [x] 2.2 Create `ComplianceLogger` in `ios/sprinty/Services/Safety/ComplianceLogger.swift`
  - [x] 2.3 Write unit tests for ComplianceLogger

- [x] Task 3: iOS — Integrate compliance logging into CoachingViewModel (AC: #1)
  - [x] 3.1 Add `complianceLogger: ComplianceLoggerProtocol` init parameter to `CoachingViewModel` (with default `ComplianceLogger(databaseManager:)`)
  - [x] 3.2 Update `RootView.swift:ensureCoachingViewModel()` to create and inject `ComplianceLogger(databaseManager: databaseManager)`
  - [x] 3.3 Call `complianceLogger.logSafetyBoundary(...)` in the done-event handler when `processedLevel >= .yellow`
  - [x] 3.4 Create `MockComplianceLogger` in `ios/Tests/Mocks/` following established mock pattern (`@unchecked Sendable`, call count tracking, last-parameter capture)
  - [x] 3.5 Add integration tests verifying logging is called on Yellow/Orange/Red and NOT on Green

- [x] Task 4: Server — Structured compliance logging (AC: #1, #2)
  - [x] 4.1 Add compliance log call in `ChatHandler` when `event.SafetyLevel` is non-green
  - [x] 4.2 Log with slog.Info using "compliance.safety_boundary" event name
  - [x] 4.3 Add test in `handlers_test.go` that configures MockProvider with non-green safetyLevel and verifies the done event streams correctly (slog output verified via code review, not httptest assertions)

- [x] Task 5: iOS — Compliance log query for audit review (AC: #2)
  - [x] 5.1 Add static query methods on `SafetyComplianceLog` for timeline retrieval
  - [x] 5.2 Write query tests

- [x] Task 6: Verify append-only enforcement (AC: #1)
  - [x] 6.1 Ensure `SafetyComplianceLog` uses `PersistableRecord` (not `MutablePersistableRecord`) and that NO call site in the codebase invokes `update()` or `delete()` on this type
  - [x] 6.2 Write test that inserts a compliance log and verifies it can be read back — append-only is enforced by application convention (no update/delete call sites), not type-system restriction

## Dev Notes

### Architecture Patterns & Constraints

- **Append-only enforcement (NFR15):** `SafetyComplianceLog` conforms to `Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable` (matching all existing GRDB models). Note: `PersistableRecord` still exposes `update()` and `delete()` at the protocol level — append-only is enforced by **application convention**: the `ComplianceLogger` only calls `insert()`, and no other code should call `update()`/`delete()` on this type. Verify during code review.
- **No conversation content:** Log entries store ONLY event metadata — timestamp, safety level, classification source, session ID. Never store message text, user input, or coaching responses.
- **Fire-and-forget pattern:** Compliance logging must NOT block safety UI processing. Use the same `Task { try? await ... }` pattern established in Story 6.3 for writing `lastSafetyBoundaryAt`.
- **Server is stateless:** Server-side compliance logging goes through `slog` structured logging to stdout. Railway captures stdout as persistent logs. No database writes server-side.
- **Safety is tier-agnostic (FR58):** Compliance logging applies identically to free and paid users.
- **Log ALL non-green levels:** Yellow, Orange, AND Red — not just Orange/Red. The epic specifies "Yellow, Orange, or Red" in AC#1.

### Key Existing Code to Reuse

- **`SafetyLevel` enum** (`ios/sprinty/Models/ConversationSession.swift`): Has `Comparable` conformance — use `processedLevel >= .yellow` to determine if logging is needed
- **`SafetyClassificationSource`** (`ios/sprinty/Services/Safety/SafetyClassificationSource.swift`): `.genuine` vs `.failsafe` — log both, but include source in metadata
- **`CoachingViewModel` done-event handler** (line ~262-296): This is where `processedLevel` is computed and where compliance logging hooks in — after `safetyStateManager.processClassification()` and `safetyHandler.uiState()`
- **GRDB record pattern**: All models use `Codable + FetchableRecord + PersistableRecord + Identifiable + Sendable`. Static query extensions on the model type returning `QueryInterfaceRequest<Self>`.
- **Database migrations** (`ios/sprinty/Services/Database/Migrations.swift`): Current latest is `v12_safetyBoundary`. Next migration is `v13_complianceLog`.
- **`DatabaseManager.shared.dbPool`**: Async write via `dbManager.dbPool.write { db in ... }`
- **`LogFields` / `LoggingMiddleware`** (`server/middleware/logging.go`): Existing structured logging context. Compliance logging can use the same `LogFieldsFromContext` for deviceId.
- **`middleware.ClaimsFromContext`** (`server/middleware/auth.go`): Extracts JWT claims including `DeviceID` and `Tier` — use for server-side compliance log context.

### iOS SafetyComplianceLog Model Design

```swift
struct SafetyComplianceLog: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var sessionId: UUID
    var timestamp: Date
    var safetyLevel: SafetyLevel       // yellow, orange, or red
    var classificationSource: String   // "genuine" or "failsafe"
    var eventType: String              // "boundary_detected"
    var previousLevel: String?         // for de-escalation tracking

    static let databaseTableName = "SafetyComplianceLog"
}

// Query extensions for audit timeline (Task 5)
extension SafetyComplianceLog {
    static func timeline(limit: Int = 100) -> QueryInterfaceRequest<SafetyComplianceLog> {
        order(Column("timestamp").desc).limit(limit)
    }
    static func forSession(id: UUID) -> QueryInterfaceRequest<SafetyComplianceLog> {
        filter(Column("sessionId") == id).order(Column("timestamp").asc)
    }
    static func forLevel(_ level: SafetyLevel) -> QueryInterfaceRequest<SafetyComplianceLog> {
        filter(Column("safetyLevel") == level.rawValue).order(Column("timestamp").desc)
    }
}
```

**Migration v13 (table + indexes):**
```swift
migrator.registerMigration("v13_complianceLog") { db in
    try db.create(table: "SafetyComplianceLog") { t in
        t.column("id", .text).primaryKey().notNull()
        t.column("sessionId", .text).notNull()
        t.column("timestamp", .text).notNull()
        t.column("safetyLevel", .text).notNull()
        t.column("classificationSource", .text).notNull()
        t.column("eventType", .text).notNull()
        t.column("previousLevel", .text)
    }
    try db.create(index: "idx_complianceLog_timestamp", on: "SafetyComplianceLog", columns: ["timestamp"])
    try db.create(index: "idx_complianceLog_safetyLevel", on: "SafetyComplianceLog", columns: ["safetyLevel"])
}
```

### Server-Side Compliance Logging Pattern

In `ChatHandler`, after the `done` event is marshaled, add compliance logging:

```go
case "done":
    // ... existing done payload marshaling ...

    // Compliance logging: non-green safety levels
    if event.SafetyLevel != "green" && event.SafetyLevel != "" {
        deviceID := ""
        tier := ""
        if claims, ok := middleware.ClaimsFromContext(r.Context()); ok {
            deviceID = claims.DeviceID
            tier = claims.Tier
        }
        slog.Info("compliance.safety_boundary",
            "safetyLevel", event.SafetyLevel,
            "deviceId", deviceID,
            "tier", tier,
            "mode", req.Mode,
        )
    }
```

**Key:** Do NOT log any message content, conversation text, or user input. Only event metadata.

**Server test approach:** Existing handler tests use `httptest` and verify SSE event data — they cannot assert on `slog` output directly. For Task 4.3, configure `MockProvider` to return a done event with a non-green `SafetyLevel` (e.g., `"yellow"`), verify the SSE stream includes the correct safety level in the done event. The slog compliance output is verified through code review and structured log inspection in Railway, not httptest assertions.

### ComplianceLogger Design

```swift
// Protocol — Sendable for safe use from Task closures
protocol ComplianceLoggerProtocol: Sendable {
    func logSafetyBoundary(
        sessionId: UUID,
        level: SafetyLevel,
        source: SafetyClassificationSource,
        previousLevel: SafetyLevel?
    ) async
}

// Implementation — takes DatabaseManager as init dependency (matches ProfileUpdateService pattern)
final class ComplianceLogger: ComplianceLoggerProtocol {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func logSafetyBoundary(sessionId: UUID, level: SafetyLevel, source: SafetyClassificationSource, previousLevel: SafetyLevel?) async {
        let entry = SafetyComplianceLog(
            id: UUID(), sessionId: sessionId, timestamp: Date(),
            safetyLevel: level, classificationSource: source.rawValue,
            eventType: "boundary_detected", previousLevel: previousLevel?.rawValue
        )
        try? await databaseManager.dbPool.write { db in
            try entry.insert(db)
        }
    }
}
```

**Note:** `SafetyClassificationSource` needs a `rawValue` — currently has none (bare enum). Either add `: String` raw value conformance to the existing enum, or use a string literal mapping in ComplianceLogger. Prefer adding `String` raw value to the existing enum since it's a minimal, backward-compatible change.

### MockComplianceLogger Pattern

Follow the established mock pattern from `MockSafetyHandler` and `MockSafetyStateManager`:

```swift
final class MockComplianceLogger: ComplianceLoggerProtocol, @unchecked Sendable {
    var logCallCount = 0
    var lastSessionId: UUID?
    var lastLevel: SafetyLevel?
    var lastSource: SafetyClassificationSource?
    var lastPreviousLevel: SafetyLevel?

    func logSafetyBoundary(sessionId: UUID, level: SafetyLevel, source: SafetyClassificationSource, previousLevel: SafetyLevel?) async {
        logCallCount += 1
        lastSessionId = sessionId
        lastLevel = level
        lastSource = source
        lastPreviousLevel = previousLevel
    }
}
```

### Integration Point in CoachingViewModel

**Init parameter addition** (follows `safetyHandler`/`safetyStateManager` pattern):
```swift
init(..., complianceLogger: ComplianceLoggerProtocol = ComplianceLogger(databaseManager: DatabaseManager.shared)) {
```

**RootView.swift update** — in `ensureCoachingViewModel(databaseManager:)` (lines 175-192), add:
```swift
let complianceLogger = ComplianceLogger(databaseManager: databaseManager)
coachingViewModel = CoachingViewModel(
    // ... existing params ...
    complianceLogger: complianceLogger
)
```

**Done-event handler** (around line 265-270), AFTER `processedLevel` is computed and BEFORE the existing `processedLevel >= .orange` boundary persistence block:

```swift
// Compliance logging for all non-green safety levels
if processedLevel >= .yellow {
    let prevLevel = self.previousSafetyLevel
    Task {
        await self.complianceLogger.logSafetyBoundary(
            sessionId: self.currentSession?.id ?? UUID(),
            level: processedLevel,
            source: source,
            previousLevel: prevLevel
        )
    }
    self.previousSafetyLevel = processedLevel
}
```

Add a `previousSafetyLevel: SafetyLevel?` property to track transitions. Add `private let complianceLogger: ComplianceLoggerProtocol` to stored properties.

### Critical Gotchas from Previous Stories

- **`SafetyStateManagerProtocol` is `@MainActor`**, not `Sendable` — compliance logger should be `Sendable` since it only does DB writes
- **Never use Combine** — use `@Observable` + async/await
- **Swift Testing framework** (`@Test`, `#expect`, `@Suite`) — NOT XCTest
- **Regenerate `project.pbxproj`** via xcodegen after adding new files
- **Fire-and-forget DB writes** — compliance logging MUST NOT block the done-event processing flow
- **`slog` on server** — structured JSON output, use consistent field names (`safetyLevel`, `deviceId`, `tier`, `mode`)

### Project Structure Notes

**iOS new files:**
- `ios/sprinty/Models/SafetyComplianceLog.swift` — GRDB record (shared model, used by multiple features)
- `ios/sprinty/Services/Safety/ComplianceLogger.swift` — Implementation
- `ios/sprinty/Services/Safety/ComplianceLoggerProtocol.swift` — Protocol
- `ios/Tests/Database/MigrationTests.swift` — Add v13 migration tests (extend existing)
- `ios/Tests/Services/Safety/ComplianceLoggerTests.swift` — New test file
- `ios/Tests/Mocks/MockComplianceLogger.swift` — Mock for CoachingViewModel tests

**iOS modified files:**
- `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` — Add `complianceLogger` dependency + done-event logging call + `previousSafetyLevel` property
- `ios/sprinty/App/RootView.swift` — Create and inject `ComplianceLogger` in `ensureCoachingViewModel()`
- `ios/sprinty/Services/Database/Migrations.swift` — Add v13_complianceLog migration
- `ios/sprinty/Services/Safety/SafetyClassificationSource.swift` — Add `: String` raw value conformance
- `ios/Tests/Database/MigrationTests.swift` — Add v13 migration tests

**Server modified files:**
- `server/handlers/chat.go` — Add compliance slog.Info call in done event handler
- `server/tests/handlers_test.go` — Add non-green safety level SSE verification test

**Alignment:** All paths follow the established project structure. Models in root `Models/` (GRDB record shared across features), services in `Services/Safety/` (alongside existing safety services), tests mirror source structure.

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 6.4 Compliance Logging]
- [Source: _bmad-output/planning-artifacts/architecture.md — Logging Standards Table, Compliance Infrastructure]
- [Source: _bmad-output/planning-artifacts/prd.md — NFR15 append-only compliance logging]
- [Source: _bmad-output/planning-artifacts/prd.md — FR58 safety tier-agnostic]
- [Source: _bmad-output/planning-artifacts/architecture.md — GRDB Record Type Pattern]
- [Source: _bmad-output/planning-artifacts/architecture.md — Server middleware/logging.go pattern]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — done event handler lines 228-296]
- [Source: ios/sprinty/Services/Database/Migrations.swift — v12_safetyBoundary is latest migration]
- [Source: server/handlers/chat.go — ChatHandler done event lines 105-127]
- [Source: 6-3-post-crisis-re-engagement.md — fire-and-forget DB write pattern, crisis detection patterns]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- All 45 iOS tests passed (MigrationTests, ComplianceLoggerTests, ComplianceLoggingIntegrationTests)
- All Go server tests passed (including new TestNonGreenSafetyLevelInDoneEvent)

### Completion Notes List
- Task 1: Created SafetyComplianceLog GRDB model with 7 columns, v13 migration with timestamp and safetyLevel indexes. 5 migration tests added.
- Task 2: Created ComplianceLoggerProtocol (Sendable) and ComplianceLogger service using fire-and-forget DB write pattern. Added String raw value to SafetyClassificationSource enum. 4 unit tests.
- Task 3: Integrated ComplianceLogger into CoachingViewModel with optional init parameter (auto-constructs from databaseManager). Added compliance logging in done-event handler for processedLevel >= .yellow with previousSafetyLevel tracking. Created MockComplianceLogger. 5 integration tests (yellow, orange, red trigger; green does NOT trigger; failsafe source captured).
- Task 4: Added slog.Info("compliance.safety_boundary") in ChatHandler done event for non-green safety levels. Added StubbedSafetyLevel to MockProvider. 1 integration test verifying SSE stream with non-green safety level.
- Task 5: Added 3 static query methods (timeline, forSession, forLevel) on SafetyComplianceLog. 3 query tests.
- Task 6: Verified PersistableRecord conformance (not MutablePersistableRecord), confirmed zero update/delete call sites via codebase grep. 1 append-only round-trip test.

### Change Log
- Story 6.4 implementation complete — compliance logging for safety boundary events (Date: 2026-03-27)
- Code review fixes: reset previousSafetyLevel on new session; capture locals in compliance logging Task to avoid strong self-capture; corrected File List paths (Date: 2026-03-28)

### File List
**New files:**
- ios/sprinty/Models/SafetyComplianceLog.swift
- ios/sprinty/Services/Safety/ComplianceLoggerProtocol.swift
- ios/sprinty/Services/Safety/ComplianceLogger.swift
- ios/Tests/Services/Safety/ComplianceLoggerTests.swift
- ios/Tests/Mocks/MockComplianceLogger.swift
- ios/Tests/Features/ComplianceLoggingIntegrationTests.swift

**Modified files:**
- ios/sprinty/Services/Database/Migrations.swift (v13_complianceLog migration)
- ios/sprinty/Services/Safety/SafetyClassificationSource.swift (added String raw value)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (complianceLogger + previousSafetyLevel + done-event logging)
- ios/sprinty/App/RootView.swift (inject ComplianceLogger)
- ios/Tests/Database/MigrationTests.swift (v13 + query + append-only tests)
- server/handlers/chat.go (compliance slog.Info in done event)
- server/providers/mock.go (StubbedSafetyLevel field)
- server/tests/handlers_test.go (TestNonGreenSafetyLevelInDoneEvent + setupMuxWithProvider)
- ios/sprinty.xcodeproj/project.pbxproj (regenerated via xcodegen)
- _bmad-output/implementation-artifacts/sprint-status.yaml (story status update)
