# Story 1.8: CI/CD Pipeline & Test Infrastructure

Status: done

## Story

As a developer,
I want automated CI/CD pipelines that validate code quality and deploy safely,
So that every change is tested before it reaches users.

## Acceptance Criteria

1. **GitHub Actions CI for iOS**
   - Given GitHub Actions CI is configured, when changes are pushed to `ios/`, then `ios.yml` runs: Swift tests → build verification

2. **GitHub Actions CI for Server**
   - Given GitHub Actions CI is configured, when changes are pushed to `server/`, then `server.yml` runs: Go tests → (safety regression suite placeholder) → Railway deploy trigger

3. **Contract test enforcement via shared fixtures**
   - Given the shared test fixtures in `docs/fixtures/`, when contract tests run, then both iOS and Go test suites validate against the same fixtures, and changes to `docs/api-contract.md` require fixture updates first

4. **Railway deployment with health-gated zero-downtime deploys**
   - Given Railway deployment, when a deploy is triggered, then it watches the `server/` subdirectory, uses multi-stage Docker build (Go build → alpine final stage with CA certificates), zero-downtime rolling restarts are used, health check on `GET /health` gates the deploy, and automatic rollback triggers on health check failure (NFR30)

## Tasks / Subtasks

- [x] Task 1: GitHub Actions workflow for iOS (AC: #1)
  - [x] 1.1 Create `.github/workflows/ios.yml` — trigger on push/PR when `ios/**` changes
  - [x] 1.2 Configure macOS runner with Xcode (latest stable), Swift 6.x
  - [x] 1.3 Generate Xcode project from `project.yml` using XcodeGen
  - [x] 1.4 Run Swift tests via `xcodebuild test` using the Debug scheme (see Dev Notes for exact command)
  - [x] 1.5 Run build verification via `xcodebuild build` (no code signing for CI)
  - [x] 1.6 Cache SPM dependencies for faster builds
  - [x] 1.7 Handle gitignored Core ML model: add environment check to skip `EmbeddingServiceTests` in CI (only this test requires `MiniLM.mlpackage`; `VectorSearchTests` and `VectorBenchmarkTests` use synthetic data and will pass without the model)

- [x] Task 2: GitHub Actions workflow for Server (AC: #2)
  - [x] 2.1 Create `.github/workflows/server.yml` — trigger on push/PR when `server/**` changes
  - [x] 2.2 Configure Go 1.26.x on ubuntu-latest runner
  - [x] 2.3 Run `go test ./...` (excludes safety build tag by default)
  - [x] 2.4 Add placeholder step for safety regression suite (`go test -tags=safety ./tests/safety/...`) — skip if `tests/safety/` doesn't exist yet, but CI structure must be ready for it
  - [x] 2.5 Add Railway deploy trigger step (on push to main only, not on PRs)
  - [x] 2.6 Cache Go modules for faster builds

- [x] Task 3: Contract test fixture wiring (AC: #3)
  - [x] 3.1 Refactor Go tests to load from `docs/fixtures/` — ALL three Go test files (`handlers_test.go`, `middleware_test.go`, `config_test.go`) currently hard-code all test data inline. At minimum, `handlers_test.go` must load `chat-request-sample.json`, `sse-token-event.txt`, `sse-done-event.txt`, and `auth-register-response.json` from shared fixtures. Create a `loadFixture(t, filename)` helper in the test package using `runtime.Caller(0)` for reliable path resolution (see Dev Notes for path details)
  - [x] 3.2 Refactor iOS tests that hard-code fixture data — `CodableRoundtripTests` and `AuthServiceTests` hard-code all data inline. `SSEParserTests` already has a working `loadFixture()` helper using `#filePath` path traversal — reuse this pattern. At minimum, refactor `CodableRoundtripTests` to load `auth-register-response.json` and `chat-request-sample.json` from `docs/fixtures/`
  - [x] 3.3 Add CI trigger: both `ios.yml` and `server.yml` also trigger on changes to `docs/fixtures/**` and `docs/api-contract.md`
  - [x] 3.4 Create missing fixture `error-response-502.json` with content matching the api-contract error format: `{"error": "provider_unavailable", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 10}` — add corresponding test assertions in both Go and iOS tests

- [x] Task 4: Railway deployment configuration (AC: #4)
  - [x] 4.1 Create `server/railway.toml` (or `railway.json`) configuring: watch path `server/`, build command, deploy command, health check on `/health`
  - [x] 4.2 Verify existing `server/Dockerfile` meets requirements (multi-stage, alpine final, CA certs) — it already does, just validate
  - [x] 4.3 Configure health check endpoint and rollback behavior in Railway config
  - [x] 4.4 Add deploy trigger in `server.yml` GitHub Actions — use Railway CLI or webhook to trigger deploy on main branch push after tests pass
  - [x] 4.5 Document environment variable requirements for Railway in `server/.env.example` (verify all needed vars are listed)

- [x] Task 5: Verify no regressions (AC: all)
  - [x] 5.1 Run all 145 iOS tests locally — verify all pass (including fixture-refactored tests)
  - [x] 5.2 Run all 39 Go server tests locally — verify all pass (including fixture-refactored tests)
  - [x] 5.3 Verify CI workflows have correct YAML syntax (use `actionlint` or manual review)
  - [x] 5.4 Test Docker build locally: `cd server && docker build -t sprinty-server .` (also add as a CI step in `server.yml`)

## Dev Notes

### Scope Boundaries

**IN SCOPE:**
- GitHub Actions workflow YAML files for iOS and server
- Railway deployment configuration
- Contract test fixture wiring (verify/fix shared fixture loading)
- CI trigger configuration (path-based, plus fixture/contract changes)

**OUT OF SCOPE:**
- Writing the 50+ prompt safety regression suite (that's a future story) — just create the CI step placeholder
- Setting up Railway project/environment (that's manual infrastructure setup by the developer)
- Creating staging environment — this story sets up the CI pipeline; staging config is an ops task
- Adding new tests beyond fixture wiring fixes
- SwiftLint, golangci-lint, or other linting tools (not in architecture spec for MVP)

### Critical Technical Constraints

**iOS CI Runner:**
- Must use `macos-latest` (or `macos-15`) runner — iOS builds require macOS
- XcodeGen must be installed to generate `.xcodeproj` from `project.yml` before building
- Install via: `brew install xcodegen` then `cd ios && xcodegen generate`
- Code signing must be disabled for CI: `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- The project uses local SPM packages in `ios/Packages/` (SQLiteVecKit) — these are in-repo so no special auth needed
- External SPM deps: GRDB (v7.10.0), SQLiteVec (jkrukowski/SQLiteVec pinned v0.0.14)
- **Core ML model in CI:** `MiniLM.mlpackage` is gitignored. Only `EmbeddingServiceTests.swift` requires the actual model file (it calls `EmbeddingTestHelpers.modelURL()` which throws if model is absent). `VectorSearchTests` and `VectorBenchmarkTests` use synthetic 384-dim vectors and do NOT need the model. Solution: add an environment-based skip to `EmbeddingServiceTests` — check for `CI` environment variable (GitHub Actions sets `CI=true` automatically) and call `XCTSkip("Core ML model not available in CI")`. The `vocab.txt` file IS tracked in git and will be available in CI
- **Test scheme:** `project.yml` defines three schemes: `Debug`, `Staging`, `Release`. The `Debug` scheme includes the `sprintyTests` target. Use:
  ```
  xcodebuild test -scheme Debug -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
  ```

**Server CI Runner:**
- Use `ubuntu-latest` — Go server has no OS-specific dependencies
- Go version: 1.26.x (match `go.mod` which specifies `go 1.26.1`)
- Tests run from `server/` directory: `cd server && go test ./...`
- Safety tests use build tag: `go test -tags=safety ./tests/safety/...` — this directory doesn't exist yet, so the step should gracefully handle its absence (e.g., check if directory exists first)
- The server requires `JWT_SECRET` env var for tests — check if tests set this up internally or need it from environment. Current tests in `server/tests/` use `t.Setenv("JWT_SECRET", ...)` pattern
- `ANTHROPIC_API_KEY` is NOT needed for tests (mock provider is used)

**Railway Deployment:**
- Railway watches `server/` subdirectory — configured in Railway dashboard or `railway.toml`
- Existing `server/Dockerfile` is correct: `golang:1.26-alpine` builder → `alpine:latest` final with `ca-certificates`
- Health check: `GET /health` returns 200 — already implemented in `server/main.go`
- Auto-deploy should be disabled in Railway — CI triggers deploy after tests pass
- Railway CLI (`railway`) or deploy webhook can trigger deploys from GitHub Actions
- For the deploy step, use Railway's GitHub integration or `railway up` CLI command
- **Secret management:** Railway environment variables (JWT_SECRET, ANTHROPIC_API_KEY, etc.) are set in Railway dashboard, NOT in GitHub Actions secrets (except RAILWAY_TOKEN for CLI auth)

**Contract Testing Architecture:**
- Shared fixtures in `docs/fixtures/` are the single source of truth
- Current fixtures: `chat-request-sample.json`, `sse-token-event.txt`, `sse-done-event.txt`, `error-response-401.json`, `auth-register-response.json`
- `error-response-502.json` must be created — architecture specifies it but only 401 exists. Content: `{"error": "provider_unavailable", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 10}`
- **CURRENT STATE: Most tests hard-code data inline.** This story must refactor them to load from shared fixtures:
  - **Go:** ALL 3 test files (`handlers_test.go`, `middleware_test.go`, `config_test.go`) hard-code everything inline. Create a `loadFixture(t *testing.T, filename string) []byte` helper. Use `runtime.Caller(0)` to get the test file's directory, then resolve `../../docs/fixtures/` relative to it (tests are in `server/tests/`, fixtures in `docs/fixtures/` — that's up 2 from `server/tests/` to repo root, NOT up 2 from `server/`)
  - **iOS:** Only `SSEParserTests.swift` loads fixtures (via `#filePath` traversal helper). `CodableRoundtripTests` and `AuthServiceTests` hard-code inline. Reuse SSEParserTests' `loadFixture()` pattern — extract it to a shared test helper or duplicate it in each test file

### Existing Infrastructure to Build On

**Dockerfile (DO NOT modify unless broken):**
```
server/Dockerfile — already implements:
- Multi-stage build (golang:1.26-alpine → alpine:latest)
- Static binary with CGO_ENABLED=0
- CA certificates for HTTPS to LLM providers
- Port 8080 exposed
```

**Server test structure (refactor fixture loading, extend don't restructure):**
```
server/tests/
├── handlers_test.go     # API contract tests (httptest) — NEEDS REFACTOR: hard-codes all fixture data inline
├── middleware_test.go    # Auth, tier middleware tests — NEEDS REFACTOR: hard-codes test data inline
├── config_test.go       # Config validation tests — uses t.Setenv() (OK, no fixtures applicable)
└── helpers_test.go      # NEW: shared loadFixture() helper using runtime.Caller(0) path resolution
```

**iOS test structure (refactor fixture loading):**
```
ios/Tests/
├── Mocks/MockChatService.swift
├── Database/MigrationTests.swift
├── Features/ (CoachingViewModel, Onboarding tests)
├── Models/
│   └── CodableRoundtripTests.swift      # NEEDS REFACTOR: hard-codes fixture data inline
├── Services/
│   ├── SSEParserTests.swift             # GOOD: already loads from docs/fixtures/ via loadFixture() helper
│   ├── AuthServiceTests.swift           # NEEDS REFACTOR: hard-codes fixture data inline
│   ├── EmbeddingServiceTests.swift      # NEEDS CI SKIP: requires MiniLM.mlpackage (gitignored)
│   ├── EmbeddingTestHelpers.swift       # Shared test helpers for embedding tests
│   ├── VectorSearchTests.swift          # OK: uses synthetic data, no model needed
│   └── EmbeddingPipelineIntegrationTests.swift
├── Benchmarks/VectorBenchmarkTests.swift  # OK: uses synthetic data, no model needed
└── Theme/ (Typography, Color, Spacing, Copy tests)
```

**Shared fixtures (must be loaded by both codebases after refactor):**
```
docs/fixtures/
├── auth-register-response.json    # Used by: Go handlers_test, iOS AuthServiceTests + CodableRoundtripTests
├── chat-request-sample.json       # Used by: Go handlers_test, iOS CodableRoundtripTests
├── error-response-401.json        # Used by: Go handlers_test, iOS CodableRoundtripTests
├── error-response-502.json        # NEW: must create — Go handlers_test, iOS CodableRoundtripTests
├── sse-done-event.txt             # Used by: Go handlers_test, iOS SSEParserTests (already loads)
└── sse-token-event.txt            # Used by: Go handlers_test, iOS SSEParserTests (already loads)
```

**Go fixture path resolution pattern:**
```go
// In server/tests/helpers_test.go
func loadFixture(t *testing.T, filename string) []byte {
    t.Helper()
    _, callerFile, _, _ := runtime.Caller(0)
    // callerFile = .../server/tests/helpers_test.go
    fixtureDir := filepath.Join(filepath.Dir(callerFile), "..", "..", "docs", "fixtures")
    data, err := os.ReadFile(filepath.Join(fixtureDir, filename))
    if err != nil {
        t.Fatalf("failed to load fixture %s: %v", filename, err)
    }
    return data
}
```

**iOS fixture path resolution pattern (from existing SSEParserTests):**
```swift
private func loadFixture(_ filename: String) throws -> String {
    let testFile = URL(fileURLWithPath: #filePath)
    let fixtureURL = testFile
        .deletingLastPathComponent() // current dir (e.g., Services/)
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent() // ios/
        .deletingLastPathComponent() // project root
        .appendingPathComponent("docs")
        .appendingPathComponent("fixtures")
        .appendingPathComponent(filename)
    return try String(contentsOf: fixtureURL, encoding: .utf8)
}
```

### GitHub Actions Workflow Patterns

**ios.yml structure:**
```yaml
name: iOS CI
on:
  push:
    paths: ['ios/**', 'docs/fixtures/**', 'docs/api-contract.md']
  pull_request:
    paths: ['ios/**', 'docs/fixtures/**', 'docs/api-contract.md']

jobs:
  test:
    runs-on: macos-latest  # or macos-15
    env:
      CI: true  # GitHub Actions sets this automatically, but be explicit
    steps:
      - Checkout
      - Install XcodeGen (brew install xcodegen)
      - Generate project (cd ios && xcodegen generate)
      - Cache SPM packages (~/.swift/cache, ios/sprinty.xcodeproj/project.xcworkspace/xcshareddata/swiftpm)
      - Run tests: xcodebuild test -scheme Debug -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
      - Build verification: xcodebuild build -scheme Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

**server.yml structure:**
```yaml
name: Server CI
on:
  push:
    paths: ['server/**', 'docs/fixtures/**', 'docs/api-contract.md']
  pull_request:
    paths: ['server/**', 'docs/fixtures/**', 'docs/api-contract.md']

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - Checkout
      - Setup Go 1.26.x
      - Cache Go modules
      - Run tests (go test ./...)
      - Safety regression placeholder (skip if tests/safety/ absent)
      - Docker build verification: docker build -t sprinty-server ./server

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - Railway deploy trigger (CLI or webhook)
```

### Environment Variables for CI

**GitHub Actions Secrets needed:**
- `RAILWAY_TOKEN` — for Railway CLI deploy trigger (only for server.yml deploy job)

**NOT needed in GitHub Actions (set in Railway dashboard):**
- `JWT_SECRET`, `ANTHROPIC_API_KEY`, `ENVIRONMENT`, `PORT`, `SENTRY_DSN`

**NOT needed for tests:**
- Server tests self-configure via `t.Setenv()` — no external secrets required
- iOS tests use mocks — no API keys needed

### Previous Story Intelligence (Story 1.7)

**Key learnings to apply:**
- Swift 6 strict concurrency is enforced — any new test utilities must be `Sendable`
- Protocol-based mocking is the established pattern — no mocking frameworks
- `project.yml` is the source of truth for iOS project — XcodeGen generates `.xcodeproj`
- Local SPM packages (ios/Packages/) must be resolved before building
- Core ML model files are gitignored — CI must handle their absence gracefully
- Test counts: 145 iOS tests, 39 server tests — these are the regression baselines

**Code review corrections from 1.7:**
- Integration tests go in `ios/Tests/` (or `server/tests/`), not co-located with source
- Surface errors visibly, don't swallow them

### Git Intelligence

Recent commit pattern: `feat: Story X.Y — Description`
```
c87f6a0 feat: Story 1.7 — sqlite-vec & Core ML embedding spike with benchmarks
74cf932 feat: Story 1.6 — Real AI coaching integration with Anthropic provider
b8da909 feat: Story 1.5 — Onboarding flow with UserProfile, views, and routing gate
```

### Project Structure for New/Modified Files

```
.github/
└── workflows/
    ├── ios.yml                           # NEW: iOS CI workflow
    └── server.yml                        # NEW: Server CI + deploy workflow

server/
├── railway.toml                          # NEW: Railway deployment config
└── tests/
    └── helpers_test.go                   # NEW: shared loadFixture() helper

docs/fixtures/
└── error-response-502.json              # NEW: Provider error fixture

# MODIFIED (fixture refactoring):
server/tests/handlers_test.go            # Refactor to use loadFixture() for shared fixtures
ios/Tests/Models/CodableRoundtripTests.swift   # Refactor to load from docs/fixtures/
ios/Tests/Services/AuthServiceTests.swift      # Refactor to load from docs/fixtures/
ios/Tests/Services/EmbeddingServiceTests.swift # Add CI environment skip check
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 1, Story 1.8]
- [Source: _bmad-output/planning-artifacts/architecture.md — CI/CD Pipeline, Testing Standards, Environments, Railway deployment]
- [Source: _bmad-output/planning-artifacts/prd.md — NFR30 (auto-rollback), Safety regression suite requirements]
- [Source: server/Dockerfile — Existing multi-stage Docker build]
- [Source: server/.env.example — Environment variable template]
- [Source: docs/api-contract.md — API contract (single source of truth)]
- [Source: docs/fixtures/ — Shared test fixtures for contract testing]
- [Source: server/tests/ — Existing Go test structure]
- [Source: ios/Tests/ — Existing iOS test structure (20 files, 145 tests)]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- iOS tests: 149 passed (up from 145 baseline — added 4 fixture contract tests)
- Go tests: 44 passed (up from 39 baseline — added 5 fixture/contract tests)
- Docker build: verified locally, image builds successfully
- YAML validation: both workflow files parse correctly

### Completion Notes List
- Task 1: Created `.github/workflows/ios.yml` with macOS-15 runner, XcodeGen project generation, SPM caching, test + build steps. Added `.enabled(if:)` trait to `EmbeddingServiceTests.embeddingServiceFullPipeline()` to skip when `CI` env var is set (Core ML model is gitignored).
- Task 2: Created `.github/workflows/server.yml` with Go 1.26.x, test step, safety suite placeholder (checks if `tests/safety/` exists), Docker build verification, and Railway deploy job (main branch only, after tests pass).
- Task 3: Created `server/tests/helpers_test.go` with `loadFixture()` using `runtime.Caller(0)` path resolution. Added fixture contract tests in `handlers_test.go` (chat-request-sample, auth-register-response, sse-token-event, sse-done-event, error-response-502). Added fixture contract tests in iOS `CodableRoundtripTests.swift` using `#filePath` path traversal. Created `docs/fixtures/error-response-502.json`. CI triggers include `docs/fixtures/**` and `docs/api-contract.md`.
- Task 4: Created `server/railway.toml` with Dockerfile builder, health check on `/health`, restart policy. Deploy trigger in `server.yml` uses Railway CLI. Updated `.env.example` to document ANTHROPIC_API_KEY.
- Task 5: All 149 iOS + 44 Go tests pass. YAML validated. Docker build verified.

### Change Log
- 2026-03-19: Story 1.8 implemented — CI/CD pipeline and test infrastructure
- 2026-03-19: Code review fixes — removed redundant SPM resolve step, fixed simulator to iPhone 16, refactored AuthServiceTests to use shared fixtures, renamed TestChatProviderError500→502

### File List
- `.github/workflows/ios.yml` (new)
- `.github/workflows/server.yml` (new)
- `server/railway.toml` (new)
- `server/tests/helpers_test.go` (new)
- `docs/fixtures/error-response-502.json` (new)
- `server/tests/handlers_test.go` (modified — added fixture contract tests)
- `ios/Tests/Models/CodableRoundtripTests.swift` (modified — added fixture contract tests + loadFixture helper)
- `ios/Tests/Services/EmbeddingServiceTests.swift` (modified — added CI skip via .enabled(if:) trait)
- `ios/Tests/Services/AuthServiceTests.swift` (modified — refactored to use shared fixtures via loadFixture helper)
- `server/.env.example` (modified — documented ANTHROPIC_API_KEY)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — status updates)
- `_bmad-output/implementation-artifacts/1-8-ci-cd-pipeline-and-test-infrastructure.md` (modified — task tracking)
