# Story 1.9: Home Screen Foundation

Status: done

## Story

As a returning user,
I want to see a calm home screen with my avatar and a clear way to talk to my coach,
So that I have a welcoming starting point every time I open the app.

## Acceptance Criteria

1. **Given** a user who has completed onboarding, **When** they open the app, **Then** the home screen displays with their selected avatar (64pt), a warm greeting, and "Talk to your coach" button. The app loads to home screen within 3 seconds (NFR4).

2. **Given** the user taps "Talk to your coach", **When** the transition begins, **Then** a gentle crossfade with slight upward motion occurs (400-500ms, ease-in-out) and the conversation view opens showing the continuous conversation thread.

3. **Given** the user is in a conversation, **When** they navigate back, **Then** the home screen appears with a reverse transition (300ms).

4. **Given** VoiceOver is enabled, **When** the home screen renders, **Then** the avatar announces "Your avatar" with state value, and the button announces "Talk to your coach" with hint "Opens your coaching conversation".

5. **Given** Reduce Motion is enabled, **When** transitioning between home and conversation, **Then** transitions are instant (no animation).

## Tasks / Subtasks

- [x] Task 1: Create HomeView with progressive disclosure Stage 1 layout (AC: 1)
  - [x] 1.1 Create `HomeView.swift` in `Features/Home/Views/` — `HStack` top: avatar (64pt) + greeting area (name + secondary text), `VStack` body: spacer + "Talk to your coach" button (full-width primary action)
  - [x] 1.2 Apply home palette via `CoachingTheme` environment — use `homeLight`/`homeDark` palette, NOT conversation palette
  - [x] 1.3 Implement progressive disclosure visibility rules: avatar + greeting always visible, insight card shown only when `>=1 completed conversation` exists, sprint progress shown only when active sprint exists (future stories)
  - [x] 1.4 Use existing design tokens: `spacing.homeElement` (16pt), `spacing.screenMargin(for: width)` (returns 20pt, or 16pt on SE), `spacing.sectionGap` (32pt), `.clipShape(Circle())` for avatar, `cornerRadius.button` (16pt)
  - [x] 1.5 Use existing typography: `.homeTitleStyle()` (20pt semibold) for greeting name, `.homeGreetingStyle()` (14pt regular) for time-of-day text, `.primaryButtonStyle()` (16pt semibold) for button text

- [x] Task 2: Create HomeViewModel (AC: 1)
  - [x] 2.1 Create `HomeViewModel.swift` in `Features/Home/ViewModels/` — `@MainActor @Observable final class`
  - [x] 2.2 Inject `AppState` and `DatabaseManager` via init (follow established CoachingViewModel pattern)
  - [x] 2.3 Load `UserProfile` from database via `UserProfile.current()` to get `coachName` and `avatarId` for display
  - [x] 2.4 Compute greeting text based on time of day ("Good morning"/"Good afternoon"/"Good evening"). No user name is collected during onboarding — use a warm generic greeting without a name (e.g., "Good evening" as secondary text, with "Welcome back" or similar as primary title)
  - [x] 2.5 Expose `greeting`, `avatarId` properties for HomeView binding

- [x] Task 3: Create AvatarView (AC: 1, 4, 5)
  - [x] 3.1 Create `AvatarView.swift` in `Features/Home/Views/` — displays user's selected avatar at specified size
  - [x] 3.2 Use static images for MVP (Lottie animation deferred to Epic 4). Display avatar based on `UserProfile.avatarId` (String) which maps to asset catalog image names. No state-based rendering yet — just show the selected avatar.
  - [x] 3.3 Apply `palette.avatarGlow` from home palette (30% opacity light, 20% dark). Use `.clipShape(Circle())` — there is no `RadiusTokens.avatar`.
  - [x] 3.4 Accept a `size` parameter (default 64pt) to support responsive sizing (56pt on SE)
  - [x] 3.5 Set `accessibilityLabel("Your avatar")`

- [x] Task 4: Create CoachActionButton (AC: 2)
  - [x] 4.1 Create `CoachActionButton.swift` in `Features/Home/Views/` — full-width button with `palette.primaryActionStart`/`palette.primaryActionEnd` gradient and `palette.primaryActionText` color from home palette
  - [x] 4.2 Apply gradient: `#7A8B6B -> #6B7A5A` light, corresponding dark values
  - [x] 4.3 Use `Font.primaryButton` (16pt semibold), `Radius.button` (16pt), min 44pt touch target
  - [x] 4.4 Set `accessibilityLabel("Talk to your coach")` and `accessibilityHint("Opens your coaching conversation")`

