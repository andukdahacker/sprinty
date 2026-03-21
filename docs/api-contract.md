# API Contract

Single source of truth for all API endpoints, request/response schemas, SSE event formats, and error taxonomy.

## Wire Format Conventions

- Field names: **camelCase** JSON throughout
- Dates: ISO 8601 with UTC timezone suffix (`2026-03-17T14:30:00Z`)
- Enums: lowercase snake_case
- Omit null fields (use `omitempty` on optional pointer fields)
- Arrays always arrays (never null — use empty `[]`)
- Booleans never 0/1

---

## Endpoints

### GET /health

No auth required.

**Response** `200 OK`
```json
{"status": "ok"}
```

---

### POST /v1/auth/register

No auth required. Idempotent — same UUID returns a fresh JWT each time (stateless server).

**Request**
```json
{
  "deviceId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response** `200 OK`
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**JWT Claims**
```json
{
  "deviceId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": null,
  "tier": "free",
  "iat": 1742220600,
  "exp": 1744812600
}
```

- `deviceId` (string): Device UUID from request
- `userId` (string|null): Always null until user account linking (future story)
- `tier` (string): Always `"free"` at registration. Values: `free`, `premium`
- `iat` (number): Issued-at Unix timestamp
- `exp` (number): Expiry Unix timestamp (30 days from `iat`)

**Errors**
- `400` — `missing_device_id`: Request body missing or `deviceId` empty
- `400` — `malformed_request`: Request body is not valid JSON

---

### POST /v1/auth/refresh

JWT required.

**Request**: Empty body. JWT provided via `Authorization: Bearer <token>` header.

**Response** `200 OK`
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

Returns a new JWT with refreshed 30-day expiry, preserving all existing claims.

**Errors**
- `401` — `invalid_jwt`: Token is malformed or signature invalid
- `401` — `token_expired`: Token signature valid but past expiry

---

### POST /v1/chat

JWT required. Streams response via Server-Sent Events (SSE).

**Request**
```json
{
  "messages": [
    {"role": "user", "content": "I've been feeling stuck at work lately."}
  ],
  "mode": "discovery",
  "promptVersion": "1.0",
  "userState": {
    "engagementLevel": "medium",
    "recentMoods": ["warm", "focused"],
    "avgMessageLength": "medium",
    "sessionCount": 5,
    "lastSessionGapHours": 12,
    "recentSessionIntensity": "moderate"
  }
}
```

- `messages` (array): Conversation messages with `role` (`user`|`assistant`) and `content`
- `mode` (string): Coaching mode. Values: `discovery`, `directive`, `summarize`
- `promptVersion` (string): System prompt version for reproducibility
- `profile` (object, optional): User profile data for personalized coaching
  - `coachName` (string): Selected coach name
  - `values` (array of strings, optional): User's core values (e.g., "authenticity", "growth")
  - `goals` (array of strings, optional): User's active goals
  - `personalityTraits` (array of strings, optional): Observed personality traits
  - `domainStates` (object, optional): Life domain context, keyed by domain name
    - Each domain has: `status` (string, optional), `conversationCount` (number, optional), `lastUpdated` (string, optional ISO 8601)
    - Valid domain keys: `career`, `relationships`, `health`, `finance`, `personal-growth`, `creativity`, `education`, `family`
- `userState` (object, optional): User engagement state computed on-device for adaptive tone
  - `engagementLevel` (string): `high`, `medium`, `low`
  - `recentMoods` (array of strings): Last 3-5 mood values from recent sessions
  - `avgMessageLength` (string): `short`, `medium`, `long`
  - `sessionCount` (number): Total recent sessions
  - `lastSessionGapHours` (number, optional): Hours since last session
  - `recentSessionIntensity` (string): `light`, `moderate`, `deep`
- `ragContext` (string, optional): Pre-formatted past conversation context retrieved via on-device RAG. Contains relevant summaries with dates, domain tags, key moments. Token budget: ~1000 tokens (~4000 characters). Omit if no relevant context or RAG unavailable

**Response** `200 OK` — `Content-Type: text/event-stream`

SSE stream of events (see SSE Event Format below).

#### Summarize Mode

When `mode` is `"summarize"`, the endpoint returns a **single JSON response** (not SSE) with the conversation summary.

**Response** `200 OK` — `Content-Type: application/json`
```json
{
  "summary": "The user explored career concerns and identified a pattern of avoidance.",
  "keyMoments": ["realized avoidance pattern", "committed to having the conversation"],
  "domainTags": ["career", "personal-growth"],
  "emotionalMarkers": ["anxious", "determined"],
  "keyDecisions": ["will schedule the meeting this week"]
}
```

- `summary` (string): 2-4 sentence substantive summary
- `keyMoments` (array of strings): 1-5 turning points or breakthroughs
- `domainTags` (array of strings): 1-3 life domains from: `career`, `relationships`, `health`, `finance`, `personal-growth`, `creativity`, `education`, `family`
- `emotionalMarkers` (array of strings, optional): Emotional trajectory markers
- `keyDecisions` (array of strings, optional): Decisions or commitments made

**Errors**
- `401` — `invalid_jwt` / `token_expired`: Auth failure
- `502` — `provider_unavailable`: LLM provider failed

---

### GET /v1/prompt/{version}

JWT required. Returns the system prompt for the given version.

**Response** `200 OK`
```json
{
  "version": "1.0",
  "systemPrompt": "You are Sprinty, an agile-inspired life coach..."
}
```

**Errors**
- `401` — `invalid_jwt` / `token_expired`: Auth failure
- `404` — `not_found`: Prompt version does not exist

---

## SSE Event Format

### Token Event

Emitted for each text chunk from the LLM provider.

```
event: token
data: {"text": "I hear you. "}
```

- `text` (string): Token text fragment

### Done Event

Emitted once when the LLM response is complete.

```
event: done
data: {"safetyLevel": "green", "domainTags": [], "mood": "welcoming", "mode": "discovery", "challengerUsed": false, "usage": {"inputTokens": 50, "outputTokens": 12}, "promptVersion": "a1b2c3d4"}
```

- `safetyLevel` (string): Safety classification. Values: `green`, `yellow`, `orange`, `red`
- `domainTags` (array of strings): Life domain tags extracted from conversation. Always an array (empty `[]` if none)
- `mood` (string): Coach expression mood. Values: `welcoming`, `thinking`, `warm`, `focused`, `gentle`
- `mode` (string): Coaching mode for this response. Values: `discovery`, `directive`. May differ from request mode when the LLM decides to transition.
- `memoryReferenced` (boolean): Whether this response references past conversations via RAG context. Default: `false`. Set by the LLM when it naturally references retrieved memories.
- `challengerUsed` (boolean): Whether this response used the Challenger capability (constructive pushback, alternative perspectives). Default: `false`.
- `profileUpdate` (object, optional): Only present when the LLM detects new user facts or corrections. Omitted for normal conversation.
  - `values` (array of strings, optional): New or updated user values
  - `goals` (array of strings, optional): New or updated user goals
  - `personalityTraits` (array of strings, optional): Newly observed personality traits
  - `domainStates` (object, optional): Domain state updates as `{domain: {status?, conversationCount?, lastUpdated?}}`
  - `corrections` (array of strings, optional): Explicit corrections the user made about their situation (audit-only)
- `usage` (object): Token consumption
  - `inputTokens` (number): Input token count
  - `outputTokens` (number): Output token count

---

## Error Response Schema

All errors follow this structure:

```json
{
  "error": "error_code",
  "message": "Human-readable message for client display.",
  "retryAfter": 0
}
```

- `error` (string): Machine-readable error code (snake_case)
- `message` (string): User-facing message
- `retryAfter` (number): Seconds to wait before retry. `0` means do not retry.

### Error Codes

| Code | HTTP Status | Taxonomy | Description |
|------|-------------|----------|-------------|
| `invalid_jwt` | 401 | hard | Token malformed or signature invalid |
| `token_expired` | 401 | recoverable | Token past expiry — client should re-register |
| `missing_device_id` | 400 | hard | Registration request missing deviceId |
| `malformed_request` | 400 | hard | Request body is not valid JSON |
| `provider_unavailable` | 502 | degraded-mode | LLM provider unreachable or errored |
| `not_found` | 404 | hard | Requested resource does not exist |

### Error Taxonomy

- **recoverable**: Client can retry or take corrective action (e.g., re-register)
- **degraded-mode**: Service partially available, some features unavailable
- **hard**: Client error, must fix request before retrying
- **silent**: Logged server-side only, client receives generic response
