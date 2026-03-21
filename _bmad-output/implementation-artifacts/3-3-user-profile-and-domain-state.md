# Story 3.3: User Profile & Domain State

Status: done

## Story

As a user,
I want my coach to maintain an evolving understanding of who I am — my values, goals, personality, and life situation,
So that coaching is deeply personalized across every session.

## Acceptance Criteria

1. **UserProfile Creation and Update** — Given a user engages in coaching conversations, When the system identifies core facts about the user, Then the UserProfile record is created/updated with values, goals, personalityTraits, and domainStates (JSON). Domain states track the user's situation across life domains (career status, relationship context, health goals, etc.).

2. **Profile Integration in Chat Request** — Given a coaching conversation begins, When the system assembles the chat request, Then the full user profile is included in the request payload (`profile` field) with values, goals, personalityTraits, and domainStates. The coach leverages profile data to personalize responses.

3. **Domain Tagging (FR14)** — Given conversations and goals are processed, When domain tags are extracted by the LLM, Then they are associated with the user's domain states and update the relevant domain state entries (conversationCount, lastUpdated). Note: Cross-domain pattern recognition is deferred to Story 3.4 (RAG-Powered Contextual Coaching) — this story only tracks per-domain conversation frequency.

4. **Profile Corrections via Conversation (FR73)** — Given a user corrects the AI's understanding through conversation (e.g., "No, that's not right — I actually left that job"), When the LLM detects a correction, Then the structured output includes a `profileUpdate` field with the correction. The UserProfile record is updated accordingly. The coach acknowledges the correction naturally. The `profileUpdate` field is added to `docs/api-contract.md`.

## Tasks / Subtasks

### Task 1: Expand ChatProfile to include full profile data (AC: 2)
- [x]1.1 Update `ChatProfile` in `ios/sprinty/Features/Coaching/Models/ChatRequest.swift` to include `values`, `goals`, `personalityTraits`, `domainStates` fields (all optional)
- [x]1.2 Update `loadChatProfile()` in `CoachingViewModel` to populate the expanded ChatProfile from UserProfile
- [x]1.3 Update Go `ChatProfile` struct in `server/providers/provider.go` to match
- [x]1.4 Add roundtrip encoding test for expanded ChatProfile in `ios/Tests/Models/`

### Task 2: Expand context-injection prompt with profile data (AC: 2)
- [x]2.1 Update `server/prompts/sections/context-injection.md` to include profile template slots: `{{user_values}}`, `{{user_goals}}`, `{{user_traits}}`, `{{domain_states}}`
- [x]2.2 Update `server/prompts/builder.go` `Build()` to inject profile fields into template slots
- [x]2.3 Handle nil/empty profile fields gracefully (cold start: replace with "not yet known")

### Task 3: Add `profileUpdate` to LLM structured output (AC: 4)
- [x]3.1 Add `profileUpdate` field to `toolSchema` in `server/providers/anthropic.go` — optional object with fields: `values`, `goals`, `personalityTraits`, `domainStates` (all optional arrays/JSON)
- [x]3.2 Add `ProfileUpdate` to `toolResult` struct
- [x]3.3 Add `ProfileUpdate` to `ChatEvent` struct so it flows to iOS client
- [x]3.4 Include `profileUpdate` in the done event JSON emitted in `ChatHandler`
- [x]3.5 Add prompt instructions in context-injection telling the LLM when and how to emit `profileUpdate`
- [x]3.6 Add prompt instructions for natural correction acknowledgment — when the LLM emits a `profileUpdate` with corrections, the coaching text must warmly acknowledge the correction (e.g., "Got it, thanks for clarifying" or "I appreciate you setting me straight on that")

### Task 4: iOS client processes profileUpdate from done event (AC: 4)
- [x]4.1 Add `profileUpdate` field to iOS done event parsing. This requires updating THREE things: (1) `DoneEventData` Codable struct — add `let profileUpdate: ProfileUpdate?`, (2) `ChatEvent` enum `.done` case — add `profileUpdate: ProfileUpdate?` parameter, (3) `.from(sseEvent:)` factory method — pass the parsed profileUpdate through. See `ios/sprinty/Services/Networking/ChatEvent.swift` for the existing structure.
- [x]4.2 Create `ProfileUpdateService` (protocol + implementation) with method `applyUpdate(_ update: ProfileUpdate, to profile: UserProfile) async throws`
- [x]4.3 Call `ProfileUpdateService.applyUpdate()` from `CoachingViewModel` when done event contains a `profileUpdate`
- [x]4.4 Merge logic: append new values/goals (no duplicates, case-insensitive), replace domainStates entries by domain key, append new traits (deduplicated)
- [x]4.5 Input validation: cap values/goals/traits at 20 items each, domainStates at 10 domains, individual strings at 200 chars. Silently truncate excess items.
- [x]4.6 Corrections handling: log corrections array for audit trail via `os.Logger` at `.info` level. Corrections are informational only in this story — manual review/edit deferred to Story 3.7 (Memory View & Profile Editing)