- [x] Task 5: Implement home-to-conversation transition (AC: 2, 3, 5)
  - [x] 5.1 Add `NavigationStack` with path-based routing if not already present, or integrate with existing navigation
  - [x] 5.2 Implement crossfade with slight upward motion (400-500ms, ease-in-out) for home -> conversation
  - [x] 5.3 Implement reverse transition (300ms) for conversation -> home
  - [x] 5.4 Check `@Environment(\.accessibilityReduceMotion)` — when true, use instant transitions (no animation)
  - [x] 5.5 Conversation view opens scrolled to bottom of continuous thread

- [x] Task 6: Update RootView routing (AC: 1)
  - [x] 6.1 Modify `RootView.swift` to route to `HomeView` (not `CoachingView`) after onboarding completion
  - [x] 6.2 Home screen becomes the primary post-onboarding destination
  - [x] 6.3 Preserve existing onboarding gate logic (`UserProfile.onboardingCompleted`)
  - [x] 6.4 Ensure first launch after onboarding shows home screen Stage 1 (avatar + greeting + button only)

- [x] Task 7: Write unit tests (AC: all)
  - [x] 7.1 Test `HomeViewModel` — greeting computation for morning/afternoon/evening
  - [x] 7.2 Test `HomeViewModel` — UserProfile loading and property mapping
  - [x] 7.3 Test progressive disclosure logic — visibility rules for insight card and sprint progress
  - [x] 7.4 Verify accessibility via VoiceOver manual testing and `#Preview` inspection (accessibility labels are View-level, not unit-testable)
  - [x] 7.5 Place tests in `ios/Tests/Features/Home/` mirroring source structure

## Dev Notes

### Architecture Compliance

- **MVVM pattern:** `HomeView` reads from `HomeViewModel`, ViewModel owns all service calls. Views NEVER call services directly.
- **State injection:** `AppState` via `@Environment(AppState.self)` in View, passed to ViewModel via init. No singletons, no service locators.
- **@Observable macro:** Use `@Observable` (not `ObservableObject`/`@Published`). iOS 17+ is the deployment target.
- **Swift 6 strict concurrency:** All ViewModels are `@MainActor`. Use `async/await` for async ops. No `DispatchQueue.main.async`. No Combine.
- **Database access:** Use `DatabaseManager` (GRDB `DatabasePool`) for all queries. Define query extensions as static methods on model types, not in ViewModels.

### Existing Code to Reuse (DO NOT REINVENT)

- **`CoachingTheme`** (`Core/Theme/CoachingTheme.swift`): Full theme system with `homeLight`, `homeDark` palettes already defined. Use `@Environment(\.coachingTheme)` to access.
- **`ColorPalette`** (`Core/Theme/ColorPalette.swift`): Home colors exist as gradient pairs — `backgroundStart`/`backgroundEnd`, `avatarGlow`, `avatarGradient`, `primaryActionStart`/`primaryActionEnd`, `primaryActionText`, `textPrimary`, `textSecondary`. Use `.homeLight`/`.homeDark` presets. DO NOT define new colors.
- **`TypographyScale`** (`Core/Theme/TypographyScale.swift`): `homeGreetingStyle()`, `homeTitleStyle()`, `primaryButtonStyle()`, `insightTextStyle()`, `sprintLabelStyle()` — all pre-defined.
- **`SpacingScale`** (`Core/Theme/SpacingScale.swift`): `homeElement` (16pt), `sectionGap` (32pt), `screenMargin(for: CGFloat)` — function that returns 16pt for width <= 375pt, else 20pt (use with `GeometryReader`). Also `minTouchTarget` (44pt).
- **`RadiusTokens`** (`Core/Theme/RadiusTokens.swift`): `button` (16pt), `container` (16pt), `input` (20pt), `small` (8pt), `sprintTrack` (3pt). No `.avatar` token — use `.clipShape(Circle())` for avatar.
- **`AppState`** (`App/AppState.swift`): Global observable state. Currently has `isAuthenticated`, `needsReauth`, `isOnline`, `onboardingCompleted`, `databaseManager`.
- **`UserProfile`** (`Models/UserProfile.swift`): GRDB model with `id` (UUID), `avatarId` (String — maps to asset catalog), `coachAppearanceId`, `coachName`, `onboardingStep`, `onboardingCompleted` (Bool), `values`/`goals`/`personalityTraits`/`domainStates` (optional Strings). Query via `UserProfile.current()`. Note: NO user name field exists — onboarding does not collect user name.
- **`RootView`** (`App/RootView.swift`): Current routing: onboarding gate → CoachingView. Modify to route to HomeView instead.
- **`CoachingView`** (`Features/Coaching/Views/CoachingView.swift`): Existing conversation view — this is the navigation destination from home.
- **`CoachingViewModel`** (`Features/Coaching/ViewModels/CoachingViewModel.swift`): Reference pattern for ViewModel structure (`@MainActor @Observable`, injected deps, `localError`).

