# Story 1.1: Server Scaffold & Auth Endpoints

Status: done

## Story

As a new user opening the app for the first time,
I want a secure backend that can authenticate my device,
So that my coaching experience is private from the start.

## Acceptance Criteria

1. **Monorepo structure**: Top-level `/ios`, `/server`, and `/docs` directories exist. `docs/api-contract.md` is created as the single source of truth for all API endpoints, request/response schemas, SSE event formats, and error taxonomy. `docs/fixtures/` contains shared test fixtures validating both iOS and Go against the contract.

2. **Health check**: `GET /health` returns `200 OK` with JSON body `{"status": "ok"}`. No auth required.

3. **Device registration**: `POST /v1/auth/register` with a device UUID returns a JWT containing `{deviceId, userId: null, tier: "free", iat, exp}` with 30-day expiry. No auth required. Idempotent — calling with the same UUID returns a fresh JWT (server is stateless, no UUID storage).

4. **Token refresh**: `POST /v1/auth/refresh` with a valid JWT returns a new JWT with refreshed 30-day expiry. JWT required.

5. **Auth protection**: Any request to a protected endpoint without a valid JWT returns 401 Unauthorized with error response body.

6. **Structured logging**: All request processing emits structured JSON logs via `slog` (request lifecycle at Info, errors at Warn).

7. **Graceful shutdown**: Server handles SIGTERM/SIGINT, drains in-flight requests, and exits cleanly for zero-downtime Railway deploys.

## Tasks / Subtasks

