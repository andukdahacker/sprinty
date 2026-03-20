---
project_name: 'sprinty'
user_name: 'Ducdo'
date: '2026-03-20'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'code_quality', 'workflow_rules', 'critical_rules']
status: 'complete'
rule_count: 127
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

### iOS
- **Language:** Swift 5.9+ with StrictConcurrency enabled
- **UI:** SwiftUI only (no UIKit)
- **Minimum target:** iOS 17
- **Project generation:** XcodeGen — `ios/project.yml` is source of truth. `.xcodeproj` is generated. NEVER edit `project.pbxproj` directly; modify `project.yml` and run `xcodegen generate`
- **Database:** GRDB (SQLite ORM) — models conform to `FetchableRecord, PersistableRecord, Identifiable, Sendable` (all four required)
- **Vector search:** SQLiteVecKit — local SPM package at `ios/Packages/SQLiteVecKit/`, NOT a registry dependency
- **Reactivity:** Observation framework (`@Observable`, `@Bindable`) — NEVER Combine (`ObservableObject`, `@ObservedObject`, `@Published`)
- **Concurrency:** async/await, `AsyncThrowingStream` — NEVER Combine publishers. `@MainActor` on entire ViewModel class, not individual methods
- **Testing:** Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect()`) — NEVER XCTest (`XCTestCase`, `XCTAssertEqual`)
- **DI:** Protocol-based injection. All services created in `RootView.swift` (DI container). ViewModels accept protocols, never concrete types
- **Mocks:** Live in `ios/Tests/Mocks/`, must be `@unchecked Sendable`

### Server
- **Language:** Go 1.26.1
- **HTTP:** `net/http` stdlib with Go 1.22+ pattern routing — method prefix required: `mux.HandleFunc("POST /v1/chat", ...)`. NO third-party router
- **LLM SDK:** `anthropic-sdk-go` v1.27.0 — uses **tool-use for structured output** (forces `respond` tool schema), NOT free-text parsing
- **Auth:** `golang-jwt/jwt` v5.3.0 (30-day JWT expiry)
- **JSON:** `tidwall/gjson` v1.18.0 for partial JSON extraction during streaming
- **Model:** Claude Haiku 4.5 (`anthropic.ModelClaudeHaiku4_5`)
- **Testing:** `httptest.Server` for handler tests. Integration tests in separate `server/tests/` package

### Wire Format (Cross-Platform)
- Field names: **camelCase** JSON throughout
- Enums: lowercase snake_case
- Optional fields: `omitempty` — omit null fields
- Arrays: always `[]`, never null
- Booleans: never 0/1

### Infrastructure
- **Monorepo:** `ios/` (Xcode project) + `server/` (Go module)
- **Backend hosting:** Railway (watches `server/` subdirectory)
- **API contract:** `docs/api-contract.md` is single source of truth

## Critical Implementation Rules

### Language-Specific Rules

#### Swift
- All ViewModels: `@MainActor @Observable final class` — never omit any of these decorators
- All ViewModels must include `#if DEBUG` static preview factory — creates temp test DB, wires mock services, returns configured ViewModel. Previews must never hit the network or use real services
- All models must be `Sendable` — use `@unchecked Sendable` only for mocks with mutable test state
- Use `Task { [weak self] in ... }` in ViewModels to prevent retain cycles
- Check `Task.isCancelled` before state mutations in async operations
- `AsyncThrowingStream` must handle `onTermination` for cleanup — forgetting this leaks URLSession tasks
- Error handling: cast to `AppError` enum — route `authExpired` → `appState.needsReauth`, `networkUnavailable` → `appState.isOnline = false`, provider errors → `localError`
- GRDB async access: `dbPool.read { db in }` and `dbPool.write { db in }` — never synchronous
- Database migrations are append-only and sequential (v1, v2, v3...). NEVER modify an existing migration — existing users' databases have already run it
- Configuration from Bundle: API URLs from `Info.plist` via `Bundle.main.infoDictionary`, fallback to localhost

