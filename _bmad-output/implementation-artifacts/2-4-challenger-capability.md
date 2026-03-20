# Story 2.4: Challenger Capability

Status: review

## Story

As a user making important decisions,
I want my coach to push back on my reasoning and offer alternative perspectives,
so that I stress-test my thinking before committing to a path.

## Acceptance Criteria

1. **Constructive pushback:** Given a user shares a decision or plan, when the Challenger capability activates, then the coach pushes back constructively on the user's reasoning, provides alternative perspectives the user may not have considered, and stress-tests assumptions without being dismissive or hostile. The conversation background subtly shifts deeper/more grounded (UX-DR10).

2. **Non-disableable:** Given the Challenger capability, when a user attempts to disable it (via conversation or settings), then it cannot be disabled (non-negotiable per FR7). The coach may acknowledge the discomfort but continues to provide balanced perspectives.

3. **Challenge-to-support transition:** Given the Challenger pushes back, when the user responds, then the coach acknowledges the user's response and either deepens the challenge or transitions to support. Contingency planning follows naturally from challenged decisions (transition rhythm: Challenge → Support with immediate contingency per UX-DR78).

## Tasks / Subtasks

- [x] Task 1: Create challenger system prompt section (AC: #1, #2)
  - [x] 1.1 Create `server/prompts/sections/challenger.md` with instructions for the Challenger capability (see Prompt Content Guidance below)
  - [x] 1.2 Add `"challenger.md"` to `sectionFiles` slice in `builder.go` `NewBuilder()` (line 26-36) — append after `"mode-transitions.md"`
  - [x] 1.3 In `Build()`, add `"challenger"` to the unconditional section loop at line 94: `for _, section := range []string{"safety", "mood", "tagging", "cultural", "mode-transitions", "challenger"}` — Challenger is always included regardless of mode because it's a capability, not a mode
  - [x] 1.4 **CRITICAL**: Update ALL 3 Go test helpers simultaneously — `builder_test.go:setupTestSections()`, `handlers_test.go:createTestPromptBuilder()`, `handlers_test.go:setupMuxWithBuilder()` — add `"challenger.md": "Challenger capability: push back constructively."` entry to each files map
  - [x] 1.5 Update `TestNewBuilder_LoadsSections` expected count from 9 → 10
  - [x] 1.6 Add `TestBuilder_Build_IncludesChallenger` — verify challenger section present in output for all modes (discovery, directive, unknown)

- [x] Task 2: Add `challengerUsed` field to structured output pipeline (AC: #1, #3)
  - [x] 2.1 Add `challengerUsed` boolean property to tool schema JSON in `anthropic.go` `toolSchema` var (lines 15-53) — add to `Properties` map: `"challengerUsed": {"type": "boolean", "description": "Set to true when this response includes constructive pushback, alternative perspectives, or stress-testing of the user's assumptions. Set to false for normal coaching responses."}`. Add `"challengerUsed"` to the `Required` array.
  - [x] 2.2 Add `ChallengerUsed bool` field to `toolResult` struct in `anthropic.go` (lines 56-63): `ChallengerUsed bool \`json:"challengerUsed"\``
  - [x] 2.3 Add `ChallengerUsed` field to `ChatEvent` struct in `provider.go` (line 27-36): `ChallengerUsed bool \`json:"challengerUsed,omitempty"\``
  - [x] 2.4 In anthropic.go done event emission (lines 174-183), add: `ChallengerUsed: result.ChallengerUsed,`
  - [x] 2.5 In `server/providers/mock.go`, add `StubbedChallengerUsed bool` field to `MockProvider` struct. In done event emission, add: `ChallengerUsed: m.StubbedChallengerUsed,`
  - [x] 2.6 **CRITICAL: Update `server/handlers/chat.go`** — The handler manually constructs the done event JSON using `map[string]any{}` (lines 88-95). It does NOT auto-serialize `ChatEvent` fields. Add `"challengerUsed": event.ChallengerUsed` to the map alongside the existing `safetyLevel`, `domainTags`, `mood`, `mode`, `usage`, `promptVersion` entries. Without this, `challengerUsed` will be silently dropped and never reach the iOS client.
  - [x] 2.7 Add handler test `TestChatHandler_DoneEvent_ChallengerUsed` — use `MockProvider{StubbedChallengerUsed: true}`, verify `challengerUsed: true` in done event JSON

- [x] Task 3: iOS — Parse `challengerUsed` and add ambient background for Challenger (AC: #1)
  - [x] 3.1 Update `ChatEvent.swift` — 4 precise changes required in `ios/sprinty/Features/Coaching/Models/ChatEvent.swift`:
      - Add `challengerUsed: Bool?` parameter to the `.done` case (line 5): `case done(safetyLevel: String, domainTags: [String], mood: String?, mode: String?, challengerUsed: Bool?, usage: ChatUsage, promptVersion: String?)`
      - Add `let challengerUsed: Bool?` to `DoneEventData` struct (lines 48-55)
      - Update `ChatEvent.from()` (lines 25-32) to pass `challengerUsed: parsed.challengerUsed` to the `.done` constructor
      - **NOTE**: Every existing `.done` pattern match in the codebase must be updated to add the new positional parameter (see 3.3 below)
  - [x] 3.2 Add `var challengerActive: Bool = false` observable property to `CoachingViewModel` (line 8-15)
  - [x] 3.3 Update `CoachingViewModel` done event handler (line 102). The current destructure is:
      ```swift
      case .done(let safetyLevel, _, let mood, let mode, _, let promptVersion):
      ```
      Update to extract `challengerUsed` at its new positional slot:
      ```swift
      case .done(let safetyLevel, _, let mood, let mode, let challengerUsed, _, let promptVersion):
      ```
      Then after existing mode handling (line 133-135), add: `self.challengerActive = challengerUsed ?? false`
  - [x] 3.4 Add Challenger ambient background colors to `ColorPalette.swift`:
      - `static func challengerBackgroundColors(for colorScheme: ColorScheme) -> (start: Color, end: Color)` — Light: deeper earth tones (e.g., `#EDE8E0` / `#E4DED4` — grounded, slightly darker than conversation base), Dark: deeper warm dark (e.g., `#1A1816` / `#161412` — grounded dark shift)
      - `func challengerGroundedShift(backgroundStart:backgroundEnd:) -> ColorPalette` — follows same pattern as `discoveryWarmShift` and `directiveCoolShift`, only changes background gradient
  - [x] 3.5 Update `CoachingView.swift` `conversationTheme` computed property (lines 8-11) — layer Challenger shift on top of the current mode's ambient when `viewModel.challengerActive` is true:
      ```swift
      private var conversationTheme: CoachingTheme {
          var theme = themeFor(context: .conversation, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)
              .applyingAmbientMode(viewModel.coachingMode, colorScheme: colorScheme)
          if viewModel.challengerActive {
              theme = theme.applyingChallengerShift(colorScheme: colorScheme)
          }
          return theme
      }
      ```
  - [x] 3.6 Add `applyingChallengerShift(colorScheme:)` method to `CoachingTheme`:
      ```swift
      func applyingChallengerShift(colorScheme: ColorScheme) -> CoachingTheme {
          let (start, end) = ColorPalette.challengerBackgroundColors(for: colorScheme)
          let shifted = palette.challengerGroundedShift(backgroundStart: start, backgroundEnd: end)
          return CoachingTheme(palette: shifted, typography: typography, spacing: spacing, cornerRadius: cornerRadius)
      }
      ```
  - [x] 3.7 Add `.animation` modifier for `challengerActive` in `CoachingView.swift` — use same 0.4s easeInOut timing, respect reduce motion
  - [x] 3.8 Add #Preview blocks for Challenger ambient in both light and dark

- [x] Task 4: Update documentation, fixtures, and fixture-dependent tests (AC: #1, #2, #3)
  - [x] 4.1 Update `docs/api-contract.md` Done Event section (lines 151-167) — add `challengerUsed` field: `challengerUsed (boolean): Whether this response used the Challenger capability (constructive pushback, alternative perspectives). Default: false.`
  - [x] 4.2 Update `docs/fixtures/sse-done-event.txt` — add `"challengerUsed": false` to the done event JSON
  - [x] 4.3 Update `server/tests/handlers_test.go` `TestSSEDoneEventMatchesFixtureFormat` (lines 435-461) — add `"challengerUsed"` to the field verification loop at line 454: `for _, field := range []string{"safetyLevel", "domainTags", "mood", "mode", "usage", "promptVersion", "challengerUsed"}`

- [x] Task 5: Swift tests for Challenger (AC: #1, #3)
  - [x] 5.1 Add test in `ios/Tests/Features/` — verify `challengerActive` is set to true when done event includes `challengerUsed: true`
  - [x] 5.2 Add test — verify `challengerActive` resets to false on next done event with `challengerUsed: false`
  - [x] 5.3 Verify Challenger ambient theme shift produces different background colors than base conversation theme
  - [x] 5.4 Update `ios/Tests/Models/ChatEventCodableTests.swift` — the `test_fromSSE_doneEvent_fromFixture` test (line 33) destructures `.done` with 6 positional parameters. Update to include `challengerUsed` at its new position. Add a new test `test_fromSSE_doneEvent_challengerUsedTrue` verifying a done event with `"challengerUsed": true` parses correctly. Also update all other `.done` pattern matches in this file (lines 80, 95, 110, 125) to add the new parameter position.
  - [x] 5.5 Verify `ios/Tests/Services/SSEParserTests.swift` — the `test_chatEventFrom_doneSSE` test (line 79) destructures `.done` with positional parameters. Update to add `challengerUsed` at its new position. Existing tests should still pass after fixture update.

## Dev Notes

### Architecture: Challenger is a CAPABILITY, not a MODE

This is the most critical distinction. The existing system has two **modes** (Discovery and Directive) with a `mode` field in the LLM's structured output that drives mode transitions. Challenger is **NOT** a third mode — it's a capability that can activate within EITHER mode.

- **Modes** (Discovery/Directive): Mutually exclusive, drive the mode-specific prompt section and mode-transitions logic
- **Challenger**: Always-on capability that fires when the LLM detects a decision or plan worth stress-testing. Can occur in Discovery (challenging assumptions about values/direction) or Directive (challenging action plans)

This means:
- `CoachingMode` enum stays as-is: `.discovery` | `.directive` — do NOT add `.challenger`
- The `mode` field in structured output stays as-is
- A NEW `challengerUsed` boolean field is added to structured output
- The ambient background shift for Challenger is an **overlay** on top of the current mode's ambient shift

### Prompt Content Guidance for `challenger.md`

The section should instruct the LLM to:

1. **Always-on, non-negotiable** — FR7: The Challenger capability cannot be disabled. Even if the user asks to stop pushback, acknowledge their discomfort but continue providing balanced perspectives.
2. **When to activate** — When the user shares a decision, plan, or strong opinion. Not every response needs pushback — use judgment about when stress-testing adds value.
3. **Constructive, not hostile** — Push back on reasoning, not the person. Frame challenges as "Have you considered..." or "What if..." rather than "You're wrong about..."
4. **Alternative perspectives** — Surface viewpoints the user hasn't considered. Draw from cross-domain awareness.
5. **Stress-test assumptions** — Identify hidden assumptions in the user's reasoning and gently probe them.
6. **Set `challengerUsed` to true** in structured output when the response includes pushback or alternative perspectives.
7. **Challenge → Support rhythm (UX-DR78)** — After challenging a decision, transition to support with immediate contingency planning. Don't leave the user hanging after pushback — help them build a stronger plan.
8. **Knows when to back off** — If the user has already stress-tested their thinking thoroughly, acknowledge the strength of their reasoning rather than finding more to challenge.
9. **Cultural sensitivity (NFR38)** — Challenges should not assume Western-centric frameworks. Be aware that directness norms vary across cultures.

### How the Ambient Background Works

The existing system uses the `applyingAmbientMode()` method to shift the conversation background gradient based on coaching mode:
- Discovery: warmer/golden shift (`ColorPalette.discoveryBackgroundColors`)
- Directive: cooler/blue-gray shift (`ColorPalette.directiveBackgroundColors`)

For Challenger, per UX-DR10, the shift should be "deeper/more grounded." This means:
- **Light mode**: Slightly darker, earthier tones than the base — creates a feeling of seriousness/depth
- **Dark mode**: Slightly deeper, warmer dark — creates a grounded feel

The Challenger shift is applied as a **layer on top** of the current mode's ambient. When `challengerActive` is true, the Challenger background overrides the mode's background. When `challengerActive` goes back to false (next response without challenger), the background reverts to the current mode's ambient.

### Provider Architecture — Current State

From Story 2.3, the structured output pipeline is:
1. `toolSchema` in `anthropic.go` defines the JSON schema the LLM must follow
2. `toolResult` struct parses the LLM's structured output
3. `ChatEvent` in `provider.go` carries the parsed data to the handler
4. Handler emits SSE `done` event with the data
5. iOS `ChatEvent` parses the SSE and the ViewModel acts on it

For Challenger, add `challengerUsed` at each level of this pipeline.

**Only two providers exist:**
- `anthropic.go` — production provider with `toolResult` struct and tool schema
- `mock.go` — test provider
- `openai.go`, `gemini.go`, `kimi.go` do NOT exist — do not create them

### Critical Regression Pattern (from Stories 2.2 and 2.3)

When adding new section files to the prompt builder, ALL Go test helpers must be updated simultaneously or all tests break:
1. `server/prompts/builder_test.go` → `setupTestSections()` (lines 10-38)
2. `server/tests/handlers_test.go` → `createTestPromptBuilder()` (lines 29-53)
3. `server/tests/handlers_test.go` → `setupMuxWithBuilder()` (lines 59-91) — specifically the `files` map inside

### Existing Files to Modify

**Server (Go):**
| File | Change |
|------|--------|
| `server/prompts/builder.go` | Add `"challenger.md"` to `sectionFiles` (line 26-36), add `"challenger"` to unconditional loop (line 94) |
| `server/prompts/builder_test.go` | Update `setupTestSections()` (line 10-38): add `"challenger.md"` entry, update expected count 9→10, add challenger inclusion test |
| `server/providers/anthropic.go` | Add `ChallengerUsed` to `toolResult` struct (lines 56-63), add `challengerUsed` to `toolSchema` properties (lines 15-53) + Required array, add to done event emission (lines 174-183) |
| `server/providers/provider.go` | Add `ChallengerUsed bool` to `ChatEvent` struct (lines 27-36) |
| `server/providers/mock.go` | Add `StubbedChallengerUsed bool` field, add `ChallengerUsed` to done event |
| `server/handlers/chat.go` | Add `"challengerUsed": event.ChallengerUsed` to the done event `map[string]any{}` (lines 88-95) |
| `server/tests/handlers_test.go` | Update both test helper file maps (lines 34-43, 68-78): add `"challenger.md"` entry, add `TestChatHandler_DoneEvent_ChallengerUsed` test, update `TestSSEDoneEventMatchesFixtureFormat` field list (line 454) |
| `docs/api-contract.md` | Add `challengerUsed` field to Done Event section (lines 151-167) |
| `docs/fixtures/sse-done-event.txt` | Add `challengerUsed` field |

**New Server File:**
| File | Purpose |
|------|---------|
| `server/prompts/sections/challenger.md` | LLM instructions for the Challenger capability |

**iOS (Swift):**
| File | Change |
|------|--------|
| `ios/sprinty/Features/Coaching/Models/ChatEvent.swift` | Add `challengerUsed: Bool?` to `.done` case, `DoneEventData` struct, and `from()` method |
| `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` | Add `challengerActive` property, update done event destructure (line 102) to extract `challengerUsed` |
| `ios/sprinty/Features/Coaching/Views/CoachingView.swift` | Apply challenger ambient shift when active, add animation modifier, add #Previews |
| `ios/sprinty/Core/Theme/CoachingTheme.swift` | Add `applyingChallengerShift()` method |
| `ios/sprinty/Core/Theme/ColorPalette.swift` | Add `challengerBackgroundColors()` and `challengerGroundedShift()` |
| `ios/Tests/Models/ChatEventCodableTests.swift` | Update ALL `.done` pattern matches (lines 33, 80, 95, 110, 125) to include `challengerUsed` parameter position, add challenger-specific test |
| `ios/Tests/Services/SSEParserTests.swift` | Update `.done` pattern match at line 79 to include `challengerUsed` parameter position |

### Files NOT to Touch

- `ios/sprinty/Models/ConversationSession.swift` — Challenger is NOT a mode; do not add `.challenger` to `CoachingMode` enum. Do not add a column for challenger state.
- `server/prompts/sections/mode-transitions.md` — Mode transitions handles Discovery ↔ Directive; Challenger is orthogonal
- `server/prompts/sections/mode-discovery.md` / `mode-directive.md` — These are mode-specific; Challenger is a cross-mode capability
- `ios/sprinty/Services/Database/Migrations.swift` — No schema changes needed for this story
- `server/providers/openai.go`, `gemini.go`, `kimi.go` — These files do not exist yet

### Testing Standards

**Go tests:**
- `TestHandlerName_Condition_Expected` naming
- `httptest` for handler tests
- Co-located `_test.go` files
- Must verify: `challengerUsed: true` in done event when MockProvider is stubbed
- Must verify: `challengerUsed` field omitted or false when not set (default behavior)

**Swift tests:**
- Swift Testing `@Test` macro, NOT XCTest
- `test_methodName_condition_expectedResult` naming
- Hand-written protocol mocks, no frameworks
- Must verify: `challengerActive` observable property updates on done event
- Must verify: Challenger ambient theme produces distinct background colors

### UX Design References

- **UX-DR10:** Ambient mode shifts — Challenger: "deeper/more grounded" background. This is a separate ambient from Discovery (warm/golden) and Directive (cool/focused). Safety states override all ambient shifts.
- **UX-DR78:** Transition rhythm — Challenge → Support: the coach should follow pushback with immediate contingency planning. Don't leave the user feeling challenged without a constructive next step. This rhythm is encoded in the prompt section, not in iOS code.
- **FR7:** Challenger is non-negotiable and cannot be disabled by the user. This is enforced in the system prompt.
- **Animation timing:** 0.4s easeInOut (same as mode transitions). Respects `accessibilityReduceMotion` (instant when reduced motion on).
- **Safety override:** When safety is `.yellow` or `.red`, all ambient shifts (including Challenger) are suppressed (enforced in Story 6.2).

### Content Hash Note

Adding `challenger.md` changes the prompt builder's `ContentHash()`. The iOS prompt version cache has a 1hr TTL and will auto-invalidate. This is expected behavior — no iOS fix needed.

### Project Structure Notes

- All changes align with established MVVM pattern and feature-based folder organization
- New prompt section follows existing pattern: markdown file in `server/prompts/sections/`
- `challengerUsed` boolean added to full pipeline: tool schema → toolResult → ChatEvent → SSE → iOS ChatEvent → ViewModel
- Challenger ambient shift follows exact same pattern as Discovery/Directive shifts in `ColorPalette.swift` and `CoachingTheme.swift`
- No new dependencies or frameworks required
- No database migrations needed — Challenger state is per-response, not persisted

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 2, Story 2.4]
- [Source: _bmad-output/planning-artifacts/architecture.md — System Prompt Sections: `challenger` section for FR7]
- [Source: _bmad-output/planning-artifacts/prd.md — FR7: Challenger capability, non-negotiable pushback]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR10 Ambient Mode Shifts, UX-DR78 Transition Rhythm]
- [Source: _bmad-output/implementation-artifacts/2-3-natural-mode-transitions.md — Go test helper regression pattern, structured output pipeline, mode transition prompt pattern]
- [Source: server/providers/anthropic.go — toolResult struct (lines 56-63), tool schema (lines 15-53), done event (lines 174-183)]
- [Source: server/providers/provider.go — ChatEvent struct (lines 27-36)]
- [Source: server/providers/mock.go — MockProvider struct with StubbedMode pattern (lines 5-7)]
- [Source: server/handlers/chat.go — done event JSON map construction (lines 86-98), manual field mapping that must include challengerUsed]
- [Source: server/prompts/builder.go — sectionFiles (lines 26-36), Build() unconditional loop (line 94)]
- [Source: server/prompts/builder_test.go — setupTestSections() (lines 10-38), expected count (line 47)]
- [Source: server/tests/handlers_test.go — createTestPromptBuilder() (lines 29-53), setupMuxWithBuilder() (lines 59-91), TestSSEDoneEventMatchesFixtureFormat field list (line 454)]
- [Source: ios/sprinty/Features/Coaching/Models/ChatEvent.swift — .done case (line 5), DoneEventData struct (lines 48-55), from() method (lines 25-32)]
- [Source: ios/sprinty/Core/Theme/ColorPalette.swift — discoveryBackgroundColors(), directiveBackgroundColors(), ambient shift methods]
- [Source: ios/sprinty/Core/Theme/CoachingTheme.swift — applyingAmbientMode() (lines 35-47)]
- [Source: ios/sprinty/Features/Coaching/Views/CoachingView.swift — conversationTheme computed property (lines 8-11), animation modifier (lines 75-78)]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — done event destructure (line 102), handler (lines 102-136)]
- [Source: ios/sprinty/Models/ConversationSession.swift — CoachingMode enum (lines 8-11)]
- [Source: ios/Tests/Models/ChatEventCodableTests.swift — .done pattern matches (lines 33, 80, 95, 110, 125)]
- [Source: ios/Tests/Services/SSEParserTests.swift — .done pattern match (line 79)]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug issues encountered.

### Completion Notes List

- Task 1: Created `challenger.md` prompt section with non-negotiable Challenger capability instructions. Updated `builder.go` to load and include it unconditionally across all modes. Updated all 3 Go test helpers simultaneously. Added `TestBuilder_Build_IncludesChallenger` verifying presence in discovery, directive, and unknown modes. Expected section count updated 9→10.
- Task 2: Added `challengerUsed` boolean through the full structured output pipeline: tool schema → toolResult → ChatEvent → MockProvider → handler done event JSON map. Added `TestChatHandler_DoneEvent_ChallengerUsed` test with `StubbedChallengerUsed: true` verification.
- Task 3: Updated iOS `ChatEvent.swift` `.done` case with `challengerUsed: Bool?` at all 3 layers (enum case, DoneEventData struct, from() method). Added `challengerActive` observable to CoachingViewModel, updated done event destructure. Added `challengerBackgroundColors()`, `challengerGroundedShift()` to ColorPalette, `applyingChallengerShift()` to CoachingTheme. Updated CoachingView to layer Challenger shift on mode ambient. Added animation modifier and #Preview blocks.
- Task 4: Updated `api-contract.md` done event docs, `sse-done-event.txt` fixture, and `TestSSEDoneEventMatchesFixtureFormat` field list to include `challengerUsed`.
- Task 5: Updated all `.done` pattern matches across test files (ChatEventCodableTests, SSEParserTests, CoachingViewModelTests). Added challenger-specific tests: `test_fromSSE_doneEvent_challengerUsedTrue`, `test_sendMessage_challengerUsedTrue_setsChallengerActive`, `test_sendMessage_challengerUsedFalse_resetsChallengerActive`, `test_applyingChallengerShift_producesDistinctBackground` (light + dark).

### Change Log

- 2026-03-20: Story 2.4 implemented — Challenger capability with full pipeline, ambient background, tests. All 177 iOS tests + all Go tests pass.

### File List

**New files:**
- server/prompts/sections/challenger.md

**Modified files (Server):**
- server/prompts/builder.go
- server/prompts/builder_test.go
- server/providers/anthropic.go
- server/providers/provider.go
- server/providers/mock.go
- server/handlers/chat.go
- server/tests/handlers_test.go
- docs/api-contract.md
- docs/fixtures/sse-done-event.txt

**Modified files (iOS):**
- ios/sprinty/Features/Coaching/Models/ChatEvent.swift
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift
- ios/sprinty/Features/Coaching/Views/CoachingView.swift
- ios/sprinty/Core/Theme/CoachingTheme.swift
- ios/sprinty/Core/Theme/ColorPalette.swift
- ios/Tests/Models/ChatEventCodableTests.swift
- ios/Tests/Services/SSEParserTests.swift
- ios/Tests/Features/CoachingViewModelTests.swift
- ios/Tests/Theme/ThemeForTests.swift
