# Story 1.3: Design System & Coaching Theme

Status: done

## Story

As a user,
I want the app to have a warm, inviting visual identity that feels like a safe coaching space,
So that the experience feels personal and calming, not like a generic tech app.

## Acceptance Criteria

1. **AC1 — Color tokens resolve for light and dark mode**
   Given the CoachingTheme is implemented,
   When applied to any view,
   Then all color tokens resolve correctly for both light and dark mode.

2. **AC2 — Home Light palette**
   Given Home Light palette,
   Then warm restful tones are used (#F4F2EC-#EDE8E0 gradient background).

3. **AC3 — Home Dark palette**
   Given Home Dark palette,
   Then warm dark tones are used (#181A16-#141612, never cold/technical).

4. **AC4 — Conversation Light palette**
   Given Conversation Light palette,
   Then tones are #F8F5EE-#F0ECE2.

5. **AC5 — Conversation Dark palette**
   Given Conversation Dark palette,
   Then tones are #1C1E18-#181A14 with coach dialogue in warm off-white #C4C4B4 (never pure white #FFFFFF).

6. **AC6 — Dynamic Type support**
   Given Dynamic Type is enabled at any size (xSmall through Accessibility XXXL),
   When text renders using theme typography tokens,
   Then all 12 semantic text styles use iOS semantic sizes (Body, Subheadline, Footnote, Caption, Title),
   And line height of 1.65 is maintained on dialogue text,
   And no fixed font sizes are used anywhere.

7. **AC7 — Spacing scale on all devices**
   Given the spacing scale is implemented,
   When layout renders on iPhone SE (375pt) through Pro Max (430pt),
   Then screen margins are 20pt (16pt on SE), content flows naturally,
   And Pro Max content column is capped at 390pt centered.

8. **AC8 — UI copy word blacklist**
   Given the UI copy standards (UX-DR79, UX-DR80),
   When any UI text is written,
   Then the word blacklist is enforced: never use "user," "session," "data," "error," "failed," "invalid," "submit," "retry," "loading," "processing," "notification," "sync," "cache," "timeout," "cancel",
   And all copy speaks as the coach — warm, specific, human tone including settings labels and error messages.

9. **AC9 — Accessibility contrast compliance**
   Given any color token pair (text/background or UI element/background),
   When rendered in any palette (all 4) in any mode,
   Then text meets WCAG AA (4.5:1 body, 3:1 large text),
   And non-text UI elements (send button, user accent border, sprint bar) meet 3:1 contrast ratio,
   And all interactive elements have a minimum touch target of 44pt.

## Tasks / Subtasks

- [x] **Task 1: CoachingTheme and supporting enums** (AC: 1)
  - [x] Create `Core/Theme/CoachingTheme.swift`:
    - `struct CoachingTheme: Sendable` with `let palette: ColorPalette`, `let typography: TypographyScale`, `let spacing: SpacingScale`, `let cornerRadius: RadiusTokens`
    - `func applying(safetyOverride: SafetyThemeOverride) -> CoachingTheme` stub (returns self — Story 6.2 fills in)
    - `func applyingPauseMode() -> CoachingTheme` stub (returns self — Story 7.1 fills in)
    - `func applyingAmbientMode(_ mode: CoachingMode) -> CoachingTheme` stub (returns self — Story 2.x fills in)
    - Custom `EnvironmentKey` + `EnvironmentValues` extension for `\.coachingTheme`
  - [x] Define `SafetyThemeOverride` enum in same file:
    ```swift
    enum SafetyThemeOverride: Sendable {
        case none                    // Green
        case warmthIncrease          // Yellow
        case noticeableDesaturation  // Orange
        case significantDesaturation // Red
    }
    ```
  - [x] Create `themeFor(context:safetyLevel:isPaused:)` function (or static method) that selects the correct palette based on `ExperienceContext` and `ColorScheme`:
    - Home context + light → `homeLight` palette
    - Home context + dark → `homeDark` palette
    - Conversation context + light → `conversationLight` palette
    - Conversation context + dark → `conversationDark` palette
    - Safety/pause overrides return self for now (stubs)
  - [x] Inject theme at App root in `AILifeCoachApp.swift` via `.environment(\.coachingTheme, themeFor(...))`

- [x] **Task 2: ColorPalette with four theme instances** (AC: 1, 2, 3, 4, 5, 9)
  - [x] Create `Core/Theme/ColorPalette.swift` with all semantic color tokens as `let` properties
  - [x] Define `homeLight`, `homeDark`, `conversationLight`, `conversationDark` static instances
  - [x] Add asset catalog color sets in `Resources/Assets.xcassets/Colors/` — each semantic color needs its own `.colorset` folder with a `Contents.json` specifying light/dark hex values (Story 1.2 build failed from missing asset catalog entries — ensure ALL referenced color sets exist before building)
  - [x] Home Light tokens: `homeBackground` (#F4F2EC→#EDE8E0), `homeTextPrimary` (#3A3A30), `homeTextSecondary` (#8B8B78), `avatarGlow` (#8B9B7A@30%), `avatarGradient` (#C4D4B0→#8B9B7A), `insightBackground` (rgba(139,155,122,0.10)), `sprintTrack` (rgba(139,155,122,0.12)), `sprintProgress` (#8B9B7A→#7A8B6B), `primaryAction` (#7A8B6B→#6B7A5A), `primaryActionText` (#FFFFFF)
  - [x] Home Dark tokens: `homeBackground` (#181A16→#141612), `homeTextPrimary` (#D8D8C8), `homeTextSecondary` (#6B7A5A), `avatarGlow` (#8B9B7A@20%), `avatarGradient` (#2A3020→#3A4830), `insightBackground` (rgba(139,155,122,0.06)), `sprintTrack` (rgba(139,155,122,0.08)), `sprintProgress` (#8B9B7A→#7A8B6B), `primaryAction` (#4A5A3A→#3E4E30), `primaryActionText` (#D0D8C0)
  - [x] Conversation Light tokens: `coachingBackground` (#F8F5EE→#F0ECE2), `coachDialogue` (#3A3A30), `userDialogue` (#4A4A3C), `userAccent` (#8B9B7A), `coachPortraitGradient` (#B8C8A0→#8B9B7A), `coachPortraitGlow` (rgba(139,155,122,0.25)), `coachNameText` (#3A3A30), `coachStatusText` (#8B8B78), `dateSeparator` (rgba(58,58,48,0.35)), `inputBorder` (rgba(120,130,100,0.20)), `sendButton` (#7A8B6B)
  - [x] Conversation Dark tokens: `coachingBackground` (#1C1E18→#181A14), `coachDialogue` (#C4C4B4 — never pure white), `userDialogue` (#B0B0A0), `userAccent` (rgba(139,155,122,0.30)), `coachPortraitGradient` (#3A4830→#5A6B48), `coachPortraitGlow` (rgba(139,155,122,0.10)), `coachNameText` (#D0D0C0), `coachStatusText` (#6B7A5A), `dateSeparator` (rgba(208,208,192,0.35)), `inputBorder` (rgba(120,130,100,0.12)), `sendButton` (#4A5A3A)
  - [x] Verify WCAG AA contrast: 4.5:1 for body text/background, 3:1 for large text, 3:1 for non-text UI elements (sendButton, userAccent, sprintProgress against their backgrounds)
  - [x] Verify color distinguishability under deuteranopia, protanopia, and tritanopia simulation (Xcode Accessibility Inspector or Sim Daltonism)

- [x] **Task 3: TypographyScale with 12 semantic text styles** (AC: 6)
  - [x] Create `Core/Theme/TypographyScale.swift` as `struct TypographyScale: Sendable`
  - [x] Define all 12 tokens using iOS semantic sizes — NEVER fixed pt values:
    - `coachVoice`: `.body`, Regular, lineSpacing for 1.65 line height
    - `userVoice`: `.body`, Regular, lineSpacing for 1.65 line height
    - `coachVoiceEmphasis`: `.body`, Semibold, lineSpacing for 1.65 line height
    - `insightText`: `.subheadline`, Regular, 1.5 line height
    - `sprintLabel`: `.footnote`, Medium, 1.4 line height
    - `coachName`: `.footnote`, Semibold, 1.3 line height
    - `coachStatus`: `.caption2`, Regular, 1.3 line height
    - `dateSeparator`: `.caption2`, Regular, 1.3 line height
    - `homeGreeting`: `.caption`, Regular, 1.4 line height — NOTE: iOS `.caption` is 12pt at default, UX spec says 14pt. Use `.caption` (semantic name is the contract) and verify on-device
    - `homeTitle`: `.title3`, Semibold, 1.3 line height
    - `sectionHeading`: `.title3`, Semibold, 1.3 line height
    - `primaryButton`: `.callout`, Semibold, 1.0 line height
  - [x] Implement as `View` extension modifiers (e.g., `.coachVoiceStyle()`) that apply font + lineSpacing together — prevents forgetting one
  - [x] Verify all styles scale with Dynamic Type (xSmall through AX-XXXL)

- [x] **Task 4: SpacingScale and RadiusTokens** (AC: 7, 9)
  - [x] Create `Core/Theme/SpacingScale.swift` as `struct SpacingScale: Sendable` on 8pt grid (9 tokens):
    - `screenMargin`: 20pt (16pt when screen width <= 375pt)
    - `dialogueTurn`: 24pt
    - `dialogueBreath`: 8pt
    - `homeElement`: 16pt
    - `insightPadding`: 16pt
    - `coachCharacterBottom`: 16pt
    - `inputAreaTop`: 12pt
    - `sectionGap`: 32pt
    - `minTouchTarget`: 44pt — minimum size for all interactive elements per accessibility requirements
  - [x] SE detection: use `GeometryReader` to read width — do NOT use `UIScreen.main.bounds` (that's UIKit). `SpacingScale` takes a `screenWidth` parameter, returns 16pt margin when `width <= 375`
  - [x] Create `Core/Theme/RadiusTokens.swift` as `struct RadiusTokens: Sendable`:
    - `container`: 16pt
    - `button`: 16pt
    - `input`: 20pt (pill shape)
    - `avatar`: circle (use `.clipShape(Circle())`)
    - `small`: 8pt
    - `sprintTrack`: 3pt
  - [x] Add Pro Max content column cap: 390pt centered via `frame(maxWidth: 390)` in a reusable layout modifier

- [x] **Task 5: Theme-aware preview helpers** (AC: 1)
  - [x] Create `Preview Content/ThemePreview.swift` — wrap ALL content in `#if DEBUG` to prevent shipping in production builds (xcodegen source glob includes Preview Content in the main target)
  - [x] Helper that renders any view in all 4 palettes (Home Light/Dark, Conversation Light/Dark)
  - [x] `ThemeShowcaseView` preview showing color swatches, typography samples, and spacing examples — for visual QA only

- [x] **Task 6: UI copy standards enforcement** (AC: 8)
  - [x] Create `Core/Utilities/CopyStandards.swift` with static blacklist array and `assertCopyCompliance(_ text: String)` debug-only assertion
  - [x] Blacklisted words: "user", "session", "data", "error", "failed", "invalid", "submit", "retry", "loading", "processing", "notification", "sync", "cache", "timeout", "cancel"
  - [x] Wire assertion into DEBUG builds only (`#if DEBUG`)

- [x] **Task 7: Unit tests** (AC: 1, 2, 3, 4, 5, 6, 7, 8, 9)
  - [x] `Tests/Theme/ColorPaletteTests.swift` — verify all 4 palette instances have non-nil values for every token; verify dark conversation `coachDialogue` is NOT pure white (#FFFFFF); verify non-text contrast ratios programmatically where feasible
  - [x] `Tests/Theme/TypographyScaleTests.swift` — verify all 12 tokens produce valid Font values; verify coachVoice/userVoice have 1.65 line height applied
  - [x] `Tests/Theme/SpacingScaleTests.swift` — verify all 9 spacing values match spec; verify SE margin is 16pt when width <= 375; verify minTouchTarget is 44pt
  - [x] `Tests/Theme/CopyStandardsTests.swift` — verify blacklist catches each forbidden word; verify clean copy passes
  - [x] `Tests/Theme/ThemeForTests.swift` — verify `themeFor()` returns correct palette for each context + color scheme combination
  - [x] All tests use Swift Testing (`@Test` macro), NOT XCTest. Use `@testable import ai_life_coach` to access internal types.

## Dev Notes

### Architecture Compliance

- **Location:** All theme files go under `ios/ai_life_coach/Core/Theme/`
- **CoachingTheme is a `struct`, not a class** — it holds immutable design tokens (`let` properties), not mutable state. A struct is `Sendable` by default, avoids the `@Observable` + `Sendable` conflict under Swift 6 strict concurrency, and works naturally with SwiftUI environment
- **Environment injection:** Use custom `EnvironmentKey` pattern (`\.coachingTheme`) — NOT the iOS 17+ `@Environment(Type.self)` pattern used for AppState. Rationale: theme selection depends on context (home vs. conversation) and color scheme, so different views may receive different theme instances. AppState is a single shared instance; theme is not
- **Palette selection is a view-level concern.** Each screen (HomeView, CoachingView) picks its palette via `themeFor()` and injects it for its subtree. AppState does NOT own the theme — it provides the `experienceContext` that informs palette selection
- **No singletons. No hardcoded colors, font sizes, or spacing values in any view code.** Views reference only semantic tokens from CoachingTheme. This is the governance rule for every future story
- **Access control:** `internal` (default) for all types. `private` for implementation details

### Color Implementation Strategy

- Use `Assets.xcassets/Colors/` color sets for semantic colors — native light/dark support via asset catalog
- Each color set requires its own `.colorset` folder containing a `Contents.json` with `appearances` array specifying `Any` and `Dark` variants. Structure:
  ```
  Colors/
    HomeBackground.colorset/
      Contents.json  ← specifies light (#F4F2EC) and dark (#181A16) hex values
    HomeTextPrimary.colorset/
      Contents.json
    ...
  ```
- Gradient backgrounds (homeBackground, coachingBackground, etc.): define TWO color sets per gradient (start + end), use `LinearGradient` in code
- Opacity colors (avatarGlow, insightBackground, etc.): define base color in asset catalog, apply `.opacity()` modifier in code
- **All hex values are design intent** — tune on-device. Semantic token names are the contract

### Dark Mode Design Principle

Dark mode is not a color inversion — it's an emotional variant. Every dark palette value should pass this test: "Would this feel right for someone opening the app at 11pm after a hard day, looking for their coach?"

- **Home Dark:** Reduced contrast between elements — everything settles down for evening. Avatar is the most alive element, with subtle luminance like a nightlight
- **Conversation Dark:** Slightly warmer and brighter than home dark — "walking from a dim hallway into a room where someone left a lamp on for you"
- Coach dialogue uses warm off-white (#C4C4B4), never pure white — pure white on dark backgrounds feels harsh and clinical

### Typography Implementation

- SwiftUI's `.font(.body)` already scales with Dynamic Type — this is the foundation
- Line height: `.lineSpacing()` adds fixed spacing. For 1.65x on Body at default size (17pt): `17 * 0.65 = 11.05` → use `.lineSpacing(11)`. Known limitation: `.lineSpacing()` doesn't scale with Dynamic Type — the ratio is approximate at non-default sizes. This is an iOS constraint; accept it
- Weight creates emphasis, not size — Semibold on key phrases like vocal emphasis in speech. Never increase size for emphasis
- Create `View` extension modifiers like `.coachVoiceStyle()` that apply both `.font()` and `.lineSpacing()` — prevents forgetting one
- Never use `.font(.system(size: N))` — this breaks Dynamic Type

### Spacing — SE Detection

- Use `GeometryReader` to detect width — do NOT use `UIScreen.main.bounds` (that's UIKit, not SwiftUI)
- `SpacingScale` takes a `screenWidth` parameter, returns 16pt margin when `width <= 375`
- Pro Max (430pt): content column capped at 390pt centered. The earthy background fills remaining width

### Accessibility Requirements

- All interactive elements: minimum 44pt touch target (enforced via `minTouchTarget` spacing token)
- Non-text UI elements (sendButton, userAccent border, sprintProgress bar) must meet 3:1 contrast ratio against their backgrounds — verify alongside text contrast
- Test all 4 palettes under color blindness simulation (deuteranopia, protanopia, tritanopia) using Xcode Accessibility Inspector
- Reduced motion: this story has no animations, but future stories using these tokens will need `@Environment(\.accessibilityReduceMotion)`. No action needed here — just awareness

### What NOT To Build in This Story

- Safety theme transformations — `applying(safetyOverride:)` is a stub returning self (Story 6.2)
- Pause mode desaturation — `applyingPauseMode()` is a stub returning self (Story 7.1). Eventually: light mode = desaturated home palette with avatar retaining color; dark mode = near-monochrome with avatar as only colored element ("everything has gone to sleep")
- Ambient mode shifts — `applyingAmbientMode(_:)` is a stub returning self (Story 2.x). Eventually: Discovery = warmer/golden, Directive = cooler/focused, Challenger = deeper/grounded
- Coach character or avatar views (Story 1.4, 1.5, 4.x) — coach portrait is 100pt default, 80pt at Accessibility XL+
- Lottie animations (Story 4.x)
- Any actual UI screens — this story is tokens/infrastructure only

### Previous Story Intelligence (Story 1.2)

**Patterns established that MUST be followed:**
- Swift 6 strict concurrency with zero warnings
- `@Observable` for state management (not Combine, not ObservableObject) — but CoachingTheme is a struct, so `@Observable` does not apply here
- Protocol-based design for testability
- Tests use Swift Testing (`@Test` macro), not XCTest
- xcodegen `project.yml` generates the Xcode project — new files in `Core/Theme/` are under the main target's source glob and will be auto-discovered

**Problems from Story 1.2 to avoid:**
- Build failed from missing asset catalog entries — ensure ALL `.colorset` folders exist with valid `Contents.json` before building
- Entitlements overwritten by xcodegen — don't modify entitlements in this story

**Files from 1.2 to modify:**
- `ios/ai_life_coach/App/AILifeCoachApp.swift` — add `.environment(\.coachingTheme, themeFor(...))` injection

### Git Intelligence

Recent commits:
- `37feade` feat: Story 1.2 — iOS project foundation & database
- `267d23a` feat: Story 1.1 — Server scaffold & auth endpoints

Commit convention: `feat: Story X.Y — description`

### Project Structure Notes

New files to create (all under `ios/ai_life_coach/`):

```
Core/Theme/
  CoachingTheme.swift          # Theme struct + environment key + SafetyThemeOverride enum + themeFor()
  ColorPalette.swift           # Four palette instances with all color tokens
  TypographyScale.swift        # 12 semantic text styles as View modifiers
  SpacingScale.swift           # 9 spacing tokens on 8pt grid
  RadiusTokens.swift           # Corner radius tokens

Core/Utilities/
  CopyStandards.swift          # UI copy blacklist enforcement (DEBUG only)

Resources/Assets.xcassets/Colors/
  HomeBackgroundStart.colorset/    # Each with Contents.json for light/dark
  HomeBackgroundEnd.colorset/
  HomeTextPrimary.colorset/
  ... (one .colorset per semantic color)

Preview Content/
  ThemePreview.swift           # #if DEBUG — preview helpers for 4-palette rendering

Tests/Theme/
  ColorPaletteTests.swift
  TypographyScaleTests.swift
  SpacingScaleTests.swift
  CopyStandardsTests.swift
  ThemeForTests.swift
```

### References

- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Color System, Typography System, Spacing & Layout Foundation, Dark Mode Principle, Accessibility Requirements]
- [Source: _bmad-output/planning-artifacts/architecture.md — Core/Theme structure, CoachingTheme class, SafetyThemeOverride enum, themeFor() injection, accessibility patterns]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 1, Story 1.3 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/prd.md — NFR21-25 accessibility, NFR37-38 reduce motion]
- [Source: _bmad-output/implementation-artifacts/1-2-ios-project-foundation-and-database.md — Swift 6 patterns, test framework, xcodegen setup, asset catalog build failure]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Dark mode sendButton contrast failure: original #4A5A3A yielded ~2.35:1 contrast against dark backgrounds. Adjusted to #607252 (~3.1:1) to meet WCAG 3:1 non-text requirement (AC9).

### Completion Notes List
- **Task 1:** Created `CoachingTheme.swift` with struct, `SafetyThemeOverride` enum, `ExperienceContext` enum, `EnvironmentKey`/`EnvironmentValues` extension, and `themeFor()` function. Safety/pause/ambient stubs return self. Injected at App root in `AILifeCoachApp.swift`.
- **Task 2:** Created `ColorPalette.swift` with 25 semantic color tokens and 4 static palette instances (homeLight, homeDark, conversationLight, conversationDark). Added `Color(hex:opacity:)` initializer extension. Created 23 asset catalog `.colorset` entries under `Resources/Assets.xcassets/Colors/`. Adjusted dark sendButton from #4A5A3A to #607252 for WCAG 3:1 compliance.
- **Task 3:** Created `TypographyScale.swift` with all 12 semantic text styles using iOS semantic fonts (never fixed sizes). Implemented 12 View extension modifiers (`.coachVoiceStyle()`, etc.) that apply font + lineSpacing together. Coach/user voice use 1.65x line height (11pt lineSpacing).
- **Task 4:** Created `SpacingScale.swift` with 9 spacing tokens on 8pt grid, including `screenMargin(for:)` function for SE detection (16pt when width <= 375). Created `RadiusTokens.swift` with 5 corner radius tokens. Added `.contentColumn()` View modifier for Pro Max 390pt cap.
- **Task 5:** Created `ThemePreview.swift` wrapped in `#if DEBUG`. `ThemePreviewer` renders any view in all 4 palettes. `ThemeShowcaseView` shows color swatches, typography samples, and spacing examples.
- **Task 6:** Created `CopyStandards.swift` with 15-word blacklist and `assertCopyCompliance()` DEBUG-only assertion.
- **Task 7:** Created 5 test files (84 tests total, all passing): ColorPaletteTests (token access, contrast ratios, coachDialogue non-white), TypographyScaleTests (12 tokens, line spacing, font assignments), SpacingScaleTests (9 values, SE margin, touch target), RadiusTokensTests, CopyStandardsTests (blacklist completeness, clean copy, word catching), ThemeForTests (palette selection, stubs, components).

### Change Log
- 2026-03-18: Implemented Story 1.3 — all 7 tasks complete. 84 tests passing. Dark sendButton adjusted #4A5A3A → #607252 for WCAG compliance.
- 2026-03-18: Code review fixes — (M1) Removed 23 dead asset catalog .colorset entries (code uses Color(hex:) not asset catalog). (M2) Added contrast tests for userAccent and sprintProgress per AC9; fixed light palette userAccent/sprintProgressStart #8B9B7A → #748465 for WCAG 3:1. (M3) Fixed CopyStandards to use word-boundary regex instead of substring matching. (M4) Added project.pbxproj to File List. (L1) Completed palette token access tests for all 4 palettes (25/25 tokens each). 89 tests passing.

### File List
- ios/ai_life_coach/Core/Theme/CoachingTheme.swift (new)
- ios/ai_life_coach/Core/Theme/ColorPalette.swift (new)
- ios/ai_life_coach/Core/Theme/TypographyScale.swift (new)
- ios/ai_life_coach/Core/Theme/SpacingScale.swift (new)
- ios/ai_life_coach/Core/Theme/RadiusTokens.swift (new)
- ios/ai_life_coach/Core/Utilities/CopyStandards.swift (new)
- ios/ai_life_coach/Preview Content/ThemePreview.swift (new)
- ios/ai_life_coach/App/AILifeCoachApp.swift (modified — theme injection)
- ios/ai_life_coach.xcodeproj/project.pbxproj (modified — new source files)
- ios/Tests/Theme/ColorPaletteTests.swift (new)
- ios/Tests/Theme/TypographyScaleTests.swift (new)
- ios/Tests/Theme/SpacingScaleTests.swift (new)
- ios/Tests/Theme/CopyStandardsTests.swift (new)
- ios/Tests/Theme/ThemeForTests.swift (new)