#### Go
- Handlers are higher-order functions returning `http.HandlerFunc` — dependencies injected via closure, not globals
- POST handlers must decompress gzip/deflate request bodies — iOS SDK sends compressed bodies. Missing this causes silent malformed JSON errors
- Context-based data flow: typed context keys (`type contextKey string`), helper functions for retrieval (`ClaimsFromContext()`)
- Structured logging via `slog` — never `fmt.Println` or `log.Println`
- Early stream error detection: call `stream.Next()` once before starting goroutine to catch immediate provider errors (429, 500)
- Provider errors translated to warm user-facing messages — never expose raw error strings
- Prompt template variables must be added to BOTH the markdown section AND `Build()` method's replacement block — miss one side and literal `{{variable}}` gets sent to Claude
- Graceful shutdown with `signal.NotifyContext` and `srv.Shutdown` with 30s timeout

#### Cross-Platform
- Error taxonomy: every error must classify as `recoverable`, `degraded-mode`, `hard`, or `silent` per API contract

### Framework-Specific Rules

#### SwiftUI
- Feature-first folder structure: `Features/{FeatureName}/ViewModels/`, `Features/{FeatureName}/Views/`, `Features/{FeatureName}/Models/`
- Shared models in top-level `Models/`, shared services in `Services/`
- Views bind to ViewModels via `@Bindable var viewModel: SomeViewModel`
- `AppState` is the global dependency — injected via `.environment(appState)`, holds auth status, network status, onboarding state, DatabaseManager
- `CoachingTheme` passed via environment key (`.environment(\.coachingTheme, theme)`) — context-aware theming for `.home` vs `.conversation`, safety-level and mode-aware. UI colors must go through theme system, never hardcode
- `CoachingMode` is mutable per-response — session mode updates when LLM returns a different mode in `done` event. Not fixed per-session
- Navigation: `RootView.swift` handles top-level routing based on `AppState` (onboarding vs main app)
- Animations: respect `@Environment(\.accessibilityReduceMotion)` — always provide static fallbacks
- Database stored in App Group container with `.complete` file protection (encrypted at rest). New file storage must use same App Group and protection level
- Services use `fromConfiguration()` factory pattern — never hardcode URLs. Always use factory or accept via protocol injection
- SwiftUI previews: provide Light and Dark variants minimum. Use `#if DEBUG` preview factories on ViewModels

#### Go net/http
- Route registration in `main.go` — public routes directly on mux, protected routes wrapped with `authMW()`
- New endpoints must be registered in BOTH `main.go` AND `setupMux()` in `tests/handlers_test.go` — or integration tests won't cover them
- Middleware pattern: `func AuthMiddleware(secret string) func(http.Handler) http.Handler` — returns handler wrapper
- Logging middleware is outermost wrapper, creates mutable `LogFields` in context that inner middleware populates
- SSE streaming: set `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`, cast to `http.Flusher`, flush after each event. Format is contractual — `event: token\ndata: {"text": "..."}\n\n` with double newline terminator. One deviation and iOS `SSEParser` silently drops events
- Error responses must go through `httputil.WriteError()` — never `http.Error()` or manual `w.Write()`. Ensures error taxonomy JSON structure is consistent
- Response helpers in `httputil/response.go` — `WriteJSON()` and `WriteError()` for consistent format
- Handler helpers in `handlers/helpers.go` — NOT a generic `utils` package

#### Prompt System
- 10 independent markdown sections in `server/prompts/sections/`
- Assembly order is load-bearing: base-persona → mode-specific (discovery OR directive) → safety, mood, tagging, cultural, transitions, challenger → context-injection (ALWAYS last — contains memory/profile placeholders)
- Content hash (`sha256`, first 8 bytes) used for prompt versioning
- User state injection via `strings.ReplaceAll` template substitution at request time

### Testing Rules

#### General
- All tests must pass before story/task completion — non-negotiable. Every task/subtask covered by unit tests before marking complete
- Test both success AND error paths minimum — success, auth failure, and domain-specific error

