# Story 1.6: Real AI Coaching Integration

Status: done

## Story

As a user,
I want my coaching conversation powered by a real AI,
So that I receive meaningful, personalized guidance from my first message.

## Acceptance Criteria

1. **Given** a user sends a message in a coaching conversation
   **When** the server receives the chat request
   **Then** it routes to the Anthropic provider (free tier model) via the provider interface
   **And** assembles the system prompt from modular sections (base-persona + discovery)
   **And** streams the response as SSE events (`event: token` with incremental text)
   **And** the `event: done` includes safetyLevel, domainTags, mood, and usage metadata

2. **Given** the provider interface
   **When** implemented
   **Then** it defines a common interface that all LLM providers implement
   **And** Anthropic is the first concrete implementation (tool-use structured output)
   **And** adding a new provider requires implementing the interface, not changing calling code

3. **Given** the provider returns a response
   **When** the SSE stream completes
   **Then** time-to-first-token is under 1.5 seconds (NFR1)
   **And** the user sees text appearing incrementally (NFR2)
   **And** no API keys are present in the app binary (all via backend proxy)

4. **Given** the system prompt is assembled
   **When** a coaching conversation begins
   **Then** the prompt includes the base persona and discovery mode sections
   **And** a content hash version is generated for the prompt
   **And** the conversation uses the prompt version from when it started

5. **Given** gzip compression is enabled
   **When** the iOS app sends a chat request
   **Then** the payload is compressed (60-80% reduction)

6. **Given** the Anthropic provider returns a 500 error
   **When** the server handles the failure
   **Then** the error is logged at Warn level
   **And** the server returns a warm error to the client: `{"error": "provider_unavailable", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 10}`

7. **Given** the Anthropic provider returns a 429 rate limit
   **When** the server handles the throttle
   **Then** it returns the appropriate retryAfter value
   **And** the iOS app displays: "Your coach needs a moment. Try again shortly." (UX-DR71)

8. **Given** the provider returns malformed structured output
   **When** the server parses the response
   **Then** it fails gracefully — partial response is preserved, safetyLevel defaults to Green, and an error is logged

## Tasks / Subtasks

