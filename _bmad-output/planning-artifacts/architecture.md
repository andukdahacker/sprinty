---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
workflow_completed: true
lastStep: 8
status: 'complete'
completedAt: '2026-03-16'
inputDocuments:
  - '_bmad-output/planning-artifacts/product-brief-ai_life_coach-2026-03-15.md'
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/research/market-ai-life-coaching-apps-research-2026-03-15.md'
  - '_bmad-output/planning-artifacts/research/domain-coaching-psychology-gamification-ai-safety-research-2026-03-15.md'
  - '_bmad-output/planning-artifacts/research/technical-local-llm-vs-cloud-for-ios-coaching-research-2026-03-15.md'
  - '_bmad-output/brainstorming/brainstorming-session-2026-03-14-1610.md'
  - '_bmad-output/brainstorming/brainstorming-session-2026-03-15-1400.md'
workflowType: 'architecture'
project_name: 'ai_life_coach'
user_name: 'Ducdo'
date: '2026-03-16'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements (80 FRs across 16 areas):**

The requirements describe a conversation-driven AI coaching system with four architectural pillars:

1. **AI Coaching Engine (FR1-FR10, FR39, FR77)** — Multi-turn streaming conversations with mode switching (Discovery/Directive), inline safety classification, pattern surfacing from memory, Challenger capability, and Autonomy Throttle. The coaching system prompt is the most complex single artifact in the system — it implements 17+ FRs and NFRs simultaneously.

2. **Persistent Intelligence Layer (FR11-FR15)** — On-device RAG system: post-conversation summarization → vector embeddings → semantic retrieval on next conversation start. Structured JSON profiles for stable facts. Backend domain tagging. Must handle irregular engagement patterns (days to weeks between sessions).

3. **Goal Execution Framework (FR16-FR22, FR34-FR38)** — Sprint-based goal tracking with configurable cadence, daily/weekly check-ins, Pause Mode with Drift Detection, and AI-suggested breaks. Lightweight enough for single action items, structured enough for multi-week sprints.

4. **Platform & Infrastructure (FR53-FR67, FR68-FR72)** — Backend proxy for model routing/failover/guardrails, StoreKit 2 subscription management, WidgetKit integration, offline capability with sync queuing, push notification orchestration (hard cap 2/day with priority ordering).

**Load-Bearing FR Clusters:**

Not all requirements carry equal architectural weight. The following clusters are foundational — if they underperform, downstream features collapse:

| Cluster | FRs | What Depends On It |
|---------|-----|-------------------|
| **Memory Pipeline** | FR11-FR15 | FR6 (pattern surfacing), FR10 (tone adaptation), FR15 (long-gap retrieval), FR77 (Autonomy Throttle), FR78 (engagement source tracking) |
| **Coaching Engine + System Prompt** | FR3-FR8, FR10, FR39 | All coaching quality, safety classification, mode switching, Challenger — the entire product experience |
| **Backend Proxy** | FR63-FR67 | Every coaching conversation, subscription enforcement, model routing, failover |
| **Streaming Pipeline** | FR2, FR74 | Perceived responsiveness, mid-conversation recovery, user trust |

Additive clusters (valuable but not load-bearing): Widgets (FR68-69), Avatar animations (FR30-33), Push notifications (FR46-52), Pause Mode AI suggestion (FR35).

**Non-Functional Requirements (38 NFRs across 6 categories):**

Architecture-driving NFRs:

| Category | Key NFRs | Architectural Impact |
|----------|----------|---------------------|
| **Performance** | TTFT < 1.5s, RAG < 500ms, 60fps animations | Streaming SSE pipeline, SQLite query optimization, Lottie rendering budget |
| **Security** | On-device encryption, no keys in binary, zero-retention providers, append-only compliance logs | Split data architecture, backend proxy as sole cloud gateway, audit infrastructure |
| **Scalability** | 10K embeddings/user, 10x user growth, provider-agnostic backend | SQLite-vec performance ceiling, horizontal proxy scaling, abstraction layers |
| **Accessibility** | VoiceOver, Dynamic Type, Reduce Motion, WCAG AA contrast, cultural adaptability | SwiftUI accessibility tree, animation fallbacks, system prompt cultural awareness |
| **Reliability** | 99.5% availability, seamless network transitions, mid-conversation recovery, iCloud backup support | Multi-provider failover, conversation state persistence, data migration strategy |
| **Integration** | 2+ LLM providers, StoreKit 2, APNs, Sentry, Railway zero-downtime deploys | Provider abstraction, receipt validation pipeline, crash reporting, deploy hooks |

**Scale & Complexity:**

- **Primary domain:** Native iOS (Swift/SwiftUI) + backend service (Railway)
- **Complexity level:** High
- **Estimated architectural components:** 12-15 distinct modules
- **Solo developer constraint** shapes every decision — simplicity and boring technology over elegance

### Technical Constraints & Dependencies

1. **Cloud-first inference** — All coaching conversations require internet; on-device LLM deferred to Phase 2 evaluation. The technical research confirmed cloud is the right MVP path.
2. **Apple ecosystem** — iOS 17+ minimum (SwiftUI, WidgetKit, StoreKit 2, APNs, Keychain, Data Protection are all Apple-native dependencies)
3. **SQLite + sqlite-vec** — Niche extension; primary risk is memory usage and query performance at scale. No fallback — this is the only local vector DB option that fits. **Requires a performance benchmark harness as a Week 1 deliverable** — generate 10K synthetic embeddings, measure query latency and memory at 1K/5K/10K thresholds to establish the ceiling before committing.
4. **Railway backend** — Chosen over Cloudflare Workers for proper logging, Sentry integration, and pre-deploy hook support (safety regression gate)
5. **LLM provider agreements** — Zero-retention clauses required contractually. Model quality gap between free/paid tiers must be validated in Week 2.
6. **Solo developer reality** — Cut order defined (Widgets → Pause AI suggestion → Sprint viz simplification → Avatar animations). Architecture must support incremental delivery.
7. **Data migration strategy** — Schema will evolve as the product matures. **Versioned SQLite migrations must be built from day one** or existing users' data bricks on every update.
8. **AnyLanguageModel abstraction scope** — For MVP, this is a **protocol with one concrete implementation** (CloudProvider via backend proxy). The abstraction exists as an interface boundary for Phase 2 extensibility, not as a runtime polymorphism layer.
9. **Cost scalability** — Technical research estimated ~$0.015/user/month for free tier; paid-tier costs scale significantly higher. At 10K users, LLM costs become material ($2-5K/month). **Soft guardrails serve dual purpose: product design and cost control.** The backend proxy needs cost-aware usage tracking from the start.
10. **Apple Privacy Manifest and iCloud backup** — App Store submission requires an Apple Privacy Manifest with explicit data collection declarations. NFR36 requires iCloud backup support with a user-facing option to exclude coaching data. The iCloud decision affects data encryption strategy — data must either be re-encryptable for iCloud transport or explicitly excluded. Both are submission blockers if missed.

### Cross-Cutting Concerns

Concerns are tiered by the level of design attention they require. A solo developer should focus architectural energy on Tier 1, make explicit decisions for Tier 2, and resolve Tier 3 during implementation.

Each concern is framed at the "identify and frame" level. Specific resolution belongs in the architecture decision steps that follow.

#### Tier 1 — Architectural Foundations

These shape the system's core structure. Must be designed up front; getting them wrong is expensive to fix.

**Delivery note:** Not all Tier 1 concerns require full resolution before coding starts.
- **Blocking (resolve in Weeks 1-2)** — Must have a concrete decision before dependent code begins
- **Evolved (start simple, refine during implementation)** — Initial decision sufficient; complexity addressed iteratively

**1. Safety classification pipeline** `[Evolved]` — Inline in coaching response → drives UI state → triggers compliance logging → affects notification suppression → feeds automated regression gate. Touches 7+ FRs across 4 capability areas. **Known risk acceptance:** MVP uses single-path inline classification — a single point of failure with the regression suite as compensating control. Phase 2 hardens to dual-path. This trade-off is deliberate and must be documented. *Start with inline approach; evolve pipeline mechanics as failure modes emerge.*

**2. Memory pipeline reliability** `[Evolved]` — Multi-step async pipeline (summarize → embed → store → retrieve) with failure points at each stage — app backgrounding, embedding failure, SQLite write failure. Needs a reliability strategy. *Start best-effort with idempotent retry on next launch; add transactional guarantees if silent failures prove problematic.*

**3. Streaming response rendering** `[Evolved]` — SSE parsing → incremental SwiftUI text → safety level extraction → UI state update. Must handle mid-stream failures, provider failover, and app lifecycle transitions. SwiftUI incremental text rendering carries layout thrashing risk. *Requires Week 2 spike to validate approach; iterate from simplest working implementation.*

**4. Backend proxy scope and API contract** `[Blocking]` — Carries 7+ responsibilities: API key protection, model routing, guardrail enforcement, multi-provider failover, usage analytics, compliance logging, system prompt serving, cost tracking. This is a real backend service. *API contract (endpoints, schemas, error responses, fallback behavior) must be defined before Week 3 coaching engine work begins.*

**5. Unified app state and experience model** `[Evolved]` — Multiple overlapping state dimensions (online/offline, free/paid, coaching/paused, safety level, coaching mode, sprint state) combine into user-facing contexts (active, celebrating, crisis, resting, cold start). One unified state system that all UI layers subscribe to. *Start with simple enum; evolve as state dimensions come online through the build schedule.*

**6. Error taxonomy** `[Blocking]` — Four failure categories requiring different architectural responses: recoverable (provider failover), degraded-mode (proceed without full capability), hard (graceful error UI), silent (no visible error, accumulated data gaps). *Define categories and expected behaviors before coding; every error path during implementation references this taxonomy.*

**7. Monetization / quality-gradient architecture** `[Blocking]` — The business model rests on perceived depth difference between free and paid tiers. Architecture must resolve: how tiers differ at the system prompt level, where guardrail enforcement lives, how Directive Mode gating works, and what happens when the proxy is unreachable. *Must be resolved before proxy API contract and system prompt design. Week 2 model benchmark depends on these decisions.*

#### Tier 2 — Design-Time Decisions

Need an explicit decision documented in the architecture. Implementation is straightforward once decided.

**8. System prompt configuration and composition** — The prompt must be versioned, backend-served, and independently deployable. A modular composition approach (persona, modes, safety, context injection points) enables targeted iteration and debugging. Versioning semantics (active conversation handling on rollback, caching/TTL) must be decided alongside. *Resolved in architecture decisions.*

**9. Online/offline state management** — Two operational modes (full coaching vs read-only + sprint updates). Detection, transition, sync conflict resolution, and UI indicator behavior need explicit decisions.

**10. Subscription tier awareness** — Model routing, feature gating, guardrail enforcement, transition messaging. Decision needed: where tier logic lives (proxy, app, or both) and graceful degradation.

**11. Cold-start bootstrap** — First conversation is architecturally distinct: zero RAG context, profile creation, first embedding, onboarding mode. Needs distinct handling in both the system prompt and memory pipeline.