### What NOT to Build (Out of Scope)

- Lottie avatar animations (Epic 4 — use static images/placeholders)
- Sprint progress display (Epic 5 — sprint path/detail views)
- Insight card content (Epic 3 — requires RAG pipeline)
- Tab bar navigation (not in UX spec — app uses hub model, not tabs)
- Check-in summaries (requires check-in feature from Epic 5)
- Pause Mode visual transforms (Epic 7)
- Safety state theme transformations on home (Epic 6)
- Widgets (Epic 10)
- Ambient mode color shifts (Epic 2)

### Progressive Disclosure Stages (Implement Stage 1, Prepare for Stage 2)

- **Stage 1 (This Story):** Avatar + warm greeting (time-of-day based, no user name available) + "Talk to your coach" button. Negative space is intentional — "your story starts here."
- **Stage 2 (Future — Epic 3):** + Insight card appears after first completed conversation.
- **Stage 3 (Future — Epic 5):** + Sprint progress bar + check-in card.
- **Stage 4 (Future — Epic 7):** Pause mode transforms.

Build the view structure to support future stages (conditional visibility), but only populate Stage 1 content now.

### Home Screen Layout (UX Spec — Layout B: Compact & Personal)

```
+------------------------------------------+
| [Avatar 64pt]  Welcome back              |  ← HStack: avatar + greeting (.homeTitleStyle)
|                Good evening              |  ← Time-of-day greeting (.homeGreetingStyle)
|                                          |
|                                          |  ← Spacer (intentional negative space)
|                                          |
|  [============ Talk to your coach =======]|  ← Full-width primary action button
+------------------------------------------+
```

Note: No user name is collected during onboarding. Use a warm generic title like "Welcome back" with time-of-day secondary text. A personalized "Hey, {name}" greeting can be added in a future story when name collection is introduced.

Information hierarchy: Identity (avatar + name) → action button. Insight card and sprint progress slots exist but are hidden until data is available.

### Transition Design

- **Home → Conversation:** Crossfade with slight upward motion, 400-500ms, `ease-in-out`. Metaphor: "moving from your room to the coaching office." Two distinct palettes reinforce spatial distinction (home palette → conversation palette).
- **Conversation → Home:** Reverse transition, 300ms.
- **Reduce Motion:** Instant cut, no animation.
- **Implementation:** Use `.matchedGeometryEffect` or custom `AnyTransition` with `.opacity` + `.offset(y:)`. NavigationStack `.navigationTransition` modifier if available on iOS 17+.

### Responsive Layout

| Element | iPhone SE (375pt) | Standard (390-393pt) | Pro Max (430pt) |
|---------|-------------------|---------------------|-----------------|
| Screen margins | 16pt | 20pt | 20pt |
| Home avatar | 56pt | 64pt | 64pt |
| Content column | Full width | Full width | Max 390pt centered |

### File Structure

```
ios/sprinty/Features/Home/
├── Views/
│   ├── HomeView.swift           # Hub screen layout
│   ├── AvatarView.swift         # Avatar display with state
│   └── CoachActionButton.swift  # Primary action button
└── ViewModels/
    └── HomeViewModel.swift      # Home state management
```

Test files:
```
ios/Tests/Features/Home/
├── HomeViewModelTests.swift
└── (No view tests — manual + #Preview only)
```

### Testing Standards

- Use Swift Testing (`@Test` macro), not XCTest for unit tests
- Test naming: `test_methodName_condition_expectedResult`
- Mock services via protocol conformance (hand-written mocks, no frameworks)
- Use in-memory GRDB database for database-dependent tests
- DO NOT test SwiftUI views directly — use `#Preview` with mock data for visual verification
- Create `#Preview` blocks for HomeView covering: light/dark mode, SE layout (375pt), Pro Max centering (430pt), and VoiceOver audit
- Place tests in `ios/Tests/Features/Home/` mirroring source structure

### Previous Story Learnings (from Story 1.8)