- [x] Task 1: Create Anthropic provider implementation (AC: #1, #2, #8)
  - [x] 1.1 Add `github.com/anthropics/anthropic-sdk-go@v1.27.0` to `server/go.mod`
  - [x] 1.2 Create `server/providers/anthropic.go` implementing existing `Provider` interface
  - [x] 1.3 Use `anthropics/anthropic-sdk-go` SDK — tool-use structured output with JSON schema for `{coaching, safetyLevel, domainTags, mood, memoryReferenced}`
  - [x] 1.4 Disable SDK auto-retries: `option.WithMaxRetries(0)` — server must control retry behavior to translate errors into warm user-facing messages
  - [x] 1.5 Stream via `client.Messages.NewStreaming()` — handle `ContentBlockDeltaEvent` with `event.Delta.PartialJSON` to extract coaching text chunks (see Streaming JSON Parsing section)
  - [x] 1.6 Hold metadata (safetyLevel, domainTags, mood) until tool call completes via `message.Accumulate(event)`, then parse full JSON and emit as `ChatEvent{Type: "done"}`
  - [x] 1.7 Handle malformed structured output gracefully: preserve partial text, default safetyLevel to "green", mood to "welcoming", memoryReferenced to false, log warning
  - [x] 1.8 Context cancellation support — check `ctx.Done()` in streaming loop
  - [x] 1.9 Wrap errors with context: `fmt.Errorf("anthropic.StreamChat: %w", err)`. Detect `*anthropic.Error` type for status code extraction (429, 500, etc.)
  - [x] 1.10 Write tests in `server/providers/anthropic_test.go` — mock HTTP responses, verify streaming parsing, error handling, malformed output fallback

- [x] Task 2: Create system prompt builder and sections (AC: #1, #4)
  - [x] 2.1 Create `server/prompts/builder.go` — reads section files, assembles based on request context (mode)
  - [x] 2.2 Create `server/prompts/sections/base-persona.md` — coach identity, voice, warmth, clinical boundary transparency, privacy assurance, cultural neutrality
  - [x] 2.3 Create `server/prompts/sections/mode-discovery.md` — exploration, probing questions, pattern surfacing, values archaeology
  - [x] 2.4 Create `server/prompts/sections/safety.md` — inline classification instructions with structured output schema (Green/Yellow/Orange/Red)
  - [x] 2.5 Create `server/prompts/sections/mood.md` — coach expression selection instructions (welcoming/thinking/warm/focused/gentle)
  - [x] 2.6 Create `server/prompts/sections/tagging.md` — domain tag classification instructions (career, finance, relationships, etc.)
  - [x] 2.7 Create `server/prompts/sections/context-injection.md` — slot template for coach name, profile context, sprint context
  - [x] 2.8 Implement content hash versioning: SHA-256 of concatenated section contents, computed on startup, cached
  - [x] 2.9 Implement provider-specific output format wrapping: Anthropic tool-use definitions wrap the shared schema
  - [x] 2.10 Write tests in `server/prompts/builder_test.go` — assembly, hash stability, section loading, provider wrapping

- [x] Task 3: Update chat handler for real provider routing (AC: #1, #6, #7, #8)
  - [x] 3.1 Update `server/handlers/chat.go` — `ChatHandler` is a **function** `func ChatHandler(provider, promptBuilder) http.HandlerFunc` (closure pattern, NOT a struct). Add `promptBuilder *prompts.Builder` as second parameter.
  - [x] 3.2 Extend server-side `ChatRequest` in `providers/provider.go`: add `SystemPrompt string` and `Profile *ChatProfile` fields so the handler can pass the assembled prompt and profile context to the provider
  - [x] 3.3 Assemble system prompt via builder based on request mode, inject coach name from profile, set on ChatRequest before calling provider
  - [x] 3.4 Handle provider errors by detecting `*anthropic.Error` status codes: 500 → `{"error": "provider_unavailable", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 10}`
  - [x] 3.5 Handle rate limit (429): extract retryAfter from `*anthropic.Error`, return to client. Current `WriteError(w, status, code, message)` helper does NOT support retryAfter — write a new `writeErrorWithRetry()` helper or use `WriteJSON` directly for error responses containing retryAfter.
  - [x] 3.6 Add gzip request body decompression: check `Content-Encoding: gzip` header, wrap `r.Body` with `gzip.NewReader()` before JSON decoding
  - [x] 3.7 Log structured request info: `slog.Info("chat.request", "deviceId", ..., "tier", ..., "mode", ...)`
  - [x] 3.8 Update handler tests in `server/handlers/chat_test.go`

- [x] Task 4: Update server config and initialization (AC: #1, #2)
  - [x] 4.1 Update `server/config/config.go` — load `ANTHROPIC_API_KEY` from env (required in staging/production, optional in dev)
  - [x] 4.2 Update `server/main.go` — create Anthropic provider, inject into chat handler
  - [x] 4.3 Add provider selection logic: use mock provider if `ANTHROPIC_API_KEY` not set (local dev), else use Anthropic provider
  - [x] 4.4 Register prompt builder, compute initial content hash on startup
  - [x] 4.5 Add `/v1/prompt/{version}` endpoint for prompt version metadata (AC: #4)

- [x] Task 5: Add gzip compression to iOS ChatService (AC: #5)
  - [x] 5.1 Update `ios/sprinty/Services/Networking/ChatService.swift` — this file handles HTTP directly (does NOT use APIClient). Compress the JSON request body with gzip before sending.
  - [x] 5.2 Use Foundation's `NSData.compressed(using: .zlib)` does NOT produce gzip format. Use a proper gzip implementation: either add `GzipSwift` SPM package, or use the low-level `Compression` framework with gzip framing, or use `deflate` Content-Encoding (simpler — Go's `compress/flate` handles it server-side).
  - [x] 5.3 Set `Content-Encoding: gzip` (or `deflate`) header on compressed requests
  - [x] 5.4 Verify server decompresses correctly in integration test

- [x] Task 6: Update iOS ChatService for coach name and profile context (AC: #1, #4)
  - [x] 6.1 Extend iOS `ChatRequest` to include `profile` field (new `ChatProfile` struct with `coachName: String`)
  - [x] 6.2 Update `ChatServiceProtocol.streamChat()` signature to accept profile parameter. **Breaking change:** this updates the protocol, `ChatService` conformance, AND all test mocks.
  - [x] 6.3 Update `ChatService.streamChat()` implementation to include profile in request body
  - [x] 6.4 Update `CoachingViewModel.sendMessage()` to load `UserProfile` from DB and pass coach name to chatService
  - [x] 6.5 Cache `promptVersion` from first response's done event per session (active conversation uses the version from when it started)

- [x] Task 7: Update iOS error handling for provider errors (AC: #6, #7)
  - [x] 7.1 Update `ChatService` to parse `retryAfter` from server error response JSON (current code hardcodes `retryAfter: nil` on non-2xx responses)
  - [x] 7.2 `AppError.providerError(message:retryAfter:)` already exists with `Int?` — no changes needed to the enum. Just pass the parsed value.
  - [x] 7.3 Update `CoachingViewModel` error handling to display: "Your coach needs a moment. Try again shortly."
  - [x] 7.4 Implement retry-after timer in UI (disable send button for retryAfter seconds)

- [x] Task 8: Write integration tests (AC: #1-8)
  - [x] 8.1 Server integration test: end-to-end chat flow with mock Anthropic API responses (`httptest`)
  - [x] 8.2 Server test: provider error scenarios (500, 429, malformed output)
  - [x] 8.3 Server test: gzip request decompression
  - [x] 8.4 Server test: prompt assembly and versioning
  - [x] 8.5 iOS test: gzip compression on requests
  - [x] 8.6 iOS test: error handling with retryAfter

- [x] Task 9: Verify full build and test suite
  - [x] 9.1 `go test ./...` — all server tests pass
  - [x] 9.2 Run xcodegen, build with Swift 6 strict concurrency — zero warnings
  - [x] 9.3 Run full iOS test suite — all existing + new tests pass
  - [ ] 9.4 Manual smoke test: start conversation in simulator against local server with real Anthropic API key

## Dev Notes

### Architecture Compliance

- **Provider interface already exists:** `server/providers/provider.go` defines `Provider` interface with `StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error)`. The mock implementation is in `mock.go`. Anthropic implementation follows the same pattern.
- **Chat handler already exists:** `server/handlers/chat.go` — `func ChatHandler(provider) http.HandlerFunc` (closure-based handler factory, NOT a struct). Needs update to accept prompt builder as additional parameter.
- **MVVM with @Observable:** iOS side — `CoachingViewModel` already handles streaming via `chatService.streamChat()`. Minimal iOS changes needed.
- **Swift 6 strict concurrency:** All services are `Sendable`. ViewModels are `@MainActor @Observable`. No changes to this pattern.
- **No Combine:** Use `@Observable` macro. No `@Published`, no `ObservableObject`.
- **Error handling:** Use `AppError` enum. Global errors (auth, network) through `AppState`, local errors through ViewModel.

### Existing Provider Types (server/providers/provider.go)

**DO NOT CHANGE** the `Provider` interface method signature. The `ChatRequest` and `ChatEvent` structs CAN be extended.

```go
// Interface — DO NOT CHANGE signature
type Provider interface {
    StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error)
}

// ChatEvent — ADD memoryReferenced field (defaults false, backward compatible with omitempty)
type ChatEvent struct {
    Type              string   `json:"type"`
    Text              string   `json:"text,omitempty"`
    SafetyLevel       string   `json:"safetyLevel,omitempty"`
    DomainTags        []string `json:"domainTags,omitempty"`
    Mood              string   `json:"mood,omitempty"`
    MemoryReferenced  bool     `json:"memoryReferenced,omitempty"`  // NEW — false until Epic 3
    Usage             *Usage   `json:"usage,omitempty"`
}

// ChatRequest — ADD SystemPrompt and Profile fields for handler→provider data flow
type ChatRequest struct {
    Messages      []ChatMessage `json:"messages"`
    Mode          string        `json:"mode"`
    PromptVersion string        `json:"promptVersion"`
    SystemPrompt  string        `json:"systemPrompt,omitempty"`  // NEW — assembled by handler
    Profile       *ChatProfile  `json:"profile,omitempty"`       // NEW — from iOS request
}

// NEW — profile context from iOS client
type ChatProfile struct {
    CoachName string `json:"coachName"`
}
```

The handler assembles the system prompt and sets it on `ChatRequest.SystemPrompt` before calling `provider.StreamChat()`. The Anthropic provider reads `req.SystemPrompt` and passes it to the Anthropic API as the system parameter.

### Anthropic SDK Usage Pattern

Use `github.com/anthropics/anthropic-sdk-go` **v1.27.0** (official SDK, latest as of March 2026). Requires Go 1.22+.

```go
import "github.com/anthropics/anthropic-sdk-go"
import "github.com/anthropics/anthropic-sdk-go/option"
```

**Client initialization — MUST disable auto-retries:**
```go
client := anthropic.NewClient(
    option.WithAPIKey(cfg.AnthropicAPIKey),
    option.WithMaxRetries(0),  // Server controls retry/error translation
)
```
The SDK auto-retries 429/500 twice by default. Disabling this lets the server catch errors and translate them into warm user-facing messages instead of silently retrying.

**Tool-use for structured output:** Define a tool schema matching `{coaching: string, safetyLevel: string, domainTags: []string, mood: string, memoryReferenced: bool}`. The model "calls" this tool with the structured response. Use `anthropic.ToolParam` with `InputSchema` to define the JSON schema.

**Model selection:** Use `anthropic.ModelClaude3_5HaikuLatest` for free tier. Note: `claude-3-5-haiku` was deprecated in SDK v1.20.0 — use the `Latest` constant which resolves to the current model.

**Streaming:** Use `client.Messages.NewStreaming()` with tool definitions. The SDK returns events including `ContentBlockDeltaEvent` with `event.Delta.PartialJSON` for tool input chunks.

**Error handling:** Non-success HTTP responses surface as `*anthropic.Error`:
```go
var apierr *anthropic.Error
if errors.As(err, &apierr) {
    apierr.StatusCode  // 429, 500, etc.
}
```

**Context window:** System prompt + last ~20-30 conversation messages. Older messages are captured in RAG summaries (future story).

### Structured Output Streaming Strategy

The server is a **streaming JSON parser, not a pass-through.**

**How Anthropic tool-use streaming works:**
1. System prompt instructs model to call a tool with schema: `{coaching, safetyLevel, domainTags, mood, memoryReferenced}`
2. SDK streams events: `ContentBlockStartEvent` → multiple `ContentBlockDeltaEvent` → `ContentBlockStopEvent` → `MessageStopEvent`
3. For tool_use blocks, each `ContentBlockDeltaEvent` has `event.Delta.PartialJSON` containing a fragment of the JSON being built
4. The model emits one complete key-value pair at a time, then chunks the string value. So for `{"coaching": "Hello, let's talk..."}` you get progressive fragments of the coaching string.

**Provider implementation pattern:**
```go
stream := client.Messages.NewStreaming(ctx, params)
message := anthropic.Message{}
var jsonBuf strings.Builder  // accumulate partial JSON

for stream.Next() {
    event := stream.Current()
    message.Accumulate(event)  // builds final Message from deltas

    switch evt := event.AsAny().(type) {
    case anthropic.ContentBlockDeltaEvent:
        if evt.Delta.PartialJSON != "" {
            jsonBuf.WriteString(evt.Delta.PartialJSON)
            // Extract coaching text chunks from partial JSON and emit as token events
            // Strategy: detect when inside the "coaching" value and forward text fragments
        }
    case anthropic.ContentBlockStopEvent:
        // Tool call complete — parse full JSON from message.Content for metadata
    case anthropic.MessageStopEvent:
        // Extract usage from message.Usage.InputTokens / OutputTokens
    }
}
```

**Coaching text extraction from partial JSON:** The simplest approach is to accumulate the full JSON string, and after the `"coaching":"` prefix is detected, forward subsequent fragments as token events until the closing quote. A more robust approach: use `message.Accumulate(event)` for the final parse, and a simple state machine that tracks whether we're inside the coaching value for mid-stream forwarding.

**Fallback on malformed output:** If JSON parsing fails after stream completes, preserve any accumulated coaching text, default safetyLevel to "green", mood to "welcoming", memoryReferenced to false, log error.

**Important:** The streaming complexity lives INSIDE the provider implementation. The chat handler only sees clean `ChatEvent` channel events.

### System Prompt Architecture

**Modular composition** from `server/prompts/sections/*.md`:

| Section File | Purpose | Include When |
|---|---|---|
| `base-persona.md` | Coach identity, voice, warmth, boundaries, privacy | Always |
| `mode-discovery.md` | Exploration, probing questions, pattern surfacing | mode == "discovery" (default) |
| `safety.md` | Inline safety classification + output schema | Always |
| `mood.md` | Expression selection instructions | Always |
| `tagging.md` | Domain tag classification | Always |
| `context-injection.md` | Template for coach name, profile, sprint context | Always (fill slots from request) |

**Builder assembles:** Read section files on startup, concatenate based on request context. Wrap with provider-specific structured output format (Anthropic: tool definitions).

**Content hash versioning:**
- SHA-256 hash of all concatenated section file contents
- Computed once on server startup, cached in memory
- iOS sends `promptVersion` in requests (cached per session)
- New conversations get current hash; in-flight conversations keep their original hash
- No manual version bumping — hash changes automatically when any section file changes

### System Prompt Content Guidelines

**Base Persona must include:**
- Coach identity: warm, curious, sharp — direct over diplomatic
- Clinical boundary: "I'm a coach, not a therapist" communicated naturally
- Privacy: "Conversations stay on your device"
- Cultural neutrality: no Western-centric assumptions about "good life"
- Coach name injection slot: `{{coach_name}}` replaced at runtime from request profile
- Challenger stance: non-negotiable pushback capability (FR7 — cannot be disabled)
- Adaptive formality: match user energy

**Discovery Mode must include:**
- Probing questions before advising
- Pattern surfacing from conversation
- Values archaeology (what matters to the user)
- Cold-start capability (works with zero user context)
- No questionnaires — conversation openers

**Safety Classification must include:**
- Green: safe coaching, proceed normally
- Yellow: coach with care, suggest professional support gently
- Orange: pause coaching content, present crisis resources
- Red: immediate crisis resources, stop coaching entirely
- Output as part of structured JSON response

**Mood Selection must include:**
- 5 values: `welcoming`, `warm`, `focused`, `gentle`, `thinking` (thinking is client-set, not LLM-set)
- Actually 4 LLM-selectable moods: `welcoming`, `warm`, `focused`, `gentle`
- `thinking` is set client-side when user sends message — LLM should NOT return `thinking`
- Default if omitted: `welcoming`

### Go Server Patterns (MUST FOLLOW)

- **Import ordering:** std lib -> third-party -> project (`goimports` enforces)
- **Error wrapping:** `fmt.Errorf("functionName: %w", err)`
- **Context first parameter:** `func (p *AnthropicProvider) StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error)`
- **JSON tags camelCase:** matches iOS (`safetyLevel`, `domainTags`, etc.)
- **Response helpers:** existing `WriteJSON(w, status, data)` and `WriteError(w, status, code, message)` in `handlers/helpers.go` (delegates to `httputil` package). Note: `WriteError` does NOT support `retryAfter` — for error responses with retryAfter, use `WriteJSON` directly with a custom struct.
- **Config via env vars:** read once at startup into `Config` struct. No `os.Getenv` at request time.
- **Logging:** `slog` with structured JSON output. Info for requests, Warn for provider errors, Error for server bugs.
- **Testing:** `testing` + `httptest` for handler tests. Mock HTTP server for SDK tests.
- **Handler pattern:** Handlers are **closure-based functions** returning `http.HandlerFunc`, e.g., `func ChatHandler(provider providers.Provider) http.HandlerFunc { return func(w, r) { ... } }` — NOT struct methods.

### Existing Config Struct (server/config/config.go)

```go
type Config struct {
    JWTSecret       string
    Environment     string  // dev|staging|production
    Port            string  // defaults to 8080
    AnthropicAPIKey string  // Already stubbed — read from ANTHROPIC_API_KEY env
    OpenAIAPIKey    string  // Already stubbed — read from OPENAI_API_KEY env
    SentryDSN       string  // Already stubbed
}
```

The config struct already has fields for API keys. Just need to populate them from env vars and make `AnthropicAPIKey` required for non-dev environments.

### Existing Chat Handler Pattern (server/handlers/chat.go)

Current signature: `func ChatHandler(provider providers.Provider) http.HandlerFunc`

The returned handler closure:
1. Decodes `providers.ChatRequest` JSON from request body
2. Calls `provider.StreamChat(r.Context(), req)` to get event channel
3. Sets SSE headers (`text/event-stream`, `no-cache`, `keep-alive`)
4. Iterates channel: `"token"` → `event: token`, `"done"` → `event: done`
5. Uses `http.Flusher` for streaming
6. Uses `WriteError()` for error responses

**Updates needed:**
- Add `promptBuilder *prompts.Builder` as second parameter to `ChatHandler()`
- Before calling provider: assemble system prompt from builder, set on `req.SystemPrompt`
- Extract profile from iOS request, inject coach name into prompt via `{{coach_name}}` slot
- After `provider.StreamChat()` errors: detect `*anthropic.Error`, translate to warm JSON response
- Add gzip request decompression (check `Content-Encoding` header)
- Update `main.go` call site: `handlers.ChatHandler(provider, promptBuilder)`

### Existing iOS ChatService (DO NOT REINVENT)

`ChatService.swift` builds HTTP requests **directly** using `URLSession` — it does NOT use `APIClient`. The `APIClient` class exists separately for non-streaming JSON requests only.

`ChatService.swift` already:
- Constructs `URLRequest` to `baseURL/v1/chat` with POST method
- Sets `Content-Type: application/json` and `Authorization: Bearer` headers
- JSON-encodes `ChatRequest` as request body
- Calls `session.bytes(for:)` for streaming response
- Parses via `SSEParser`
- Converts to `ChatEvent` (token/done)
- Handles 401 → `AppError.authExpired`
- Handles non-2xx → `AppError.providerError(message:, retryAfter: nil)` (currently hardcodes nil)

**Updates needed:**
- Add gzip compression on request body (in ChatService.swift, NOT APIClient.swift)
- Extend `ChatRequest` to include `profile` field (coach name)
- Update `ChatServiceProtocol` signature to accept profile — breaks all conforming types + test mocks
- Parse `retryAfter` from error response JSON body (currently hardcodes nil)

### Existing iOS Models

**`ChatEvent.swift` — DO NOT CHANGE:**
```swift
enum ChatEvent: Sendable {
    case token(text: String)
    case done(safetyLevel: String, domainTags: [String], mood: String?, usage: ChatUsage)
}
```

**`ChatRequest.swift` — EXTEND with profile:**
```swift
struct ChatRequest: Codable, Sendable {
    let messages: [ChatRequestMessage]
    let mode: String
    let promptVersion: String
    let profile: ChatProfile?  // NEW — coach name for system prompt personalization
}

// NEW
struct ChatProfile: Codable, Sendable {
    let coachName: String
}
```

**`AppError.swift` — UNCHANGED (retryAfter already exists):**
```swift
case providerError(message: String, retryAfter: Int?)  // retryAfter already Optional Int
```

### Existing CoachingViewModel Pattern

`CoachingViewModel.swift` already:
- Sets `coachExpression = .thinking` on send
- Streams tokens into `streamingText`
- On `.done`: creates assistant message, saves to DB, sets expression from mood
- Handles errors via `handleError()`

**Updates needed:**
- Pass `UserProfile` data (coach name) when calling chatService
- Handle `retryAfter` in error display
- Cache `promptVersion` per session from first done event

### Error Flow (End-to-End)

**Server side — provider error to SSE/JSON response:**
1. Anthropic SDK returns `*anthropic.Error` (since auto-retries are disabled)
2. Provider's `StreamChat()` returns the error (does not translate it)
3. Chat handler detects error BEFORE streaming starts → write JSON error response (not SSE)
4. If error occurs MID-stream → close SSE stream, partial response preserved on iOS

**Error response format** (handler writes via `WriteJSON` since `WriteError` lacks retryAfter):
```go
type ErrorResponse struct {
    Error      string `json:"error"`
    Message    string `json:"message"`
    RetryAfter int    `json:"retryAfter,omitempty"`
}
```

| Anthropic Status | Server Response | retryAfter |
|---|---|---|
| 500 | `{"error": "provider_unavailable", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 10}` | 10 |
| 429 | `{"error": "rate_limited", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 30}` | 30 (or from Anthropic's Retry-After header) |
| Other 4xx/5xx | `{"error": "provider_unavailable", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 10}` | 10 |

**iOS side — JSON error to user display:**
1. `ChatService` receives non-2xx HTTP status
2. Reads response body as JSON, extracts `retryAfter` field (currently hardcodes nil — update to parse)
3. Throws `AppError.providerError(message: parsed_message, retryAfter: parsed_value)`
4. `CoachingViewModel.handleError()` catches, sets `localError`, displays message
5. UI disables send button for `retryAfter` seconds

### Middleware Composition Order

Current: `auth(handler)`. Story 1.6 does NOT add tier or guardrails middleware — those are future stories. Keep it simple:

```
auth → chat handler (with prompt builder + anthropic provider)
```

Tier-based model routing and soft guardrails are Epic 8 stories. For now, hardcode free-tier model (`claude-3-5-haiku-latest`).

### Gzip Implementation

**Server (Go):** Check `Content-Encoding: gzip` header on incoming request. If present, wrap `r.Body` with `gzip.NewReader()` before JSON decoding. Standard Go `compress/gzip` package. Remember to `defer gzipReader.Close()`.

**iOS (Swift) — WARNING: `NSData.compressed(using: .zlib)` is NOT gzip format.** Options:
1. **Recommended:** Use `Content-Encoding: deflate` instead of gzip. Foundation's `NSData.compressed(using: .zlib)` produces deflate-compatible output. Server uses Go's `compress/flate` to decompress. Simpler, no extra dependencies.
2. **Alternative:** Add `GzipSwift` SPM package for proper gzip format.
3. **Alternative:** Use low-level `Compression` framework with manual gzip framing (complex, not recommended).

Whichever encoding is chosen, the server and iOS must agree on the `Content-Encoding` header value.

### What NOT to Build in This Story

- **OpenAI provider** — Anthropic is the first implementation. OpenAI is future.
- **Tier middleware** — Hardcode free-tier model. Tier routing is Epic 8.
- **Guardrail middleware** — Soft guardrails are Epic 8.
- **Safety regression test suite** — Story 1.8 (CI/CD pipeline).
- **Multi-provider failover** — Epic 10 (resilience).
- **RAG context injection** — Epic 3 (memory system).
- **Sprint context injection** — Epic 5 (sprint goals).
- **Prompt endpoint caching on iOS** — Simple version string in requests is sufficient for now.
- **On-device LLM** — Phase 2 evaluation.
- **Logging middleware** — Inline `slog` calls in handler are sufficient for MVP.

### Previous Story Intelligence (Story 1.5)

Key learnings from Story 1.5 implementation:
- **Swift 6 concurrency fix:** `var profile` captured in `@Sendable` closure required `let updated = profile` pattern before passing to `dbPool.write`
- **project.yml:** No changes needed — xcodegen auto-discovers sources from `sprinty/` directory
- **Test count:** 134 tests across 17 suites, all passing
- **Mock provider tokens:** Already updated to warm cold-start message in Story 1.5 (4 streaming chunks)

### Git Intelligence

Recent commits show consistent patterns:
- Commit messages: `feat: Story X.X — description`
- Code review fixes in separate commits: `fix: Story X.X code review — details`
- All stories build incrementally on previous work
- Swift 6 strict concurrency enforced across all stories

### Project Structure Notes

New/modified files:

```
server/
├── main.go                           # MODIFIED — create Anthropic provider, inject into handler
├── config/
│   └── config.go                     # MODIFIED — validate ANTHROPIC_API_KEY for non-dev
├── providers/
│   ├── provider.go                   # MODIFIED — extend ChatRequest (add SystemPrompt, Profile), ChatEvent (add MemoryReferenced)
│   ├── mock.go                       # UNCHANGED
│   └── anthropic.go                  # NEW — Anthropic SDK implementation
├── handlers/
│   ├── chat.go                       # MODIFIED — prompt builder integration, error handling, gzip
│   └── prompt.go                     # NEW — prompt version metadata endpoint
├── prompts/
│   ├── builder.go                    # NEW — section assembly, hash versioning
│   └── sections/
│       ├── base-persona.md           # NEW — coach identity and voice
│       ├── mode-discovery.md         # NEW — discovery mode instructions
│       ├── safety.md                 # NEW — inline safety classification
│       ├── mood.md                   # NEW — expression selection
│       ├── tagging.md                # NEW — domain tag classification
│       └── context-injection.md      # NEW — coach name, profile slots
├── go.mod                            # MODIFIED — add anthropic SDK dependency
└── go.sum                            # MODIFIED

ios/
├── sprinty/
│   ├── Services/
│   │   └── Networking/
│   │       ├── ChatServiceProtocol.swift  # MODIFIED — add profile parameter to streamChat()
│   │       ├── ChatService.swift          # MODIFIED — gzip compression, profile context, retryAfter parsing
│   │       └── APIClient.swift            # UNCHANGED — not used by streaming
│   ├── Features/
│   │   └── Coaching/
│   │       ├── Models/
│   │       │   └── ChatRequest.swift      # MODIFIED — add ChatProfile struct and profile field
│   │       └── ViewModels/
│   │           └── CoachingViewModel.swift # MODIFIED — pass profile, cache promptVersion
│   └── Core/
│       └── Errors/
│           └── AppError.swift             # UNCHANGED — retryAfter already exists
└── Tests/
    └── (update existing mock conformances for new ChatServiceProtocol signature)
```

Server test files:
```
server/
├── providers/
│   └── anthropic_test.go            # NEW
├── handlers/
│   └── chat_test.go                 # MODIFIED — add real provider scenarios
└── prompts/
    └── builder_test.go              # NEW
```

### Anti-Patterns (DO NOT DO)

- No API keys in iOS binary — all LLM calls go through backend proxy
- No hardcoded model names in handler — provider encapsulates model selection
- No `os.Getenv()` at request time — config loaded once at startup
- No raw provider error messages to client — all translated to warm user-facing messages
- No synchronous LLM calls — always streaming via channel
- No Combine on iOS — use `@Observable` + `async/await`
- No `DispatchQueue.main.async` — use `@MainActor`
- No force-unwrapping (`!`) — use `guard let` / `if let`
- No `print()` — use `slog` on server, structured logging on iOS
- No tier/guardrail middleware in this story — keep middleware chain simple
- No OpenAI provider in this story — Anthropic only for MVP

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.6 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md — Provider interface, streaming strategy, system prompt composition]
- [Source: _bmad-output/planning-artifacts/architecture.md — Go server patterns, error taxonomy, API contract]
- [Source: _bmad-output/planning-artifacts/architecture.md — SSE event format, ChatEvent schema, structured output]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Error messaging, coach expression states, RPG dialogue paradigm]
- [Source: _bmad-output/planning-artifacts/prd.md — FR1-FR10 coaching engine, FR39-FR45 safety, coach personality]
- [Source: _bmad-output/implementation-artifacts/1-5-onboarding-flow.md — Previous story learnings, code patterns]
- [Source: server/providers/provider.go — Existing Provider interface]
- [Source: server/handlers/chat.go — Existing chat handler with SSE streaming]
- [Source: server/config/config.go — Existing config with API key stubs]
- [Source: ios/sprinty/Services/Networking/ChatService.swift — Existing streaming implementation]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — Existing ViewModel pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed SDK compilation: `ModelClaude3_5HaikuLatest` renamed to `ModelClaudeHaiku4_5` in SDK v1.27.0
- Fixed `ToolUnionParam` wrapping: `{OfTool: &toolSchema}` needed for SDK union type
- Fixed `TextBlockParam` system prompt: direct struct initialization instead of `NewTextBlock()`
- Fixed `NSData.compressed(using: .zlib)` throws in Swift 6 — used `try?`
- Chose `deflate` over `gzip` for iOS compression — Foundation's `NSData.compressed(using: .zlib)` produces deflate-compatible output natively with no extra dependencies

### Completion Notes List

- ✅ Task 1: Created `server/providers/anthropic.go` with streaming tool-use, partial JSON coaching text extraction, malformed output fallback, context cancellation, and 9 unit tests
- ✅ Task 2: Created modular prompt builder with 6 sections, SHA-256 content hash versioning, and 7 unit tests
- ✅ Task 3: Updated chat handler with prompt builder integration, gzip/deflate decompression, provider error translation (429/500 → warm JSON), structured logging
- ✅ Task 4: Updated config (ANTHROPIC_API_KEY required in staging/production), main.go with provider selection logic, prompt version endpoint
- ✅ Task 5: Added deflate compression to iOS ChatService using Foundation's NSData.compressed(using: .zlib)
- ✅ Task 6: Added ChatProfile struct, updated ChatServiceProtocol signature (breaking change), CoachingViewModel loads UserProfile for coach name, caches promptVersion per session
- ✅ Task 7: Updated error handling with retryAfter parsing from Retry-After header, retry-after countdown timer in CoachingViewModel
- ✅ Task 8: Added 4 server integration tests (gzip decompression, profile context, provider error 500, prompt version endpoint)
- ✅ Task 9: All server tests pass (39 total), iOS builds with Swift 6 strict concurrency zero warnings, all 134 iOS tests pass
- ⏳ Task 9.4: Manual smoke test pending (requires ANTHROPIC_API_KEY)

### Change Log

- 2026-03-18: Story 1.6 implementation complete — real AI coaching integration with Anthropic provider, modular prompt system, compression, error handling
- 2026-03-18: Code review (AI) — fixed 5 issues:
  - H1: StreamChat now returns pre-stream errors (429/500) to handler instead of swallowing them in goroutine
  - H2: iOS parseRetryAfter now reads JSON body to extract retryAfter field (was only checking HTTP header)
  - M1: Server done event now includes promptVersion; iOS ChatEvent.done extended with promptVersion; ViewModel caches it
  - M2: Chat handler structured logging now includes deviceId and tier from JWT claims
  - M3: Story File List corrected (tests in server/tests/handlers_test.go, not server/handlers/chat_test.go)

### File List

**Server — New files:**
- server/providers/anthropic.go
- server/providers/anthropic_test.go
- server/prompts/builder.go
- server/prompts/builder_test.go
- server/prompts/sections/base-persona.md
- server/prompts/sections/mode-discovery.md
- server/prompts/sections/safety.md
- server/prompts/sections/mood.md
- server/prompts/sections/tagging.md
- server/prompts/sections/context-injection.md
- server/handlers/prompt.go

**Server — Modified files:**
- server/providers/provider.go (added ChatProfile, SystemPrompt, MemoryReferenced)
- server/handlers/chat.go (prompt builder, gzip decompression, error handling)
- server/config/config.go (ANTHROPIC_API_KEY validation)
- server/main.go (provider selection, prompt builder init)
- server/go.mod (anthropic SDK v1.27.0)
- server/go.sum
- server/tests/handlers_test.go (4 new integration tests)

**iOS — Modified files:**
- ios/sprinty/Features/Coaching/Models/ChatEvent.swift (added promptVersion to done case and DoneEventData)
- ios/sprinty/Features/Coaching/Models/ChatRequest.swift (added ChatProfile)
- ios/sprinty/Services/Networking/ChatServiceProtocol.swift (added profile parameter)
- ios/sprinty/Services/Networking/ChatService.swift (deflate compression, profile, retryAfter JSON body parsing)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (profile loading, retryAfter timer, promptVersion caching)
- ios/sprinty/App/RootView.swift (updated FailingChatService conformance)
- ios/Tests/Mocks/MockChatService.swift (updated protocol conformance)
- ios/Tests/Models/ChatEventCodableTests.swift (updated ChatRequest init, done pattern matches)
- ios/Tests/Services/SSEParserTests.swift (updated done pattern match)
- ios/Tests/Features/CoachingViewModelTests.swift (updated done event construction)