#### Swift (Swift Testing Framework)
- Test files: `{ComponentName}Tests.swift` in `ios/Tests/` mirroring source structure (`Tests/Features/`, `Tests/Services/`, `Tests/Models/`)
- New test files must be added to `ios/project.yml` — CI uses XcodeGen, won't find files not in the manifest
- Tests use `@testable import sprinty` (lowercase) — never make types `public` just for testing
- Test naming: `test_{function}_{scenario}_{expected}` — e.g., `test_loadMessages_loadsFromDB`
- Test classes: `@Suite struct SomeTests` — NOT `class`
- Async tests: `@Test @MainActor func test_something() async { }` — `@MainActor` required when testing ViewModel state
- Assertions: `#expect(value == expected)` — NEVER `XCTAssertEqual`
- Database: use `makeTestDB()` — runs real GRDB migrations against in-memory database. NEVER mock the database. The test DB IS the mock
- GRDB test pattern: write → read back → assert. Never assert on write alone — write may succeed but data could be malformed for reads
- Use existing test helpers: `createSession()`, `createMessage()`, `makeDate(hour:)` — don't construct models inline with arbitrary data
- Mocks: `final class Mock{ServiceName}: {ServiceProtocol}, @unchecked Sendable` — record call arguments (`lastMessages`, `lastMode`), expose stub injection (`stubbedError`, `stubbedEvents`)
- New service protocol → must create corresponding mock in `ios/Tests/Mocks/` with full protocol implementation, recorded args, and stub injection
- Conditional tests: `.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)` for tests requiring hardware (e.g., CoreML)

#### Go
- Test naming: `Test<Component><Scenario>` PascalCase — e.g., `TestChatProviderError502`. Different from Swift's snake_case convention
- Unit tests: `_test.go` in same package
- Integration tests: `server/tests/` separate package with full mux setup via `setupMux()`
- Prompt-related tests: use `setupMuxWithBuilder(builder)`, not plain `setupMux()` — plain variant gives nil builder
- Test helpers must call `t.Helper()` for clean stack traces
- Test fixtures in `docs/fixtures/`, loaded via `loadFixture(t, "filename")`
- Token helpers: `createValidToken(t)`, `createExpiredToken(t)` for auth tests
- Mock provider: `providers.NewMockProvider()` with `StubbedMode`, `StubbedChallengerUsed` fields
- Provider tests: use `httptest.Server` with `buildStreamingResponse()` for full HTTP→SSE→channel pipeline testing — NOT mock structs. This tests streaming parsing where bugs actually live
- Streaming code must have context cancellation tests to prevent goroutine leaks
- Test organization: story-based comment markers (`// --- Story X.Y Tests ---`) — new story tests go under a new marker section
- API contract changes must update `tests/handlers_test.go` simultaneously — prevents drift between `docs/api-contract.md` and server behavior

### Code Quality & Style Rules

#### File & Folder Structure
- iOS files: PascalCase (`CoachingViewModel.swift`, `ChatService.swift`)
- Go files: snake_case or single-word (`chat.go`, `helpers.go`, `provider.go`)
- Prompt sections: kebab-case (`base-persona.md`, `mode-discovery.md`)
- No generic `utils/` or `helpers/` packages — helpers scoped to their domain (`handlers/helpers.go`, not `utils/response.go`)
- No barrel files or re-export patterns — each file imports what it needs directly
- No README files in subdirectories — architecture doc and API contract are the documentation

#### Naming Conventions
- Swift types: PascalCase (`CoachingViewModel`, `ChatServiceProtocol`)
- Swift functions/vars: camelCase (`sendMessage`, `isStreaming`)
- Go exported: PascalCase (`ChatHandler`, `StreamChat`)
- Go unexported: camelCase (`handleProviderError`, `extractCoachingChunk`)
- Protocols: `{Name}Protocol` suffix — NOT `-able`/`-ing` (`ChatServiceProtocol`, not `ChatServicing`)
- Mocks: `Mock{ServiceName}` prefix (`MockChatService`, `MockAPIClient`)