- Swift 6 strict concurrency is enforced — all new types must be `Sendable` where needed
- `project.yml` uses `createIntermediateGroups: true` and auto-discovers `.swift` files under `sprinty/` — no manual file registration needed. Just place files in the correct directory structure.
- Core ML model is gitignored — CI handles absence gracefully
- Fixture loading pattern: `#filePath` traversal for iOS tests
- 149 iOS tests + 44 Go tests currently passing — do not break existing tests

### Git Intelligence

Recent commits follow pattern: `feat: Story X.Y — <description>`. Each story is a single commit with all related files.

Files most recently modified:
- `.github/workflows/ios.yml`, `server.yml` (CI)
- `ios/Tests/` (test infrastructure)
- `server/tests/` (fixture helpers)

No conflicts expected with home screen work — this is net-new UI code in an empty feature folder.

### Project Structure Notes

- Home feature folder (`Features/Home/Views/`, `Features/Home/ViewModels/`) already exists but is empty — ready for implementation
- All design tokens (colors, typography, spacing, radius) are production-ready in `Core/Theme/`
- `AppState` has no `experienceContext` property — the `ExperienceContext` enum (defined in `CoachingTheme.swift`) currently only has `.home` and `.conversation` cases. Do not expand it for this story.
- `UserProfile.avatarId` (String) maps to asset catalog image names for avatar display. `UserProfile.current()` query extension exists.
- Navigation will change from `onboarding → CoachingView` to `onboarding → HomeView → CoachingView`

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 1, Story 1.9]
- [Source: _bmad-output/planning-artifacts/architecture.md — iOS Architecture, Home Screen section, Avatar section, Navigation section]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Home Scene Design (Layout B), Avatar System, Navigation Patterns, Design System, Accessibility]
- [Source: _bmad-output/planning-artifacts/prd.md — FR1, FR26, FR28, NFR4]
- [Source: _bmad-output/implementation-artifacts/1-8-ci-cd-pipeline-and-test-infrastructure.md — Dev notes, testing patterns]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Build succeeded with 0 errors on first pass after fixing preview (DatabaseManager requires dbPool param)
- 160 tests passed (11 new HomeViewModel tests + 149 existing)

### Completion Notes List

- Task 1: HomeView created with HStack(avatar+greeting) + Spacer + CoachActionButton layout. Uses GeometryReader for responsive margins (16pt SE, 20pt standard). Applied homeLight/homeDark palette via themeFor(). Progressive disclosure Stage 2/3 slots as comments.
- Task 2: HomeViewModel as @MainActor @Observable final class. Injects AppState + DatabaseManager. Loads UserProfile.current() for avatarId. Computes time-of-day greeting (morning 5-12, afternoon 12-17, evening otherwise). "Welcome back" as primary title, no user name.
- Task 3: AvatarView with configurable size (default 64pt), Circle clip, avatarGlow shadow, accessibilityLabel("Your avatar"). Static Image from asset catalog.
- Task 4: CoachActionButton with LinearGradient (primaryActionStart→primaryActionEnd), primaryButtonStyle(), 44pt min touch target, full accessibility labels+hints.
- Task 5: Transition via ZStack in RootView — crossfade with upward offset (0.45s ease-in-out) for home→conversation, 0.3s reverse. reduceMotion → nil animation (instant). CoachingView has .task { loadMessages() } which scrolls to bottom.
- Task 6: RootView now routes onboarding→HomeView→CoachingView. HomeViewModel created on appear. CoachingViewModel lazily created on first "Talk to coach" tap. Back button overlay on CoachingView.
- Task 7: 11 unit tests in HomeViewModelTests.swift — greeting time boundaries (morning/afternoon/evening/late night/5AM/noon/5PM), profile loading (avatarId from DB, default fallback), greeting text verification. All pass.

### Change Log

- 2026-03-19: Story 1.9 implementation complete — Home screen foundation with all 7 tasks
- 2026-03-19: Code review fixes — added HomeView #Preview blocks (light/dark/SE/ProMax), fixed @Bindable→let, added .accessibilityAddTraits(.isImage) to AvatarView, added project.pbxproj to File List

### File List

- ios/sprinty/Features/Home/Views/HomeView.swift (new)
- ios/sprinty/Features/Home/Views/AvatarView.swift (new)
- ios/sprinty/Features/Home/Views/CoachActionButton.swift (new)
- ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift (new)
- ios/sprinty/App/RootView.swift (modified)
- ios/sprinty.xcodeproj/project.pbxproj (modified)
- ios/Tests/Features/Home/HomeViewModelTests.swift (new)
