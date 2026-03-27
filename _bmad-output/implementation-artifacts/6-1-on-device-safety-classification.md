# Story 6.1: On-Device Safety Classification

Status: done

## Story

As a user,
I want every coaching response to be safety-classified in real time,
So that the app can protect me if I'm in distress without sending my data to external systems.

## Acceptance Criteria (BDD)

1. **Given** the coach generates a response, **When** the SSE `event: done` is received, **Then** it includes a `safetyLevel` field: `green`, `yellow`, `orange`, or `red`. Primary classification is server-side (inline structured LLM output in the `done` event — already implemented). On-device classification is deferred to Phase 2 (Apple Foundation Models requires iOS 26+, project targets iOS 17+). Server classification is the sole classification source at MVP.

2. **Given** a `green` safety classification, **When** the response is rendered, **Then** normal coaching continues with no UI changes.

3. **Given** a `yellow` classification, **When** the response is rendered, **Then** the coaching tone becomes more attentive and careful, and the coach naturally suggests professional support as an option. Coach expression shifts to `.gentle`.

4. **Given** an `orange` classification, **When** the response is rendered, **Then** coaching pauses, gamification elements are hidden (sprint, celebrations), and a compassionate redirect with professional resources is presented. Coach expression shifts to `.gentle`.

5. **Given** a `red` classification, **When** the response is rendered, **Then** crisis protocol activates, emergency resources are prominently displayed, and all non-essential UI elements are removed. Coach expression shifts to `.gentle`.

6. **Given** safety classification operates identically across tiers (FR58), **When** a free or paid user triggers a safety boundary, **Then** the response is identical regardless of subscription tier.

7. **Given** on-device classification is unavailable at MVP, **When** the server returns no `safetyLevel` or parsing fails, **Then** the system fail-safes to `yellow` (not `green`) per UX-DR71.

## Tasks / Subtasks

- [x] **Task 1: Fix SafetyLevel enum — add `.orange` case** (AC: 1, 2, 3, 4, 5)
  - [x] 1.1 Add `.orange` case to the EXISTING `SafetyLevel` enum in `ios/sprinty/Models/ConversationSession.swift:14-18` — do NOT create a new file. Current enum has only `green`, `yellow`, `red`. Add `orange` between `yellow` and `red`
  - [x] 1.2 Make `SafetyLevel` conform to `Comparable` (ordered by severity: green < yellow < orange < red) — needed for "most cautious wins" reconciliation in future on-device classification
  - [x] 1.3 Add GRDB migration v12: `ALTER TABLE ConversationSession` — the column already exists as `.text` with default `"green"`, so no schema change needed. But verify the existing `SafetyLevel(rawValue:)` conversion handles `"orange"` now that the case exists
  - [x] 1.4 Fix `CheckInViewModel.swift:109` — currently checks `safetyLevel == "orange"` as raw string. After adding `.orange` to enum, this raw string comparison will work correctly with `SafetyLevel(rawValue:)`, but verify the code path
  - [x] 1.5 Create `SafetyUIState` struct in `ios/sprinty/Models/SafetyUIState.swift` — `level: SafetyLevel`, `hiddenElements: Set<HiddenElement>`, `coachExpression: CoachExpression`, `notificationBehavior: NotificationBehavior`, `showCrisisResources: Bool`
  - [x] 1.6 Create `HiddenElement` enum: `.gamification`, `.sprintProgress`, `.avatarActivity`, `.celebrations`
  - [x] 1.7 Create `NotificationBehavior` enum: `.normal`, `.safetyOnly`, `.suppressed`

