# Story 2.1: Discovery Mode Coaching

Status: done

## Story

As a user without clear goals,
I want my coach to facilitate exploration through probing questions and values archaeology,
So that I can discover what matters to me and find direction.

## Acceptance Criteria

1. **Given** a user is in a coaching conversation
   **When** the coaching mode is Discovery
   **Then** the system prompt includes the discovery mode section
   **And** the coach asks probing questions, surfaces values, and explores rather than prescribes
   **And** the conversation background subtly shifts warmer/more golden (UX-DR10)
   **And** the `event: done` SSE payload includes `mode: "discovery"`

2. **Given** the conversation starts
   **When** the user has not expressed a clear goal
   **Then** the system defaults to Discovery Mode
   **And** the coach explores the user's situation without pushing toward action

3. **Given** Discovery Mode is active
   **When** the system prompt is assembled
   **Then** it includes the `mode-discovery` section and excludes the `mode-directive` section

4. **Given** cultural context adaptation (NFR38)
   **When** the coach facilitates discovery
   **Then** coaching does not assume Western-centric models of career, family, or success
   **And** the system asks about cultural context during intake rather than assuming defaults

## Tasks / Subtasks

- [x] Task 1: Add `mode` field to `event: done` SSE payload (AC: #1)
  - [x] 1.1 Server: Add `Mode string` field to `ChatEvent` in `server/providers/provider.go`
  - [x] 1.2 Server: Pass `req.Mode` through to done event in `server/providers/anthropic.go` — set `Mode: req.Mode` on the done `ChatEvent` (line ~168)
  - [x] 1.3 Server: Include `"mode"` in done event JSON map in `server/handlers/chat.go` (line ~88)
  - [x] 1.4 Server: Update mock provider (`server/providers/mock.go`) to set `Mode` on its done `ChatEvent` so test SSE output includes `mode`
  - [x] 1.5 Server: Update `docs/fixtures/sse-done-event.txt` to include `"mode": "discovery"` — this is the shared contract fixture used by both Go and Swift tests
  - [x] 1.6 iOS: Add `mode: String?` (optional for backward compat) to `DoneEventData` in `ChatEvent.swift`
  - [x] 1.7 iOS: Add `mode` parameter to `ChatEvent.done` case — becomes 6-tuple: `.done(safetyLevel:, domainTags:, mood:, mode:, usage:, promptVersion:)`
  - [x] 1.8 **REGRESSION WARNING — broad blast radius**: Update ALL existing `ChatEvent.done` pattern matches across the codebase:
    - `CoachingViewModel.swift` line ~98: `case .done(let safetyLevel, _, let mood, _, let promptVersion)` → add `mode` param
    - `ChatEventCodableTests.swift` lines 33, 78, 93: 4 pattern matches in test assertions
    - `CoachingViewModelTests.swift` lines 79, 103: 3 `MockChatService.stubbedEvents` `.done(...)` constructions
    - `MockChatService` usages: all `.done(...)` literals in test files
  - [x] 1.9 Go test in `server/tests/handlers_test.go`: `TestChatHandler_DoneEvent_IncludesMode` — assert `mode` field exists in done event SSE output
  - [x] 1.10 Go test: Update `TestSSEDoneEventMatchesFixtureFormat` to verify `mode` field in fixture
  - [x] 1.11 Go test: Update `TestChatSSEMatchesFixtureFormat` to assert `doneData["mode"]` exists
  - [x] 1.12 Swift test in `ios/Tests/Models/ChatEventCodableTests.swift`: `test_parseSseEvent_withDoneEvent_extractsMode`
  - [x] 1.13 Swift test: Update `test_fromSSE_doneEvent_fromFixture` pattern match for 6-tuple

- [x] Task 2: Create `cultural.md` prompt section (AC: #4)
  - [x] 2.1 Create `server/prompts/sections/cultural.md` — no Western-centric assumptions about career, family, success, relationships, or happiness; ask about cultural context during intake
  - [x] 2.2 Add `"cultural.md"` to `sectionFiles` slice in `server/prompts/builder.go` NewBuilder (after `tagging.md`, before `context-injection.md`)
  - [x] 2.3 Include `cultural` section in Build() — always included (not mode-gated), placed after tagging and before context-injection
  - [x] 2.4 **REGRESSION WARNING — Go test helpers must be updated**: All test helpers that create temp section files need `cultural.md` added:
    - `server/prompts/builder_test.go` `setupTestSections()` (line 18-25) — add `"cultural.md": "Cultural context."` to files map
    - `server/tests/handlers_test.go` `createTestPromptBuilder()` (line 34-41) — add `"cultural.md": "Cultural."` to files map
    - `server/tests/handlers_test.go` `setupMux()` inline section creation (line 65-72) — add `"cultural.md": "Cultural."` to files map
    - If not updated, `NewBuilder()` will fail on missing file and **ALL existing Go tests will break**
  - [x] 2.5 Go test in `server/prompts/builder_test.go`: `TestBuilder_Build_IncludesCulturalSection`
  - [x] 2.6 Go test: Update `TestNewBuilder_LoadsSections` expected count from 6 → 7

- [x] Task 3: Enhance `mode-discovery.md` prompt content (AC: #1, #2, #3)
  - [x] 3.1 Expand discovery prompt with deeper probing question guidance, values archaeology techniques, pattern surfacing instructions, and explicit instruction to explore rather than prescribe
  - [x] 3.2 Add guidance: default to discovery when no clear goal expressed
  - [x] 3.3 Go test: `TestBuilder_Build_DiscoveryMode_IncludesDiscoverySection`

- [x] Task 4: Implement ambient background mode shift for Discovery (AC: #1)
  - [x] 4.1 Implement `applyingAmbientMode(.discovery)` in `CoachingTheme.swift` — compute warmer background colors by shifting the existing conversation palette's `backgroundStart`/`backgroundEnd` toward golden/amber tones. Return a new `CoachingTheme` with the shifted palette. For `.directive` and other modes, return `self` (stub for future stories). Light: shift from `#F8F5EE`/`#F0ECE2` → `#FAF4E4`/`#F2EBDA`. Dark: shift from `#1C1E18`/`#181A14` → `#1E1C16`/`#1A1812`. Only background gradient shifts — keep all text colors unchanged.
  - [x] 4.2 Expose `coachingMode: CoachingMode` as a published property on `CoachingViewModel` (read from `currentSession?.mode ?? .discovery`)
  - [x] 4.3 Update `CoachingView` to apply ambient mode: compute theme as `conversationTheme.applyingAmbientMode(viewModel.coachingMode)` and use the result for background gradient and environment injection
  - [x] 4.4 Animate background gradient change: `.animation(.easeInOut(duration: 0.4), value: viewModel.coachingMode)`. **Accessibility**: check `UIAccessibility.isReduceMotionEnabled` — if true, use `nil` animation (instant transition), matching the pattern established in Story 1.9 for home→conversation transitions.
  - [x] 4.5 Swift test in `ios/Tests/Theme/ThemeForTests.swift`: `test_applyingAmbientMode_discovery_returnsWarmerPalette` — verify discovery background colors differ from base conversation palette
  - [x] 4.6 Swift test in `ios/Tests/Theme/ThemeForTests.swift`: `test_applyingAmbientMode_discovery_darkMode_returnsWarmerPalette`
  - [x] 4.7 Swift test: `test_applyingAmbientMode_directive_returnsSelf` — verify directive stub returns unchanged palette

- [x] Task 5: Parse mode from done event and update session (AC: #1)
  - [x] 5.1 In `CoachingViewModel.sendMessage`, extract `mode` from `.done` event (the new 6th parameter)
  - [x] 5.2 If server-returned mode differs from session mode, update `currentSession.mode` in DB and update the `coachingMode` property (triggers ambient shift)
  - [x] 5.3 Swift test in `ios/Tests/Features/CoachingViewModelTests.swift`: `test_sendMessage_whenDoneEventHasMode_updatesSessionMode`

- [x] Task 6: #Preview blocks and visual verification
  - [x] 6.1 Add #Preview for CoachingView with discovery ambient background (light + dark)
  - [x] 6.2 Add #Preview for CoachingView with directive ambient background for visual comparison (even though directive is Story 2.2, the stub palette should show no change)

## Dev Notes

### Architecture Compliance

- **MVVM pattern**: ViewModel owns all service calls; Views read from ViewModel. No direct View-to-service access.
- **@Observable macro** (not ObservableObject/@Published) — iOS 17+ deployment target
- **Swift 6 strict concurrency**: All ViewModels are `@MainActor`; all types crossing isolation boundaries must be `Sendable`
- **GRDB conventions**: Record types use `Codable + FetchableRecord + PersistableRecord + Identifiable`; queries as static extensions on model types
- **Protocol-based mocking**: Hand-written mocks via protocol conformance, no frameworks
- **Swift Testing**: Use `@Test` macro, not XCTest. Naming: `test_methodName_condition_expectedResult`
- **Go Testing**: Naming: `TestHandlerName_Condition_Expected`. Co-located `_test.go` files.

### Existing Code to Reuse — DO NOT REINVENT

**Server-side (already exists):**
- `server/prompts/sections/mode-discovery.md` — Discovery prompt section (enhance, don't replace)
- `server/prompts/sections/base-persona.md` — Already contains "make no assumptions about Western-centric defaults" (cultural.md should complement, not duplicate)
- `server/prompts/builder.go` — Prompt assembly with mode switching; `Build(mode, coachName)` already handles discovery/default case
- `server/handlers/chat.go` — SSE event emission; done event already emits `safetyLevel`, `domainTags`, `mood`, `usage`, `promptVersion`
- `server/providers/provider.go` — `ChatRequest` already has `Mode string` field; `ChatEvent` has `Type`, `Text`, `SafetyLevel`, `DomainTags`, `Mood`, `Usage` fields
- `server/providers/anthropic.go` — Structured output via `tool_use`; streams `ChatEvent` channel

**iOS-side (already exists):**
- `CoachingViewModel` — Already defaults new sessions to `.discovery` mode (line 184: `mode: .discovery`)
- `ConversationSession` — Already has `mode: CoachingMode` field with `.discovery`/`.directive` enum
- `ChatEvent.swift` — Already parses `DoneEventData` with `safetyLevel`, `domainTags`, `mood`, `usage`, `promptVersion`
- `CoachingTheme.swift` — Has stubbed `applyingAmbientMode(_ mode: CoachingMode)` returning `self` (line 35-37)
- `ColorPalette.swift` — Has `conversationLight`/`conversationDark` palettes; extend these for discovery warmth
- `CoachingView.swift` — Already uses `LinearGradient` with `conversationTheme.palette.backgroundStart/End`; already calls `themeFor(context:colorScheme:safetyLevel:isPaused:)`

### Implementation Strategy

**Server changes are minimal.** The prompt builder already loads `mode-discovery.md` and assembles it correctly. Main server work is:
1. Adding `mode` to the done event JSON (currently missing)
2. Creating `cultural.md` section file and adding it to the builder
3. Enriching the discovery prompt content

**iOS ambient mode is the core visual work.** The stub `applyingAmbientMode()` needs real implementation:
- Create warmer palette variants by shifting `backgroundStart`/`backgroundEnd` toward golden/amber tones
- For light mode: shift from earthy neutrals (`#F8F5EE`/`#F0ECE2`) toward warm gold (`#FAF4E4`/`#F2EBDA`)
- For dark mode: shift from cool dark (`#1C1E18`/`#181A14`) toward warm dark (`#1E1C16`/`#1A1812`)
- Keep text colors unchanged — only background gradient shifts
- The shift should be subtle, not dramatic. Per UX spec: "The space opens up — exploratory, inviting"

**Mode from server.** Currently the `done` event doesn't include `mode`. Adding it allows the server to eventually signal mode transitions (Story 2.3). For now, the mode will always match what the client sent, but the plumbing needs to exist.

### Project Structure Notes

- New file: `server/prompts/sections/cultural.md`
- Modified source files:
  - `server/providers/provider.go` (add Mode to ChatEvent)
  - `server/providers/anthropic.go` (pass mode through to done event)
  - `server/providers/mock.go` (add Mode to mock done event)
  - `server/handlers/chat.go` (add mode to done JSON)
  - `server/prompts/builder.go` (add cultural.md to sections list)
  - `server/prompts/sections/mode-discovery.md` (enhance content)
  - `ios/sprinty/Features/Coaching/Models/ChatEvent.swift` (add mode to done case — 6-tuple)
  - `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` (expose coachingMode, handle mode from done event)
  - `ios/sprinty/Features/Coaching/Views/CoachingView.swift` (apply ambient mode + animation)
  - `ios/sprinty/Core/Theme/CoachingTheme.swift` (implement applyingAmbientMode)
- Modified fixture files:
  - `docs/fixtures/sse-done-event.txt` (add `"mode": "discovery"` to JSON)
- Modified test files (regression updates):
  - `server/prompts/builder_test.go` (add cultural.md to setupTestSections, update section count 6→7)
  - `server/tests/handlers_test.go` (add cultural.md to both test helpers, add mode assertions)
  - `ios/Tests/Models/ChatEventCodableTests.swift` (update all .done pattern matches for 6-tuple)
  - `ios/Tests/Features/CoachingViewModelTests.swift` (update .done constructions + pattern matches)
  - `ios/Tests/Theme/ThemeForTests.swift` (new ambient mode tests)
- No new database migrations needed — `ConversationSession.mode` column already exists

### SSE Done Event Wire Format (Updated)

Current:
```json
{"safetyLevel": "green", "domainTags": ["career"], "mood": "warm", "usage": {...}, "promptVersion": "abc123"}
```

After this story:
```json
{"safetyLevel": "green", "domainTags": ["career"], "mood": "warm", "mode": "discovery", "usage": {...}, "promptVersion": "abc123"}
```

iOS `DoneEventData` must add `mode: String?` (optional for backward compatibility with older server versions). The `ChatEvent.done` enum case gains a 6th parameter: `.done(safetyLevel:, domainTags:, mood:, mode:, usage:, promptVersion:)`. This is a breaking change to the enum case signature — all existing pattern matches must be updated (see Task 1.8).

### Ambient Mode Color Guidance

Per UX spec (UX-DR10):
| Mode | Shift | Effect |
|------|-------|--------|
| Discovery | Slightly warmer, more golden | The space opens up — exploratory, inviting |
| Directive | Slightly cooler, more focused | (Story 2.2 — stub only) |
| Challenger | Slightly deeper, more grounded | (Story 2.4 — stub only) |

**Safety always wins.** If safety override is active (Yellow/Orange/Red), coaching mode ambient shifts are suppressed. The existing `CoachingView` doesn't currently pass safety level, but the `applyingAmbientMode` implementation should document this precedence rule for when safety is wired in (Story 6.2).

### Cultural Context (NFR38)

The `base-persona.md` already states: "You make no assumptions about what a 'good life' looks like. You avoid Western-centric defaults about success, relationships, or happiness."

The new `cultural.md` section should **complement** this with explicit discovery-phase guidance:
- During early discovery conversations, ask about cultural context rather than assuming
- Don't project individualistic vs. collectivist values
- Acknowledge that "success," "family," "career" mean different things in different cultures
- Let the user's own framework emerge through conversation

### Previous Story Intelligence

**From Story 1.9 (Home Screen Foundation):**
- `RootView` routing: onboarding → HomeView → CoachingView. Navigation uses ZStack with crossfade + upward offset transition.
- `CoachingView` has `.task { viewModel.loadMessages() }` on appear and `.onDisappear { viewModel.cancelStreaming() }`
- Test count: 160 tests passing (149 pre-existing + 11 from 1.9)
- Swift 6 strict concurrency enforced; all types must be Sendable
- `project.yml` uses `createIntermediateGroups: true`; auto-discovers `.swift` files

**From Git History:**
- Commits follow pattern: `feat: Story X.Y — description`
- Most recent: `b2303b3 feat: Story 1.9 — Home screen foundation with avatar, greeting, and coach action`

### Testing Standards Summary

**Swift Tests (iOS):**
- Framework: Swift Testing (`@Test` macro)
- Naming: `test_methodName_condition_expectedResult`
- Mocking: Hand-written protocol mocks (e.g., `MockChatService`)
- Database: In-memory GRDB for tests
- No SwiftUI view unit tests — use #Preview for visual verification

**Go Tests (Server):**
- Framework: `testing` std lib
- Naming: `TestHandlerName_Condition_Expected`
- HTTP testing: `httptest` package
- Co-located `_test.go` files

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 2, Story 2.1]
- [Source: _bmad-output/planning-artifacts/architecture.md — System Prompt Configuration, Coaching Modes]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Ambient Mode Shifts, Coach Expression States, RPG Dialogue Paradigm]
- [Source: server/prompts/builder.go — Prompt assembly logic]
- [Source: server/handlers/chat.go — SSE done event emission]
- [Source: ios/sprinty/Core/Theme/CoachingTheme.swift — applyingAmbientMode stub at line 35-37]
- [Source: ios/sprinty/Features/Coaching/Views/CoachingView.swift — Background gradient at lines 64-71]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift — Session creation at lines 178-195]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Go tests: 3 packages pass (prompts, providers, tests)
- Swift tests: 166 tests in 21 suites pass (6 new tests added)
- Dark mode ambient color shift is intentionally subtle (2-3 hex values) — within 0.01 tolerance in tests

### Completion Notes List
- Task 1: Added `Mode` field to `ChatEvent` struct (Go), threaded `req.Mode` through Anthropic + Mock providers to done event, updated done event JSON in handler, updated SSE fixture, added `mode` to iOS `ChatEvent.done` enum (5→6 tuple), updated all pattern matches across 5 files (SSEParserTests was an unlisted regression catch)
- Task 2: Created `cultural.md` prompt section complementing existing base-persona.md cultural guidance, added to builder section list and Build() always-included sections, updated 3 Go test helpers
- Task 3: Enhanced `mode-discovery.md` with probing question techniques, values archaeology guidance, pattern surfacing instructions, and default-to-discovery behavior
- Task 4: Implemented `applyingAmbientMode(.discovery)` with warm golden background shift (light: #FAF4E4/#F2EBDA, dark: #1E1C16/#1A1812), exposed `coachingMode` on ViewModel, wired ambient mode into CoachingView with reduce-motion-aware animation
- Task 5: Extracted `mode` from done event in ViewModel, added `updateSessionMode()` to persist mode changes to DB and trigger ambient shift
- Task 6: Added 4 #Preview blocks for ambient mode visual verification (discovery light/dark, directive light/dark)

### Change Log
- 2026-03-19: Story 2.1 implementation complete — Discovery mode coaching with ambient background shift, mode in SSE done event, cultural prompt section, enhanced discovery prompt
- 2026-03-19: Code review fix — Added missing `promptVersion` field to SSE done event fixture, updated Go fixture field assertions and Swift fixture test to verify promptVersion

### File List
- server/providers/provider.go (modified — added Mode field to ChatEvent)
- server/providers/anthropic.go (modified — pass req.Mode to done event)
- server/providers/mock.go (modified — pass req.Mode to done event)
- server/handlers/chat.go (modified — include mode in done event JSON)
- server/prompts/builder.go (modified — added cultural.md to sections, included in Build)
- server/prompts/sections/cultural.md (new — cultural context prompt section)
- server/prompts/sections/mode-discovery.md (modified — enhanced discovery content)
- server/prompts/builder_test.go (modified — updated section count 6→7, added cultural.md to helper, added 2 new tests)
- server/tests/handlers_test.go (modified — added cultural.md to 2 helpers, added TestChatHandler_DoneEvent_IncludesMode, updated fixture/format tests for mode)
- docs/fixtures/sse-done-event.txt (modified — added mode field)
- ios/sprinty/Features/Coaching/Models/ChatEvent.swift (modified — 5→6 tuple with mode)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified — coachingMode property, mode extraction, updateSessionMode)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified — ambient mode, animation, #Preview blocks)
- ios/sprinty/Core/Theme/CoachingTheme.swift (modified — implemented applyingAmbientMode)
- ios/sprinty/Core/Theme/ColorPalette.swift (modified — discoveryBackgroundColors, discoveryWarmShift)
- ios/Tests/Models/ChatEventCodableTests.swift (modified — updated pattern matches, added mode extraction tests)
- ios/Tests/Features/CoachingViewModelTests.swift (modified — updated .done constructions, added mode update test)
- ios/Tests/Theme/ThemeForTests.swift (modified — added 3 ambient mode tests)
- ios/Tests/Services/SSEParserTests.swift (modified — updated pattern match for 6-tuple)