### Task 5: Post-conversation profile enrichment from summaries (AC: 1, 3)
- [x]5.1 Create `ProfileEnricher` (protocol + implementation) that takes a `ConversationSummary` and updates UserProfile
- [x]5.2 Use `domainTags` from summary to update/create entries in `domainStates` JSON (increment conversationCount, update lastUpdated). Handle summaries with empty/nil domainTags gracefully (no-op — old summaries from before Story 3.1 may lack tags)
- [x]5.3 Call `ProfileEnricher` in `CoachingViewModel.generateSummary()` after summary creation (fire-and-forget, non-fatal like embedding)
- [x]5.4 Wire DI in `RootView.swift`

### Task 6: Update api-contract.md (AC: 2, 4)
- [x]6.1 Add expanded `profile` schema to POST /v1/chat request docs
- [x]6.2 Add `profileUpdate` to done event schema docs
- [x]6.3 Add shared test fixture `profile-update-event.json` in `docs/fixtures/`

### Task 7: Tests (All ACs)
- [x]7.1 UserProfile encoding/decoding roundtrip with domainStates JSON
- [x]7.2 ChatProfile expanded encoding roundtrip
- [x]7.3 ProfileUpdateService merge logic tests (append, dedupe, domain key merge)
- [x]7.4 ProfileEnricher tests (domainTags → domainStates update)
- [x]7.5 CoachingViewModel integration test: done event with profileUpdate triggers profile save
- [x]7.6 Cold start test: nil profile fields don't crash request assembly
- [x]7.7 Cold start test: server prompt builder replaces all profile slots with "not yet known" when profile is nil
- [x]7.8 Partial profile test: some fields populated (values exist, goals nil) — request assembly and prompt injection both work
- [x]7.9 Input validation test: profileUpdate with >20 values is truncated silently
- [x]7.10 ProfileEnricher test: summary with empty domainTags is a no-op (no profile mutation)

## Dev Notes

### Architecture Compliance

- **UserProfile model already exists** at `ios/sprinty/Models/UserProfile.swift` with `values`, `goals`, `personalityTraits`, `domainStates` columns already in the schema (v2 migration). All are nullable `String?` typed. **No new migration needed.** The columns are present but currently unpopulated — this story populates them.
- **ChatProfile currently only sends `coachName`** to the server. This story expands it to send the full profile context. ChatProfile lives in `ChatRequest.swift` (feature model, not shared GRDB model).
- **GRDB model conventions**: `Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable`. UserProfile already conforms.
- **JSON string columns**: `domainStates`, `values`, `goals`, `personalityTraits` are stored as JSON-encoded strings in SQLite (same pattern as `ConversationSummary.keyMoments`, `ConversationSession.modeHistory`). Add decode/encode helpers following the `ConversationSummary.encodeArray()` / `decodedKeyMoments` pattern.
- **Cold start safety**: `ChatProfile` and `UserState` are optional in `ChatRequest`. Profile fields will be nil during onboarding (first conversation). Server prompt builder must handle nil gracefully (replace with "not yet known").
- **Fire-and-forget pattern**: Profile enrichment after summary follows the same pattern as embedding in Story 3.2 — failure is logged but non-fatal, doesn't propagate to user.
- **Error handling**: Both ProfileUpdateService and ProfileEnricher failures are **local/silent** — log at Error level via `os.Logger`, do NOT route to AppState (no global error). Use `do { try await ... } catch { Logger.error(...) }` pattern. Profile operations must never block the conversation flow.
- **Structured logging**: Use `Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "profile")` for all profile operations. Log levels: `.info` for successful updates and corrections, `.error` for failures.
- **Sendable compliance**: ProfileUpdateService and ProfileEnricher are stateless — they take a `DatabaseManager` via init and perform all work through GRDB's thread-safe `dbPool`. Mark as `Sendable` (not `@unchecked`). Mocks use `@unchecked Sendable` as established.
- **Input validation**: Cap array fields at 20 items, strings at 200 chars, domain keys at 10 entries. Validate domain keys against the closed vocabulary (`career`, `relationships`, `health`, `finance`, `personal-growth`, `creativity`, `education`, `family`). Silently drop invalid domain keys.
- **Corrections are audit-only**: The `corrections` field in `profileUpdate` is logged for transparency but NOT auto-applied to specific profile fields. The LLM handles the correction in its *next* profileUpdate by sending updated values/goals/traits/domainStates directly. Story 3.7 (Memory View) enables manual user editing.

