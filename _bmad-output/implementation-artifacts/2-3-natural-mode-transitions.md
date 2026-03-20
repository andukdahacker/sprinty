# Story 2.3: Natural Mode Transitions

Status: done

## Story

As a user whose needs evolve during a conversation,
I want the coach to transition naturally between exploration and direction,
so that the coaching adapts to where I am in real time without jarring shifts.

## Acceptance Criteria

1. **Discovery → Directive transition:** Given a user starts in Discovery Mode, when they express a clear goal or ask for specific advice, then the coach transitions naturally to Directive Mode within the same conversation. The ambient background shift occurs smoothly (standard 0.4s timing). No UI interruption or mode indicator is shown to the user.

2. **Directive → Discovery transition:** Given a user is in Directive Mode, when they express uncertainty or want to explore a new topic, then the coach transitions back to Discovery Mode naturally. The transition feels conversational, not mechanical.

3. **Multi-segment mode tracking:** Given multiple mode transitions occur in one conversation, when the conversation summary is generated, then the mode used for each segment is captured in metadata.

## Tasks / Subtasks

- [x] Task 1: Add mode transition instructions to system prompt sections (AC: #1, #2)
  - [x] 1.1 Create `server/prompts/sections/mode-transitions.md` — instructions for the LLM on when and how to switch modes naturally (see Prompt Content Guidance below)
  - [x] 1.2 Add `"mode-transitions.md"` to `sectionFiles` slice in `builder.go` `NewBuilder()` (line 26-35)
  - [x] 1.3 In `Build()`, add `"mode-transitions"` to the unconditional section loop at line 93: `for _, section := range []string{"safety", "mood", "tagging", "cultural", "mode-transitions"}` — this ensures it is always included regardless of current mode
  - [x] 1.4 **CRITICAL**: Update ALL 3 Go test helpers simultaneously — `builder_test.go:setupTestSections()`, `handlers_test.go:createTestPromptBuilder()`, `handlers_test.go:setupMuxWithBuilder()` — add `"mode-transitions.md": "Mode transitions: analyze user intent."` entry to each files map
  - [x] 1.5 Update `TestNewBuilder_LoadsSections` expected count from 8 → 9
  - [x] 1.6 Add `TestBuilder_Build_IncludesModeTransitions` — verify mode-transitions section present in output regardless of mode

- [x] Task 2: Add `mode` field to LLM structured output schema (AC: #1, #2)
  - [x] 2.1 Add `Mode string` field to `toolResult` struct in `server/providers/anthropic.go` (lines 51-57) — values: `"discovery"`, `"directive"`. Note: `toolResult` is defined ONLY in anthropic.go, not shared across providers
  - [x] 2.2 Add `mode` property to tool schema JSON in `anthropic.go` `toolSchema` var (lines 15-48) — add to `Properties` map with description: `"The coaching mode for this response. Set to 'discovery' when user is exploring or uncertain, 'directive' when user has clear goals or wants action steps. Default to current mode if unclear."`. Add `"mode"` to the `Required` array.
  - [x] 2.3 In anthropic.go done event emission (lines 168-176), replace `Mode: req.Mode` with: `Mode: func() string { if result.Mode != "" { return result.Mode }; return req.Mode }()`
  - [x] 2.4 In `server/providers/mock.go` done event emission (line 38), update `Mode: req.Mode` to support mode transition testing — add a `StubbedMode string` field to MockProvider; if non-empty use it, otherwise fall back to `req.Mode`
  - [x] 2.5 Update Go tests: `handlers_test.go` — add test verifying that when MockProvider returns a different mode, the done SSE event reflects the new mode (not the request mode)

- [x] Task 3: Add mode segment tracking to conversation metadata (AC: #3)
  - [x] 3.1 Define a `ModeSegment` struct in `ConversationSession.swift` — conforming to `Codable` and `Sendable`:
    ```swift
    struct ModeSegment: Codable, Sendable {
        let mode: CoachingMode
        let messageIndex: Int
    }
    ```
  - [x] 3.2 Add `modeHistory: String?` column to `ConversationSession` — stores JSON-encoded `[ModeSegment]`
  - [x] 3.3 Add GRDB migration `v3` in `ios/sprinty/Services/Database/Migrations.swift` (after existing `v2`):
    ```swift
    migrator.registerMigration("v3") { db in
        try db.alter(table: "ConversationSession") { t in
            t.add(column: "modeHistory", .text)
        }
    }
    ```
  - [x] 3.4 Add `modeSegments: [ModeSegment]` property to `CoachingViewModel` — initialize with `[ModeSegment(mode: session.mode, messageIndex: 0)]` when loading/creating a session (use the session's actual mode from DB, not hardcoded `.discovery`)
  - [x] 3.5 In `updateSessionMode()`, append new `ModeSegment(mode: newMode, messageIndex: messages.count)` to `modeSegments`, then JSON-encode and persist to `currentSession.modeHistory`
  - [x] 3.6 Add Swift tests in `ios/Tests/Features/ModeSegmentTests.swift`: verify segments accumulate on mode changes, verify initial segment uses session's actual mode, verify JSON roundtrip encoding

- [x] Task 4: Update documentation and fixtures (AC: #1, #2)
  - [x] 4.1 Update `docs/api-contract.md` (lines 151-166) — add `mode` field documentation to the Done Event section: `mode (string): Coaching mode for this response. Values: "discovery", "directive". May differ from request mode when the LLM decides to transition.`
  - [x] 4.2 Verify `docs/fixtures/sse-done-event.txt` — currently has `"mode": "discovery"`. No change needed (represents a valid done event).

- [x] Task 5: Verify existing iOS mode transition UI works end-to-end (AC: #1, #2)
  - [x] 5.1 Verify `CoachingViewModel` lines 131-133 correctly detect mode changes from done event — no code changes expected, just confirmation
  - [x] 5.2 Verify `CoachingView` animation (0.4s easeInOut) triggers on `coachingMode` changes — no code changes expected
  - [x] 5.3 Verify ambient color shifts (Discovery warm → Directive cool, Directive cool → Discovery warm) work bidirectionally
  - [x] 5.4 Add/verify #Preview blocks showing both transition directions
  - [x] 5.5 Verify reduce-motion accessibility check: animation disabled when `UIAccessibility.isReduceMotionEnabled` is true

## Dev Notes

### Architecture: How Mode Transitions Work (Current State)

The mode transition pipeline is ~80% complete. The iOS client already handles mode changes from the server:

1. Client sends `mode` in `ChatRequest` → server builds prompt with mode-specific section
2. Server returns `mode` in `.done` SSE event
3. ViewModel detects mode change (line 131-133 in `CoachingViewModel.swift`): `if newMode != self.coachingMode { await self.updateSessionMode(newMode) }`
4. `updateSessionMode()` persists to GRDB and updates observable property → triggers 0.4s animated theme transition

**The gap:** Server currently echoes `req.Mode` back. The LLM is never asked to decide mode. The `toolResult` struct in `anthropic.go` has no `mode` field.

### Provider Architecture Context

Only two providers currently exist in `server/providers/`:
- `anthropic.go` — production provider with `toolResult` struct (lines 51-57) and tool schema (lines 15-48)
- `mock.go` — test provider that echoes `req.Mode` (line 38)
- `provider.go` — shared `ChatEvent`, `ChatRequest`, `Provider` interface

**`openai.go`, `gemini.go`, `kimi.go` do NOT exist yet.** Do not create or modify them.

### What Needs to Change

**1. Anthropic provider structured output** — Add `Mode` to `toolResult` (anthropic.go only):
```go
type toolResult struct {
    Coaching         string   `json:"coaching"`
    SafetyLevel      string   `json:"safetyLevel"`
    DomainTags       []string `json:"domainTags"`
    Mood             string   `json:"mood"`
    MemoryReferenced bool     `json:"memoryReferenced"`
    Mode             string   `json:"mode"`              // NEW: "discovery" or "directive"
}
```

**2. Anthropic done event** — Use LLM-decided mode instead of echoing:
```go
// In anthropic.go done event (lines 168-176), change:
Mode: req.Mode,
// To:
Mode: func() string { if result.Mode != "" { return result.Mode }; return req.Mode }(),
```

**3. MockProvider** — Add `StubbedMode` field for test control:
```go
// In mock.go, add field and use in done event:
Mode: func() string { if p.StubbedMode != "" { return p.StubbedMode }; return req.Mode }(),
```

**4. New prompt section** — `mode-transitions.md` instructs the LLM on natural transitions

**5. Content hash note** — Adding `mode-transitions.md` changes the prompt builder's `ContentHash()`. The iOS prompt version cache has a 1hr TTL and will auto-invalidate. This is expected behavior — no iOS fix needed.

### Critical Regression Pattern (from Story 2.2)

When adding new section files to the prompt builder, ALL Go test helpers must be updated simultaneously or all tests break:
1. `server/prompts/builder_test.go` → `setupTestSections()` (lines 10-37)
2. `server/tests/handlers_test.go` → `createTestPromptBuilder()` (lines 29-51)
3. `server/tests/handlers_test.go` → `setupMuxWithBuilder()` (lines 57-87)

### Existing Files to Modify

**Server (Go):**
| File | Change |
|------|--------|
| `server/providers/anthropic.go` | Add `Mode` to `toolResult` struct (lines 51-57) + tool schema JSON (lines 15-48) + use `result.Mode` in done event (lines 168-176) |
| `server/providers/mock.go` | Add `StubbedMode` field + use it in done event (line 38) |
| `server/prompts/builder.go` | Add `"mode-transitions.md"` to `sectionFiles` (line 26-35), add `"mode-transitions"` to unconditional loop (line 93) |
| `server/prompts/builder_test.go` | Update `setupTestSections()` (line 10-37), expected count 8→9, add transition test |
| `server/tests/handlers_test.go` | Update both test helpers (lines 29-51, 57-87), add mode transition done event test |
| `docs/api-contract.md` | Add `mode` field documentation to Done Event section (lines 151-166) |

**New Server File:**
| File | Purpose |
|------|---------|
| `server/prompts/sections/mode-transitions.md` | LLM instructions for natural mode switching |

**iOS (Swift):**
| File | Change |
|------|--------|
| `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` | Add `modeSegments: [ModeSegment]` array, initialize from session mode, append in `updateSessionMode()`, persist to session |
| `ios/sprinty/Models/ConversationSession.swift` | Add `ModeSegment` struct, add `modeHistory: String?` column |
| `ios/sprinty/Services/Database/Migrations.swift` | Add migration `v3` with `modeHistory` column (after existing `v2` on line 33) |
| `ios/Tests/Features/ModeSegmentTests.swift` (new) | Tests for mode segment tracking |

**No iOS changes needed for core transition** — the ViewModel already detects and handles mode changes from the server. Only segment tracking (AC #3) requires iOS changes.

### Files NOT to Touch

- `CoachingView.swift` — animation already in place (line 75-78), ambient mode application already generic (line 8-11)
- `ColorPalette.swift` — discovery and directive colors fully implemented
- `CoachingTheme.swift` — `applyingAmbientMode()` already handles both modes
- `ChatEvent.swift` — `.done` event already parses `mode: String?`
- `ChatRequest.swift` — already sends mode string
- `AppState.swift` — not used for mode (mode lives on ViewModel/session)
- `server/providers/openai.go`, `gemini.go`, `kimi.go` — these files do not exist yet

### Mode Transition Prompt Content Guidance

The `mode-transitions.md` section should instruct the LLM to:

1. **Analyze user intent each turn** — Is the user exploring (Discovery) or seeking action (Directive)?
2. **Signal transitions through coaching tone** — Don't announce "switching to directive mode"; shift naturally in response style
3. **Conservative switching** — Default to current mode when intent is ambiguous. Avoid ping-ponging.
4. **Discovery signals:** Open questions, uncertainty, "I don't know what I want", exploring values, brainstorming, new topic without clear goal
5. **Directive signals:** Clear goal stated, asking "what should I do?", ready for action, requesting specific steps, follow-up on previous plan
6. **Set the `mode` field** in structured output to match the mode used in the current response
7. **UX-DR78 transition rhythms the LLM must honor:**
   - Vulnerability → Action: include 2-3 beats of acknowledgment before shifting to Directive mode. Don't jump to action steps when the user is being vulnerable.
   - Celebration → Challenge: wait for a full session boundary before shifting to Challenger-style pushback after a celebration moment.
   - Compassion → Resilience: wait for the user to signal readiness before shifting from gentle support to growth-oriented coaching.

### Testing Standards

**Go tests:**
- `TestHandlerName_Condition_Expected` naming
- `httptest` for handler tests
- Co-located `_test.go` files
- Must verify: mode transition in done event when LLM returns different mode
- Must verify: fallback to `req.Mode` when LLM returns empty mode

**Swift tests:**
- Swift Testing `@Test` macro, NOT XCTest
- `test_methodName_condition_expectedResult` naming
- Hand-written protocol mocks, no frameworks
- In-memory GRDB for database tests
- Must verify: mode segments track transitions correctly
- Must verify: initial segment uses session's actual mode (not hardcoded discovery)
- Must verify: `ModeSegment` JSON encode/decode roundtrip

### UX Design References

- **UX-DR10:** Ambient mode shifts — Discovery: warmer/golden, Directive: cooler/focused. Safety states override all coaching mode shifts.
- **UX-DR78:** Transition rhythm — Vulnerability → Action: 2-3 beats of acknowledgment before goals. Celebration → Challenge: wait for session boundary. Compassion → Resilience: wait for user readiness signal. These rhythms must be encoded in the prompt section.
- **Transition animation:** 0.4s easeInOut crossfade. Respects `accessibilityReduceMotion` (instant when reduced motion on).
- **No UI indicators:** Mode transitions are invisible to the user — expressed only through ambient background shift and coach expression/tone changes.
- **Coach expression:** Expression driven by `mood` field (warm for Discovery, focused for Directive) — already handled, no changes needed.
- **Safety override:** Current `SafetyLevel` enum has `.green`, `.yellow`, `.red`. When safety is `.yellow` or `.red`, coaching mode ambient shifts are suppressed (enforced in Story 6.2).

### GRDB Migration Pattern

Add migration `v3` in `ios/sprinty/Services/Database/Migrations.swift` after the existing `v2` migration (line 33):
```swift
migrator.registerMigration("v3") { db in
    try db.alter(table: "ConversationSession") { t in
        t.add(column: "modeHistory", .text) // JSON-encoded [ModeSegment] array
    }
}
```

The `modeHistory` column stores a JSON array. Default to `nil` for existing sessions.

### Project Structure Notes

- All changes align with established MVVM pattern and feature-based folder organization
- New prompt section follows existing pattern: markdown file in `server/prompts/sections/`
- `toolResult` struct change is Anthropic-specific (only provider with structured output currently)
- iOS migration follows GRDB `DatabaseMigrator` sequential pattern (`v1`, `v2`, `v3`)
- No new dependencies or frameworks required

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 2, Story 2.3]
- [Source: _bmad-output/planning-artifacts/architecture.md — System Prompt Sections, Provider Interface, CoachingMode enum]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR10 Ambient Mode Shifts, UX-DR78 Transition Rhythm]
- [Source: _bmad-output/planning-artifacts/prd.md — The Directive Trust Gap, Mode Switching]
- [Source: _bmad-output/implementation-artifacts/2-2-directive-mode-with-contingency-plans.md — Go test helper regression pattern]
- [Source: server/providers/anthropic.go — toolResult struct (lines 51-57), tool schema (lines 15-48), done event (lines 168-176)]
- [Source: server/providers/mock.go — MockProvider done event (line 38)]
- [Source: server/prompts/builder.go — sectionFiles (lines 26-35), Build() mode switch (lines 73-90), unconditional loop (line 93)]
- [Source: server/prompts/builder_test.go — setupTestSections() (lines 10-37), expected count (line 46)]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — mode detection (lines 131-133), updateSessionMode (lines 203-216)]
- [Source: ios/sprinty/Services/Database/Migrations.swift — migration pattern, latest migration v2 (line 33)]
- [Source: ios/sprinty/Models/ConversationSession.swift — CoachingMode enum, table "ConversationSession"]
- [Source: docs/api-contract.md — Done Event section (lines 151-166), missing mode field documentation]
- [Source: docs/fixtures/sse-done-event.txt — includes mode field already]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Go tests: 12 prompts tests, 9 provider tests, 29 handler tests — all pass
- iOS tests: All suites pass including 4 new ModeSegmentTests

### Completion Notes List
- Task 1: Created `mode-transitions.md` prompt section with Discovery/Directive signal detection, conservative switching, and UX-DR78 transition rhythms. Added to builder's unconditional loop. Updated all 3 Go test helpers and added `TestBuilder_Build_IncludesModeTransitions`.
- Task 2: Added `Mode` field to `toolResult` struct and tool schema in `anthropic.go`. Done event now uses LLM-decided mode with fallback to `req.Mode`. `MockProvider` gained `StubbedMode` field for test control. Added 2 handler tests: mode transition and empty-mode fallback.
- Task 3: Defined `ModeSegment` struct (Codable, Sendable) in `ConversationSession.swift`. Added `modeHistory` column via GRDB migration v3. `CoachingViewModel` initializes `modeSegments` from session mode on load and appends/persists on mode changes. 4 Swift tests verify accumulation, initial mode, and JSON roundtrip.
- Task 4: Updated `docs/api-contract.md` Done Event section with `mode` field documentation and example. Verified fixture already includes `mode`.
- Task 5: Verified existing iOS transition pipeline: ViewModel detection (lines 131-133), 0.4s easeInOut animation (lines 75-78), bidirectional ambient shifts via `applyingAmbientMode`, #Preview blocks for both directions, and reduce-motion accessibility check. No changes needed.

### File List
- server/prompts/sections/mode-transitions.md (new)
- server/prompts/builder.go (modified)
- server/prompts/builder_test.go (modified)
- server/providers/anthropic.go (modified)
- server/providers/mock.go (modified)
- server/tests/handlers_test.go (modified)
- ios/sprinty/Models/ConversationSession.swift (modified)
- ios/sprinty/Services/Database/Migrations.swift (modified)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified)
- ios/Tests/Features/ModeSegmentTests.swift (new)
- ios/sprinty.xcodeproj/project.pbxproj (modified)
- docs/api-contract.md (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)

### Change Log
- 2026-03-20: Story 2.3 implemented — natural mode transitions with LLM-driven mode selection, mode segment tracking, and documentation updates