**12. App lifecycle and conversation continuity** — iOS backgrounding drops SSE connections mid-conversation. Decisions needed: what conversation state to persist, partial response handling, resume vs restart semantics.

**13. Conversation data model** — Message schema, session boundaries, metadata structure, and how different interaction types (deep conversation, check-in, onboarding) map to a unified model. Foundational schema affecting storage, rendering, summarization, and analytics.

**14. Discovery-to-Directive transition signal** — Coaching psychology research shows directive advice requires accumulated understanding (3-5 deep sessions). The system needs a trust readiness signal per domain to inform mode transition. Decision: what constitutes readiness and how the signal flows from memory into the system prompt.

**15. Embedding model choice** — Affects index size, retrieval quality, pipeline latency, and Phase 2 migration (changing models means regenerating all embeddings). Pick early, benchmark against sqlite-vec harness, commit.

#### Tier 3 — Implementation Details

Resolved during coding, not requiring up-front architectural design.

**16. Coach persona consistency** — System prompt implementing 17+ requirements. Resolved through prompt engineering iteration; modular composition (Tier 2 #8) enables targeted work.

**17. Coach identity propagation** — User-given coach name stored in profile, injected into prompt, displayed in UI. Standard data flow.

**18. Polymorphic conversation UI** — Chat view supporting 4+ interaction modes. Resolved through SwiftUI view composition patterns.

**19. Non-deterministic testing framework** — Coaching quality evaluation beyond safety regression. Define benchmark prompts, quality criteria, and run frequency. Safety gate needs a provider-down fallback.

**20. Compliance infrastructure** — Append-only logging with audit trail. Storage location, retention policy, query capability. Structured logging to persistent store.

**21. Safety test data governance** — Sensitive test fixtures in private repo or access-controlled file at MVP scale. Formal governance deferred to Phase 2.

**22. Coaching quality observability** — Lightweight analytics signals: conversation length trends, mode distribution, session source ratio, RAG hit rate. Ensure data flows exist in proxy and app; build visibility when needed.

**23. Summary schema strategy** — Pre-populate empty Phase 2 fields in MVP schema vs add via migration later. Minor decision touching data migration strategy.

### Testability Landscape

Understanding what's testable and how informs module boundary decisions in later architecture steps.

| Testing Approach | Components | Implication |
|-----------------|------------|-------------|
| **Unit testable** | SQLite operations, data models, state machine transitions, subscription logic, offline sync queue, embedding storage/retrieval, schema migrations | These modules need clean interfaces and dependency injection — design for testability |
| **Integration testable** | Backend proxy API contract, SSE streaming pipeline, StoreKit receipt validation, multi-provider failover, push notification delivery | Need contract tests or staging environments; proxy API contract (Tier 1 #4) enables this |
| **Benchmark testable** | Safety regression suite (50+ prompts), coaching quality benchmarks, RAG retrieval quality, model quality gap validation | Non-deterministic; scheduled runs with quality thresholds, not pass/fail assertions |
| **Manual only** | Avatar animations, onboarding UX flow, notification timing/tone, home screen emotional context, Lottie performance on older devices | Cannot be automated at MVP; inform which components can be "good enough" vs pixel-perfect |

## Starter Template Evaluation

### Primary Technology Domain

**Native iOS (Swift/SwiftUI) + Go backend service** — based on PRD requirements for premium coaching UX with native polish, and a backend service handling LLM orchestration with concurrent streaming connections.

### Repository Strategy

**Monorepo** with two top-level directories. For a solo developer, one repo means one git log, one search scope, shared documentation, and a single source of truth for the API contract between iOS and server.

```
ai-life-coach/
├── ios/                          # Xcode project root
├── server/                       # Go module root
├── docs/
│   └── api-contract.md           # Shared API contract (SSE format, schemas, errors)
├── _bmad-output/                 # Planning artifacts (existing)
└── README.md
```

Railway is configured to watch the `server/` subdirectory for deploys. Xcode project lives at `ios/ai_life_coach.xcodeproj`.

### Local Development Workflow

- **Daily development:** iOS Simulator hits `localhost:8080` (Go server running locally)
- **Device testing:** Railway staging environment URL
- **Environment switching:** Single environment variable in iOS app for server URL (`COACH_API_URL`), toggled by Xcode scheme (Debug → localhost, Staging → Railway)

### Starter Options Considered

#### iOS App

| Option | Verdict |
|--------|---------|
| **Xcode SwiftUI App template** | Standard starting point. Minimal but correct — `@main` App struct, WindowGroup, asset catalogs. No architectural opinions imposed. |
| Third-party iOS starter templates | Limited ecosystem; most are opinionated toward specific architectures (TCA, Clean) or outdated. Not recommended for MVVM. |
| Custom Xcode template | Over-engineering for a solo developer. |

**Decision:** Xcode default SwiftUI App template with manual MVVM project structure.

#### Backend Service

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Go + `net/http` std lib** | Zero dependencies, official LLM SDKs (Anthropic + OpenAI), built-in SSE via `Flusher`, goroutine concurrency, single binary deploy (~15MB), near-instant cold starts, lowest memory/cost on Railway | Requires Go knowledge | **Selected** |
| Go + Chi | Clean middleware chaining, zero transitive deps | Unnecessary — Go 1.22+ ServeMux covers routing needs | Good but not needed |
| Hono + TypeScript | Built-in SSE helper, familiar JS ecosystem, all LLM SDKs | Heavier runtime (~100MB+), higher memory, slower cold starts | Strong alternative if Go is unfamiliar |
| Fastify + TypeScript | Mature, rich plugins | Heavier than needed | Over-engineered |
| Python (FastAPI) | Good LLM SDK support | Slower runtime, GIL, heavier deploy | Not ideal for this workload |

### Selected Starters

#### iOS: Xcode SwiftUI App Template + MVVM Structure

**Initialization:**

```
Xcode → New Project → App → SwiftUI → ai_life_coach (inside ios/ directory)
```

**Architectural Decisions:**

- **Language & Runtime:** Swift 6.x, iOS 17+ deployment target
- **UI Framework:** SwiftUI with @Observable macro (iOS 17+)
- **Architecture:** MVVM — feature-based folder organization
- **Concurrency:** Swift structured concurrency (async/await, AsyncSequence, actors). No Combine dependency.
- **Package Management:** Swift Package Manager
- **Testing:** Swift Testing (`@Test` macro) for unit tests, XCTest for UI and integration tests. Both coexist in the same test target.

**Project Structure Convention:**

```
ios/ai_life_coach/
├── App/                          # App lifecycle (@main, AppState)
├── Features/
│   ├── Coaching/                 # Conversation engine UI
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   ├── Sprint/                   # Goal/sprint framework (display + tracking)
│   ├── Home/                     # Home screen + avatar
│   ├── Onboarding/               # 4-step onboarding flow
│   ├── Settings/                 # Preferences, coach name, privacy
│   └── Widgets/                  # WidgetKit extension
├── Services/
│   ├── Networking/               # API client, SSE streaming, AnyLanguageModel protocol
│   ├── Memory/                   # RAG pipeline, SQLite + sqlite-vec, MemoryService
│   ├── Database/                 # SQLite manager, migrations, schema
│   ├── Safety/                   # Safety level handling, UI state response
│   ├── Subscription/             # StoreKit 2, tier management
│   └── Notifications/            # APNs, notification orchestration
├── Core/
│   ├── State/                    # Unified AppState, experience model
│   ├── Extensions/               # Swift/SwiftUI extensions
│   └── Utilities/                # Helpers, constants
├── Resources/
│   ├── Assets.xcassets
│   └── Animations/               # Lottie JSON files
└── Tests/
    └── Mocks/                    # Mock service implementations for unit tests
```

**Structural Notes:**

- **Services/ is flat for MVP.** If it grows painful, split into `Services/` (external integrations: networking, subscription, notifications), `Data/` (local persistence: database, memory/RAG, migrations), and `Domain/` (business rules: safety logic, experience state, tier behavior). This split aligns with the testability landscape — Data and Domain are unit testable, Services are integration testable.
- **Coaching → Sprint dependency is directional.** Sprint creation happens inside coaching conversations (the coach suggests a sprint, user agrees, it's created). Sprint *display* is a separate feature (home screen progress). The dependency flows one way: Coaching creates sprints, Sprint displays them and feeds context back into coaching. Sprint creation logic lives in Coaching, sprint viewing/tracking lives in Sprint.
- **SwiftUI previews are a productivity multiplier.** Each feature's Views use `#Preview` with mock data to render different states (Green/Yellow/Orange conversations, streaming, offline, check-in mode, onboarding) without booting the full stack. For the polymorphic conversation UI especially, being able to preview all interaction modes accelerates development significantly.

**iOS Dependency Decisions (Early — Week 1):**

| Dependency | Purpose | Status |
|-----------|---------|--------|
| **sqlite-vec** | Vector embeddings for RAG | **Risk — requires Week 1 spike.** iOS can't load dynamic SQLite extensions (sandbox restriction). Requires custom SQLite build with sqlite-vec compiled as a static library. Integration path: SPM wrapper (if maintained), manual C compilation, or via GRDB.swift which supports custom SQLite builds. This is a build configuration risk that could burn days if not spiked early. |
| **GRDB.swift** (or raw SQLite) | Swift SQLite interface | **Decision needed alongside sqlite-vec.** GRDB provides Swift-native SQLite access, custom build support, WAL mode, migrations, and query builder. If sqlite-vec integration requires a custom SQLite build, GRDB likely simplifies the path. Alternatively, raw C bindings work but are more manual. |
| **Lottie** (`lottie-ios`) | Avatar animations | SPM package, straightforward integration |
| **Sentry** (`sentry-cocoa`) | Crash reporting, performance | SPM package, straightforward integration |

#### Backend: Go + Standard Library on Railway

**Initialization:**

```bash
cd server/
go mod init github.com/ducdo/ai-life-coach/server
go get github.com/anthropics/anthropic-sdk-go
go get github.com/openai/openai-go/v3
go get github.com/getsentry/sentry-go
```

**Architectural Decisions:**

- **Language & Runtime:** Go 1.23+ (leverages Go 1.22+ enhanced `ServeMux` routing)
- **Framework:** None — `net/http` standard library only
- **Routing:** `ServeMux` with method matching and path variables (Go 1.22+)
- **Streaming:** Native SSE via `http.Flusher` interface
- **LLM SDKs:** `anthropics/anthropic-sdk-go` (official), `openai/openai-go` (official)
- **Monitoring:** `sentry-go`
- **Deployment:** Railway watching `server/` subdirectory — single binary via multi-stage Docker build, zero-downtime deploys
- **Testing:** Go standard `testing` package + `httptest` for integration tests
- **Pre-deploy gate:** Safety regression suite (see execution notes below)
- **External dependencies:** 3 total (two LLM SDKs + Sentry)

**Project Structure Convention:**

```
server/
├── main.go                       # Entry point, route registration, server startup
├── handlers/
│   ├── chat.go                   # Coaching conversation endpoint (SSE streaming)
│   ├── prompt.go                 # System prompt serving endpoint
│   └── health.go                 # Health check
├── providers/
│   ├── provider.go               # LLM provider interface (architectural core — see note)
│   ├── anthropic.go              # Anthropic implementation
│   └── openai.go                 # OpenAI implementation
├── middleware/
│   ├── auth.go                   # Request authentication
│   ├── tier.go                   # Subscription tier routing
│   ├── guardrails.go             # Soft guardrail enforcement
│   └── logging.go                # Usage analytics + compliance logging
├── prompts/
│   └── versions/                 # Versioned system prompt files
├── config/
│   └── config.go                 # Provider configuration, failover order, env vars
├── tests/
│   ├── safety/                   # Safety regression test suite (50+ prompts)
│   └── handlers_test.go          # API contract tests (httptest)
├── Dockerfile                    # Multi-stage build → alpine-based minimal image
├── go.mod
└── go.sum
```

**Implementation Notes:**

- **`providers/provider.go` is the architectural core of the server.** The `Provider` interface defines the central abstraction — everything else (handlers, middleware, failover) depends on it. Getting this interface right (streaming channel type, error handling, context cancellation) determines whether the server is clean or tangled. Design it first.

- **Dockerfile must use `alpine` (not `scratch`)** for the final stage. The server makes outbound HTTPS calls to LLM providers, which requires CA certificates. `scratch` has no certs bundle. Use `FROM alpine:latest` or explicitly copy `/etc/ssl/certs/ca-certificates.crt` from the builder stage.

- **Middleware composition order is an architectural constraint.** With bare `net/http`, middleware nests as function wrapping: `logging(guardrails(tier(auth(handler))))`. Required order: auth (reject unauthorized) → tier (determine model routing) → guardrails (enforce session limits) → logging (capture everything including tier and guardrail decisions). Document this ordering; reversing tier and guardrails produces subtle bugs.

- **Safety regression suite execution:** The 50+ prompt suite sends real requests to LLM providers, taking 2-4 minutes (50 prompts × 2-5s each). Verify Railway's pre-deploy hook timeout accommodates this duration. If Railway's timeout is too short, run the suite in CI (GitHub Actions) and gate the Railway deploy on CI pass instead. Either approach works; the constraint is ensuring no deploy bypasses the safety gate.

- **Safety test data location:** If the repository is private, the `tests/safety/` directory can contain the clinical edge-case prompts inline. If the repo ever becomes public, extract test fixtures to a separate access-controlled location.

### Shared API Contract

**`docs/api-contract.md`** is the single source of truth that bridges the iOS and Go codebases. It defines:

- Request/response JSON schemas for all endpoints
- SSE event format (event name, data structure, safety level field, done signal)
- Error response format (status codes, error body schema)
- Authentication mechanism
- System prompt request/response schema

**Contract-based testing:** Both Go `httptest` tests and iOS networking tests validate against the same SSE event format defined in the contract. When the contract changes, both test suites should break — that's the desired behavior. This catches iOS ↔ server mismatches at test time, not runtime.

**Note:** Project initialization using these commands should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Resolved — were blocking implementation):**
1. Server API contract — endpoints, SSE format, request schema
2. Monetization tier architecture — same prompt, model-based quality gradient, server-enforced guardrails
3. Error taxonomy implementation — 4 categories with concrete HTTP/SSE behavior

**Important Decisions (Resolved — shape architecture):**
4. Data architecture — GRDB, all-MiniLM embeddings, conversation data model, migration approach
5. Authentication & security — Device UUID + JWT, Phase 2 account linking, on-device encryption
6. iOS state management — @Observable AppState, computed ExperienceContext, NavigationStack
7. System prompt configuration — modular composition, content-hash versioning, server-side assembly
8. Infrastructure & deployment — GitHub Actions CI/CD, 3 environments, Railway with CI-gated deploys
9. Push notification scoping — local notifications only at MVP, APNs deferred to Phase 2

**Deferred Decisions (Phase 2+):**
- Apple/Google/Email sign-in (Phase 2 — `/v1/auth/link` endpoint, JWT gains `userId`)
- Cloud RAG sync for cross-device (Phase 2 — depends on user accounts)
- Custom admin dashboard (Phase 2 — provider dashboards sufficient at MVP)
- On-device LLM evaluation (Phase 2 — AnyLanguageModel protocol enables this)
- APNs push notifications (Phase 2 — requires server-side user state)

### Server API Contract

**Endpoints:**

| Endpoint | Method | Purpose | Auth |
|----------|--------|---------|------|
| `POST /v1/chat` | POST | Coaching conversation (SSE streaming) | JWT required |
| `GET /v1/prompt/{version}` | GET | Fetch system prompt version metadata | JWT required |
| `GET /health` | GET | Health check for Railway | None |
| `POST /v1/auth/register` | POST | Device UUID → JWT | None (initial) |
| `POST /v1/auth/refresh` | POST | Old JWT → New JWT | JWT required |

**SSE Event Format:**

```
event: token
data: {"text": "incremental text chunk"}

event: done
data: {"safetyLevel": "green", "domainTags": ["career"], "mood": "warm", "memoryReferenced": false, "degraded": false, "usage": {"promptTokens": 450, "completionTokens": 120}}
```

**Request Format (POST /v1/chat):**

```json
{
  "messages": [],
  "ragContext": [],
  "profile": {},
  "sprintContext": {},
  "mode": "discovery | directive",
  "promptVersion": "abc123hash"
}
```

**Request Payload Management:**
- **Conversation history truncation:** iOS sends only the last N messages (configurable, default ~20-30). Older messages are already captured in RAG summaries — that's the purpose of the memory pipeline. Prevents payload bloat in long conversations.
- **Gzip compression:** Both iOS and server support `Content-Encoding: gzip` on request bodies. Cuts payload size 60-80%. Critical for cellular connections where a 20-turn conversation could otherwise mean 1-2MB of repeated upload.

**Error Response Format (hard failures):**

```json
{
  "error": "provider_unavailable",
  "message": "User-appropriate message",
  "retryAfter": 30
}
```

**Structured Output Streaming Strategy:**

The server is a **streaming JSON parser, not a pass-through.** Each LLM provider returns structured output differently:

| Provider | Structured Output Mechanism |
|----------|---------------------------|
| Anthropic | Tool use — `tool_use` content block with JSON schema |
| OpenAI | `response_format` with JSON schema |
| Gemini | Function calling with structured response |
| Kimi K2 | OpenAI-compatible `response_format` |

The system prompt instructs the model to respond in a schema containing `coaching` (text), `safetyLevel`, `domainTags`, `mood`, and `memoryReferenced`. The server streams the `coaching` field value as `event: token` chunks, holds back metadata until JSON is complete, then emits `event: done` with extracted fields.

**`mood` field:** One of 5 values — `welcoming`, `thinking`, `warm`, `focused`, `gentle`. Drives coach character expression state on iOS. The `thinking` expression is set client-side on message send; `mood` from the `done` event determines the resting expression after response completion. Default if LLM omits: `welcoming`.

**`memoryReferenced` field:** Boolean. When `true`, the LLM's response references a past conversation retrieved via RAG. iOS renders memory-reference turns with italic styling at 0.7 opacity (UX-DR51). VoiceOver announces "Referencing a past conversation."

This parsing complexity lives **inside each provider implementation** — the `Provider` interface returns a clean `ChatEvent` channel (text chunk or done-with-metadata). The chat handler stays simple. This is where the Provider interface earns its architectural weight.

**LLM Providers:**

| Provider | Go SDK | Pattern |
|----------|--------|---------|
| Anthropic | `anthropics/anthropic-sdk-go` | Native SDK |
| OpenAI | `openai/openai-go` | Native SDK |
| Gemini | `google.golang.org/genai` | Native SDK |
| Kimi K2 | `openai/openai-go` + custom base URL | OpenAI-compatible |

Provider failover chain configurable per tier via server config.

### Monetization Tier Architecture

- **System prompt:** Same prompt for all tiers. Quality gap comes from model capability, not different instructions. One prompt to maintain, one regression suite.
- **Soft guardrails:** Server-enforced, app-aware. Server tracks daily session count per device JWT. Returns coaching-style wind-down when limit reached — never an error response. App receives guardrail signal in `done` event for UI treatment.
- **Directive Mode:** No explicit gate. Same prompt, same mode flags across tiers. Weaker free-tier model naturally produces less directive depth. Quality gradient, not feature wall.
- **Tier routing:** JWT `tier` field determines model selection. Server config maps tiers to providers/models.

### Error Taxonomy

| Category | Server Behavior | Signal | iOS Handling |
|----------|----------------|--------|-------------|
| **Recoverable** | Failover to secondary provider | Transparent (optional `event: provider_switch`) | User never notices |
| **Degraded** | Proceed without full context | `"degraded": true` in `done` event | Normal rendering, logged for diagnostics |
| **Hard** | All providers failed / auth failure | HTTP 401, 502, 503 with JSON error body | Graceful error UI, no retry spam |
| **Silent** | N/A (on-device pipeline failures) | No server involvement | Retry on next launch, log gap |

Design principle: Server never exposes raw provider errors to client. All errors translated to taxonomy with user-appropriate messages.

### Data Architecture

**SQLite Wrapper:** GRDB.swift via SPM — handles custom SQLite build for sqlite-vec, provides migrations, WAL mode, Swift-native query API.

**Embedding Model:** all-MiniLM-L6-v2 converted to Core ML (~22MB, 384 dimensions). On-device, free, offline-capable. Benchmarked against sqlite-vec in Week 1 spike.

**App Groups (WidgetKit requirement):** SQLite database must live in the **App Group shared container** from day one, not the default app sandbox. WidgetKit extensions run in a separate process and can only access shared container data. Both the main app and widget extension join the same App Group. Widget reads sprint state and avatar state (read-only). Set up App Groups during Week 1 project initialization — retrofitting later means migrating the database file location for existing users.

**Schema:**

```
ConversationSession
  id: UUID, startedAt: Date, endedAt: Date?, type: enum, mode: enum,
  safetyLevel: enum, promptVersion: String

Message
  id: UUID, sessionId: UUID (FK), role: enum, content: String, timestamp: Date

ConversationSummary
  id: UUID, sessionId: UUID (FK), summary: String, keyMoments: [String],
  domainTags: [String], emotionalMarkers: [String]?, keyDecisions: [String]?,
  goalReferences: [String]?, embedding: [Float] (384-dim), createdAt: Date

UserProfile
  id: UUID, coachName: String, values: [String], goals: [String],
  personalityTraits: [String], domainStates: JSON, createdAt: Date, updatedAt: Date

Sprint
  id: UUID, name: String, startDate: Date, endDate: Date, status: enum

SprintStep
  id: UUID, sprintId: UUID (FK), description: String, completed: Bool,
  completedAt: Date?, order: Int
```

Phase 2 fields (emotionalMarkers, keyDecisions, goalReferences) pre-populated as null — avoids future migration.

**Migration Approach:** GRDB DatabaseMigrator — sequential, versioned, idempotent, runs on every app launch.

### Authentication & Security

**Auth Flow:**
1. First launch: app generates UUID, **stored in Keychain** (persists across reinstall), sends `POST /v1/auth/register`
2. Before registering: app checks `Transaction.currentEntitlements` (StoreKit 2) for existing subscriptions. If found, includes receipt in register request so JWT comes back with correct tier immediately.
3. Server responds with JWT: `{deviceId, userId: null, tier: "free"|"paid", iat, exp}`
4. Subsequent requests: `Authorization: Bearer <jwt>`
5. 30-day expiry, refresh via `POST /v1/auth/refresh`
6. Subscription upgrade: StoreKit receipt → server validates → new JWT with `tier: "paid"`

**Reinstall Resilience:** Device UUID in Keychain survives app deletion/reinstall. Combined with StoreKit entitlement check, a reinstalling user gets their correct identity and tier restored automatically — no "new user" artifact.

**Phase 2 Account Linking:** `POST /v1/auth/link` accepts device JWT + identity token (Apple/Google/Email). Associates device with user account. JWT gains non-null `userId`. No data migration, no forced sign-in, additive changes only. Server middleware checks `userId` first, falls back to `deviceId`.

**On-Device Security:**
- NSFileProtectionComplete on SQLite database
- JWT and device UUID stored in iOS Keychain
- No secrets in app binary — all LLM communication via server

**Server-Side Security:**
- Stateless JWT verification on every request
- In-memory rate limiting per device ID (MVP scale)
- No PII stored server-side
- Compliance logging: event metadata only, no conversation content

### iOS State Management

**AppState (@Observable singleton):**

```swift
@Observable final class AppState {
    var isOnline: Bool
    var tier: Tier              // .free | .paid
    var coachingMode: CoachingMode  // .discovery | .directive
    var safetyLevel: SafetyLevel    // .green | .yellow | .orange | .red
    var activeSprint: Sprint?
    var isPaused: Bool
    var experienceContext: ExperienceContext { /* computed */ }
}

enum ExperienceContext {
    case coldStart, active, celebrating, struggling, crisis, resting
}
```

Injected via SwiftUI environment at App root. Avatar, home screen, notifications, and conversation UI all read `experienceContext`.

**SafetyStateManager:**

Transforms `SafetyLevel` into concrete UI decisions. Lives in `Services/Safety/SafetyHandler.swift` alongside `AppState` updates.

```swift
struct SafetyUIState {
    let level: SafetyLevel
    let themeOverride: SafetyThemeOverride  // saturation/warmth adjustments
    let hiddenElements: Set<HiddenElement>  // .gamification, .sprintProgress, .avatarActivity, .celebrations
    let coachExpression: CoachExpression     // .gentle for Yellow+, .gentle for Orange/Red
    let notificationBehavior: NotificationBehavior // .normal, .safetyOnly, .suppressed
}

enum SafetyThemeOverride {
    case none                    // Green — no change
    case warmthIncrease          // Yellow — subtle warmth + slight desaturation
    case noticeableDesaturation  // Orange — noticeable desaturation
    case significantDesaturation // Red — significant desaturation, minimal UI
}

enum HiddenElement { case gamification, sprintProgress, avatarActivity, celebrations }
```

**Theme transformation rules:**
- Green: No change. Normal coaching continues.
- Yellow: Warmth increase + subtle desaturation. All elements visible. Coach expression → `.gentle`.
- Orange: Noticeable desaturation. Gamification hidden, sprint muted, celebrations suppressed. Crisis resources shown.
- Red: Significant desaturation. All non-essential elements removed. Crisis resources prominent. Emergency resources displayed.

**De-escalation (sticky minimum):** Orange/Red holds for 3 consecutive turns or until 2 consecutive Green classifications from `source: .genuine` (not `.failsafe`). Failsafe classifications (from on-device fallback failures) clear immediately. Sticky state tracked in `SafetyHandler` as `turnsAtElevatedLevel: Int` and `consecutiveGreenCount: Int`.

**Safety always wins:** When safety state conflicts with Pause Mode, coaching mode ambient shifts, or any other visual state, safety overrides all (UX-DR94).

**CoachingTheme & Design Token System:**

```swift
@Observable final class CoachingTheme {
    let palette: ColorPalette       // Home Light, Home Dark, Conversation Light, Conversation Dark
    let typography: TypographyScale // 12 semantic text styles using iOS system sizes
    let spacing: SpacingScale       // 9 semantic tokens on 8pt grid
    let cornerRadius: RadiusTokens  // container 16pt, button 16pt, input 20pt pill, avatar circle, small 8pt

    /// Returns a copy with safety-level theme transformations applied
    func applying(safetyOverride: SafetyThemeOverride) -> CoachingTheme { ... }

    /// Returns a copy with Pause Mode desaturation applied
    func applyingPauseMode() -> CoachingTheme { ... }
}
```

**Token location:** `Core/Theme/CoachingTheme.swift` with palette definitions in `Assets.xcassets/` as semantic colors (supporting light/dark variants natively via asset catalog).

**Injection:** Environment value at App root, computed from `AppState`:

```swift
.environment(\.coachingTheme, themeFor(
    context: appState.experienceContext,
    safetyLevel: appState.safetyLevel,
    isPaused: appState.isPaused
))
```

**Four palettes:**
- Home Light: warm restful (#F4F2EC-#EDE8E0)
- Home Dark: warm dark room (#181A16-#141612)
- Conversation Light: slightly warmer (#F8F5EE-#F0ECE2)
- Conversation Dark: warmer/brighter than home (#1C1E18-#181A14), coach dialogue in warm off-white #C4C4B4

**Ambient mode shifts** (coaching mode → subtle background color temperature):
- Discovery: warmer/golden shift
- Directive: cooler/focused shift
- Challenger: deeper/grounded shift
- Safety states override all coaching mode shifts

**Pause Mode visual transform:** When `isPaused`:
- Light mode: reduced saturation across palette
- Dark mode: shifts to near-monochrome warmth
- Avatar → `.resting` state (derived via `experienceContext`)
- InsightCard → Pause message text
- SprintPathView → muted (opacity reduction, not hidden)
- Notifications → zero (enforced by `NotificationService`)

**Coach Expression State Machine:**

Managed by `CoachingViewModel`. Two transitions per turn maximum:

1. **On message send:** Expression → `.thinking` (immediate)
2. **On `done` event received:** Expression → value from `mood` field (`.welcoming`, `.warm`, `.focused`, `.gentle`)

Fallback if `mood` field missing: `.welcoming`. Expression state stored as `@Published var coachExpression: CoachExpression` on `CoachingViewModel`, read by `CoachCharacterView`.

**Navigation:** NavigationStack with path-based routing. No tab bar — home screen as hub, conversation as primary action.

**Offline/Online:** NWPathMonitor → `AppState.isOnline`. Reactive UI updates. Sprint step completions queued offline, synced on reconnect.

### System Prompt Configuration

**Composition:** Modular sections as markdown files in `server/prompts/sections/`:

| Section | Purpose | FR Coverage |
|---------|---------|-------------|
| `base-persona` | Coach identity, voice, warmth | Coach personality |
| `mode-discovery` | Exploration, probing questions, pattern surfacing | FR3 |
| `mode-directive` | Confident guidance, contingency plans | FR4, FR8 |
| `challenger` | Non-negotiable pushback rules | FR7 |
| `safety` | Inline classification instructions + output schema | FR39, FR40 |
| `mood` | Coach expression/mood selection for UI rendering | UX-DR15 |
| `tagging` | Domain tag classification instructions + output schema | FR14 |
| `cultural` | No Western-centric assumptions | NFR38 |
| `autonomy` | Gradual self-reliance encouragement | FR77 |
| `context-injection` | Slot for coach name, RAG, profile, sprint | FR6, FR10 |

Server assembles relevant sections based on request context (mode, tier). One place to edit each concern. `tagging` is separate from `safety` — domain classification and clinical boundary classification are independent concerns.

**Provider-Specific Output Format:** The `safety` and `tagging` sections include structured output instructions that require **provider-specific variants.** Anthropic expects tool use definitions, OpenAI expects JSON schema in `response_format`, Gemini expects function declarations. Base instructions are shared; output format wrapper is provider-specific — handled during server-side prompt assembly based on the provider being called. This is a prompt composition concern, not a prompt content concern.

**Versioning:** Dual version scheme:
- **Functional version (content hash):** Auto-generated from hash of all section file contents. When any section changes, the hash changes. This is what iOS sends in requests and the server matches against. No manual version bumping — eliminates human error.
- **Human-readable label (semantic):** `v1.2.3` in prompt config for changelogs and communication. Updated manually when meaningful milestones are reached.

The server computes the content hash on startup and caches it. Rollback = deploy old section files → hash reverts automatically.

**Caching:** iOS caches version hash on launch, 1hr TTL, falls back to cached on failure. Prompt content stays server-side only.

**Active Conversation Handling:** Conversations use the prompt version active when the conversation started. iOS caches the version per session. Mid-conversation version changes don't affect in-flight sessions — only new conversations get the new version.

### Push Notifications (MVP Scoping)

**Decision: All notifications are iOS local notifications at MVP.** The stateless server architecture (no user data, no cron jobs, no device token storage) cannot send push notifications via APNs.

All 4 PRD notification types implemented on-device:

| Type | iOS Implementation |
|------|-------------------|
| Daily check-in | `UNUserNotificationCenter` scheduled at user-configured time |
| Sprint milestone | Triggered locally when sprint step marked complete |
| Pause suggestion | Triggered by on-device engagement intensity tracking |
| Re-engagement nudge | Triggered by on-device drift detection (days since last interaction outside Pause Mode) |

Hard cap of 2/day and Pause Mode suppression enforced locally.

**APNs integration deferred to Phase 2** when the server gains user state (accounts, device token storage, scheduled jobs). The PRD's NFR28 (APNs graceful handling) applies to Phase 2 scope.

### Infrastructure & Deployment

**CI/CD (GitHub Actions):**

| Workflow | Trigger | Steps | Gate |
|----------|---------|-------|------|
| `ios.yml` | Changes to `ios/` | Swift tests → build | Tests pass |
| `server.yml` | Changes to `server/` | Go tests → safety regression suite (50+ prompts) → Railway deploy | All pass |

Safety regression suite runs as Go test with build tag: `go test -tags=safety ./tests/safety/...`. CI timeout accommodates 2-4 minute LLM evaluation.

**Environments:**

| Environment | Server | iOS | Purpose |
|-------------|--------|-----|---------|
| Local | localhost:8080 | Simulator (Debug scheme) | Daily development |
| Staging | Railway staging | Device (Staging scheme) | Integration + device testing |
| Production | Railway production | App Store (Release) | Users |

**Server Config (env vars):** `LLM_*_PROVIDER`, `*_API_KEY`, `JWT_SECRET`, `SENTRY_DSN`, `ENVIRONMENT`

**iOS Config:** `COACH_API_URL` per Xcode scheme (Debug/Staging/Release)

**Railway:** Watches `server/`, Dockerfile deploy (multi-stage → alpine), health check on `/health`, zero-downtime rolling restart, auto-deploy disabled — CI triggers on main after gates pass.

### Decision Impact Analysis

**Implementation Sequence:**
1. **Week 1 first half:** Server scaffold — auth endpoints, health check, chat endpoint returning hardcoded mock SSE stream. iOS networking layer connects and parses. App Groups setup. **Validates end-to-end pipeline with mock data before adding real intelligence.**
2. **Week 1 second half:** sqlite-vec + GRDB + embedding model spike on iOS. Benchmark 1K/5K/10K embeddings. Database in App Group shared container.
3. **Week 2:** Provider interface + Anthropic implementation + real SSE streaming with structured output parsing. System prompt v1 assembly.
4. **Week 2-3:** Complete chat endpoint with real LLM responses. Safety regression suite initial version.
5. **Week 3+:** RAG pipeline (summary → embed → store → retrieve). Everything else layers on top.

Don't parallelize two unknowns in Week 1. Get the pipeline working end-to-end first, then add depth.

**Cross-Component Dependencies:**

```
JWT Auth ──→ Tier Routing ──→ Model Selection ──→ Provider Interface
                                                        ↓
System Prompt Assembly ──→ Provider-Specific Wrapping ──→ Chat Handler
                                                        ↓
                                              Streaming JSON Parser
                                              ↓                  ↓
                                    event: token          event: done
                                        ↓                      ↓
iOS SSE Parser ──→ Incremental Text ──→ Safety Level ──→ AppState
                                   ──→ Domain Tags  ──→ ConversationSummary
                                                              ↑
RAG Pipeline ──→ Summary ──→ Embedding ──→ sqlite-vec (App Group shared container)
                                                              ↓
                                                        WidgetKit (read-only)

Local Notifications ──→ UNUserNotificationCenter (on-device only, no server)
```

## Implementation Patterns & Consistency Rules

### Why These Patterns Exist

Multiple AI agents will implement features across two codebases (Swift iOS + Go server) that must interoperate seamlessly. These patterns prevent the most common divergence points — areas where two agents, both making reasonable choices, would produce incompatible code.

### API Wire Format

All data crossing the iOS ↔ server boundary follows these rules:

| Pattern | Convention | Example |
|---------|-----------|---------|
| JSON field names | camelCase | `safetyLevel`, `domainTags`, `promptVersion` |
| Date format | ISO 8601 with timezone | `2026-03-16T14:30:00Z` |
| Enum values | lowercase snake_case strings | `"discovery"`, `"directive"`, `"provider_unavailable"` |
| Null handling | Omit null fields (absent = not set) | No `"field": null` |
| Arrays | Always arrays, even empty | `"domainTags": []`, never omitted |
| Boolean fields | Never 0/1, always true/false | `"degraded": false` |

Swift API model types use explicit `CodingKeys` — no automatic key strategy conversion.

### Database Conventions (GRDB/SQLite)

| Pattern | Convention | Example |
|---------|-----------|---------|
| Table names | PascalCase singular | `ConversationSession`, `SprintStep` |
| Column names | camelCase | `startedAt`, `safetyLevel` |
| Foreign keys | `{related}Id` | `sessionId`, `sprintId` |
| Primary keys | `id` (always UUID) | `id` |
| Booleans | `is` prefix | `isCompleted`, `isPaused` |
| Timestamps | `At` suffix | `createdAt`, `updatedAt`, `completedAt` |

### Swift Patterns

**Concurrency Rules (Swift 6 strict checking):**

```swift
// ViewModels: ALWAYS @MainActor (they update UI state)
@MainActor @Observable final class CoachingViewModel { ... }

// Services: NOT @MainActor — they do background work
// Marked Sendable so they can be passed across concurrency domains
final class ChatService: ChatServiceProtocol, Sendable { ... }

// Database: GRDB's DatabasePool handles thread safety — don't wrap in your own actor

// Streaming: AsyncThrowingStream is the return type for SSE and similar
func streamChat(...) -> AsyncThrowingStream<ChatEvent, Error>
```

Rules:
- ViewModels are always `@MainActor` — they hold `@Observable` state that drives UI
- Services are `Sendable` — can be passed across concurrency domains
- **Never use `DispatchQueue.main.async`** — use `@MainActor` instead
- `AsyncThrowingStream` for all streaming operations (SSE parsing, RAG retrieval)
- Check `Task.isCancelled` in long-running loops
- Store `Task` references, cancel on view disappear

**Error Handling — Two-Tier Routing:**

```swift
// One app-wide error enum mapping to the error taxonomy
enum AppError: Error {
    case networkUnavailable          // Hard → Global
    case providerError(message: String, retryAfter: Int?)  // Hard → Global
    case authExpired                 // Hard → Global
    case degraded                    // Degraded → Local
    case databaseError(underlying: Error)  // Silent → Local
}
```

Global errors flow through AppState; local errors stay on the ViewModel:

```swift
catch let err as AppError {
    switch err {
    case .networkUnavailable:
        appState.isOnline = false       // Global — entire app reacts
    case .authExpired:
        appState.needsReauth = true     // Global — entire app reacts
    case .providerError(let msg, _):
        appState.isOnline = false       // Global
        self.localError = err           // Also show locally
    default:
        self.localError = err           // Local — only this view
    }
}
```

Services throw, ViewModels catch and route. **Never force-unwrap. Use `guard let` / `if let`.**

**ViewModel Pattern:**

```swift
@MainActor @Observable final class CoachingViewModel {
    var isLoading = false
    var localError: AppError?

    private let chatService: ChatServiceProtocol  // Injected via protocol
    private let appState: AppState                // Injected

    init(appState: AppState, chatService: ChatServiceProtocol) {
        self.appState = appState
        self.chatService = chatService
    }

    func sendMessage(_ text: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await chatService.send(text)
        } catch let err as AppError {
            // Route error to correct tier (global vs local)
        } catch {
            self.localError = .providerError(message: error.localizedDescription, retryAfter: nil)
        }
    }
}
```

Rules:
- Services injected via protocol (testable)
- ViewModels own service calls — Views never call services directly
- `Task { }` in ViewModel methods, not in View body
- Loading state as `@Observable` property on ViewModel

**File Naming:**
- One primary type per file, named after the type: `CoachingViewModel.swift`, `ChatService.swift`
- Views: `HomeView.swift`, `CoachingView.swift`
- Models: `ConversationSession.swift`, `Sprint.swift`
- Protocols: `ChatServiceProtocol.swift` (separate file from implementation)

**Import Ordering:**

```swift
// System → Third-party → Project (alphabetical within each group)
import Foundation
import SwiftUI

import GRDB
import Lottie

import Services
import Core
```

**Access Control:**
- Types crossing feature boundaries: explicit `public` or `package`
- Types within their feature: `internal` (default, no keyword)
- Implementation details: `private`
- **Never use `open`** — not designing for subclassing

Simple rule: if it leaves the feature folder, mark it explicitly.

### Go Server Patterns

**Naming and Structure:**

```go
// JSON tags always camelCase — matches iOS
type ChatEvent struct {
    Text              string   `json:"text"`
    SafetyLevel       string   `json:"safetyLevel"`
    DomainTags        []string `json:"domainTags"`
    Mood              string   `json:"mood"`              // welcoming|thinking|warm|focused|gentle
    MemoryReferenced  bool     `json:"memoryReferenced"`  // true if response references RAG context
}

// Errors always wrapped with context
if err != nil {
    return fmt.Errorf("anthropic.StreamChat: %w", err)
}

// Context always first parameter
func (h *ChatHandler) HandleChat(ctx context.Context, w http.ResponseWriter, r *http.Request)
```

**Import Ordering:**

```go
// Standard lib → Third-party → Project (goimports enforces this)
import (
    "context"
    "net/http"

    "github.com/anthropics/anthropic-sdk-go"

    "github.com/ducdo/ai-life-coach/server/providers"
)
```

**Response Helpers:**

```go
// All responses go through helpers — never raw w.Write in handlers
func writeJSON(w http.ResponseWriter, status int, data any) { ... }
func writeError(w http.ResponseWriter, status int, err AppError) { ... }
```

**Configuration:** Env vars read once at startup into a `Config` struct. No `os.Getenv` at request time.

**Logging:** `slog` (std lib) with structured JSON output:

```go
slog.Info("chat.request", "deviceId", claims.DeviceID, "tier", claims.Tier, "mode", req.Mode)
slog.Warn("provider.failover", "from", "anthropic", "to", "openai", "reason", err)
```

### AppState Injection Pattern

One concrete rule: AppState is created once, lives in SwiftUI Environment, passed to ViewModels by the View that owns them.

```swift
// Created once at App root
@main struct AILifeCoachApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

// Views read from Environment
struct HomeView: View {
    @Environment(AppState.self) private var appState
}

// ViewModels receive via init (injected by owning View)
@MainActor @Observable final class CoachingViewModel {
    private let appState: AppState
    init(appState: AppState, chatService: ChatServiceProtocol) { ... }
}
```

**No singletons. No service locators. No global access.**

### GRDB Record Type Pattern

All database models use the same protocol conformance set:

```swift
struct ConversationSession: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: UUID
    var startedAt: Date
    var type: SessionType
    // ...

    static let databaseTableName = "ConversationSession"
}
```

Standard set: `Codable` + `FetchableRecord` + `PersistableRecord` + `Identifiable`. Every database model, every time.

Queries live as static extensions on the model type — never in ViewModels or services:

```swift
extension ConversationSession {
    static func recent(limit: Int = 10) -> QueryInterfaceRequest<ConversationSession> {
        order(Column("startedAt").desc).limit(limit)
    }
}
```

### Testing Conventions

**Test File Location:**
- Swift: `Tests/` directory mirroring `Features/` and `Services/` structure
- Go: `_test.go` files co-located with source (Go convention)

**Test Naming:**

```swift
// Swift: test_methodName_condition_expectedResult
func test_sendMessage_whenOffline_setsNetworkError() async { }
func test_parseSseEvent_withDoneEvent_extractsSafetyLevel() { }
```

```go
// Go: TestHandlerName_Condition_Expected
func TestChatHandler_ValidRequest_StreamsTokens(t *testing.T) { }
func TestChatHandler_AllProvidersFail_Returns502(t *testing.T) { }
```

**Mocking Approach — Protocol/Interface Based (no frameworks):**

```swift
protocol ChatServiceProtocol: Sendable {
    func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error>
}

// Test mock — hand-written, explicit
final class MockChatService: ChatServiceProtocol {
    var stubbedEvents: [ChatEvent] = []
    func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        // Return canned events from stubbedEvents
    }
}
```

Go uses interface-based mocking. The `Provider` interface and `httptest` cover most needs.

**What to Test:**

| Category | Test? | Approach |
|----------|-------|----------|
| Data model encoding/decoding | Always | Unit test — verify Codable roundtrip matches API contract |
| State machine transitions | Always | Unit test — verify ExperienceContext derivation |
| Error mapping / routing | Always | Unit test — verify global vs local routing |
| Database operations (GRDB) | Always | Unit test with in-memory database |
| API contract conformance | Always | Integration test — Go httptest, Swift mock SSE data |
| Safety regression | Always | Benchmark test — 50+ prompts in CI |
| SwiftUI views | Never | Manual testing + `#Preview` |
| Lottie animations | Never | Manual testing |
| Navigation flows | Never | Manual testing |

### Logging Standards

| Event | Level | Codebase |
|-------|-------|----------|
| Request received / completed | Info | Server |
| Provider failover | Warn | Server |
| Safety classification result | Info | Server (compliance) |
| All provider errors (before failover) | Warn | Server |
| SSE stream lifecycle | Debug | Server |
| RAG retrieval results | Debug | iOS |
| Memory pipeline failure | Error | iOS |
| State transitions | Debug | iOS |
| User actions (message sent, step completed) | Info | iOS |

iOS uses `os.Logger` (Apple unified logging). Go uses `slog` (std lib). Both produce structured output.

### Date/Time Handling

| Context | Format |
|---------|--------|
| API wire | ISO 8601: `2026-03-16T14:30:00Z` |
| SQLite storage | ISO 8601 string (GRDB handles Date ↔ String) |
| Swift code | `Date` type — format only at display layer |
| Go code | `time.Time` — marshal as RFC 3339 / ISO 8601 |
| User display | Relative when < 7 days ("2 hours ago"), absolute otherwise ("Mar 14") |

### Extension Point Patterns

These patterns validate that the architecture's abstractions are working. If adding a new capability touches more files than specified, the abstraction is wrong — fix the architecture, don't hack around it.

**Adding a new LLM provider:**

| Step | File | Change |
|------|------|--------|
| 1 | `server/providers/newprovider.go` | Implement `Provider` interface |
| 2 | `server/config/config.go` | Add provider config (API key env var, model names) |
| 3 | `main.go` | Register in provider map and failover chain |
| 4 | `.env` / Railway env vars | Add API key |

4 files. No changes to handlers, middleware, or iOS code.

**Adding a new system prompt section:**

| Step | File | Change |
|------|------|--------|
| 1 | `server/prompts/sections/new-section.md` | Write the section content |
| 2 | Prompt assembly logic | Include section conditionally based on context |

2 files. Content hash auto-updates on next server restart. No iOS changes needed.

### Accessibility Patterns (NFR21-25, NFR37-38)

**VoiceOver (NFR21):** All interactive elements get explicit accessibility labels and hints:

```swift
Button("Talk to your coach") { }
    .accessibilityLabel("Start a coaching conversation")
    .accessibilityHint("Opens a chat with your coach")

// Sprint step completion
Toggle(isOn: $step.isCompleted) { Text(step.description) }
    .accessibilityLabel("\(step.description), \(step.isCompleted ? "completed" : "not completed")")
```

**Dynamic Type (NFR22):** Use system text styles, never fixed font sizes:

```swift
Text(message).font(.body)           // ✅ scales with Dynamic Type
// .font(.system(size: 16))         // ❌ NEVER — doesn't scale
```

All layouts must accommodate larger text sizes without clipping or overlapping. Use `ScrollView` for content that may grow with accessibility sizes.

**Reduce Motion (NFR37):** Check environment, provide static fallback for Lottie animations:

```swift
struct AvatarView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        if reduceMotion {
            Image("avatar-\(state)")    // Static fallback
        } else {
            LottieView(animation: avatarAnimation)
        }
    }
}
```

**Contrast (NFR25):** Use semantic colors from the asset catalog — system adapts for light/dark mode. Never hardcode color values. All text must meet WCAG AA (4.5:1 body, 3:1 large text).

**Non-Color Indicators (NFR24):** Safety levels, sprint progress, and avatar states must be distinguishable without color — use shape, label, or icon alternatives alongside color.

**Cultural Adaptability (NFR38):** Handled in system prompt via `prompts/sections/cultural.md`. The coaching system asks about cultural context during intake rather than assuming defaults.

**Accessibility enforcement rule:** Every View that displays information or accepts interaction must support VoiceOver labels, Dynamic Type text styles, and Reduce Motion fallbacks. No exceptions.

### Enforcement Guidelines

**All AI agents implementing features MUST:**
1. Reference this patterns section before writing any new model, service, or handler
2. Use the `AppError` enum for all error handling — route global vs local correctly
3. Match JSON field names exactly as specified in the API contract — explicit `CodingKeys`, no auto-conversion
4. Follow the ViewModel pattern (protocol-injected services, `@MainActor`, two-tier error routing)
5. Use structured logging at the specified levels — never `print()` in Swift or `fmt.Println()` in Go
6. Wrap all Go errors with context using `fmt.Errorf("scope: %w", err)`
7. Mark ViewModels `@MainActor @Observable`, services `Sendable`
8. Write tests following the naming convention and protocol-based mocking approach
9. Follow import ordering conventions
10. Use GRDB record type pattern (4 protocols, explicit table name, query extensions)
11. Inject AppState via Environment → ViewModel init — no singletons

**Anti-Patterns (explicitly forbidden):**
- Singleton services (use protocol injection)
- Force-unwrapping (`!`) in Swift
- Raw `print()` / `fmt.Println()` for logging
- `DispatchQueue.main.async` (use `@MainActor`)
- Calling `os.Getenv()` at request time in Go
- Returning HTTP 500 from the Go server (always specific status codes)
- Using `snake_case` in JSON (always `camelCase`)
- Making service calls from SwiftUI View body
- Nested `if let` chains — prefer `guard let` early returns
- `open` access control in Swift
- Creating ad-hoc error types instead of using `AppError`
- Database queries in ViewModels (use model static extensions)
- Accessing AppState via singleton or service locator

## Project Structure & Boundaries

### Complete Project Directory Structure

```
ai-life-coach/
├── .github/
│   └── workflows/
│       ├── ios.yml                           # Swift tests + build on ios/ changes
│       └── server.yml                        # Go tests + safety suite + Railway deploy on server/ changes
├── .gitignore                                # Combined iOS + Go + macOS patterns
│
├── docs/
│   ├── api-contract.md                       # Shared API contract (SSE format, schemas, errors)
│   └── fixtures/                             # Shared test fixtures — both codebases validate against these
│       ├── chat-request-sample.json
│       ├── sse-token-event.txt
│       ├── sse-done-event.txt
│       ├── error-response-502.json
│       └── auth-register-response.json
│
├── ios/
│   ├── ai_life_coach.xcodeproj/
│   │   └── xcshareddata/xcschemes/
│   │       ├── Debug.xcscheme
│   │       ├── Staging.xcscheme
│   │       └── Release.xcscheme
│   ├── ai_life_coach/
│   │   ├── ai_life_coach.entitlements        # App Groups + Keychain access groups
│   │   ├── Configuration/
│   │   │   ├── Debug.xcconfig                # COACH_API_URL = http://localhost:8080
│   │   │   ├── Staging.xcconfig              # COACH_API_URL = https://staging.railway.app
│   │   │   └── Release.xcconfig              # COACH_API_URL = https://production.railway.app
│   │   │
│   │   ├── App/
│   │   │   ├── AILifeCoachApp.swift          # @main entry, AppState creation, Environment injection
│   │   │   └── AppState.swift                # @Observable unified state, ExperienceContext enum
│   │   │
│   │   ├── Features/
│   │   │   ├── Coaching/
│   │   │   │   ├── Views/
│   │   │   │   │   ├── CoachingView.swift             # Main conversation screen
│   │   │   │   │   ├── MessageBubbleView.swift         # Individual message rendering
│   │   │   │   │   └── StreamingTextView.swift         # Incremental text display
│   │   │   │   ├── ViewModels/
│   │   │   │   │   └── CoachingViewModel.swift         # Conversation state, SSE consumption, error routing
│   │   │   │   └── Models/
│   │   │   │       ├── ChatRequest.swift               # Transient — request model (Codable, CodingKeys)
│   │   │   │       ├── ChatEvent.swift                 # Transient — SSE event models (token, done)
│   │   │   │       └── CoachingMode.swift              # Transient — discovery/directive enum
│   │   │   │
│   │   │   ├── Sprint/
│   │   │   │   ├── Views/
│   │   │   │   │   ├── SprintView.swift                # Sprint progress display
│   │   │   │   │   └── SprintStepRow.swift             # Individual step with completion toggle
│   │   │   │   └── ViewModels/
│   │   │   │       └── SprintViewModel.swift           # Sprint state, step completion, offline queue
│   │   │   │
│   │   │   ├── Home/
│   │   │   │   ├── Views/
│   │   │   │   │   ├── HomeView.swift                  # Hub screen: avatar + sprint + coach action
│   │   │   │   │   └── AvatarView.swift                # Avatar display with state-based rendering
│   │   │   │   └── ViewModels/
│   │   │   │       └── HomeViewModel.swift             # Home state, recent insight, avatar state
│   │   │   │
│   │   │   ├── Onboarding/
│   │   │   │   ├── Views/
│   │   │   │   │   ├── WelcomeView.swift               # Brand moment (3s)
│   │   │   │   │   ├── AvatarSelectionView.swift       # Style picker
│   │   │   │   │   ├── CoachNamingView.swift           # Name your coach
│   │   │   │   │   └── OnboardingCoachingView.swift    # First conversation (coaching-as-onboarding)
│   │   │   │   └── ViewModels/
│   │   │   │       └── OnboardingViewModel.swift       # Onboarding flow state, profile creation
│   │   │   │
│   │   │   ├── Settings/
│   │   │   │   ├── Views/
│   │   │   │   │   └── SettingsView.swift              # Preferences, coach name, privacy, notifications
│   │   │   │   └── ViewModels/
│   │   │   │       └── SettingsViewModel.swift         # Settings state, notification config, data deletion
│   │   │   │
│   │   │   └── Widgets/
│   │   │       ├── SmallWidget.swift                   # Avatar state + sprint progress
│   │   │       └── MediumWidget.swift                  # Avatar + sprint name + next action + tap target
│   │   │
│   │   ├── Services/
│   │   │   ├── Networking/
│   │   │   │   ├── ChatServiceProtocol.swift           # Protocol for chat operations
│   │   │   │   ├── ChatService.swift                   # SSE streaming implementation
│   │   │   │   ├── SSEParser.swift                     # AsyncThrowingStream SSE event parser
│   │   │   │   ├── APIClient.swift                     # HTTP client, auth headers, gzip, base URL config
│   │   │   │   └── AuthService.swift                   # JWT registration, refresh, Keychain storage
│   │   │   ├── Memory/
│   │   │   │   ├── MemoryServiceProtocol.swift         # Protocol: store, retrieve, getProfile
│   │   │   │   ├── MemoryService.swift                 # RAG pipeline orchestration
│   │   │   │   ├── EmbeddingService.swift              # Core ML all-MiniLM inference
│   │   │   │   └── SummaryGenerator.swift              # Post-conversation summary via cloud LLM
│   │   │   ├── Database/
│   │   │   │   ├── DatabaseManager.swift               # GRDB DatabasePool setup (App Group container)
│   │   │   │   ├── Migrations.swift                    # All versioned migrations in sequence
│   │   │   │   └── VectorSearch.swift                  # sqlite-vec query wrapper
│   │   │   ├── Safety/
│   │   │   │   └── SafetyHandler.swift                 # Safety level → SafetyUIState → AppState + theme overrides
│   │   │   ├── Subscription/
│   │   │   │   ├── SubscriptionServiceProtocol.swift   # Protocol for subscription operations
│   │   │   │   └── SubscriptionService.swift           # StoreKit 2, entitlement check, receipt handling
│   │   │   └── Notifications/
│   │   │       └── NotificationService.swift           # UNUserNotificationCenter, local scheduling, 2/day cap
│   │   │
│   │   ├── Core/
│   │   │   ├── State/
│   │   │   │   ├── ExperienceContext.swift              # Enum + derivation logic
│   │   │   │   └── ConnectivityMonitor.swift           # NWPathMonitor → AppState.isOnline
│   │   │   ├── Theme/
│   │   │   │   ├── CoachingTheme.swift                  # @Observable theme with palette, typography, spacing, radius tokens
│   │   │   │   ├── ColorPalette.swift                   # Home Light/Dark, Conversation Light/Dark palettes
│   │   │   │   ├── TypographyScale.swift                # 12 semantic text styles (coachVoice, userVoice, etc.)
│   │   │   │   └── CoachExpression.swift                # Enum: welcoming, thinking, warm, focused, gentle
│   │   │   ├── Extensions/
│   │   │   │   ├── Date+Formatting.swift               # Relative/absolute display formatting
│   │   │   │   └── View+Extensions.swift               # Common SwiftUI modifiers
│   │   │   ├── Utilities/
│   │   │   │   └── Constants.swift                     # App-wide constants
│   │   │   └── Errors/
│   │   │       └── AppError.swift                      # App-wide error enum (taxonomy mapping)
│   │   │
│   │   ├── Models/                                     # ALL GRDB record types (shared/persisted)
│   │   │   ├── ConversationSession.swift               # GRDB record + query extensions
│   │   │   ├── Message.swift                           # GRDB record
│   │   │   ├── ConversationSummary.swift               # GRDB record + embedding field
│   │   │   ├── UserProfile.swift                       # GRDB record + structured profile
│   │   │   ├── Sprint.swift                            # GRDB record + query extensions
│   │   │   ├── SprintStep.swift                        # GRDB record + query extensions
│   │   │   └── SafetyLevel.swift                       # Enum: green/yellow/orange/red
│   │   │
│   │   ├── Resources/
│   │   │   ├── Assets.xcassets/                        # App icons, colors, images
│   │   │   ├── Animations/                             # Lottie JSON files per avatar state
│   │   │   ├── MiniLM.mlmodelc/                        # Core ML embedding model (~22MB)
│   │   │   └── PrivacyInfo.xcprivacy                   # Apple Privacy Manifest
│   │   │
│   │   └── Preview Content/
│   │       └── PreviewData.swift                       # Mock data for SwiftUI previews
│   │
│   ├── ai_life_coach_widgetExtension/                  # WidgetKit target (same App Group)
│   │   ├── WidgetBundle.swift
│   │   └── Info.plist
│   │
│   └── Tests/
│       ├── Mocks/
│       │   ├── MockChatService.swift
│       │   ├── MockMemoryService.swift
│       │   └── MockSubscriptionService.swift
│       ├── Features/
│       │   ├── CoachingViewModelTests.swift
│       │   ├── SprintViewModelTests.swift
│       │   └── OnboardingViewModelTests.swift
│       ├── Services/
│       │   ├── SSEParserTests.swift
│       │   ├── MemoryServiceTests.swift
│       │   ├── AuthServiceTests.swift
│       │   └── VectorSearchTests.swift
│       ├── Models/
│       │   ├── CodableRoundtripTests.swift             # Verify all models encode/decode matching fixtures
│       │   └── ExperienceContextTests.swift            # State derivation tests
│       └── Database/
│           └── MigrationTests.swift                    # In-memory GRDB migration tests
│
├── server/
│   ├── .env.example                                    # Template: all required env vars with comments
│   ├── main.go                                         # Entry, route registration, middleware chain, server startup
│   ├── handlers/
│   │   ├── chat.go                                     # POST /v1/chat — SSE streaming, structured output parsing
│   │   ├── prompt.go                                   # GET /v1/prompt/{version} — prompt version metadata
│   │   ├── auth.go                                     # POST /v1/auth/register, POST /v1/auth/refresh
│   │   ├── health.go                                   # GET /health
│   │   └── helpers.go                                  # writeJSON, writeError response helpers
│   ├── providers/
│   │   ├── provider.go                                 # Provider interface + ChatEvent types (architectural core)
│   │   ├── anthropic.go                                # Anthropic: tool use structured output
│   │   ├── openai.go                                   # OpenAI: response_format structured output
│   │   ├── gemini.go                                   # Gemini: function calling structured output
│   │   └── kimi.go                                     # Kimi K2: OpenAI-compatible with custom base URL
│   ├── middleware/
│   │   ├── auth.go                                     # JWT verification, claims extraction
│   │   ├── tier.go                                     # Tier-based model selection from JWT claims
│   │   ├── guardrails.go                               # Soft guardrail enforcement, session counting
│   │   └── logging.go                                  # Structured slog, compliance event logging
│   ├── prompts/
│   │   ├── builder.go                                  # Section assembly, provider-specific wrapping, hash computation
│   │   └── sections/
│   │       ├── base-persona.md
│   │       ├── mode-discovery.md
│   │       ├── mode-directive.md
│   │       ├── challenger.md
│   │       ├── safety.md
│   │       ├── tagging.md
│   │       ├── cultural.md
│   │       └── autonomy.md
│   ├── config/
│   │   └── config.go                                   # Env var parsing into Config struct at startup
│   ├── auth/
│   │   └── jwt.go                                      # JWT creation, validation, claims struct
│   ├── tests/
│   │   ├── handlers_test.go                            # API contract tests (httptest) using shared fixtures
│   │   ├── providers_test.go                           # Mock provider, streaming tests
│   │   ├── middleware_test.go                           # Auth, tier, guardrail tests
│   │   └── safety/
│   │       ├── safety_test.go                          # Safety regression suite (build tag: safety)
│   │       └── prompts.go                              # 50+ clinical edge-case test prompts
│   ├── Dockerfile                                      # Multi-stage: golang builder → alpine with CA certs
│   ├── go.mod
│   └── go.sum
│
├── _bmad-output/                                       # Planning artifacts (existing)
│   └── planning-artifacts/
│       └── architecture.md                             # This document
│
└── README.md
```

### Model Location Rule

| Type | Location | Rule |
|------|----------|------|
| **GRDB record types** (persisted) | Root `Models/` | Always shared — database is a shared resource. ConversationSession, Message, ConversationSummary, UserProfile, Sprint, SprintStep, SafetyLevel. |
| **API/transient models** (not persisted) | Feature `Models/` | Feature-local. ChatRequest, ChatEvent, CoachingMode stay in `Features/Coaching/Models/`. |

If two or more features need a model, it's in root `Models/`. If it's only used within one feature and not a GRDB record, it stays in the feature.

### Architectural Boundaries

**API Boundary (iOS ↔ Server):**

All communication crosses one boundary: the HTTP API defined in `docs/api-contract.md`. iOS never calls LLM providers directly. Server never accesses on-device data.

```
iOS (APIClient.swift) ──HTTP/SSE──→ Server (handlers/*.go)
```

**Service Boundaries (iOS):**

```
Views ──→ ViewModels ──→ Services ──→ External Systems
  ↑                         ↑
  └── reads AppState        └── protocols (testable)
```

- Views only talk to their ViewModel and read AppState from Environment
- ViewModels call Services via protocols — never access database or network directly
- Services own their external dependencies (GRDB, URLSession, StoreKit, UNUserNotification)
- Cross-service communication: only through AppState (global) or ViewModel coordination (local)

**Data Boundaries (iOS):**

```
Services/Database/ ──→ GRDB DatabasePool ──→ SQLite (App Group shared container)
Services/Memory/   ──→ GRDB + sqlite-vec ──→ Same SQLite database
Widgets/           ──→ GRDB (read-only)  ──→ Same SQLite database
```

All database access goes through GRDB. No raw SQL in ViewModels or Views. Query extensions live on model types.

**Server Boundaries:**

```
handlers/ ──→ providers/ (LLM calls)
          ──→ prompts/   (prompt assembly)
          ──→ auth/      (JWT operations)

middleware/ wraps handlers (auth → tier → guardrails → logging)
```

**Handler/Service Split Rule:** Handlers parse HTTP requests and write HTTP responses. Business logic lives in its own package.

| HTTP layer (handlers/) | Business logic layer |
|----------------------|---------------------|
| `handlers/chat.go` | `providers/*.go` (LLM operations) |
| `handlers/auth.go` | `auth/jwt.go` (JWT operations) |
| `handlers/prompt.go` | `prompts/builder.go` (prompt assembly) |

### FR Category to Structure Mapping

| FR Category | iOS Location | Server Location |
|-------------|-------------|-----------------|
| **Coaching Conversation (FR1-FR10)** | `Features/Coaching/`, `Services/Networking/` | `handlers/chat.go`, `providers/`, `prompts/` |
| **Coaching Memory (FR11-FR15)** | `Services/Memory/`, `Services/Database/`, `Models/ConversationSummary.swift` | N/A (on-device) |
| **Sprint Framework (FR16-FR22)** | `Features/Sprint/`, `Models/Sprint.swift`, `Models/SprintStep.swift` | N/A (on-device) |
| **Onboarding (FR23-FR25)** | `Features/Onboarding/` | `prompts/sections/` (onboarding prompt mode) |
| **Home Screen (FR26-FR29)** | `Features/Home/` | N/A |
| **Avatar System (FR30-FR33)** | `Features/Home/Views/AvatarView.swift`, `Resources/Animations/` | N/A |
| **Pause Mode (FR34-FR38)** | `App/AppState.swift`, `Services/Notifications/` | N/A |
| **Clinical Boundary (FR39-FR45)** | `Services/Safety/`, `Core/State/ExperienceContext.swift` | `prompts/sections/safety.md`, `middleware/logging.go`, `tests/safety/` |
| **Push Notifications (FR46-FR52)** | `Services/Notifications/NotificationService.swift` | N/A (local only at MVP) |
| **Monetization (FR53-FR58)** | `Services/Subscription/`, `Services/Networking/AuthService.swift` | `middleware/tier.go`, `middleware/guardrails.go`, `auth/jwt.go` |
| **Privacy & Data (FR59-FR62)** | `Services/Database/DatabaseManager.swift`, `Resources/PrivacyInfo.xcprivacy` | N/A (on-device) |
| **Backend & Infra (FR63-FR67)** | N/A | `providers/`, `middleware/`, `config/`, `Dockerfile` |
| **Widgets (FR68-FR69)** | `Features/Widgets/`, `ai_life_coach_widgetExtension/` | N/A |
| **Offline Capability (FR70-FR72)** | `Core/State/ConnectivityMonitor.swift`, `App/AppState.swift` | N/A |
| **Conversation History (FR73-FR76)** | `Features/Coaching/`, `Services/Memory/` | N/A |
| **Autonomy & Self-Reliance (FR77-FR78)** | `Services/Networking/` (tracks engagement source) | `prompts/sections/autonomy.md` |
| **Coach Personalization (FR80)** | `Features/Onboarding/`, `Features/Settings/`, `Models/UserProfile.swift` | `prompts/` (coach name injection) |

### Cross-Cutting Concern Locations

| Concern | Primary Location | Touches |
|---------|-----------------|---------|
| **Safety classification** | `prompts/sections/safety.md` → `handlers/chat.go` → `Services/Safety/SafetyHandler.swift` → `SafetyUIState` → `AppState` → `CoachingTheme` | Coaching UI, Home, Avatar, Notifications, Theme |
| **Coach expression** | `prompts/sections/mood.md` → `handlers/chat.go` (done event `mood` field) → `CoachingViewModel.coachExpression` → `CoachCharacterView` | Conversation UI |
| **Design tokens** | `Core/Theme/CoachingTheme.swift` → SwiftUI Environment → all views | All UI |
| **Subscription tier** | `auth/jwt.go` → `middleware/tier.go` → `Services/Subscription/` → `AppState.tier` | Model routing, guardrails, feature depth |
| **Offline/online** | `Core/State/ConnectivityMonitor.swift` → `AppState.isOnline` | All features |
| **Coach identity** | `Models/UserProfile.swift` → `prompts/` context injection → Notification copy → Home screen | System prompt, notifications, UI |
| **Memory pipeline** | `Services/Memory/` → `Services/Database/` → `Models/ConversationSummary.swift` | Every coaching conversation |
| **Error taxonomy** | `Core/Errors/AppError.swift` → ViewModels (routing) → `AppState` (global) | All services, all features |

### Shared Test Fixtures

`docs/fixtures/` contains canonical sample data that both iOS and Go tests validate against:

| Fixture | Used By | Purpose |
|---------|---------|---------|
| `chat-request-sample.json` | iOS `CodableRoundtripTests`, Go `handlers_test.go` | Verify request encoding matches |
| `sse-token-event.txt` | iOS `SSEParserTests`, Go `handlers_test.go` | Verify SSE format agreement |
| `sse-done-event.txt` | iOS `SSEParserTests`, Go `handlers_test.go` | Verify metadata extraction |
| `error-response-502.json` | iOS `CodableRoundtripTests`, Go `handlers_test.go` | Verify error format agreement |
| `auth-register-response.json` | iOS `AuthServiceTests`, Go `handlers_test.go` | Verify JWT response format |

When the API contract changes, update fixtures first. Both test suites break — contract-based testing in practice.

### Data Flow

```
USER INPUT
    ↓
CoachingView → CoachingViewModel.sendMessage()
    ↓
ChatService.streamChat(request)
    ↓ builds ChatRequest:
    ├── messages (last ~20-30, truncated)
    ├── ragContext (MemoryService.retrieve → VectorSearch → sqlite-vec)
    ├── profile (UserProfile from GRDB)
    ├── sprintContext (Sprint + SprintSteps from GRDB)
    ├── mode (discovery/directive)
    └── promptVersion (cached hash)
    ↓
APIClient → POST /v1/chat (gzip, JWT auth)
    ↓
SERVER: auth middleware → tier middleware → guardrails middleware → logging middleware
    ↓
ChatHandler:
    ├── Loads system prompt (builder.go assembles sections, wraps for provider)
    ├── Selects provider by tier config
    ├── Calls provider.StreamChat(ctx, fullRequest)
    ↓
Provider implementation (e.g., anthropic.go):
    ├── Sends to LLM API with structured output schema
    ├── Parses streaming JSON response
    ├── Emits ChatEvent channel: text chunks + done-with-metadata
    ↓
ChatHandler writes SSE:
    ├── event: token → {"text": "..."}  (per chunk)
    └── event: done  → {"safetyLevel": "green", "domainTags": [...], ...}
    ↓
iOS SSEParser (AsyncThrowingStream):
    ├── token events → CoachingViewModel renders incrementally
    └── done event → SafetyHandler updates AppState
                   → ConversationSession saved to GRDB
    ↓
POST-CONVERSATION PIPELINE (async, best-effort):
    ├── SummaryGenerator → cloud LLM call for summary
    ├── EmbeddingService → Core ML all-MiniLM → 384-dim vector
    └── ConversationSummary → GRDB + sqlite-vec storage
```

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** All technology choices are compatible — Swift 6.x + @Observable + MVVM + async/await + GRDB on iOS; Go 1.23+ + net/http + official LLM SDKs on server; JWT auth + stateless server + StoreKit 2; monorepo with shared API contract. No contradictory decisions found.

**Pattern Consistency:** camelCase JSON throughout both codebases, protocol-based injection on iOS, interface-based abstraction in Go, two-tier error routing, structured logging standards. All patterns align with technology choices.

**Structure Alignment:** Project tree supports all architectural decisions. Boundaries clearly defined. FR mapping covers all 16 capability areas.

### Requirements Coverage ✅

**Functional Requirements:** All 80 FRs across 16 categories mapped to specific files and directories. No gaps.

**Non-Functional Requirements:** All 38 NFRs addressed:
- Performance (NFR1-8): SSE streaming, RAG benchmark, Lottie budget ✅
- Security (NFR9-16): Encryption, Keychain, no keys in binary, compliance logging ✅
- Scalability (NFR17-20): sqlite-vec benchmark, horizontal proxy, provider-agnostic ✅
- Accessibility (NFR21-25, 37-38): Patterns added for VoiceOver, Dynamic Type, Reduce Motion, contrast, cultural adaptability ✅
- Integration (NFR26-30): Multi-provider, StoreKit 2, Sentry, Railway ✅
- Reliability (NFR31-36): Failover, offline, network transitions, iCloud backup ✅

### Implementation Readiness ✅

- **Decision Completeness:** 9 major decisions documented with rationale and implementation notes
- **Structure Completeness:** Full file tree (~80 files) with FR mapping for all 16 categories
- **Pattern Completeness:** 11 enforcement rules, 13+ anti-patterns, code examples for all major patterns including accessibility

### Architecture Completeness Checklist

**✅ Requirements Analysis**
- [x] Project context analyzed (23 cross-cutting concerns, tiered by priority)
- [x] Scale and complexity assessed (High, 12-15 modules, solo developer)
- [x] Technical constraints identified (10 constraints including cost scalability)
- [x] Cross-cutting concerns mapped (7 Tier 1, 8 Tier 2, 8 Tier 3)
- [x] Testability landscape defined (unit / integration / benchmark / manual)

**✅ Starter Template**
- [x] iOS: Xcode SwiftUI App + MVVM + @Observable + async/await
- [x] Server: Go 1.23+ + net/http std lib + official LLM SDKs (Anthropic, OpenAI, Gemini, Kimi)
- [x] Monorepo (ios/ + server/) with shared API contract and test fixtures
- [x] Local development workflow (Simulator + localhost, Railway staging for device)
- [x] Dependencies documented (GRDB, sqlite-vec, all-MiniLM, Lottie, Sentry)

**✅ Architectural Decisions**
- [x] API contract (5 endpoints, SSE format, structured output streaming strategy)
- [x] Monetization (quality gradient, server-enforced guardrails, no feature wall)
- [x] Error taxonomy (4 categories with HTTP/SSE mapping)
- [x] Data architecture (GRDB, all-MiniLM Core ML, schema with 6 tables, App Groups)
- [x] Auth (device UUID + JWT, Keychain persistence, Phase 2 account linking)
- [x] State management (@Observable AppState, ExperienceContext, NavigationStack)
- [x] System prompt (modular sections, content-hash versioning, provider-specific wrapping)
- [x] Infrastructure (GitHub Actions CI/CD, 3 environments, Railway with CI-gated deploy)
- [x] Push notifications scoped to local-only at MVP

**✅ Implementation Patterns**
- [x] API wire format, database conventions, date/time handling
- [x] Swift concurrency (@MainActor, Sendable, AsyncThrowingStream)
- [x] Two-tier error routing (global → AppState, local → ViewModel)
- [x] ViewModel + AppState injection patterns
- [x] GRDB record type pattern with query extensions
- [x] Go server patterns (slog, helpers, context, response writing)
- [x] Testing conventions (naming, protocol mocking, what to test)
- [x] Accessibility patterns (VoiceOver, Dynamic Type, Reduce Motion, contrast)
- [x] Extension point patterns (add provider: 4 files, add prompt section: 2 files)
- [x] Enforcement guidelines and anti-patterns

**✅ Project Structure**
- [x] Complete directory tree (~80 files across both codebases)
- [x] All 80 FRs mapped to specific directories
- [x] Architectural boundaries (API, service, data, server handler/service split)
- [x] Model location rule (persisted = root Models/, transient = feature Models/)
- [x] Shared test fixtures (docs/fixtures/) for contract-based testing
- [x] Full data flow diagram (user input → server → SSE → post-conversation pipeline)

### Architecture Readiness Assessment

**Overall Status: READY FOR IMPLEMENTATION**

**Confidence Level: High**

**Key Strengths:**
- Every FR has explicit architectural support with directory mapping
- Clear separation: iOS owns data, server is stateless orchestrator
- Provider interface enables 4 LLM providers without architectural changes
- Error taxonomy + two-tier routing prevents ad-hoc error handling
- Contract-based testing with shared fixtures catches mismatches before runtime
- Implementation sequence (end-to-end pipeline first) de-risks late integration
- Accessibility patterns address all 8 accessibility NFRs

**Areas for Future Enhancement (Phase 2+):**
- APNs push notifications (requires server-side user state)
- Apple/Google/Email sign-in (auth/link endpoint, JWT gains userId)
- Cloud RAG sync for cross-device (depends on user accounts)
- Admin dashboard for operational monitoring
- On-device LLM evaluation (AnyLanguageModel protocol enables this)
- Dual-path safety classification (independent parallel model)

### Implementation Handoff

**AI Agent Guidelines:**
1. Follow all architectural decisions exactly as documented
2. Use implementation patterns consistently — check enforcement rules before writing code
3. Respect project structure and boundaries — check FR mapping for where code lives
4. Reference the anti-patterns list to avoid common mistakes
5. Use shared test fixtures (docs/fixtures/) for all API-related tests
6. When adding new capabilities, follow extension point patterns (4 files for provider, 2 for prompt section)

**First Implementation Priority:**
1. Monorepo setup (ai-life-coach/ with ios/, server/, docs/ directories, .gitignore)
2. Server scaffold: `go mod init`, auth endpoints, health check, mock SSE chat endpoint
3. iOS project: Xcode SwiftUI App in ios/, App Groups entitlement, xcconfig files
4. Connect: iOS Simulator hits localhost server, parses mock SSE stream — validates end-to-end pipeline
5. sqlite-vec + GRDB + all-MiniLM spike — benchmark 1K/5K/10K embeddings
6. Then: real provider integration, system prompt v1, RAG pipeline, everything else layers on top