#### Code Organization
- One responsibility per file — avoid god files
- Swift: group related functionality with `// MARK: -` comments
- Go: keep packages small and focused — each package has a single clear responsibility
- Core shared code in `ios/sprinty/Core/` (Errors, Theme, Utilities, Extensions)
- No premature abstractions — no `Manager`/`Coordinator`/`Helper` classes for single-use operations
- No new third-party dependencies without justification — minimal deps policy (Go: 3 direct deps, iOS: GRDB + 1 local SPM)

#### Swift Safety
- `Sendable` is viral — new model properties must be `Sendable`-compatible or cascading compiler errors
- No force unwraps (`!`) in production code — only acceptable in tests. Use `guard let`/`if let`
- `guard` for early returns, `if let` for conditional work — no deep nesting
- Compiler warnings are errors — StrictConcurrency means concurrency warnings = build failures

#### Documentation & Comments
- No docstrings on self-evident code — only comment where logic isn't obvious (e.g., partial JSON parsing)
- API contract (`docs/api-contract.md`) updated FIRST or simultaneously with code changes — it's source of truth, not the implementation
- Story specs in `_bmad-output/implementation-artifacts/{story-number}-{story-name}.md` — reference for acceptance criteria

#### Commits
- Format: `feat: Story X.Y — Description` with type prefix
- Prefixes: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Reference story number when applicable for traceability

#### Accessibility
- Required on all new views: `.accessibilityLabel()`, `.accessibilityHint()` where appropriate
- Support Dynamic Type
- WCAG AA contrast compliance
- Respect `@Environment(\.accessibilityReduceMotion)` with static fallbacks

### Development Workflow Rules

#### Local Development
- iOS Simulator hits `localhost:8080` (Go server running locally)
- Device testing uses Railway staging environment URL
- Environment switching via Xcode schemes only — Debug → localhost, Staging → Railway. NEVER modify `Info.plist` values or hardcode URLs in code
- Go server: `go run .` from `server/` directory — no hot reload, must stop and restart after changes
- Local dev uses `server/.env` (gitignored) — never commit secrets. Update `.env.example` when adding new env vars
- Docker Compose exists but isn't primary workflow — daily dev runs Go natively
- Run `xcodegen generate` after any `project.yml` modification — stale `.xcodeproj` breaks CI
- `project.yml` — new files must go under the correct target's `sources` group (app target vs test target). Wrong target = cryptic build failures

#### Architecture Constraints
- Server is stateless — no database, no persistence, no caching. All state lives on iOS device (GRDB/SQLite). Server is a proxy only: receives requests, assembles prompts, forwards to Anthropic, streams back responses
- Prompts are independently deployable — markdown files loaded at server startup. Prompt changes need only a Railway redeploy, no iOS update. Never embed prompt text in iOS code

#### Story Implementation
- Read story file BEFORE implementation — `_bmad-output/implementation-artifacts/{story-number}-{story-name}.md` contains acceptance criteria and subtasks. Story specs are the implementation contract
- Epic/story numbering is hierarchical (`{epic}.{story}`) — used in commits, test markers, and file names. Never invent alternative numbering
- Sprint status tracked in `sprint-status.yaml` — agents should NOT modify this file

#### Schema & Contract Changes
- Schema changes require coordination: update API contract → server → iOS (or simultaneously)
- Never let code drift ahead of `docs/api-contract.md` — contract is source of truth

#### CI/CD
- `.github/workflows/ios.yml` — runs `xcodegen generate` before build
- Railway watches `server/` subdirectory for auto-deploys
- `railway.toml` configures deploy behavior — don't create CI deploy steps
- Run tests locally before declaring complete — `go test ./...` and Xcode tests
- Go tests create fresh mux instances per test — never hardcode ports or share state between tests

#### Deployment
- Backend: Railway with zero-downtime deploys
- iOS: Standard App Store submission pipeline
- Apple Privacy Manifest required for App Store submission

### Critical Don't-Miss Rules