- [x] **Task 2: Verify server-side safety pipeline (already implemented)** (AC: 1, 6)
  - [x] 2.1 VERIFY (do not recreate) `server/prompts/sections/safety.md` exists with green/yellow/orange/red classification instructions — it already has full content
  - [x] 2.2 VERIFY `safety` section is in the always-included list in `builder.go` Build() — confirmed at line 138: `[]string{"safety", "mood", "tagging", "cultural", "mode-transitions", "challenger"}`
  - [x] 2.3 VERIFY `safetyLevel` is a required enum field in Anthropic tool schema (`anthropic.go:24-28`) with values `["green", "yellow", "orange", "red"]`
  - [x] 2.4 VERIFY `parseFinalResult()` extracts `safetyLevel` with `"green"` default fallback (`anthropic.go:407-425`)
  - [x] 2.5 VERIFY done event sends `safetyLevel` as first field (`chat.go:107-108`)
  - [x] 2.6 VERIFY safety is tier-agnostic — `safety` section included in always-included list (not filtered by tier)
  - [x] 2.7 VERIFY `api-contract.md` documents `safetyLevel` in SSE done event (lines 219-223)
  - [x] 2.8 Review `safety.md` prompt content quality — consider if classification instructions need more specificity for distinguishing yellow vs orange vs red (current content is brief)

- [x] **Task 3: SafetyHandler service** (AC: 1, 2, 3, 4, 5, 7)
  - [x] 3.1 Create `SafetyHandlerProtocol` in `ios/sprinty/Services/Safety/SafetyHandlerProtocol.swift` — `func classify(serverLevel: SafetyLevel?) -> SafetyLevel` (MVP: server-only, no on-device parameter), `func uiState(for level: SafetyLevel) -> SafetyUIState`
  - [x] 3.2 Create `SafetyHandler` in `ios/sprinty/Services/Safety/SafetyHandler.swift` — MVP implementation: pass through server level, fail-safe to `.yellow` when nil/missing (UX-DR71)
  - [x] 3.3 Implement `uiState(for:)` mapping with `SafetyThemeOverride` bridge:
    - Green → `.none` override, no hidden elements, `.welcoming` expression, `.normal` notifications, no crisis resources
    - Yellow → `.warmthIncrease` override, no hidden elements, `.gentle` expression, `.normal` notifications, no crisis resources
    - Orange → `.noticeableDesaturation` override, hide `.gamification`, `.celebrations`, `.sprintProgress`; `.gentle` expression; `.safetyOnly` notifications; show crisis resources
    - Red → `.significantDesaturation` override, hide ALL non-essential; `.gentle` expression; `.suppressed` notifications; show crisis resources prominently
  - [x] 3.4 Wire `SafetyHandler` creation in `RootView.swift` DI container, inject via protocol into CoachingViewModel

- [x] **Task 4: Integration with CoachingViewModel** (AC: 1, 2, 3, 4, 5)
  - [x] 4.1 Add `safetyHandler: SafetyHandlerProtocol` dependency to `CoachingViewModel`
  - [x] 4.2 On `done` event received: the existing code at `CoachingViewModel.swift:251-252` already converts `safetyLevel` String → `SafetyLevel` enum via `SafetyLevel(rawValue:)`. Extend this to call `safetyHandler.classify(serverLevel:)` for fail-safe handling
  - [x] 4.3 Add `currentSafetyUIState: SafetyUIState` published property to `CoachingViewModel` — computed from `safetyHandler.uiState(for:)` after each classification
  - [x] 4.4 Store `safetyLevel` on `ConversationSession` — code already exists at `CoachingViewModel.swift:559-571` via `updateSessionSafetyLevel()`. Verify it handles `.orange` correctly now
  - [x] 4.5 Set `CoachExpression` to `.gentle` when safety level is yellow or above — `.gentle` already exists at `CoachExpression.swift:8`

- [x] **Task 5: Safety-responsive UI in CoachingView** (AC: 2, 3, 4, 5)
  - [x] 5.1 Fix `CoachingView.swift:9` — currently hardcodes `safetyLevel: .none`. Wire to actual `viewModel.currentSafetyUIState.level` for theme construction. Map `SafetyLevel` → `SafetyThemeOverride` (existing enum in `CoachingTheme.swift:12-17`)
  - [x] 5.2 Create `ProfessionalResourcesView` in `ios/sprinty/Features/Coaching/Views/ProfessionalResourcesView.swift` — displays crisis text line (741741), 988 Suicide & Crisis Lifeline, therapist finder link. Calm, clear, compassionate presentation. No gamification framing
  - [x] 5.3 Add `ProfessionalResource` model with `name`, `description`, `contactMethod` (phone/text/url), `value` — hardcoded resource list (not server-dependent, must work offline)
  - [x] 5.4 Conditionally hide gamification elements (sprint progress, celebrations) in CoachingView based on `SafetyUIState.hiddenElements`
  - [x] 5.5 Show `ProfessionalResourcesView` inline when safety level is orange or red
  - [x] 5.6 For red: show emergency resources prominently at top of view, remove all non-essential UI elements
  - [x] 5.7 Accessibility: VoiceOver announcements per safety level change — Yellow: "Coach is being more attentive", Orange: "Connecting you with resources", Red: "Safety resources available"
  - [x] 5.8 All safety transitions are immediate (0.0s, no animation per UX-DR74) — use `.animation(nil)` or `withAnimation(nil)` for safety state changes

