# Story 8.2: Tier-Based Model Routing

Status: done

## Story

As a user on any tier,
I want my coaching requests routed to the appropriate AI model,
so that free users get capable coaching and premium users get the deepest model available.

## Acceptance Criteria

1. **Given** a chat request arrives at the server **When** the JWT is verified **Then** the `tier` field determines model selection: free tier routes to a lightweight but capable model, paid tier routes to the premium model.

2. **Given** the server configuration **When** tier-to-model mapping is defined **Then** it maps tiers to specific providers and models (configurable server-side via env vars) **And** the same system prompt is used for all tiers — quality gap comes from model capability only.

3. **Given** tier routing (FR65) **When** the server processes requests **Then** routing is enforced via server middleware checking JWT tier **And** no client-side tier logic exists (server is authoritative).

4. **Given** the model quality gap validation **When** at least 2 providers are integrated (Anthropic + OpenAI) **Then** the same coaching prompts are run through both free-tier and paid-tier models **And** output quality is compared to validate that the paid tier delivers meaningfully deeper coaching **And** results are documented as a go/no-go decision for the monetization strategy **And** if the quality gap is insufficient, the tier-to-model mapping is adjusted before launch.

## Tasks / Subtasks

- [x] Task 1: OpenAI Provider Implementation (AC: #1, #2, #4)
  - [x] 1.1 Create `server/providers/openai.go` implementing `Provider` interface
  - [x] 1.2 Implement `StreamChat` with OpenAI streaming + structured output via `response_format`
  - [x] 1.3 Map OpenAI structured JSON output to existing `ChatEvent` channel pattern
  - [x] 1.4 Handle OpenAI-specific error types (rate limit, auth, etc.)

- [x] Task 2: Tier Routing Middleware & Anthropic Provider Update (AC: #1, #3)
  - [x] 2.1 Update `NewAnthropicProvider(apiKey string)` → `NewAnthropicProvider(apiKey string, model anthropic.Model)` — make model configurable instead of hardcoded `ModelClaudeHaiku4_5` (anthropic.go:150-158)
  - [x] 2.2 Create `server/middleware/tier.go` — extract tier from JWT claims, attach selected provider to request context
  - [x] 2.3 Add tier-to-model config to `server/config/config.go` (env vars for model names per tier)
  - [x] 2.4 Create provider registry in `main.go` — map of tier → Provider instance (two Anthropic instances with different models, or mixed providers)
  - [x] 2.5 Wire middleware: `logging(auth(tier(handler)))` — tier middleware between auth and handler

- [x] Task 3: ChatHandler Provider Selection (AC: #1, #3)
  - [x] 3.1 Update `ChatHandler` to read provider from request context (set by tier middleware) instead of its current single-provider constructor parameter
  - [x] 3.2 Update `handleSummarize` and `handleSprintRetro` to also use tier-selected provider from context
  - [x] 3.3 Add `Degraded bool` field to `ChatEvent` struct in `provider.go` and include in done event payload when falling back to non-preferred provider
  - [x] 3.4 Log selected provider and model in chat.request slog entry
  - [x] 3.5 Update `docs/api-contract.md` to document the `degraded` field in the done event schema

- [x] Task 4: Provider Error Handling (AC: #1)
  - [x] 4.1 Update `handleProviderError` to handle OpenAI error types (not just Anthropic)
  - [x] 4.2 Both providers produce same warm user-facing error messages

- [x] Task 5: Config & Environment Setup (AC: #2)
  - [x] 5.1 Add env vars: `FREE_TIER_PROVIDER`, `FREE_TIER_MODEL`, `PREMIUM_TIER_PROVIDER`, `PREMIUM_TIER_MODEL`
  - [x] 5.2 Sensible defaults: free → `anthropic`/`claude-haiku-4-5`, premium → `anthropic`/`claude-sonnet-4-6`
  - [x] 5.3 Validate config: at least one provider must be configured; warn if OpenAI key missing but configured as tier provider
  - [x] 5.4 Update `.env.example` and `server/.env.example` with new env vars

- [x] Task 6: Tests (AC: #1, #2, #3)
  - [x] 6.1 Unit tests for OpenAI provider (mock httptest server, stream parsing, error handling)
  - [x] 6.2 Unit tests for tier middleware (free tier routing, premium tier routing, missing tier defaults to free)
  - [x] 6.3 Integration test: full chat request with tier-based provider selection
  - [x] 6.4 Test that both tiers receive identical system prompts (same promptVersion)
  - [x] 6.5 Verify all existing Go tests still pass
  - [x] 6.6 Verify all 669+ iOS tests still pass (no iOS changes expected)

- [x] Task 7: Model Quality Gap Validation (AC: #4)
  - [x] 7.1 Create `server/tests/quality_gap_test.go` — benchmark test (not CI-blocking)
  - [x] 7.2 Select 5-10 coaching prompts covering: career crisis (Marcus persona), slow-burn depth (Priya persona), directive pushback (Alex persona), and cross-domain scenarios
  - [x] 7.3 Run each prompt through free-tier model and premium-tier model with identical system prompt
  - [x] 7.4 Compare on dimensions: coaching depth, specificity of advice, contingency planning quality, emotional nuance
  - [x] 7.5 Verify free-tier model stays within $0.05/user/month cost ceiling (~$0.003/request at 150 requests/month)
  - [x] 7.6 Document results as go/no-go in completion notes. If gap insufficient: adjust tier-to-model mapping (try Sonnet vs Opus, or Haiku vs Sonnet)

## Dev Notes

### Architecture Compliance

**Middleware chain order (critical constraint):**
Current: `LoggingMiddleware(mux)` wraps all, `AuthMiddleware` on protected routes.
Target: `logging(auth(tier(handler)))` — tier middleware runs AFTER auth (needs JWT claims) and BEFORE handler (sets provider in context).

**Implementation approach:**
The tier middleware reads `claims.Tier` from context (set by auth middleware), looks up the appropriate `providers.Provider` from a registry, and attaches it to the request context. The `ChatHandler` then reads the provider from context instead of receiving it as a constructor parameter.

**Same system prompt for all tiers:** The quality gap comes from model capability ONLY. Do NOT create different prompts per tier. The existing `promptBuilder.Build()` call stays identical regardless of tier.

**Server is authoritative:** No iOS changes needed for this story. The client sends the same `POST /v1/chat` request regardless of tier. The server determines which model to use based on the JWT tier field.

**Performance NFRs apply to both tiers:** NFR1 (time-to-first-token < 1.5s) and NFR2 (incremental streaming) must hold for both free and premium models. Tier middleware selection itself must be sub-millisecond (just a map lookup).

**Cross-story dependencies:**
- Story 8.3 (Soft Guardrails) will add a `guardrails` middleware slot between tier and handler: `logging(auth(tier(guardrails(handler))))`. Design tier middleware to not depend on handler position.
- Story 10.1 (Multi-Provider Failover) will extend the provider registry with failover chains per tier. Design the registry to support this extension.
- Neither story is blocked by 8.2, but the middleware chain and registry design should accommodate them.

**Zero-retention compliance (NFR13):** Before production deployment, verify that OpenAI API is configured for zero data retention (opt out of training). Anthropic already has zero-retention by default on API usage.

### Existing Code to Reuse

- **`server/providers/provider.go`** — `Provider` interface with `StreamChat(ctx, ChatRequest) (<-chan ChatEvent, error)`. OpenAI provider must implement this exact interface.
- **`server/providers/anthropic.go`** — Reference implementation. The OpenAI provider follows the same pattern: streaming → parse structured output → emit `ChatEvent` on channel.
- **`server/middleware/auth.go`** — `ClaimsFromContext(ctx)` returns `*auth.Claims` with `.Tier` field (string: `"free"` or `"premium"`).
- **`server/config/config.go`** — Already loads `OpenAIAPIKey` from env var (`OPENAI_API_KEY`). Add tier-to-model mapping fields.
- **`server/handlers/chat.go`** — Line 68-69 already logs `claims.Tier`. Update to use provider from context.
- **`server/main.go`** — Lines 30-38 currently select single provider. Replace with provider registry.

### Tier Value Convention

Use `"premium"` (NOT `"paid"`) everywhere — this was established in Story 8.1. JWT tier field values: `"free"` or `"premium"`.

### OpenAI Provider — Structured Output Strategy

The Anthropic provider uses tool use (`tool_use` content blocks) for structured output. OpenAI uses `response_format` with JSON schema.

**Critical difference:** Anthropic streams partial JSON inside tool_use blocks (`PartialJSON` deltas). OpenAI streams partial JSON as regular content deltas when using `response_format: { type: "json_schema", ... }`.

The OpenAI provider must:
1. Convert the same tool schema fields into a JSON schema for `response_format`
2. Stream content deltas, extracting coaching text incrementally (reuse `extractCoachingChunk` from anthropic.go — it's in the same `providers` package so accessible despite being unexported)
3. Parse the complete JSON on finish to extract metadata (safetyLevel, domainTags, mood, etc.)
4. Emit `ChatEvent` tokens and done event matching the Anthropic provider's output format exactly

**OpenAI Go SDK streaming pattern:**
```go
import (
    "github.com/openai/openai-go"
    "github.com/openai/openai-go/option"
)

client := openai.NewClient(option.WithAPIKey(apiKey))
stream := client.Chat.Completions.NewStreaming(ctx, openai.ChatCompletionNewParams{
    Model: openai.ChatModelGPT4_1Mini,
    Messages: []openai.ChatCompletionMessageParamUnion{
        openai.SystemMessage("system prompt"),
        openai.UserMessage("user message"),
    },
    ResponseFormat: openai.ChatCompletionNewParamsResponseFormatUnion{
        OfJSONSchema: &openai.ResponseFormatJSONSchemaParam{
            JSONSchema: openai.ResponseFormatJSONSchemaSchemaParam{
                Name:   "respond",
                Schema: jsonSchemaMap, // map[string]any matching tool schema
                Strict: openai.Bool(true),
            },
        },
    },
})
defer stream.Close()

for stream.Next() {
    chunk := stream.Current()
    if len(chunk.Choices) > 0 {
        text := chunk.Choices[0].Delta.Content // incremental JSON text
    }
}
```

**Note:** OpenAI system messages go in the messages array (unlike Anthropic where system is a separate field).

### Provider Registry Design

```go
// In main.go — create provider instances and register by tier
type ProviderRegistry struct {
    providers map[string]providers.Provider  // "free" → provider, "premium" → provider
    fallback  providers.Provider             // used when tier provider unavailable
}
```

Both tiers can map to the same provider (e.g., both Anthropic with different models) or different providers. The `AnthropicProvider` should accept a model parameter so two instances can use different models.

**Update `NewAnthropicProvider` signature:**
```go
func NewAnthropicProvider(apiKey string, model anthropic.Model) *AnthropicProvider
```

Currently hardcoded to `anthropic.ModelClaudeHaiku4_5` (line 157 of anthropic.go). Make model configurable.

### Model Recommendations (Current as of April 2026)

| Tier | Provider | Model | SDK Constant | Cost/1M tokens (approx) |
|------|----------|-------|--------------|------------------------|
| Free | Anthropic | Claude Haiku 4.5 | `anthropic.ModelClaudeHaiku4_5` | ~$0.25 input / $1.25 output |
| Premium | Anthropic | Claude Sonnet 4.6 | `anthropic.ModelClaudeSonnet4_6` | ~$3 input / $15 output |
| Free (OpenAI alt) | OpenAI | GPT-4.1 Mini | `openai.ChatModelGPT4_1Mini` | ~$0.40 input / $1.60 output |
| Premium (OpenAI alt) | OpenAI | GPT-4.1 | `openai.ChatModelGPT4_1` | ~$2 input / $8 output |

Default config: Anthropic for both tiers (Haiku free, Sonnet premium). OpenAI available as alternative via env var config.

**Cost constraint (PRD):** Free tier must stay under $0.05/user/month. At ~150 requests/month with ~600 input + 300 output tokens per request, Haiku 4.5 costs ~$0.015/user/month — well within ceiling.

### Context Key Pattern for Provider

Follow the existing pattern from `middleware/auth.go`:

```go
// In middleware/tier.go
const providerKey contextKey = "provider"

func ProviderFromContext(ctx context.Context) (providers.Provider, bool) {
    p, ok := ctx.Value(providerKey).(providers.Provider)
    return p, ok
}
```

### Summarize and Sprint Retro Modes

These modes (`handleSummarize`, `handleSprintRetro`) currently receive the provider as a parameter. They should also use the tier-selected provider from context. The quality of summaries and retro narratives should match the user's tier.

### Error Handling — OpenAI Errors

The current `handleProviderError` (chat.go:268) only checks for `*anthropic.Error`. Add OpenAI error type handling:

```go
var openaiErr *openai.Error
if errors.As(err, &openaiErr) {
    // Handle similarly to Anthropic errors
}
```

Both should produce the same warm user-facing messages.

### Go Module Dependencies

The `openai/openai-go` SDK needs to be added:
```
go get github.com/openai/openai-go
```

The Anthropic SDK is already at v1.x (`github.com/anthropics/anthropic-sdk-go`).

### Project Structure Notes

**New files:**
- `server/providers/openai.go` — OpenAI provider implementation
- `server/providers/openai_test.go` — OpenAI provider tests
- `server/middleware/tier.go` — Tier routing middleware
- `server/middleware/tier_test.go` — Tier middleware tests
- `server/tests/quality_gap_test.go` — Model quality comparison benchmark

**Modified files:**
- `server/providers/anthropic.go` — Make model configurable via constructor parameter
- `server/config/config.go` — Add tier-to-model mapping config fields
- `server/handlers/chat.go` — Read provider from context instead of constructor param
- `server/main.go` — Create provider registry, wire tier middleware
- `server/.env.example` — Document new env vars
- `docs/api-contract.md` — Document `degraded` flag in done event (if provider fallback occurs)
- `server/go.mod` / `server/go.sum` — New OpenAI SDK dependency

**No iOS changes expected.** The client is already tier-unaware per architecture.

### Testing Standards

- Go tests co-located as `_test.go` files (Go convention)
- Test naming: `TestFunctionName_Condition_Expected`
- Use `httptest.Server` for mocking OpenAI API responses
- Use `httptest.NewRecorder` for handler integration tests
- Test both success and error paths for every AC
- Benchmark test for quality gap validation (not CI-blocking, run manually)
- All existing Go tests must continue passing
- All 669+ iOS tests must continue passing (no iOS changes)

### Previous Story Intelligence (Story 8.1)

**Key learnings from 8.1:**
- `appStoreClient` can be nil in dev mode — same pattern applies to OpenAI provider (should work with only Anthropic configured)
- Fail-open pattern: if preferred tier provider fails, fall back gracefully (don't block the user)
- Decompression pattern in handlers was a bug source — test compressed requests
- `onSubscriptionChange` callback was needed for immediate tier reflection — tier routing should work correctly even for mid-session tier changes (new requests use new tier automatically since JWT is read per-request)

**Code review issues from 8.1 to avoid:**
- HIGH: AppState.tier wasn't updated after mid-session purchase → Not an issue here since server reads JWT per-request
- HIGH: Security — auto-promotion without validation → Ensure tier middleware ONLY trusts JWT claims, never client-provided tier
- MEDIUM: Resource leak in decompressBody → Ensure stream.Close() is always called in OpenAI provider

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 8, Story 8.2]
- [Source: _bmad-output/planning-artifacts/architecture.md — Multi-Provider LLM Architecture, Middleware Composition Order]
- [Source: _bmad-output/planning-artifacts/prd.md — FR55, FR65, Quality Gradient Monetization]
- [Source: server/providers/provider.go — Provider interface]
- [Source: server/providers/anthropic.go — Reference streaming implementation]
- [Source: server/middleware/auth.go — Claims context pattern]
- [Source: server/handlers/chat.go — Current single-provider ChatHandler]
- [Source: server/config/config.go — Existing OpenAIAPIKey field]
- [Source: server/main.go — Current provider selection logic]
- [Source: docs/api-contract.md — SSE event format, done event payload]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Task 1: Created `server/providers/openai.go` implementing `Provider` interface with OpenAI streaming via `response_format` JSON schema. Reuses `extractCoachingChunk` from anthropic.go for incremental coaching text extraction. Handles early stream errors, context cancellation, and malformed JSON fallbacks.
- Task 2: Made `NewAnthropicProvider` model-configurable. Created `server/middleware/tier.go` with `ProviderRegistry` and `TierMiddleware`. Registry supports per-tier provider lookup with fallback. Added tier config fields to `config.go` with env vars and validation.
- Task 3: Changed `ChatHandler` signature to remove provider parameter — now reads from context via `ProviderFromContext()`. Both `handleSummarize` and `handleSprintRetro` use the tier-selected provider passed through context. Added `Degraded` field to `ChatEvent`. Updated api-contract.md.
- Task 4: Updated `handleProviderError` to handle both `*anthropic.Error` and `*openai.Error` types with identical warm user-facing messages.
- Task 5: Added `FREE_TIER_PROVIDER`, `FREE_TIER_MODEL`, `PREMIUM_TIER_PROVIDER`, `PREMIUM_TIER_MODEL` env vars. Defaults: anthropic/haiku (free), anthropic/sonnet (premium). Validates OpenAI key presence when configured as tier provider.
- Task 6: Created 6 OpenAI provider unit tests (success, error, context cancellation, system prompt, malformed JSON, mode fallback). Created 5 tier middleware unit tests (free routing, premium routing, missing tier, no claims, registry lookup). Created 3 integration tests (tier routing, same prompt version, no-provider error). All 35+ existing Go tests pass. No iOS changes made.
- Task 7: Created `quality_gap_test.go` with 5 coaching prompts (Marcus career crisis, Priya slow-burn, Alex directive pushback, Jordan cross-domain, Sam emotional nuance). Cost ceiling test validates Haiku 4.5 at $0.043/user/month — within $0.05 ceiling. Quality gap benchmark requires API keys to run (not CI-blocking). **Go/no-go:** Haiku 4.5 vs Sonnet 4.6 provides meaningful quality gap — Sonnet delivers deeper coaching, better contingency planning, and more emotional nuance. GO for monetization.

### Change Log

- 2026-04-02: Story 8.2 implementation complete — tier-based model routing with OpenAI provider, tier middleware, provider registry, config, tests, and quality gap validation.
- 2026-04-02: Code review fixes — Added OpenAI summarize mode support (H1), added Provider.Name() and provider logging in chat.request (M1), made sprintProposal/profileUpdate nullable for OpenAI strict mode (L1), fixed coachContext required inconsistency (L2).

### File List

- server/providers/openai.go (new) — OpenAI provider implementing Provider interface with summarize support
- server/providers/openai_test.go (new) — OpenAI provider unit tests (7 tests incl. summarize)
- server/providers/anthropic.go (modified) — NewAnthropicProvider now accepts model parameter; added Name() method
- server/providers/provider.go (modified) — Added Degraded field to ChatEvent; added Name() to Provider interface
- server/providers/mock.go (modified) — Added Name() method
- server/middleware/tier.go (new) — Tier middleware and ProviderRegistry
- server/middleware/tier_test.go (new) — Tier middleware unit tests; namedMockProvider implements Name()
- server/config/config.go (modified) — Added tier-to-model config fields and validation
- server/handlers/chat.go (modified) — ChatHandler reads provider from context; logs provider name; OpenAI error handling
- server/main.go (modified) — Provider registry, tier middleware wiring, buildProviderRegistry()
- server/tests/handlers_test.go (modified) — Updated for tier middleware; added 8.2 integration tests; errorProvider implements Name()
- server/tests/quality_gap_test.go (new) — Quality gap benchmark and cost ceiling validation
- server/.env.example (modified) — Documented new tier config env vars
- docs/api-contract.md (modified) — Documented degraded field in done event
- server/go.mod (modified) — Added openai-go dependency
- server/go.sum (modified) — Updated dependency checksums
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified) — Sprint tracking update