#### Anti-Patterns to Avoid
- NEVER use Combine (`ObservableObject`, `@Published`, `PassthroughSubject`) — this project uses Observation framework exclusively
- NEVER use XCTest (`XCTestCase`, `XCTAssert*`) — this project uses Swift Testing framework exclusively
- NEVER edit `.xcodeproj/project.pbxproj` directly — modify `project.yml` and run `xcodegen generate`
- NEVER add server-side state/storage — the server is a stateless proxy
- NEVER hardcode API URLs — use Bundle configuration or `fromConfiguration()` factories
- NEVER expose raw provider errors to users — translate to warm, human-friendly messages
- NEVER modify existing database migrations — append new versioned migrations only
- NEVER create parallel state stores (singletons, global vars) — `AppState` is the single source of truth for app-wide state
- NEVER create messages without associating to a `ConversationSession` — no orphan messages
- NEVER add model selection logic to iOS — model routing is a server concern
- NEVER invent new API endpoints for on-device data — only 5 endpoints exist: `/health`, `/v1/auth/register`, `/v1/auth/refresh`, `/v1/chat`, `/v1/prompt/{version}`
- NEVER add engagement logic to the Go server — `EngagementCalculator` runs on-device only, sends metrics to server in `userState`

#### Domain Rules
- `ChatProfile` and `UserState` are optional in chat requests — cold start/onboarding has neither. Don't force-require them or the first conversation breaks
- Safety levels (`green`, `yellow`, `orange`, `red`) are load-bearing — drive UI state, notification suppression, compliance logging, and theme changes. Not decorative metadata
- Free vs paid tier is architecturally significant — affects model routing, Directive Mode availability, system prompt depth, and guardrail strictness. Consider tier implications for every new feature
- Prompt sections have cascading effects — never edit a section without understanding downstream impact on safety classification, mode switching, tone, and Challenger behavior
- Domain tags are a closed vocabulary in the Anthropic tool schema — new domains require schema update, not free-text tags
- Test the cold start path — zero RAG context, no profile, no mode history. Bugs hide in empty state
- Cut order if scope shrinks: Widgets → Pause AI suggestion → Sprint viz simplification → Avatar animations. Never cut load-bearing features (memory pipeline, safety classification, streaming)

#### Streaming & State
- `isStreaming` guards against double-sends — new interaction paths during coaching must respect this flag. Firing a second request mid-stream corrupts conversation state
- `retryAfter` requires countdown timer implementation in ViewModel — don't just store the value, decrement every second and show in UI
- Mode history is serialized JSON on `ConversationSession`, not a relational table — not queryable via SQL
- Mock provider returns hardcoded greeting — customize `MockProvider` stubs for tests needing specific LLM output
- SSE parser uses exact string matching — format deviations break iOS parsing silently. Verify server changes against iOS `SSEParser`

#### Change Chains
- Adding a new field to coaching responses is a 7-step chain: (1) Anthropic tool schema → (2) `toolResult` struct → (3) `parseFinalResult()` → (4) `ChatEvent` (Go) → (5) SSE done event data → (6) `ChatEvent` (iOS) → (7) API contract doc. Miss one link and the field silently drops

#### Security Rules
- API keys live in server environment only — never in iOS binary or source code
- JWT tokens stored in iOS Keychain via `KeychainHelperProtocol` — never UserDefaults
- Database encrypted at rest via `.complete` file protection in App Group container
- Zero-retention LLM provider requirement — contractual, not just technical
- Never log or persist raw user coaching content outside the on-device database

#### Performance Gotchas
- SwiftUI incremental text rendering during streaming can cause layout thrashing — test with long responses
- SQLite-vec queries at scale (10K embeddings) — performance ceiling validated by benchmark harness
- `AsyncThrowingStream` `onTermination` handler required — missing it leaks URLSession tasks and goroutines
- Early `stream.Next()` call in Go provider catches 429/500 before committing to goroutine — without it, errors surface as broken SSE streams

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Cross-reference `docs/api-contract.md` for endpoint schemas
- Read story spec files before starting implementation

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack or patterns change
- Review periodically for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-03-20
