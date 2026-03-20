# Story 2.2: Directive Mode with Contingency Plans

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user with defined goals,
I want my coach to provide confident, specific action steps with backup plans,
So that I know exactly what to do and have a fallback if things don't work out.

## Acceptance Criteria

1. **Given** a user has expressed a clear goal or need for direction
   **When** the coaching mode is Directive
   **Then** the system prompt includes the directive mode section
   **And** the coach provides confident, specific action steps (not hedging or vague)
   **And** the coach generates contingency plans (Plan B and Plan C) alongside primary recommendations
   **And** the conversation background subtly shifts cooler/more focused (UX-DR10)
   **And** the `event: done` SSE payload includes `mode: "directive"`

2. **Given** the coach provides a recommendation
   **When** the response includes contingency plans
   **Then** Plan B and Plan C are clearly articulated with conditions for when to switch
   **And** the contingency plans are specific to the user's situation (not generic)

## Tasks / Subtasks

- [x] Task 1: Create `mode-directive.md` prompt section (AC: #1, #2)
  - [x] 1.1 Create `server/prompts/sections/mode-directive.md` — Directive mode prompt content: confident action steps, contingency plan generation (Plan B + Plan C), structured recommendations with switch conditions, no hedging or vague language
  - [x] 1.2 Add `"mode-directive.md"` to `sectionFiles` slice in `server/prompts/builder.go` NewBuilder (line 26-34) — add after `"mode-discovery.md"` on line 28
  - [x] 1.3 **REGRESSION WARNING — Go test helpers must be updated**: All test helpers that create temp section files need `mode-directive.md` added:
    - `server/prompts/builder_test.go` `setupTestSections()` (line 18-26) — add `"mode-directive.md": "Directive mode: provide confident action steps."` to files map
    - `server/tests/handlers_test.go` `createTestPromptBuilder()` (lines 29-51) — add `"mode-directive.md": "Directive."` to files map
    - `server/tests/handlers_test.go` `setupMuxWithBuilder()` (lines 57-87) — add `"mode-directive.md": "Directive."` to its files map. Note: `setupMux()` (lines 53-55) is just a wrapper calling `setupMuxWithBuilder(nil)` — the section files are created inside `setupMuxWithBuilder`, not `setupMux`
    - If not updated, `NewBuilder()` will fail on missing file and **ALL existing Go tests will break**
  - [x] 1.4 Go test: Update `TestNewBuilder_LoadsSections` expected count from 7 → 8

- [x] Task 2: Add directive case to prompt builder (AC: #1)
  - [x] 2.1 In `server/prompts/builder.go` Build() method (line 72-85), replace the comment `// Future modes (directive, etc.) will be added here` with a `case "directive":` that loads `b.sections["mode-directive"]` — mirror the discovery case pattern exactly
  - [x] 2.2 Go test: `TestBuilder_Build_DirectiveMode` — assert prompt contains directive section content and does NOT contain discovery section content
  - [x] 2.3 Go test: `TestBuilder_Build_DirectiveMode_ExcludesDiscovery` — verify `mode-discovery` content is absent when building with `"directive"` mode

- [x] Task 3: Implement directive ambient background shift (AC: #1)
  - [x] 3.1 Add `directiveBackgroundColors(for colorScheme: ColorScheme) -> (start: Color, end: Color)` static method to `ColorPalette.swift` (in a new `// MARK: - Directive Ambient Mode Shift` extension, after the Discovery section at line 244). UX-DR10 specifies "slightly cooler, more focused" — shift conversation palette toward cooler/blue-green tones. Light: shift from `#F8F5EE`/`#F0ECE2` toward cooler tones (e.g., `#F2F5F8`/`#E8ECF0`). Dark: shift from `#1C1E18`/`#181A14` toward cooler dark (e.g., `#181C1E`/`#14181A`). The shift must be subtle — same magnitude as discovery's warm shift.
  - [x] 3.2 Add `directiveCoolShift(backgroundStart:backgroundEnd:) -> ColorPalette` method to `ColorPalette.swift` — mirrors `discoveryWarmShift` pattern exactly: creates new ColorPalette with shifted background, all other colors unchanged
  - [x] 3.3 In `CoachingTheme.swift` line 42, replace `return self // Stub — Story 2.2 fills in` with real implementation: call `ColorPalette.directiveBackgroundColors(for: colorScheme)` then `palette.directiveCoolShift(backgroundStart:backgroundEnd:)` and return new CoachingTheme — mirror the `.discovery` case pattern exactly (lines 37-40)
  - [x] 3.4 Swift test in `ios/Tests/Theme/ThemeForTests.swift`: Replace or update `test_applyingAmbientMode_directive_returnsSelf` → `test_applyingAmbientMode_directive_returnsCoolerPalette` — verify directive background colors differ from base conversation palette (cooler, not warmer)
  - [x] 3.5 Swift test: `test_applyingAmbientMode_directive_darkMode_returnsCoolerPalette` — verify dark mode directive shift
  - [x] 3.6 Swift test: `test_applyingAmbientMode_directive_textColorsUnchanged` — verify text colors remain identical to base palette

- [x] Task 4: #Preview blocks for directive ambient mode (AC: #1)
  - [x] 4.1 Update existing directive #Preview blocks in `CoachingView.swift` (lines 170-178) — rename from `"Directive Ambient — Light (Stub)"` / `"Directive Ambient — Dark (Stub)"` to `"Directive Ambient — Light"` / `"Directive Ambient — Dark"` (remove "(Stub)" labels). After Task 3, these previews will automatically show the cooler shift. Verify visually that the directive preview looks cooler/more focused compared to discovery's warmer/golden look.

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
- `server/prompts/sections/mode-discovery.md` — Discovery prompt section (32 lines). Use as structural reference for `mode-directive.md` — same style, different coaching behavior.
- `server/prompts/builder.go` — Prompt assembly with mode switching. `Build(mode, coachName)` already has discovery case at lines 73-77 and a comment at line 78 marking where directive goes. The default case (lines 79-84) falls back to discovery — this remains correct after adding directive.
- `server/prompts/builder_test.go` — `setupTestSections()` helper at lines 18-26 creates temp section files. Must add `mode-directive.md` entry or `NewBuilder()` will fail on missing file.
- `server/tests/handlers_test.go` — Has `createTestPromptBuilder()` (lines 29-51) and `setupMuxWithBuilder()` (lines 57-87) helpers that also create temp section files. Both must add `mode-directive.md`. Note: `setupMux()` (lines 53-55) is just a wrapper — the actual section file creation is inside `setupMuxWithBuilder()`.

**iOS-side (already exists):**
- `CoachingTheme.swift` line 42 — `case .directive: return self // Stub — Story 2.2 fills in`. Replace this stub with real implementation.
- `ColorPalette.swift` lines 197-244 — Discovery ambient mode shift section. Mirror this pattern exactly for directive (cooler shift instead of warmer).
- `CoachingMode` enum in `ConversationSession.swift` lines 8-11 — Already has `.discovery` and `.directive` cases. No changes needed.
- `CoachingView.swift` lines 8-11 — Already applies ambient mode via `themeFor(...).applyingAmbientMode(viewModel.coachingMode, colorScheme: colorScheme)`. No changes needed — directive will work automatically once CoachingTheme is updated.
- `CoachingView.swift` line 77 — Animation already in place: `.animation(.easeInOut(duration: 0.4), value: viewModel.coachingMode)` with reduce-motion check.
- `CoachingViewModel.swift` lines 131-133 — Mode extraction from done event already handles any CoachingMode rawValue. When server sends `mode: "directive"`, it will be parsed and trigger ambient shift. No changes needed.
- `CoachingViewModel.swift` lines 203-216 — `updateSessionMode(_ newMode:)` already persists mode changes to DB. No changes needed.
- `ChatEvent.swift` line 5 — Done event already includes `mode: String?` field. No changes needed.

**What does NOT need changing on iOS:**
- No ViewModel changes — mode switching infrastructure already works for any CoachingMode value
- No ChatEvent changes — mode field already parsed from SSE done event
- No CoachingView changes — ambient mode application already generic
- No database changes — mode column already exists
- Only `CoachingTheme.swift` and `ColorPalette.swift` need real implementation (replacing stub)
- Only `ThemeForTests.swift` needs test updates (directive now produces different palette, not same)

### Implementation Strategy

**Server changes are the core prompt work.** Create `mode-directive.md` with coaching psychology guidance for confident directive behavior and contingency planning. Add to builder and wire up the switch case.

**iOS changes are minimal color work.** The discovery pattern provides a complete blueprint — copy it, change warm→cool direction, plug in cooler hex values. Everything else (ViewModel, View, events) already works.

**Order of implementation:**
1. Create `mode-directive.md` prompt file (Task 1.1)
2. Add to builder section list and update Go test helpers (Task 1.2-1.4) — do this before Task 2 or tests break
3. Add directive case to Build() (Task 2.1-2.3)
4. Add directive colors to ColorPalette.swift (Task 3.1-3.2)
5. Replace CoachingTheme.swift stub (Task 3.3)
6. Update Swift tests (Task 3.4-3.6)
7. Verify #Preview blocks (Task 4.1)

### Directive Mode Prompt Content Guidance

The `mode-directive.md` section should embody the "Directive Trust Gap" — the core product insight from the PRD. Key principles:

**Confident action guidance:**
- Provide specific, actionable recommendations — not hedged suggestions
- Use direct language: "Here's what I'd do" not "You might consider"
- Back recommendations with reasoning — confidence comes from understanding, not authority
- Prioritize: lead with the highest-impact action, not a laundry list

**Contingency planning (Plan B + Plan C):**
- Every major recommendation must include backup plans
- Contingency plans are specific to the user's situation, never generic templates
- Include clear conditions for when to switch plans: "If X doesn't work by [timeframe], switch to Plan B"
- Plans should be complementary, not contradictory — each backup builds on learnings from the primary
- Per UX-DR78: When Challenger pushback leads to planning, contingency follows immediately in the same breath

**Cross-domain intelligence:**
- Connect insights across life domains (career + finance, relationships + health)
- The coach sees the whole picture and weaves connections the user hasn't made
- Reference per PRD Journey 2 (Marcus): "Nobody has given him this level of structured, confident, cross-domain thinking"

**What directive mode is NOT:**
- Not bossy or authoritarian — confident, not commanding
- Not generic advice — specific to the user's unique situation and context
- Not ignoring emotions — acknowledges feelings while providing direction
- Not abandoning discovery — uses understanding already built to inform advice

**Do not duplicate `base-persona.md` content.** The base persona section is always included in the assembled prompt and already covers empathy, warmth, cultural sensitivity, and the instruction to "make no assumptions about Western-centric defaults." The `mode-directive.md` section should focus exclusively on directive-specific behavior (confident action steps, contingency planning, cross-domain synthesis) without restating general coaching principles.

### Directive Ambient Color Guidance

Per UX-DR10 and architecture doc:
| Mode | Shift | Effect |
|------|-------|--------|
| Discovery | Slightly warmer, more golden | The space opens up — exploratory, inviting |
| Directive | Slightly cooler, more focused | The space sharpens — clarity, purpose |

**Color direction:** Shift conversation palette toward blue-green/steel tones (opposite of discovery's golden warmth).
- Light mode: Conversation base is `#F8F5EE`/`#F0ECE2` (warm beige). Suggested starting point: `#F2F5F8`/`#E8ECF0` (cool blue-gray). The shift should be the same subtle magnitude as discovery's warm shift (~6-8 hex units). These are suggested values — verify in #Preview that the result feels "cooler/more focused" before finalizing.
- Dark mode: Conversation base is `#1C1E18`/`#181A14` (warm dark). Suggested starting point: `#181C1E`/`#14181A` (cool dark). Same subtle 2-3 hex unit shift as discovery dark. Verify visually in #Preview.

**Safety always wins.** If safety override is active (Yellow/Orange/Red), coaching mode ambient shifts are suppressed. The `applyingAmbientMode` implementation should document this precedence rule (enforcement comes in Story 6.2).

### Project Structure Notes

- New file: `server/prompts/sections/mode-directive.md`
- Modified source files:
  - `server/prompts/builder.go` (add mode-directive.md to sections list, add directive case to Build switch)
  - `ios/sprinty/Core/Theme/CoachingTheme.swift` (replace directive stub with real implementation)
  - `ios/sprinty/Core/Theme/ColorPalette.swift` (add directive ambient mode shift methods)
- Modified test files:
  - `server/prompts/builder_test.go` (add mode-directive.md to setupTestSections, update section count 7→8, add directive mode tests)
  - `server/tests/handlers_test.go` (add mode-directive.md to both test helpers)
  - `ios/Tests/Theme/ThemeForTests.swift` (update directive test from stub→real, add dark mode + text color tests)
- No database migrations needed — `ConversationSession.mode` column already supports `.directive`
- No ViewModel changes needed — mode switching already generic
- No View changes needed — ambient mode application already generic
- No ChatEvent changes needed — mode field already in done event

### Testing Standards Summary

**Swift Tests (iOS):**
- Framework: Swift Testing (`@Test` macro)
- Naming: `test_methodName_condition_expectedResult`
- Mocking: Hand-written protocol mocks (e.g., `MockChatService`)
- Database: In-memory GRDB for tests
- Color comparison: Use `colorsMatch()` helper already in ThemeForTests.swift (line 103+) — handles floating point tolerance
- No SwiftUI view unit tests — use #Preview for visual verification

**Go Tests (Server):**
- Framework: `testing` std lib
- Naming: `TestHandlerName_Condition_Expected`
- HTTP testing: `httptest` package
- Co-located `_test.go` files
- Builder tests use `setupTestSections()` helper — creates temp dir with all section files

### Previous Story Intelligence

**From Story 2.1 (Discovery Mode Coaching):**
- Added `Mode` field to `ChatEvent` struct (Go), threaded through providers → done event → iOS
- `ChatEvent.done` is now a 6-tuple: `.done(safetyLevel:, domainTags:, mood:, mode:, usage:, promptVersion:)`
- Created `cultural.md` prompt section — added to builder, updated 3 Go test helpers. Follow same pattern for `mode-directive.md`.
- Implemented `applyingAmbientMode(.discovery)` — warm golden shift. Directive stub returns `self`. This is the stub to replace.
- `discoveryBackgroundColors(for:)` and `discoveryWarmShift(backgroundStart:backgroundEnd:)` in ColorPalette.swift — mirror this pattern exactly for directive.
- Key lesson: When adding a new section file to the builder, ALL Go test helpers must be updated simultaneously or all tests break.
- Test count after 2.1: 166 tests in 21 suites passing (Go: 3 packages, Swift: 166 tests)
- Dark mode ambient color shift is intentionally subtle (2-3 hex values) — within 0.01 tolerance in tests

**From Git History:**
- Commits follow pattern: `feat: Story X.Y — description`
- Most recent: `387b0e9 feat: Story 2.1 — Discovery mode coaching with ambient background shift`

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 2, Story 2.2, lines 769-788]
- [Source: _bmad-output/planning-artifacts/prd.md — FR4 (Directive Mode), FR8 (Contingency Plans), Directive Trust Gap]
- [Source: _bmad-output/planning-artifacts/architecture.md — System Prompt Configuration lines 666-683, Ambient Mode Shifts lines 639-643, mode-directive section at line 674]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Ambient Mode Shifts lines 929-940, Coach Expression States line 1033]
- [Source: server/prompts/builder.go — Mode switch at lines 72-85, section list at lines 26-34]
- [Source: server/prompts/sections/mode-discovery.md — Reference pattern for mode-directive.md]
- [Source: ios/sprinty/Core/Theme/CoachingTheme.swift — Directive stub at line 42]
- [Source: ios/sprinty/Core/Theme/ColorPalette.swift — Discovery shift pattern at lines 197-244]
- [Source: _bmad-output/implementation-artifacts/2-1-discovery-mode-coaching.md — Previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug issues encountered. All tests passed on first run.

### Completion Notes List

- Created `mode-directive.md` prompt section with coaching psychology guidance for confident directive behavior, contingency planning (Plan B + Plan C with switch conditions), and cross-domain synthesis. Does not duplicate base-persona.md content.
- Added `mode-directive.md` to builder section list (8 sections total) and updated all 3 Go test helpers to prevent regression.
- Added `case "directive":` to Build() switch — loads directive section, excludes discovery section. Default still falls back to discovery.
- Added `directiveBackgroundColors(for:)` and `directiveCoolShift(backgroundStart:backgroundEnd:)` to ColorPalette.swift mirroring discovery pattern. Light: `#F2F5F8`/`#E8ECF0` (cool blue-gray). Dark: `#181C1E`/`#14181A` (cool dark).
- Replaced directive stub in CoachingTheme.swift with real implementation calling directive color methods.
- Updated 1 existing Swift test (stub → real) and added 2 new Swift tests (dark mode, text color preservation). Total: 168 Swift tests in 21 suites passing.
- Added 2 new Go tests (TestBuilder_Build_DirectiveMode, TestBuilder_Build_DirectiveMode_ExcludesDiscovery). All Go tests passing across 3 packages.
- Removed "(Stub)" labels from directive #Preview blocks in CoachingView.swift.

### Change Log

- 2026-03-20: Story 2.2 implemented — directive mode prompt section, builder integration, ambient cool shift, tests

### File List

- `server/prompts/sections/mode-directive.md` (new)
- `server/prompts/builder.go` (modified — added mode-directive.md to section list, added directive case to Build switch)
- `server/prompts/builder_test.go` (modified — added mode-directive.md to setupTestSections, updated section count 7→8, added 2 directive mode tests)
- `server/tests/handlers_test.go` (modified — added mode-directive.md to both test helpers)
- `ios/sprinty/Core/Theme/ColorPalette.swift` (modified — added directive ambient mode shift extension)
- `ios/sprinty/Core/Theme/CoachingTheme.swift` (modified — replaced directive stub with real implementation)
- `ios/Tests/Theme/ThemeForTests.swift` (modified — replaced stub test, added dark mode and text color tests)
- `ios/sprinty/Features/Coaching/Views/CoachingView.swift` (modified — removed "(Stub)" from directive preview labels)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — updated last_updated, added story 2.2 dev comment, set status to review)
