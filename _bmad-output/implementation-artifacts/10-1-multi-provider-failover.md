# Story 10.1: Multi-Provider Failover

Status: done

## Story

As a user in a coaching conversation,
I want the system to seamlessly switch AI providers if one goes down,
So that my coaching experience is never interrupted by backend issues.

## Acceptance Criteria

1. **Given** the primary LLM provider fails, **When** the server detects the failure, **Then** it reroutes to the secondary provider within 5 seconds (NFR3), the failover is logged at Warn level (slog structured JSON), and the user sees a seamless or minimally interrupted experience.

2. **Given** a provider fails mid-conversation (FR74), **When** the SSE stream breaks, **Then** partial responses are preserved, failover to the secondary provider resumes generation, and the user sees continuous (or near-continuous) text output.

3. **Given** the provider interface, **When** configured on the server, **Then** at least 2 providers are active simultaneously (primary + fallback per NFR26), failover order is configurable per tier, and the server never exposes raw provider errors to the client.

4. **Given** a new provider needs to be added (FR67), **When** the server configuration is updated, **Then** the new provider is available without requiring an app update (NFR19) — provider swapping is server-side only.

## Tasks / Subtasks

- [x] Task 1: Extend Config for failover chain (AC: #3, #4)
  - [x] 1.1 Add `FreeTierFallbackProvider`, `FreeTierFallbackModel`, `PremiumTierFallbackProvider`, `PremiumTierFallbackModel` env vars to `config/config.go`
  - [x] 1.2 Add corresponding fields to `Config` struct
  - [x] 1.3 Update `.env.example` with new env vars and comments
  - [x] 1.4 Log failover chain configuration at startup

- [x] Task 2: Refactor ProviderRegistry for failover chains (AC: #3)
  - [x] 2.1 Change `ProviderRegistry` to store `map[string][]providers.Provider` (ordered chain per tier) instead of single provider. Rename existing `fallback` field to `defaultProvider` to avoid confusion with failover fallback concept — `defaultProvider` is the tier-not-found default, failover is within a tier's chain.
  - [x] 2.2 Add `RegisterChain(tier string, chain []providers.Provider)` method
  - [x] 2.3 `GetChain(tier)` returns the full `[]providers.Provider` chain (primary + failover providers)
  - [x] 2.4 Keep `Get(tier)` returning a single provider (first in chain) for backward compatibility
  - [x] 2.5 Add new context key `providerChainKey` and `ProviderChainFromContext(ctx) ([]providers.Provider, bool)` function. Keep existing `ProviderFromContext` returning first provider in chain for non-failover paths.
  - [x] 2.6 Update `TierMiddleware` to attach the full provider chain to context via `providerChainKey`
  - [x] 2.7 Update `main.go` `buildProviderRegistry` to build chains from config

- [x] Task 3: Add error signaling to ChatEvent channel (AC: #2)
  - [x] 3.1 Add `Err error` field to `ChatEvent` struct in `providers/provider.go` (use `json:"-"` tag so it's never serialized)
  - [x] 3.2 Update `AnthropicProvider.StreamChat` to send a `ChatEvent{Type: "error", Err: err}` before closing the channel when an error occurs mid-stream (after initial success)
  - [x] 3.3 Update `OpenAIProvider.StreamChat` with the same error event pattern
  - [x] 3.4 Update `MockProvider` to support configurable error injection: add `StubbedError error` and `FailAfterNTokens int` fields. When `FailAfterNTokens > 0`, send that many token events then send error event.

- [x] Task 4: Implement failover orchestration in chat handler (AC: #1, #2, #3)
  - [x] 4.1 Create `streamWithFailover` function in `handlers/chat.go` that:
    - Gets provider chain from context via `ProviderChainFromContext`
    - Tries primary provider's `StreamChat`
    - On initial error (before streaming starts): log at Warn, try next provider in chain
    - **Rate limit discrimination**: Before failover, check if error is 429 via `errors.As` for `*anthropic.Error` / `*openai.Error` with `StatusCode == 429`. If 429, do NOT failover — return `rate_limited` error to client immediately.
    - On mid-stream error (detected via `ChatEvent.Err != nil`): preserve accumulated partial tokens, try next provider with continuation context
    - Sets `Degraded = true` on the done event when a non-primary provider was used
  - [x] 4.2 **SSE header timing**: Do NOT write SSE headers (`Content-Type: text/event-stream`, `WriteHeader(200)`) until a provider successfully begins streaming. This allows clean failover on initial errors without corrupting the response.
  - [x] 4.3 Replace direct `provider.StreamChat` call in `ChatHandler` with `streamWithFailover`
  - [x] 4.4 Ensure failover completes within 5 seconds (NFR3) — use context with timeout per provider attempt
  - [x] 4.5 If ALL providers fail, return existing `provider_unavailable` error response via `handleProviderError`
  - [x] 4.6 Log each failover attempt: `slog.Warn("provider.failover", "from", name, "to", name, "reason", err)`

- [x] Task 5: Handle mid-stream failover (AC: #2)
  - [x] 5.1 Track accumulated token text during streaming in `streamWithFailover`
  - [x] 5.2 On mid-stream provider failure (detected via `ChatEvent{Type: "error"}`), construct a continuation request:
    - Append accumulated partial response as an assistant message to `ChatRequest.Messages`
    - Add a continuation instruction to the system prompt: "Continue the response seamlessly from where it was interrupted. Do not repeat any prior content."
  - [x] 5.3 Resume streaming to client from fallback provider — tokens flow continuously to the client with no gap
  - [x] 5.4 Merge usage stats from both providers in the final `done` event: sum `InputTokens` and `OutputTokens`

- [x] Task 6: Apply failover to summarize and sprint_retro handlers (AC: #1)
  - [x] 6.1 Add failover to `handleSummarize` — note: even though summarize is "non-streaming" to the client, it still calls `provider.StreamChat` internally and collects events. Failover should handle both initial errors AND mid-collection channel close before `done` event.
  - [x] 6.2 Add failover to `handleSprintRetro` — same streaming failover pattern as chat

- [x] Task 7: Write tests (AC: #1, #2, #3, #4)
  - [x] 7.1 `TestChatHandler_PrimaryFails_FailsOverToSecondary` — mock primary returns error, secondary succeeds
  - [x] 7.2 `TestChatHandler_PrimaryFailsMidStream_PreservesPartialAndContinues` — mock primary sends 3 tokens then error event, secondary picks up
  - [x] 7.3 `TestChatHandler_AllProvidersFail_Returns502` — all providers error, verify 502 response
  - [x] 7.4 `TestChatHandler_FailoverSetsDegradedFlag` — verify `degraded: true` in done event
  - [x] 7.5 `TestChatHandler_FailoverLogsWarn` — verify slog output contains provider.failover
  - [x] 7.6 `TestChatHandler_RateLimited_NoFailover` — verify 429 error is returned directly without failover attempt
  - [x] 7.7 `TestProviderRegistry_ChainOrdering` — verify chain returns providers in correct order
  - [x] 7.8 `TestProviderRegistry_DefaultProvider` — verify unknown tier returns default provider chain
  - [x] 7.9 Update existing `handlers_test.go` tests to work with new chain-based registry

## Dev Notes

### Current State of the Codebase

**Provider Interface** (`server/providers/provider.go`):
```go
type Provider interface {
    StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error)
    Name() string
}
```
Two implementations exist: `AnthropicProvider` (`anthropic.go`) and `OpenAIProvider` (`openai.go`), plus `MockProvider` for testing.

**Current ProviderRegistry** (`server/middleware/tier.go`):
- Maps tier name → single `Provider` instance
- `Get(tier)` returns one provider or fallback
- `TierMiddleware` attaches single provider to request context
- **This is what needs to change** — must support ordered chains per tier

**Current Chat Handler** (`server/handlers/chat.go`):
- Calls `provider.StreamChat()` once — no retry or failover
- On error, `handleProviderError()` translates SDK-specific errors to user-facing JSON
- `Degraded` field already exists in `ChatEvent` and is conditionally included in SSE `done` event
- Three streaming paths: `ChatHandler` (main), `handleSummarize` (non-streaming), `handleSprintRetro` (streaming)

**Current Config** (`server/config/config.go`):
- `FreeTierProvider/Model` and `PremiumTierProvider/Model` env vars
- Supports `anthropic` and `openai` as provider names
- `buildProviderRegistry()` in `main.go` creates providers and registers per tier

**Current Error Handling** (`handlers/chat.go:289-347`):
- `handleProviderError()` checks for `*anthropic.Error` and `*openai.Error` via `errors.As`
- Returns `rate_limited` (429) or `provider_unavailable` (502) with `retryAfter`
- This function remains useful as the final fallback when ALL providers fail

### Architecture Compliance

- **Go stdlib only** — no third-party HTTP frameworks. Use `net/http`, `slog`, `context`.
- **Middleware order** is `logging(auth(tier(guardrails(handler))))` — failover lives INSIDE the handler, not as middleware.
- **Error wrapping**: `fmt.Errorf("scope: %w", err)` for all Go errors.
- **Logging**: `slog.Warn("provider.failover", "from", "anthropic", "to", "openai", "reason", err)` — structured JSON, Warn level for failover events.
- **No HTTP 500** — use specific status codes (401, 502, 503).
- **Docker**: Alpine-based image. Ensure no new dependencies break the multi-stage build.

### Key Design Decisions

1. **Failover in handler, not middleware**: The `TierMiddleware` attaches the provider chain to context. The `ChatHandler` owns the failover loop. This keeps middleware simple and gives the handler control over partial-response recovery.

2. **Mid-stream error signaling**: Currently `StreamChat` returns `<-chan ChatEvent` and the channel just closes when done. There is NO way to distinguish a normal close from a mid-stream error. **Solution**: Add an `Err error` field to `ChatEvent` (with `json:"-"` tag). Providers send a `ChatEvent{Type: "error", Err: err}` before closing the channel on mid-stream failure. The failover loop checks for this error event.

3. **Mid-stream failover strategy**: When the primary provider's channel sends an error event mid-stream:
   - Collect all tokens received so far into a string
   - Create a new `ChatRequest` with the partial response appended as an assistant message
   - Add a continuation instruction to the system prompt
   - Call the fallback provider's `StreamChat` and continue streaming to the client
   - The client never sees a break — tokens flow continuously

4. **Per-tier failover chains**: Each tier gets an ordered list of providers. Example: free tier might be `[haiku, gpt-4.1-mini]`, premium might be `[sonnet, gpt-4.1]`. Configured via env vars.

5. **Naming clarity**: The existing `ProviderRegistry.fallback` field means "default provider when tier is not found." Rename it to `defaultProvider`. "Fallback" in the failover context means "next provider in the chain within a tier." Keep these concepts separate.

6. **Rate limit (429) vs. failover**: Do NOT failover on 429 errors. 429 means the provider is working but rate-limited — the fallback would likely also be rate-limited. Check `StatusCode == 429` via `errors.As` for `*anthropic.Error` / `*openai.Error` before attempting failover. On 429, return `rate_limited` error directly.

7. **SSE header timing**: Do NOT write SSE headers until a provider successfully begins streaming. If headers are written before failover, the HTTP status code is locked to 200 and error responses cannot be sent.

8. **Timeout budget**: Each provider attempt gets a context timeout. NFR3 requires total failover within 5 seconds, so budget ~4s for detection + ~1s for fallback initiation. Use `context.WithTimeout` per attempt.

9. **Degraded flag**: Already in the schema. When failover occurs, set `event.Degraded = true` on the done event. iOS already handles this field — no client changes needed.

10. **Usage stats merging**: When failover occurs mid-stream, sum `InputTokens` and `OutputTokens` from both providers in the final `done` event.

### Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `server/providers/provider.go` | MODIFY | Add `Err error` field with `json:"-"` to `ChatEvent` |
| `server/providers/anthropic.go` | MODIFY | Send error event before channel close on mid-stream failure |
| `server/providers/openai.go` | MODIFY | Send error event before channel close on mid-stream failure |
| `server/providers/mock.go` | MODIFY | Add `StubbedError`, `FailAfterNTokens` for test error injection |
| `server/config/config.go` | MODIFY | Add fallback provider/model env vars |
| `server/middleware/tier.go` | MODIFY | Rename `fallback` → `defaultProvider`, store chains, add `ProviderChainFromContext` |
| `server/handlers/chat.go` | MODIFY | Add `streamWithFailover`, update all three handler paths |
| `server/main.go` | MODIFY | Build provider chains from config |
| `server/.env.example` | MODIFY | Add fallback env var documentation |
| `server/tests/handlers_test.go` | MODIFY | Update existing tests, add failover test cases |

### Existing Patterns to Follow

- **Provider creation**: See `buildProviderRegistry()` in `main.go:110-154` — use the same `makeProvider` pattern for fallback providers
- **Mock provider**: `providers/mock.go` — use for testing failover scenarios. May need a `FailingMockProvider` that errors on demand
- **Error detection**: Both providers check `stream.Next()` immediately in `StreamChat` to detect initial errors before streaming. The channel is closed on error. Check for channel close + error in the failover loop.
- **SSE format**: `fmt.Fprintf(w, "event: %s\ndata: %s\n\n", eventType, data)` — contractual format, do not change
- **Test pattern**: Go standard `testing` + `httptest`. Test names: `TestHandlerName_Condition_Expected`

### Previous Story Intelligence

Story 10.1 is **server-only (Go)** — no iOS changes needed. The `degraded` field is already handled in iOS `ChatEvent.swift` and `SSEParser.swift`. All previous iOS patterns (MVVM, Swift Testing, GRDB) are not applicable to this story.

### Git Intelligence

Recent commits follow pattern: `feat: Story X.Y — Description with code review fixes`. Last 5 commits are all Epic 9 (Notifications). This is the first story in Epic 10.

### What NOT to Do

- **Do NOT modify iOS code** — failover is entirely server-side. The `degraded` flag is already in the API contract and iOS data model.
- **Do NOT add a circuit breaker** — overkill for MVP. Simple sequential failover is sufficient. Circuit breaker can be added in a future story if needed.
- **Do NOT add health check probing** — providers are tested on-demand when a request comes in, not via background health checks.
- **Do NOT change the SSE event format** — the `event: provider_switch` event mentioned in architecture is optional and adds complexity. Use the existing `degraded` flag in the `done` event instead.
- **Do NOT add Gemini or Kimi K2 providers** — those are future work. This story focuses on failover between existing Anthropic and OpenAI providers.
- **Do NOT add retry logic for rate limiting (429)** — rate limiting means the provider is working but busy. Failover is for provider failure, not rate limiting. Keep existing `retryAfter` behavior for 429s.

### Project Structure Notes

- All server code lives in `server/` directory
- Go module path: `github.com/ducdo/sprinty/server`
- Imports use full module path: `github.com/ducdo/sprinty/server/providers`
- Tests co-located with source (Go convention) or in `server/tests/` for integration tests
- Provider SDKs: `github.com/anthropics/anthropic-sdk-go`, `github.com/openai/openai-go`

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Provider Failover Architecture, Error Taxonomy, Multi-Provider Support]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 10, Story 10.1 requirements and BDD scenarios]
- [Source: docs/api-contract.md — Error codes, degraded field, retryAfter semantics]
- [Source: server/providers/provider.go — Provider interface definition]
- [Source: server/middleware/tier.go — ProviderRegistry current implementation]
- [Source: server/handlers/chat.go — Current chat handler, error handling, SSE streaming]
- [Source: server/config/config.go — Current configuration with tier routing]
- [Source: server/main.go — Provider initialization and registry building]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None — clean implementation with no blocking issues.

### Completion Notes List
- Task 1: Added `FreeTierFallbackProvider/Model` and `PremiumTierFallbackProvider/Model` env vars to config. Updated `.env.example` with documentation. Failover chain logged at startup when configured.
- Task 2: Refactored `ProviderRegistry` from single provider per tier to ordered chains (`[]providers.Provider`). Renamed `fallback` to `defaultProvider`. Added `RegisterChain`, `GetChain`, `ProviderChainFromContext`. `TierMiddleware` now attaches full chain to context. `main.go` builds chains from config.
- Task 3: Added `Err error` field (`json:"-"`) to `ChatEvent`. Both `AnthropicProvider` and `OpenAIProvider` now send `ChatEvent{Type: "error", Err: err}` before closing channel on mid-stream failure. `MockProvider` supports `StubbedError` and `FailAfterNTokens` for test error injection.
- Task 4: Implemented `streamWithFailover` in `handlers/chat.go`. Tries providers in chain order. Rate limit (429) detection via `isRateLimitError` — no failover on 429. SSE headers deferred until first successful stream event. Per-provider 4s timeout. `Degraded=true` set on done event when non-primary provider used.
- Task 5: Mid-stream failover preserves accumulated tokens, constructs continuation request with partial response as assistant message + continuation instruction. Usage stats merged (summed) across providers.
- Task 6: Applied failover to `handleSummarize` (non-streaming, uses `streamWithFailover` with `nil` eventCh) and `handleSprintRetro` (streaming, uses eventCh pattern).
- Task 7: 9 test cases covering: primary fails/failover, mid-stream failover with partial preservation, all providers fail (502), degraded flag, rate limit no-failover (429), chain ordering, default provider, and backward compatibility.

### Change Log
- 2026-04-03: Story 10.1 implemented — multi-provider failover with mid-stream recovery
- 2026-04-03: Code review — simplified `streamWithFailover` control flow (M1 fix: eliminated dead code path for non-streaming degraded case)

### File List
- server/config/config.go (modified)
- server/config/config_test.go (created)
- server/middleware/tier.go (modified)
- server/middleware/tier_test.go (modified)
- server/providers/provider.go (modified)
- server/providers/anthropic.go (modified)
- server/providers/openai.go (modified)
- server/providers/mock.go (modified)
- server/handlers/chat.go (modified)
- server/main.go (modified)
- server/.env.example (modified)
- server/tests/handlers_test.go (modified)