### Existing Code to Reuse (DO NOT Reinvent)

| What | Where | How to Reuse |
|------|-------|-------------|
| UserProfile GRDB model | `ios/sprinty/Models/UserProfile.swift` | Extend with decode/encode helpers for JSON fields |
| UserProfile.current() query | Same file | Already returns the single active profile |
| ChatProfile struct | `ios/sprinty/Features/Coaching/Models/ChatRequest.swift` | Expand with new optional fields |
| loadChatProfile() in CoachingViewModel | `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift:266` | Expand to populate new ChatProfile fields |
| Go ChatProfile struct | `server/providers/provider.go:10` | Expand with new fields |
| Go prompt builder Build() | `server/prompts/builder.go:79` | Add profile field injection after userState injection |
| context-injection.md template | `server/prompts/sections/context-injection.md` | Add profile template slots |
| ConversationSummary.encodeArray() | `ios/sprinty/Models/ConversationSummary.swift` | Pattern for JSON array ↔ String encoding |
| EmbeddingPipeline fire-and-forget | `CoachingViewModel.swift:231-238` | Same do/catch pattern for ProfileEnricher |
| DI wiring in RootView | `ios/sprinty/App/RootView.swift` | Add ProfileEnricher + ProfileUpdateService |

### Server-Side Changes

**context-injection.md** — Current template only has `coach_name` and engagement metrics. Expand to:
```
Context for this conversation:
- Coach name: {{coach_name}}
- User values: {{user_values}}
- User goals: {{user_goals}}
- Personality traits: {{user_traits}}
- Domain context: {{domain_states}}
- User engagement: {{engagement_level}}
- Recent mood pattern: {{recent_moods}}
- Message style: {{avg_message_length}} messages
- Sessions completed: {{session_count}}
- Time since last session: {{last_session_gap}}
- Recent session intensity: {{recent_session_intensity}}
```

**toolSchema in anthropic.go** — Add optional `profileUpdate` field:
```go
"profileUpdate": map[string]any{
    "type": "object",
    "properties": map[string]any{
        "values":          map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "New or updated user values to add to profile."},
        "goals":           map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "New or updated user goals to add to profile."},
        "personalityTraits": map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "New personality traits observed."},
        "domainStates":    map[string]any{"type": "object", "description": "Domain state updates as {domain: {key: value}}."},
        "corrections":     map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "Explicit corrections the user made about their situation."},
    },
    "description": "Only emit when the user reveals new facts about themselves or corrects your understanding. Do NOT emit for normal conversation.",
},
```
Do NOT add `profileUpdate` to the `Required` array — it must remain optional.

**Prompt instructions for profileUpdate + correction acknowledgment** — Add to context-injection.md (or a new `profile-instructions.md` section):
```
When the user reveals new information about themselves (values, goals, life situation), emit a profileUpdate with the new facts.
When the user corrects your understanding ("No, that's not right", "Actually I...", "You're misremembering"), you MUST:
1. Emit a profileUpdate with the corrected values AND include the correction text in the corrections array
2. Warmly acknowledge the correction in your coaching response — e.g., "Got it, thanks for clarifying" or "I appreciate you setting me straight on that"
3. Do NOT over-explain or apologize excessively — a brief natural acknowledgment is best
Do NOT emit profileUpdate for routine conversation — only when genuinely new facts or corrections surface.
```

**prompt builder** — Add to `Build()` after userState replacement block:
```go
if req.Profile != nil {
    result = strings.ReplaceAll(result, "{{user_values}}", strings.Join(req.Profile.Values, ", "))
    // ... same pattern for goals, traits, domainStates
} else {
    result = strings.ReplaceAll(result, "{{user_values}}", "not yet known")
    // ... defaults for all profile slots
}
```