- [x] **Task 6: Tests** (AC: all)
  - [x] 6.1 `SafetyHandlerTests.swift` in `ios/Tests/Services/` — test classify() fail-safe logic (nil server level → yellow), test uiState mapping for each of the 4 levels, test SafetyThemeOverride mapping
  - [x] 6.2 `SafetyLevelTests.swift` in `ios/Tests/Models/` — test Comparable ordering (green < yellow < orange < red), Codable roundtrip for all 4 values including orange, DatabaseValueConvertible roundtrip
  - [x] 6.3 `CoachingViewModelSafetyTests.swift` in `ios/Tests/Features/` — test done event triggers classification, currentSafetyUIState updated correctly, CoachExpression set to .gentle on yellow+, session safety level persisted to DB
  - [x] 6.4 `MockSafetyHandler.swift` in `ios/Tests/Mocks/` — `final class MockSafetyHandler: SafetyHandlerProtocol, @unchecked Sendable` with recorded args and stub injection
  - [x] 6.5 Go tests: VERIFY existing test coverage — `safety.md` stub in `setupMux` (handlers_test.go:38), safetyLevel in done event fixture (handlers_test.go:462, 530-531), parseFinalResult fallback (anthropic_test.go:401). No new Go tests needed unless safety.md content is modified in Task 2.8
  - [x] 6.6 Test files auto-discovered by `project.yml` (test target uses `path: Tests`) — no manual addition needed

## Dev Notes

### Architecture Decisions

- **Server-side classification pipeline is fully implemented** — the complete 7-step chain already works: (1) Anthropic tool schema (anthropic.go:24-28) → (2) toolResult struct (anthropic.go:133) → (3) parseFinalResult() (anthropic.go:407-425) → (4) ChatEvent Go (provider.go:82) → (5) SSE done event data (chat.go:107-108) → (6) ChatEvent iOS (ChatEvent.swift:6) → (7) api-contract.md (line 223). Do NOT recreate any of this
- **On-device classification deferred to Phase 2** — Apple Foundation Models requires iOS 26+ (`FoundationModels` framework, WWDC25). Project targets iOS 17+. Architecture says "MVP uses single-path inline classification" with regression suite as compensating control. On-device classification adds no value until iOS 26+ is the minimum target or a Create ML model is trained. The `SafetyHandlerProtocol` is designed to accept future on-device input without refactoring
- **"Most cautious wins" reconciliation** — implement `Comparable` on `SafetyLevel` now (green < yellow < orange < red) so future on-device integration is trivial: `max(serverLevel, onDeviceLevel)`
- **Safety is NOT a coaching mode** — it's an overlay/override that affects ALL modes. Safety always wins over coaching mode ambient shifts (UX-DR94)

### Critical Constraints

- **Safety classification must be tier-agnostic** (FR58) — server already includes `safety` section for all tiers (confirmed in always-included list). Do NOT add tier-based filtering
- **Server is stateless** — all safety state lives on iOS. Server classifies and returns. No server-side safety state tracking
- **Safety levels are load-bearing** — they drive UI state, notification suppression, compliance logging (Story 6.4), and theme changes (Story 6.2). This story establishes the foundation
- **No new API endpoints** — safety flows through existing `/v1/chat` endpoint
- **No centralized AppState type exists** — safety state is per-session, stored on `ConversationSession` in GRDB. The `currentSafetyUIState` property lives on `CoachingViewModel`, scoped to the active coaching session

### What Already Exists (DO NOT recreate)

