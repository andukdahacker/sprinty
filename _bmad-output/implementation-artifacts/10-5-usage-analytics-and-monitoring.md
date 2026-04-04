# Story 10.5: Usage Analytics & Monitoring

Status: done

## Story

As a system operator,
I want usage analytics collected by the backend proxy,
so that I can monitor system health, understand usage patterns, and make informed decisions.

## Acceptance Criteria

1. **Given** the backend proxy processes requests (FR66), **When** a chat request completes, **Then** usage analytics are collected: request count, latency, provider used, tier, safety level — structured as slog JSON.

2. **Given** the analytics data, **When** reviewed, **Then** it supports cost tracking (~$0.015/user/month free, higher for paid) **And** provider performance comparison is possible **And** no PII or conversation content is included.

3. **Given** Railway deployment (NFR30), **When** deploying updates, **Then** zero-downtime rolling restarts are used **And** automatic rollback triggers on health check failure.

## Tasks / Subtasks

- [x] Task 1: Enhance logging middleware with analytics fields (AC: #1)
  - [x] 1.1 Extend `LogFields` struct in `middleware/logging.go` to carry: Tier, Provider, SafetyLevel, Mode, FailoverOccurred
  - [x] 1.2 Update `LoggingMiddleware` to log all analytics fields on request completion: deviceId, tier, provider, mode, status, duration_ms, safetyLevel, failoverOccurred
  - [x] 1.3 Ensure auth middleware populates `LogFields.Tier` (from claims)
  - [x] 1.4 Ensure tier middleware populates `LogFields.Provider` (selected provider name)
  - [x] 1.5 Ensure chat handler populates `LogFields.SafetyLevel`, `LogFields.Mode`, `LogFields.FailoverOccurred` after response completes

- [x] Task 2: Create in-process metrics collector (AC: #1, #2)
  - [x] 2.1 Create `server/metrics/collector.go` — atomic counters for request count, error count; ring-buffer histogram for latency; sync.Map counters by provider, tier, status code, safety level
  - [x] 2.2 Implement `RecordRequest(provider, tier string, status int, latencyMs float64, safetyLevel string)` method
  - [x] 2.3 Implement `Snapshot() map[string]any` returning JSON-serializable metrics summary with p50/p95/p99 latencies, counts by dimension
  - [x] 2.4 Create `Handler() http.HandlerFunc` serving metrics as JSON at `/debug/metrics`

- [x] Task 3: Wire metrics into request lifecycle (AC: #1, #2)
  - [x] 3.1 Instantiate `MetricsCollector` in `main.go` and pass to logging middleware
  - [x] 3.2 Call `collector.RecordRequest(...)` in logging middleware after response completes (same place as the slog.Info call)
  - [x] 3.3 Register `/debug/metrics` endpoint behind auth middleware
  - [x] 3.4 Verify zero PII in metrics output — only aggregate counts and latencies, no deviceId or content

- [x] Task 4: Integrate Sentry for error tracking and performance monitoring (AC: #1)
  - [x] 4.1 Add `github.com/getsentry/sentry-go` and `github.com/getsentry/sentry-go/http` dependencies
  - [x] 4.2 Initialize Sentry in `main.go` using existing `cfg.SentryDSN` config field, with tracing enabled at 20% sample rate, skip /health traces
  - [x] 4.3 Add `sentryhttp.Handler` wrapping the mux (outermost middleware, before logging)
  - [x] 4.4 Add `defer sentry.Flush(2 * time.Second)` before graceful shutdown
  - [x] 4.5 Set Sentry tags in chat handler: tier, provider, mode
  - [x] 4.6 Capture provider errors as Sentry events with context (provider name, error type, failover status)

- [x] Task 5: Enhance health check endpoint (AC: #3)
  - [x] 5.1 Update `handlers/health.go` to include commit SHA from `RAILWAY_GIT_COMMIT_SHA` env var and uptime duration
  - [x] 5.2 Create `server/railway.toml` with healthcheck config: path `/health`, timeout 60s, overlap 10s, draining 30s

- [x] Task 6: Compliance logging for safety events (AC: #1)
  - [x] 6.1 Verify existing compliance logging in chat handler covers all safety levels (it currently logs non-green only — extend log to Info level for all safety classifications including green, per architecture spec)
  - [x] 6.2 Add slog group `"compliance"` to safety event logs to distinguish from operational logs
  - [x] 6.3 Ensure compliance logs are append-only structured events: timestamp, deviceId (hashed), safetyLevel, provider, mode — no conversation content

- [x] Task 7: Testing (AC: #1, #2, #3)
  - [x] 7.1 Unit test `MetricsCollector`: increment counters, observe latencies, verify p50/p95/p99 calculations, verify by-provider and by-tier breakdowns
  - [x] 7.2 Unit test `/debug/metrics` handler returns valid JSON with expected structure
  - [x] 7.3 Integration test: send chat request through middleware chain, verify slog output contains all analytics fields (provider, tier, latency, status, safetyLevel)
  - [x] 7.4 Integration test: verify `/debug/metrics` endpoint requires authentication
  - [x] 7.5 Unit test: verify health endpoint returns commit SHA and status
  - [x] 7.6 Verify no PII leakage: assert analytics logs and metrics contain no deviceId in plaintext, no message content, no user profile data
  - [x] 7.7 Test Sentry initialization with mock DSN (verify no panic on empty DSN)

## Dev Notes

### Current Server Architecture

The backend proxy is a Go 1.23+ `net/http` server deployed on Railway. Key files:

| Component | File |
|-----------|------|
| Entry point | `server/main.go` |
| Logging middleware | `server/middleware/logging.go` |
| Auth middleware | `server/middleware/auth.go` |
| Tier middleware | `server/middleware/tier.go` |
| Guardrails middleware | `server/middleware/guardrails.go` |
| Chat handler | `server/handlers/chat.go` |
| Health handler | `server/handlers/health.go` |
| Config | `server/config/config.go` |
| Provider interface | `server/providers/provider.go` |

### Middleware Composition Order (Architectural Constraint)

```
LoggingMiddleware -> SentryMiddleware -> [mux]
  Protected routes: AuthMiddleware -> TierMiddleware -> GuardrailsMiddleware -> Handler
```

Logging is outermost to capture everything. Sentry wraps inside logging to capture panics. Auth → Tier → Guardrails → Handler for protected routes. **Do NOT change this order** — reversing tier and guardrails produces subtle bugs.

### What Already Exists

- **slog JSON handler** configured in `main.go` line 25: `slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))`
- **LogFields struct** in `middleware/logging.go` — currently only carries `DeviceID`. Extend this, don't replace.
- **Request lifecycle logging** — logs method, path, status, duration, deviceId. Enhance with provider, tier, mode, safetyLevel.
- **Compliance logging** in `handlers/chat.go` lines 306-319 — logs non-green safety levels. Extend to all levels.
- **Provider failover logging** at Warn level in `handlers/chat.go` lines 64, 85.
- **SentryDSN config field** in `config/config.go` line 17 — loaded from env but NOT yet used. Sentry SDK is NOT in go.mod yet.
- **Health endpoint** at `/health` returns `{"status":"ok"}` — enhance, don't replace.
- **Graceful shutdown** with 30s timeout on SIGTERM/SIGINT — add Sentry flush before shutdown.

### What Does NOT Exist

- No in-process metrics collection (counters, histograms)
- No `/debug/metrics` endpoint
- No Sentry SDK dependency or initialization
- No `railway.toml` configuration file
- No per-request analytics fields beyond deviceId in LogFields
- No safety-level tracking in metrics

### Architecture Compliance

- **slog structured JSON** — all logging MUST use `slog` with structured fields. Never `fmt.Println` or `log.Println`.
- **Wire format**: camelCase JSON, ISO 8601 dates, lowercase snake_case enums, omit null fields.
- **No PII server-side** — analytics must track operational metrics only. DeviceID in compliance logs should be hashed. No conversation content ever.
- **Zero-retention** — no conversation content stored. Analytics are aggregate operational data only.
- **Middleware order** — logging outermost, then sentry, then auth → tier → guardrails → handler.
- **In-memory metrics** — MVP uses in-process counters (no Prometheus/Grafana). Data resets on restart — acceptable at MVP scale.

### Library/Framework Requirements

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `log/slog` | stdlib (Go 1.21+) | Structured JSON logging — already in use |
| `sync/atomic` | stdlib | Thread-safe counters for metrics |
| `github.com/getsentry/sentry-go` | v0.44.1 | Error tracking + performance monitoring |
| `github.com/getsentry/sentry-go/http` | v0.44.1 | net/http middleware integration |

No other new dependencies. Metrics collector uses only stdlib (`sync`, `sync/atomic`, `sort`, `encoding/json`).

### File Structure

New files to create:
```
server/metrics/
├── collector.go          # MetricsCollector with counters, histogram, snapshot
└── collector_test.go     # Unit tests for metrics collection

server/railway.toml       # Railway deployment config (healthcheck, zero-downtime)
```

Modified files:
```
server/main.go                    # Init Sentry, create MetricsCollector, register /debug/metrics
server/middleware/logging.go       # Extend LogFields, add provider/tier/safety to completion log, call metrics.RecordRequest
server/middleware/auth.go          # Populate LogFields.Tier from claims
server/middleware/tier.go          # Populate LogFields.Provider from selected provider
server/handlers/chat.go            # Populate LogFields.SafetyLevel, Mode, FailoverOccurred; set Sentry tags
server/handlers/health.go          # Add commit SHA and uptime to response
server/go.mod / go.sum             # Add sentry-go dependencies
```

### Testing Standards

- Go standard `testing` package + `net/http/httptest` for integration tests
- Test file naming: `*_test.go` in same package
- Table-driven tests preferred for metrics edge cases
- No mocking frameworks — use interfaces and test doubles
- Verify structured log output by capturing slog handler output in tests

### What NOT To Do

- **Do NOT add Prometheus, Grafana, DataDog, or any external metrics infrastructure** — MVP uses in-process metrics + Railway built-in monitoring + Sentry
- **Do NOT create a custom admin dashboard** — deferred to Phase 2. Use `/debug/metrics` JSON endpoint + Railway dashboard + Sentry for now
- **Do NOT store conversation content in analytics** — operational metrics only
- **Do NOT add client-side (iOS) analytics in this story** — this is server-side only
- **Do NOT add OpenTelemetry or distributed tracing** — overkill for MVP single-service architecture
- **Do NOT persist metrics to disk** — in-memory is fine, resets on deploy are acceptable
- **Do NOT log raw deviceId in analytics output** — hash it for compliance logs, omit from metrics entirely
- **Do NOT change the middleware composition order** — auth → tier → guardrails → handler

### Previous Story Intelligence (Story 10.4)

- **Code review pattern**: One commit per story with review fixes included. Follow same pattern.
- **Test ratio**: Recent stories have 40%+ test code. Maintain similar ratio.
- **Project conventions**: Swift Testing (`@Test`) for iOS, Go `testing` package for server. No external test frameworks.
- **Pre-existing flaky tests**: 3 SSEParser/ChatEventCodable fixture count mismatches — not related to this story, ignore if they appear.
- **Widget refresh calls**: `WidgetCenter.shared.reloadAllTimelines()` was added in multiple view models. Not relevant to this server-side story.

### Git Intelligence

Recent commit pattern: single commit per story with descriptive message format `feat: Story X.Y — [description] with code review fixes`. Follow this pattern.

Files from recent Epic 10 work:
- 10.1: Multi-provider failover — established provider chain and failover logging patterns in `handlers/chat.go`
- 10.2: Offline mode — added `ConnectivityMonitor`, message delivery status, database migration v17
- 10.3: Offline sprint step completion — sync status pattern, migration v19
- 10.4: Home screen widgets — WidgetKit extension, read-only DB access pattern

### Key Analytics Dimensions to Track

Per acceptance criteria and architecture spec, the following must appear in slog JSON output on every chat request completion:

| Field | Source | slog Key |
|-------|--------|----------|
| Request count | Logging middleware | (implicit — each log line = 1 request) |
| Latency (ms) | Logging middleware timing | `duration_ms` |
| Provider used | Tier middleware selection | `provider` |
| Subscription tier | Auth middleware claims | `tier` |
| Safety level | Chat handler response | `safetyLevel` |
| Coaching mode | Chat request payload | `mode` |
| HTTP status | Response writer wrapper | `status` |
| Failover occurred | Chat handler failover path | `failoverOccurred` |

### Cost Tracking Context

- Free tier: ~$0.015/user/month LLM cost
- Paid tier: significantly higher (model routing to premium models)
- At 10K users: $2-5K/month LLM costs
- Metrics by tier enable cost-per-tier tracking without storing per-user costs
- Provider comparison enables cost optimization decisions

### Coaching Quality Observability Signals (Phase 2 Foundation)

This story lays groundwork for future observability (not in scope but design for extensibility):
- Conversation length trends (derivable from request count per device over time)
- Mode distribution (tracked in mode dimension)
- Provider performance comparison (tracked in provider + latency dimensions)
- Safety classification distribution (tracked in safetyLevel dimension)

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 10, Story 10.5]
- [Source: _bmad-output/planning-artifacts/architecture.md — Backend Proxy Scope, Logging Standards, Middleware Composition, Wire Format]
- [Source: _bmad-output/planning-artifacts/prd.md — FR66, NFR30, Solo Dev Ops Journey, Measurable Outcomes]
- [Source: _bmad-output/planning-artifacts/architecture.md — Testing Approach table, Go Testing standards]
- [Source: server/middleware/logging.go — Existing LogFields and LoggingMiddleware]
- [Source: server/handlers/chat.go — Existing compliance logging, failover logging]
- [Source: server/config/config.go — SentryDSN field already defined]
- [Source: docs/api-contract.md — API endpoint specifications]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- All tests pass: `go test -count=1 ./...` — 0 failures across all packages

### Completion Notes List
- Task 1: Extended `LogFields` with Tier, Provider, SafetyLevel, Mode, FailoverOccurred. Updated auth middleware to populate Tier, tier middleware to populate Provider, chat handler to populate SafetyLevel/Mode/FailoverOccurred. `LoggingMiddleware` now logs all analytics fields including `duration_ms`.
- Task 2: Created `metrics/collector.go` with atomic counters, ring-buffer histogram, sync.Map dimension counters, `RecordRequest()`, `Snapshot()` with p50/p95/p99, and `Handler()` serving JSON.
- Task 3: Instantiated `MetricsCollector` in `main.go`, passed to `LoggingMiddleware` (signature changed to accept `*metrics.Collector`), registered `/debug/metrics` behind auth. No PII in metrics output — only aggregate counts.
- Task 4: Added `sentry-go` v0.44.1 dependencies. Initialized Sentry with 20% trace sampling (skipping /health), sentryhttp wrapping mux inside logging middleware. Added `sentry.Flush` before shutdown. Set Sentry tags (tier, provider, mode) in chat handler. Provider errors captured as Sentry events with context.
- Task 5: Enhanced health endpoint with uptime and `RAILWAY_GIT_COMMIT_SHA`. Updated `railway.toml` with timeout 60s, overlap 10s, draining 30s for zero-downtime deploys.
- Task 6: Extended compliance logging to all safety levels (including green). Added slog group "compliance" for structured distinction. DeviceID hashed with SHA-256 (truncated to 8 bytes) in compliance logs.
- Task 7: 16 unit tests for MetricsCollector (counters, percentiles, breakdowns, concurrency, ring buffer, handler JSON). 5 integration tests (metrics auth, health uptime/commitSHA, no-PII verification, Sentry empty DSN).

### Change Log
- 2026-04-04: Story 10.5 implementation complete — all 7 tasks implemented with tests
- 2026-04-04: Code review fixes — M1: added LogFields population to handleSummarize/handleSprintRetro; M2: added providerUsed to failoverResult so analytics/Sentry/compliance track actual provider (not just primary); M3: rewrote TestSentryInitWithEmptyDSN to actually call sentry.Init; M4: added TestChatRequestSlogAnalyticsFields verifying slog output; L1: added error handling to metrics Handler json.Encode

### File List
- server/metrics/collector.go (new)
- server/metrics/collector_test.go (new)
- server/middleware/logging.go (modified)
- server/middleware/auth.go (modified)
- server/middleware/tier.go (modified)
- server/handlers/chat.go (modified)
- server/handlers/health.go (modified)
- server/main.go (modified)
- server/railway.toml (modified)
- server/go.mod (modified)
- server/go.sum (modified)
- server/tests/handlers_test.go (modified)