**ChatEvent flow** — Three changes needed:
1. Add `ProfileUpdate *ProfileUpdate` to `ChatEvent` struct in `provider.go`
2. Add `ProfileUpdate json.RawMessage` to `toolResult` struct in `anthropic.go` (use `json.RawMessage` to preserve flexible JSON)
3. In `parseFinalResult()`, extract `profileUpdate` from the tool result and assign to `ChatEvent.ProfileUpdate`
4. In `ChatHandler` (chat.go line 94), add `"profileUpdate": event.ProfileUpdate` to the done event JSON marshal — only include if non-nil (use `omitempty`)

**iOS done event parsing** — The iOS `ChatEvent` is in `ios/sprinty/Services/Networking/ChatEvent.swift`. Current structure:
- `DoneEventData` Codable struct parses the SSE JSON
- `ChatEvent` enum has `.done(safetyLevel:domainTags:mood:mode:challengerUsed:usage:promptVersion:)` case
- `.from(sseEvent:)` factory method converts SSE → enum
All three must be updated to thread `profileUpdate: ProfileUpdate?` through. In `CoachingViewModel.sendMessage()` (line 113), the `.done` case destructuring must add the new `profileUpdate` parameter.

### iOS-Side Changes

**ChatProfile expansion** (in ChatRequest.swift):
```swift
struct ChatProfile: Codable, Sendable {
    let coachName: String
    let values: [String]?
    let goals: [String]?
    let personalityTraits: [String]?
    let domainStates: [String: DomainState]?
}

struct DomainState: Codable, Sendable {
    let status: String?
    let conversationCount: Int?
    let lastUpdated: String?
}
```

**ProfileUpdate model** (new, in Coaching/Models/ProfileUpdate.swift):
```swift
struct ProfileUpdate: Codable, Sendable {
    let values: [String]?
    let goals: [String]?
    let personalityTraits: [String]?
    let domainStates: [String: DomainState]?  // keyed by domain name
    let corrections: [String]?               // audit-only, not auto-applied
}
```
Uses the same `DomainState` struct as ChatProfile for consistency.

**ProfileUpdateService** — Merge logic:
- `values`: Append new, deduplicate (case-insensitive), cap at 20
- `goals`: Append new, deduplicate, cap at 20
- `personalityTraits`: Append new, deduplicate, cap at 20
- `domainStates`: Merge by domain key — existing domain entries are updated, new domains are added. Validate keys against closed vocabulary. Cap at 10 domains.
- `corrections`: Log at `.info` level for audit trail. Do NOT auto-apply to profile fields — the LLM sends corrected values/goals/traits directly in the same or next profileUpdate. Manual editing deferred to Story 3.7.

**ProfileEnricher** — Post-conversation, uses `ConversationSummary.domainTags` to:
- For each domain tag, find or create the domain state entry
- Increment `conversationCount`
- Update `lastUpdated` to current ISO 8601 date
- Save updated profile with `updatedAt = Date()`

**loadChatProfile() expansion** in CoachingViewModel:
```swift
private func loadChatProfile() async throws -> ChatProfile? {
    let userProfile: UserProfile? = try await databaseManager.dbPool.read { db in
        try UserProfile.current().fetchOne(db)
    }
    guard let userProfile else { return nil }
    return ChatProfile(
        coachName: userProfile.coachName,
        values: userProfile.decodedValues,
        goals: userProfile.decodedGoals,
        personalityTraits: userProfile.decodedPersonalityTraits,
        domainStates: userProfile.decodedDomainStates
    )
}
```

### DomainStates JSON Structure

The `domainStates` column stores flexible JSON. Target structure:
```json
{
  "career": {"conversationCount": 5, "lastUpdated": "2026-03-21T10:00:00Z"},
  "health": {"conversationCount": 3, "lastUpdated": "2026-03-20T08:00:00Z"},
  "relationships": {"conversationCount": 1, "lastUpdated": "2026-03-19T14:00:00Z"}
}
```
Domain keys come from the closed vocabulary in the summarize tool schema: `career`, `relationships`, `health`, `finance`, `personal-growth`, `creativity`, `education`, `family`.

### Testing Standards

- **Framework**: Swift Testing (`@Suite`, `@Test`, `#expect()`) — NEVER XCTest
- **Naming**: `test_{function}_{scenario}_{expected}`
- **Database tests**: Use `makeTestDB()` with real GRDB in-memory migrations — NEVER mock database
- **Mocks**: `final class Mock{ServiceName}: {ServiceProtocol}, @unchecked Sendable`
- **New protocols need mocks**: `MockProfileUpdateService`, `MockProfileEnricher` in `ios/Tests/Mocks/`
- **ViewModel tests**: `@MainActor` on async tests
- **Go tests**: Verify prompt builder injects profile fields correctly; verify toolResult parses profileUpdate

