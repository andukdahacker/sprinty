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
  "promptVersion": "1.0"
}
```

- `messages` (array): Conversation messages with `role` (`user`|`assistant`) and `content`
- `mode` (string): Coaching mode. Values: `discovery`, `directive`, `challenger`
- `promptVersion` (string): System prompt version for reproducibility

**Response** `200 OK` — `Content-Type: text/event-stream`

SSE stream of events (see SSE Event Format below).

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
data: {"safetyLevel": "green", "domainTags": [], "usage": {"inputTokens": 50, "outputTokens": 12}}
```

- `safetyLevel` (string): Safety classification. Values: `green`, `yellow`, `orange`, `red`
- `domainTags` (array of strings): Life domain tags extracted from conversation. Always an array (empty `[]` if none)
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