- **`SafetyLevel` enum** — exists at `ConversationSession.swift:14-18` with `green`, `yellow`, `red`. ADD `.orange` case, do not create a new file
- **`SafetyThemeOverride` enum** — exists at `CoachingTheme.swift:12-17` with all four levels (`.none`, `.warmthIncrease`, `.noticeableDesaturation`, `.significantDesaturation`). Method `applying(safetyOverride:)` is a stub returning `self` — Story 6.2 fills it in
- **`ChatEvent.done`** — already carries `safetyLevel` as `String` (ChatEvent.swift:6). Conversion to `SafetyLevel` enum already happens at `CoachingViewModel.swift:251-252`
- **`ConversationSession.safetyLevel`** — already a `SafetyLevel` typed property (ConversationSession.swift:31). Column exists since v1 migration with default `"green"`
- **`CoachExpression.gentle`** — already exists at CoachExpression.swift:8. Use for Yellow+ safety states
- **`updateSessionSafetyLevel()`** — already implemented at CoachingViewModel.swift:559-571
- **Server safety pipeline** — fully wired: prompt section, tool schema, parsing, done event, API contract, tests. See Task 2 for verification checklist
- **Go test coverage** — safety field tested in handler tests (done event fixture), provider tests (parseFinalResult fallback), and streaming tests

### What This Story Does NOT Cover (Scope Boundaries)

- **Theme transformation implementation** (saturation/warmth actual color shifts) → Story 6.2 fills in the `applying(safetyOverride:)` stub
- **Sticky minimum** (Orange/Red holds for 3 turns or Green×2 consecutive) → Story 6.2
- **Post-crisis re-engagement** → Story 6.3
- **Compliance logging** → Story 6.4
- **Safety regression test suite (50+ prompts)** → Story 6.5
- **Notification suppression wiring** → Set `notificationBehavior` on `SafetyUIState`, but don't wire into `CheckInNotificationService` (future integration)

### Project Structure Notes

New files follow established patterns:
```
ios/sprinty/
├── Models/
│   └── SafetyUIState.swift         # SafetyUIState, HiddenElement, NotificationBehavior
├── Services/
│   └── Safety/                     # NEW directory
│       ├── SafetyHandlerProtocol.swift
│       └── SafetyHandler.swift
├── Features/
│   └── Coaching/
│       └── Views/
│           └── ProfessionalResourcesView.swift

ios/Tests/
├── Models/
│   └── SafetyLevelTests.swift
├── Services/
│   └── SafetyHandlerTests.swift
├── Features/
│   └── CoachingViewModelSafetyTests.swift
├── Mocks/
│   └── MockSafetyHandler.swift
```

Note: No on-device classifier files at MVP. `OnDeviceClassifierProtocol` and `OnDeviceClassifier` are Phase 2 when iOS 26+ is targeted.

### Previous Story Intelligence (from Story 5.4)

- **Migration pattern:** Append-only, sequential. Last migration was v11. Use v12 if schema change needed (likely not — safetyLevel column exists since v1, just needs enum to include orange)
- **GRDB model conformance:** `Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable` (all five required)
- **ViewModel pattern:** `@MainActor @Observable final class`, protocol-based dependencies, no Combine
- **Testing:** Swift Testing (`@Test`, `#expect`), in-memory GRDB (`DatabaseQueue()`) for DB tests, protocol-based mocking
- **DI:** All services created in `RootView.swift`, injected via protocols
- **Code review finding pattern:** Dead code (unwired services), missing deep-links, missing state change handlers. Wire everything end-to-end — don't leave SafetyHandler disconnected from CoachingViewModel or CoachingView hardcoded to `.none`

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 6, Story 6.1]
- [Source: _bmad-output/planning-artifacts/architecture.md — Safety classification pipeline, SafetyUIState, Cross-cutting concerns Tier 1]
- [Source: _bmad-output/planning-artifacts/prd.md — Journey 6: Clinical Boundary Escalation, AI Safety as Domain Constraint]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Safety Palette Overrides, Journey 5: Mid-Conversation Safety Boundary, Component Strategy SafetyStateManager]
- [Source: _bmad-output/project-context.md — Safety levels are load-bearing, prompt assembly order, 7-step chain for new fields]
- [Source: ios/sprinty/Models/ConversationSession.swift:14-18 — existing SafetyLevel enum (missing .orange)]
- [Source: ios/sprinty/Core/Theme/CoachingTheme.swift:12-17 — existing SafetyThemeOverride enum]
- [Source: ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift:251-252 — existing safetyLevel conversion]
- [Source: server/providers/anthropic.go:24-28 — existing tool schema with safetyLevel]
- [Source: server/handlers/chat.go:107-108 — existing done event with safetyLevel]
- [FR58: Safety classification identical across tiers]
- [UX-DR71: Failsafe to yellow on classification failure]
- [UX-DR74: Safety transitions immediate (0.0s) — for Story 6.2]
- [UX-DR94: Safety overrides all other visual states]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Build error: `RadiusTokens` has no `card` member, `ColorPalette` has no `cardBackground` → fixed to use `container` and `insightBackground`
- No migration v12 needed — `safetyLevel` column exists since v1 as `.text` with default `"green"`, adding `.orange` enum case is sufficient