### Project Structure Notes

New files to create:
```
ios/sprinty/Features/Coaching/Models/ProfileUpdate.swift        # ProfileUpdate model
ios/sprinty/Services/Memory/ProfileUpdateServiceProtocol.swift  # Protocol
ios/sprinty/Services/Memory/ProfileUpdateService.swift          # Implementation
ios/sprinty/Services/Memory/ProfileEnricherProtocol.swift       # Protocol
ios/sprinty/Services/Memory/ProfileEnricher.swift               # Implementation
ios/Tests/Services/ProfileUpdateServiceTests.swift              # Merge logic tests
ios/Tests/Services/ProfileEnricherTests.swift                   # Domain enrichment tests
ios/Tests/Mocks/MockProfileUpdateService.swift                  # Mock
ios/Tests/Mocks/MockProfileEnricher.swift                       # Mock
docs/fixtures/profile-update-event.json                         # Shared fixture
```

Files to modify:
```
ios/sprinty/Models/UserProfile.swift                            # Add decode/encode helpers
ios/sprinty/Features/Coaching/Models/ChatRequest.swift          # Expand ChatProfile, add DomainState
ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift # Profile update handling + enrichment
ios/sprinty/App/RootView.swift                                  # DI wiring
server/providers/provider.go                                    # Expand ChatProfile, add ProfileUpdate to ChatEvent
server/providers/anthropic.go                                   # Add profileUpdate to toolSchema + toolResult
server/handlers/chat.go                                         # Pass profileUpdate in done event
server/prompts/builder.go                                       # Inject profile fields
server/prompts/sections/context-injection.md                    # Add profile template slots
docs/api-contract.md                                            # Document profile + profileUpdate schemas
```

### Previous Story Intelligence

**From Story 3.2 (Embedding Pipeline):**
- Dual-database architecture: GRDB for relational data, separate sqlite-vec for vectors. Profile is GRDB-only.
- Graceful degradation pattern: `do { try await pipeline.embed(...) } catch { Logger.error(...) }` — use identical pattern for profile enrichment.
- DI injection via protocol parameters in RootView — follow same pattern for new services.
- `@unchecked Sendable` on mocks with mutable state.
- All 222 tests pass — ensure zero regressions.

**From Story 3.1 (Conversation Summaries):**
- `ConversationSummary.domainTags` is a JSON-encoded `[String]` — use `decodedDomainTags` accessor pattern for UserProfile fields.
- `encodeArray()` / `decodeArray()` static methods on ConversationSummary — extract to shared utility or duplicate pattern on UserProfile.
- Post-conversation pipeline: summary → embedding → (now) profile enrichment. Chain after embedding.
- **Dependency**: Story 3.1 is complete (done). ProfileEnricher consumes `domainTags` from ConversationSummary. Old summaries created before Story 3.1 may have nil/empty domainTags — handle gracefully.

**Concurrency note**: ProfileEnricher runs inside a fire-and-forget `Task` after summary generation in `generateSummary()`. GRDB's `DatabasePool` handles concurrent read/write safety — no additional locking needed. If two conversations end simultaneously, GRDB serializes writes. ProfileUpdateService (from done events) also writes via `dbPool.write` — same serialization guarantee.

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3, Story 3.3]
- [Source: _bmad-output/planning-artifacts/architecture.md — Database Schema, API Contract, Memory Pipeline]
- [Source: _bmad-output/planning-artifacts/prd.md — FR13, FR14, FR73]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 8: Memory View, SettingsView]
- [Source: docs/api-contract.md — POST /v1/chat, SSE done event]
- [Source: server/providers/anthropic.go — toolSchema, toolResult]
- [Source: server/prompts/builder.go — Build() template replacement]
- [Source: ios/sprinty/Models/UserProfile.swift — Existing GRDB model]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — loadChatProfile(), generateSummary()]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None — clean implementation with no debugging issues.