- [x] Task 1: Initialize monorepo and Go module (AC: #1)
  - [x] Create top-level `/ios`, `/server`, `/docs` directories
  - [x] Run `go mod init github.com/ducdo/ai-life-coach/server` inside `/server`
  - [x] Run `go get github.com/golang-jwt/jwt/v5@v5.3.0`
  - [x] Set `go 1.23` explicitly in go.mod (required for enhanced ServeMux routing — silently fails without this)
  - [x] Create `docs/api-contract.md` with full specification:
    - All 5 MVP endpoints: `POST /v1/auth/register`, `POST /v1/auth/refresh`, `POST /v1/chat`, `GET /v1/prompt/{version}`, `GET /health`
    - JSON request/response schemas for each endpoint (including JWT claims structure)
    - SSE event format: `event: token` and `event: done` with all fields
    - Error response schema with taxonomy (recoverable, degraded-mode, hard, silent)
    - Error codes: `invalid_jwt`, `token_expired`, `missing_device_id`, `provider_unavailable`
    - Wire format conventions (camelCase, ISO 8601, snake_case enums)
  - [x] Create `docs/fixtures/` with all 5 shared test fixtures:
    - `auth-register-response.json` — valid JWT response with all claims
    - `error-response-401.json` — unauthorized error format
    - `chat-request-sample.json` — sample coaching request with messages, mode, promptVersion
    - `sse-token-event.txt` — SSE token event format
    - `sse-done-event.txt` — SSE done event with safetyLevel, domainTags, usage
  - [x] Create `.env.example` in `/server` with all env vars documented

- [x] Task 2: Implement config loading (AC: #2, #3, #4, #7)
  - [x] Create `server/config/config.go` — parse env vars into Config struct at startup
  - [x] Required vars: `JWT_SECRET`, `ENVIRONMENT` (dev|staging|production), `PORT` (default: 8080)
  - [x] Future vars stubbed: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `SENTRY_DSN`
  - [x] Fail fast at startup if required vars are missing (log error + os.Exit)
  - [x] No `os.Getenv()` at request time — read once at startup, Config struct is immutable after init

- [x] Task 3: Implement JWT auth (AC: #3, #4, #5)
  - [x] Create `server/auth/jwt.go` — JWT creation, validation, claims struct
  - [x] Use `github.com/golang-jwt/jwt/v5` (v5.3.0)
  - [x] Claims struct with JSON tags (camelCase): `DeviceID` → `"deviceId"`, `UserID` → `"userId"` (pointer for nullable), `Tier` → `"tier"`
  - [x] Signing method: HMAC SHA-256 (HS256)
  - [x] 30-day expiry: `time.Now().Add(30 * 24 * time.Hour)` from creation
  - [x] Validation returns parsed claims or typed error (expired vs invalid vs malformed)

- [x] Task 4: Implement middleware chain (AC: #5, #6)
  - [x] Create `server/middleware/auth.go` — JWT verification, claims extraction into request context
    - Store claims in context using unexported key type: `type contextKey string; const claimsKey contextKey = "claims"`
    - Export `ClaimsFromContext(ctx) (*Claims, bool)` helper for handlers
    - Return 401 with JSON error body for: missing token, invalid token, expired token
  - [x] Create `server/middleware/logging.go` — structured slog JSON logging
    - Log request start (method, path, deviceId if authed) at Info
    - Log request completion (status, duration) at Info
    - Log errors at Warn
  - [x] Middleware composition order: `logging(auth(handler))` (tier and guardrails added in later stories)
  - [x] Middleware pattern: `func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler`

- [x] Task 5: Implement handlers (AC: #1, #2, #3, #4)
  - [x] Create `server/handlers/health.go` — `GET /health` returns `{"status": "ok"}` with 200
  - [x] Create `server/handlers/auth.go` — register and refresh endpoints
    - Register: parse `deviceId` from request body, validate non-empty, create JWT, return token
    - Refresh: extract claims from context (set by auth middleware), create new JWT, return token
  - [x] Create `server/handlers/helpers.go`:
    - `writeJSON(w http.ResponseWriter, status int, data any)` — sets Content-Type, marshals, writes
    - `writeError(w http.ResponseWriter, status int, code string, message string)` — structured error response
    - Sets `Content-Type: application/json; charset=utf-8` on all responses

- [x] Task 6: Implement Provider interface stub and mock chat (AC: #1)
  - [x] Create `server/providers/provider.go` — Provider interface definition (architectural core):
    ```go
    type Provider interface {
        StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error)
    }
    type ChatEvent struct {
        Type           string   // "token" or "done"
        Text           string   // token text (for "token" events)
        SafetyLevel    string   // "green"|"yellow"|"orange"|"red" (for "done")
        DomainTags     []string // life domain tags (for "done")
        Usage          Usage    // token counts (for "done")
    }
    type Usage struct {
        InputTokens  int `json:"inputTokens"`
        OutputTokens int `json:"outputTokens"`
    }
    ```
  - [x] Create `server/providers/mock.go` — MockProvider implementing Provider interface with hardcoded responses
  - [x] Create `server/handlers/chat.go` — mock `POST /v1/chat` that uses MockProvider and streams SSE

- [x] Task 7: Wire up main.go and routing (AC: #1-#7)
  - [x] Create `server/main.go` — entry point, route registration, middleware chain, server startup
  - [x] Use `http.NewServeMux()` with method patterns: `"POST /v1/auth/register"`, `"POST /v1/auth/refresh"`, `"POST /v1/chat"`, `"GET /health"`
  - [x] Apply auth middleware only to protected routes (chat, refresh) — not health, not register
  - [x] Listen on `0.0.0.0:{PORT}` (PORT from config, default 8080)
  - [x] Graceful shutdown: trap SIGTERM/SIGINT → `context.WithCancel` → `server.Shutdown(ctx)` with 30s drain timeout

- [x] Task 8: Create Dockerfile (AC: #1)
  - [x] Multi-stage build: `golang:1.23-alpine` builder → `alpine:latest` final stage
  - [x] Builder: `WORKDIR /build`, `COPY go.mod go.sum ./`, `RUN go mod download`, `COPY . .`, `RUN CGO_ENABLED=0 go build -o /app/server .`
  - [x] Final: `FROM alpine:latest`, `RUN apk --no-cache add ca-certificates`, `COPY --from=builder /app/server /server`, `EXPOSE 8080`, `CMD ["/server"]`
  - [x] CRITICAL: `alpine` not `scratch` — CA certificates needed for outbound HTTPS to LLM providers

- [x] Task 9: Write tests (AC: #1-#7)
  - [x] Create `server/tests/handlers_test.go` — httptest integration tests
  - [x] Test health endpoint returns 200 with `{"status": "ok"}`
  - [x] Test register with valid UUID returns valid JWT with correct claims (deviceId, tier="free", userId=null, 30-day exp)
  - [x] Test register with missing/empty UUID returns 400 with error body
  - [x] Test register is idempotent (same UUID twice → both return valid JWTs)
  - [x] Test refresh returns new JWT with extended expiry
  - [x] Test protected endpoint returns 401 without JWT (with JSON error body)
  - [x] Test protected endpoint returns 401 with expired JWT
  - [x] Test protected endpoint returns 401 with malformed JWT
  - [x] Test protected endpoint succeeds with valid JWT
  - [x] Test config fails fast on missing JWT_SECRET
  - [x] Validate responses against shared fixtures in `docs/fixtures/`

## Dev Notes

### Technical Stack

- **Go 1.23+** with `net/http` standard library only — zero third-party HTTP frameworks
- **ServeMux** with method matching and path variables (Go 1.22+ feature). CRITICAL: `go.mod` must explicitly declare `go 1.23` or the enhanced routing patterns silently fail ([ref](https://github.com/golang/go/issues/69686))
- **JWT**: `github.com/golang-jwt/jwt/v5` (v5.3.0, latest stable as of July 2025)
- **Logging**: `log/slog` standard library — structured JSON output
- **Testing**: Go standard `testing` + `net/http/httptest`

### Wire Format Standards

- Field names: **camelCase** JSON throughout (Go struct tags: `json:"camelCase"`)
- Dates: ISO 8601 with UTC timezone suffix (`2026-03-17T14:30:00Z`)
- Enums: lowercase snake_case
- Omit null fields (`json:",omitempty"` on optional pointer fields)
- Arrays always arrays (never null — use empty `[]`)
- Booleans never 0/1

### Error Response Format

```json
{
  "error": "invalid_jwt",
  "message": "Your session has expired. Please reconnect.",
  "retryAfter": 0
}
```

Error codes for this story: `invalid_jwt`, `token_expired`, `missing_device_id`, `malformed_request`.

Error taxonomy (4 categories): recoverable, degraded-mode, hard, silent. Server never exposes raw errors to client. Use specific HTTP status codes — never 500 except actual crashes.

### Forbidden Patterns

- `fmt.Println()` or `log.Println()` — use `slog` exclusively
- `os.Getenv()` at request time — read config once at startup
- Returning HTTP 500 — always use specific status codes (400, 401, 502, 503)
- `snake_case` in JSON fields — always `camelCase`
- Raw `w.Write()` in handlers — always use `writeJSON`/`writeError` helpers
- Ad-hoc error types — use the structured error response format

### Go Code Conventions

- **Import ordering** (goimports enforced): stdlib → third-party → project
- **Error wrapping**: `fmt.Errorf("scope: %w", err)` — always wrap with context
- **Response helpers**: All HTTP responses go through `writeJSON`/`writeError` — never raw `w.Write`
- **Context propagation**: Always pass `context.Context` through the call chain

### Server Architecture

- **Stateless**: No server-side session storage. JWT verified on every request. Enables horizontal scaling (NFR17).
- **Config**: Env vars read once at startup into immutable `Config` struct. Fail fast if required vars missing.
- **Port**: Listen on `0.0.0.0:{PORT}` — Railway sets `PORT` env var, default 8080 for local dev.
- **Graceful shutdown**: Trap SIGTERM/SIGINT → drain in-flight requests (30s timeout) → clean exit. Required for Railway zero-downtime deploys.
- **Middleware order** (architectural constraint): `logging(guardrails(tier(auth(handler))))` — for Story 1.1, only implement `logging(auth(handler))`. Tier and guardrails come in later stories.

### Provider Interface (Architectural Core)

`server/providers/provider.go` defines the central abstraction that all LLM providers implement. Even though Story 1.1 only uses a MockProvider, the interface must be correct because everything else (handlers, middleware, failover) depends on it. Story 1.6 replaces MockProvider with AnthropicProvider — the chat handler should not change.

Streaming pattern: Provider returns a `<-chan ChatEvent` channel. Chat handler reads from channel and writes SSE events. This keeps streaming complexity inside providers and handlers simple.

### Mock Chat SSE Format

The mock `POST /v1/chat` uses MockProvider to emit a hardcoded SSE stream. Must match the contract in `docs/api-contract.md` and fixtures exactly:

```
event: token
data: {"text": "I hear you. "}

event: token
data: {"text": "Let's explore that together."}

event: done
data: {"safetyLevel": "green", "domainTags": [], "usage": {"inputTokens": 50, "outputTokens": 12}}
```

### Claims Context Pattern

Auth middleware stores parsed claims in request context. Handlers retrieve via exported helper:

```go
// In middleware/auth.go
type contextKey string
const claimsKey contextKey = "claims"
// store: context.WithValue(r.Context(), claimsKey, claims)

// Exported helper for handlers
func ClaimsFromContext(ctx context.Context) (*auth.Claims, bool)
```

### Register Endpoint Behavior

- Accepts `{"deviceId": "uuid-string"}` in request body
- Returns `{"token": "jwt-string"}` with camelCase JWT claims
- Idempotent: same UUID produces a new valid JWT each time (stateless server, no UUID storage)
- All new devices register as `tier: "free"` — StoreKit tier upgrade happens via iOS-side receipt validation in later stories

### Project Structure to Create

```
ai-life-coach/
├── docs/
│   ├── api-contract.md
│   └── fixtures/
│       ├── auth-register-response.json
│       ├── error-response-401.json
│       ├── chat-request-sample.json
│       ├── sse-token-event.txt
│       └── sse-done-event.txt
├── ios/                              # Empty, created for structure
├── server/
│   ├── main.go
│   ├── go.mod
│   ├── go.sum
│   ├── .env.example
│   ├── Dockerfile
│   ├── auth/
│   │   └── jwt.go
│   ├── config/
│   │   └── config.go
│   ├── handlers/
│   │   ├── auth.go
│   │   ├── health.go
│   │   ├── chat.go                   # Mock SSE via MockProvider
│   │   └── helpers.go
│   ├── providers/
│   │   ├── provider.go               # Provider interface (architectural core)
│   │   └── mock.go                   # MockProvider for Story 1.4 integration
│   ├── middleware/
│   │   ├── auth.go
│   │   └── logging.go
│   └── tests/
│       ├── handlers_test.go
│       └── middleware_test.go
└── _bmad-output/
```

### Deployment Notes

- Dockerfile uses multi-stage build: `golang:1.23-alpine` builder → `alpine:latest` final
- CRITICAL: Final stage must be `alpine` (not `scratch`) — CA certificates needed for outbound HTTPS to LLM providers
- Railway watches `server/` subdirectory, health check gates deploy on `GET /health`
- Railway sets `PORT` env var — server must read it (not hardcode 8080)
- Three environments: Local (localhost:8080), Staging (Railway staging), Production (Railway production)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Server Directory Structure, Authentication, Middleware Composition, Provider Interface]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 1, Story 1.1 Acceptance Criteria]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Error Messaging Patterns, UI Copy Blacklist]
- [Source: golang-jwt/jwt v5.3.0 — https://pkg.go.dev/github.com/golang-jwt/jwt/v5]
- [Source: Go 1.22+ ServeMux routing — https://go.dev/blog/routing-enhancements]
- [Source: Go 1.23 ServeMux compatibility — https://github.com/golang/go/issues/69686]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Resolved import cycle: `handlers` ↔ `middleware` by extracting `httputil` package for shared `WriteJSON`/`WriteError` helpers
- Go version: used Go 1.26.1 per user request (story spec said 1.23 but user instructed to use latest)

### Completion Notes List
- ✅ Monorepo structure created: `/ios`, `/server`, `/docs` with all subdirectories
- ✅ `docs/api-contract.md` — full API contract with 5 endpoints, schemas, SSE format, error taxonomy
- ✅ `docs/fixtures/` — 5 shared test fixtures matching contract spec
- ✅ Config loading with fail-fast validation, immutable Config struct, env-only reads at startup
- ✅ JWT auth with HS256, 30-day expiry, typed claims with camelCase JSON tags, nullable UserID
- ✅ Auth middleware with context-based claims propagation, expired vs invalid error differentiation
- ✅ Logging middleware with structured slog JSON, request lifecycle logging
- ✅ Health, Register, Refresh, Chat handlers all using writeJSON/writeError helpers
- ✅ Provider interface with MockProvider streaming hardcoded SSE events via channel
- ✅ main.go with ServeMux method routing, selective auth middleware, graceful shutdown (30s drain)
- ✅ Multi-stage Dockerfile (golang:1.23-alpine → alpine:latest with CA certs)
- ✅ 19 tests passing: handlers (13), config (5), middleware (2) — covers all ACs

### Change Log
- 2026-03-17: Initial implementation of Story 1.1 — all 9 tasks complete, 19 tests passing
- 2026-03-17: Code review fixes applied (7 issues: 1 HIGH, 3 MEDIUM, 3 LOW):
  - H1: Fixed Dockerfile Go version mismatch (1.23 → 1.26 to match go.mod 1.26.1)
  - M1: Fixed logging middleware deviceId never logged — added shared LogFields struct between logging/auth middleware
  - M2: Fixed handlers returning HTTP 500 (forbidden pattern) → changed to 503 ServiceUnavailable
  - M3: Fixed config tests leaking env state via os.Unsetenv → replaced with t.Setenv
  - L1: Fixed go.mod marking direct dependency as indirect (go mod tidy)
  - L2: Fixed error-response-401.json fixture message/code mismatch
  - L3: httputil package deviation — no fix needed, documented

### File List
- docs/api-contract.md (new)
- docs/fixtures/auth-register-response.json (new)
- docs/fixtures/error-response-401.json (new)
- docs/fixtures/chat-request-sample.json (new)
- docs/fixtures/sse-token-event.txt (new)
- docs/fixtures/sse-done-event.txt (new)
- ios/ (new, empty directory)
- server/main.go (new)
- server/go.mod (new)
- server/go.sum (new)
- server/.env.example (new)
- server/Dockerfile (new)
- server/auth/jwt.go (new)
- server/config/config.go (new)
- server/handlers/auth.go (new)
- server/handlers/health.go (new)
- server/handlers/chat.go (new)
- server/handlers/helpers.go (new)
- server/httputil/response.go (new)
- server/middleware/auth.go (new)
- server/middleware/logging.go (new)
- server/providers/provider.go (new)
- server/providers/mock.go (new)
- server/tests/handlers_test.go (new)
- server/tests/config_test.go (new)
- server/tests/middleware_test.go (new)