### Completion Notes List
- Task 1: Added `.orange` case to `SafetyLevel` enum, made it `Comparable` (green < yellow < orange < red). Created `SafetyUIState`, `HiddenElement`, `NotificationBehavior` types. Verified existing DB column and CheckInViewModel code paths work with orange.
- Task 2: Verified complete server-side safety pipeline — safety.md prompt, Anthropic tool schema with 4 enum values, parseFinalResult with green fallback, done event payload, API contract docs, tier-agnostic inclusion, and existing Go test coverage. All confirmed intact.
- Task 3: Created `SafetyHandlerProtocol` and `SafetyHandler` with classify() fail-safe (nil → yellow per UX-DR71) and uiState() mapping for all 4 levels. Wired into RootView DI.
- Task 4: Integrated SafetyHandler into CoachingViewModel — done event now runs through classify() → uiState() pipeline, updates `currentSafetyUIState`, persists to DB, and overrides coach expression to `.gentle` for yellow+.
- Task 5: Wired actual safety level to theme construction (replacing hardcoded `.none`). Created ProfessionalResourcesView with 988 Lifeline, Crisis Text Line (741741), and therapist finder. Conditionally hides gamification at orange+, shows crisis resources inline at orange/red, prominently at top for red. Added VoiceOver announcements and immediate (nil animation) safety transitions.
- Task 6: 20 new tests across 3 suites (SafetyLevelTests, SafetyHandlerTests, CoachingViewModelSafetyTests) + MockSafetyHandler. Full regression suite: 535 tests, 53 suites, all passing. Go tests verified passing.

### Change Log
- 2026-03-27: Story 6.1 implemented — on-device safety classification foundation with server-side pipeline verification, SafetyHandler service, CoachingViewModel integration, safety-responsive UI, and comprehensive test coverage
- 2026-03-27: Code review fixes — (M1) Added project.pbxproj to File List, (M2) CoachCharacterView now hidden when .avatarActivity in hiddenElements (red level), (L1) Removed unreliable &body= param from SMS URL scheme

### File List
- ios/sprinty/Models/ConversationSession.swift (modified — added .orange case, Comparable conformance)
- ios/sprinty/Models/SafetyUIState.swift (new — SafetyUIState, HiddenElement, NotificationBehavior)
- ios/sprinty/Services/Safety/SafetyHandlerProtocol.swift (new)
- ios/sprinty/Services/Safety/SafetyHandler.swift (new)
- ios/sprinty/Features/Coaching/Views/ProfessionalResourcesView.swift (new — ProfessionalResource, ProfessionalResourcesView)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified — safetyHandler DI, currentSafetyUIState, classify/uiState pipeline, gentle expression override)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified — safety theme override, crisis resources, gamification hiding, VoiceOver, nil animation)
- ios/sprinty/App/RootView.swift (modified — SafetyHandler DI wiring)
- ios/Tests/Models/SafetyLevelTests.swift (new)
- ios/Tests/Services/SafetyHandlerTests.swift (new)
- ios/Tests/Features/CoachingViewModelSafetyTests.swift (new)
- ios/Tests/Mocks/MockSafetyHandler.swift (new)
- ios/sprinty.xcodeproj/project.pbxproj (modified — new source files added to project)