### Completion Notes List
- Task 1: Expanded ChatProfile (iOS + Go) with values, goals, personalityTraits, domainStates fields. Added DomainState Codable struct. Updated loadChatProfile() to populate from UserProfile JSON columns. Added decode/encode helpers to UserProfile.
- Task 2: Updated context-injection.md with profile template slots. Updated builder.go Build() signature to accept *ChatProfile. Added profile field injection with "not yet known" fallback for nil/empty fields.
- Task 3: Added profileUpdate to Anthropic toolSchema (optional, not required). Added ProfileUpdate to toolResult, ChatEvent (Go), and done event JSON emission in ChatHandler. Added prompt instructions for profileUpdate emission and natural correction acknowledgment.
- Task 4: Updated iOS ChatEvent enum with profileUpdate parameter. Created ProfileUpdate model. Created ProfileUpdateService with merge logic (append/dedupe values/goals/traits, domain key merge, input validation caps, domain key validation). Added fire-and-forget profile update handling in CoachingViewModel done event processing.
- Task 5: Created ProfileEnricher that processes ConversationSummary domainTags to update/create domainStates entries (increment conversationCount, update lastUpdated). Integrated as fire-and-forget in generateSummary(). Wired DI in RootView.swift.
- Task 6: Updated api-contract.md with expanded profile schema and profileUpdate done event schema. Created shared fixture profile-update-event.json.
- Task 7: 20 new tests added (242 total, up from 222). All pass with zero regressions. Go tests: profile injection, nil profile defaults, empty profile fields. iOS tests: ChatProfile roundtrip, UserProfile JSON field roundtrip, ProfileUpdateService merge/dedupe/validation, ProfileEnricher domain enrichment, CoachingViewModel integration (profileUpdate trigger, cold start, partial profile, enrichment).

### Change Log
- Story 3.3 implemented: User Profile & Domain State — 2026-03-21
- Code review fixes applied — 2026-03-21:
  - M1: Fixed `mergeAndDeduplicate` to truncate existing items during dedup comparison (prevents bloat if existing values exceed 200 chars)
  - M2: Added `project.pbxproj` and `DomainState.swift` to File List
  - M3: Moved `DomainState` from `ChatRequest.swift` (feature model) to `ios/sprinty/Models/DomainState.swift` (shared Models) — correct per project architecture

### File List
**New files:**
- ios/sprinty/Features/Coaching/Models/ProfileUpdate.swift
- ios/sprinty/Services/Memory/ProfileUpdateServiceProtocol.swift
- ios/sprinty/Services/Memory/ProfileUpdateService.swift
- ios/sprinty/Services/Memory/ProfileEnricherProtocol.swift
- ios/sprinty/Services/Memory/ProfileEnricher.swift
- ios/Tests/Mocks/MockProfileUpdateService.swift
- ios/Tests/Mocks/MockProfileEnricher.swift
- ios/Tests/Services/ProfileUpdateServiceTests.swift
- ios/Tests/Services/ProfileEnricherTests.swift
- docs/fixtures/profile-update-event.json

**Modified files:**
- ios/sprinty/Models/UserProfile.swift — Added JSON decode/encode helpers
- ios/sprinty/Models/DomainState.swift — Moved DomainState to shared Models (code review fix)
- ios/sprinty/Features/Coaching/Models/ChatRequest.swift — Expanded ChatProfile (DomainState moved to shared Models)
- ios/sprinty/Features/Coaching/Models/ChatEvent.swift — Added profileUpdate to done case
- ios/sprinty.xcodeproj/project.pbxproj — Regenerated by xcodegen for new files
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — Profile update handling, enrichment, DI
- ios/sprinty/App/RootView.swift — DI wiring for ProfileUpdateService and ProfileEnricher
- server/providers/provider.go — Expanded ChatProfile, DomainState, ChatEvent with ProfileUpdate
- server/providers/anthropic.go — Added profileUpdate to toolSchema and toolResult
- server/handlers/chat.go — ProfileUpdate in done event, profile passed to builder
- server/prompts/builder.go — Profile field injection in Build()
- server/prompts/sections/context-injection.md — Profile template slots and profileUpdate instructions
- server/prompts/builder_test.go — Updated Build() calls, added Story 3.3 tests
- server/tests/handlers_test.go — Updated context-injection fixture
- docs/api-contract.md — Expanded profile and profileUpdate schemas
- ios/Tests/Models/CodableRoundtripTests.swift — Story 3.3 roundtrip tests
- ios/Tests/Models/ChatEventCodableTests.swift — Updated done pattern matches
- ios/Tests/Services/SSEParserTests.swift — Updated done pattern match
- ios/Tests/Features/CoachingViewModelTests.swift — Story 3.3 integration tests
