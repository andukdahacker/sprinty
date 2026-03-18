# Story 1.5: Onboarding Flow

Status: done

## Story

As a new user,
I want to complete a quick, delightful onboarding that introduces me to my coach,
So that I feel welcomed and ready for my first conversation in under 2 minutes.

## Acceptance Criteria

1. **Given** a user opens the app for the first time (no completed onboarding)
   **When** the app launches
   **Then** the `OnboardingWelcomeView` displays centered wordmark + tagline with earthy gradient
   **And** it auto-advances after 3 seconds (VoiceOver: announces label and auto-advances)

2. **Given** the welcome view completes
   **When** the avatar selection screen appears
   **Then** 2-3 avatar options display as circular images (placeholder art — final art in Story 4.6)
   **And** tapping one shows a glow ring selection indicator
   **And** tapping confirm saves the selection and advances

3. **Given** the avatar is selected
   **When** the coach selection screen appears
   **Then** 2-3 coach options display with portrait + name + personality hint (placeholder art — final art in Story 4.6)
   **And** the user can name their coach (custom text input)
   **And** confirming saves selection and transitions to conversation (400-500ms crossfade)

4. **Given** the user enters their first conversation
   **When** the coach sends the first message
   **Then** the message is warm, non-generic, and works for users with no stated problem (cold-start)
   **And** clinical boundary transparency is communicated naturally ("I'm your coach, not your therapist")
   **And** privacy is communicated ("Your conversations stay on your device")

5. **Given** the user force-quits mid-onboarding
   **When** they reopen the app
   **Then** onboarding resumes from the last incomplete step

## Tasks / Subtasks

- [x] Task 1: Create `UserProfile` GRDB model and database migration (AC: #2, #3, #5)
  - [x] 1.1 Add `UserProfile` struct in `Models/UserProfile.swift` — GRDB record with full architecture schema PLUS onboarding fields (see UserProfile Schema section below)
  - [x] 1.2 Add migration `v2` in `Migrations.swift` — create `UserProfile` table with all columns
  - [x] 1.3 Add static query extensions on `UserProfile` (e.g., `UserProfile.current()`)
  - [x] 1.4 Write Codable roundtrip and DB read/write tests in `Tests/Models/UserProfileTests.swift`

- [x] Task 2: Create `OnboardingViewModel` (AC: #1-5)
  - [x] 2.1 Create `OnboardingViewModel` in `Features/Onboarding/ViewModels/OnboardingViewModel.swift` — `@MainActor @Observable final class`, injected `AppState` + `DatabaseManager`
  - [x] 2.2 Implement `currentStep` enum: `.welcome`, `.avatarSelection`, `.coachSelection`, `.complete`
  - [x] 2.3 Implement per-step persistence — on each step advance, save `onboardingStep` to `UserProfile` in DB (survives force-quit)
  - [x] 2.4 Implement `resumeFromLastStep()` — reads `UserProfile` from DB, sets `currentStep` to last incomplete step
  - [x] 2.5 Implement `completeOnboarding()` — sets `onboardingCompleted = true`, updates `AppState`
  - [x] 2.6 Write tests in `Tests/Features/OnboardingViewModelTests.swift`: step transitions, persistence/resume, avatar/coach selection saving

- [x] Task 3: Create `OnboardingWelcomeView` (AC: #1)
  - [x] 3.1 Create view in `Features/Onboarding/Views/OnboardingWelcomeView.swift`
  - [x] 3.2 Centered wordmark "sprinty" + tagline on earthy gradient background (`homeBackground` palette)
  - [x] 3.3 Auto-advance after 3 seconds via `Task.sleep` (check `Task.isCancelled`)
  - [x] 3.4 VoiceOver: `accessibilityLabel` on wordmark, announce then auto-advance
  - [x] 3.5 Reduce Motion: no animated entrance if `accessibilityReduceMotion` is true
  - [x] 3.6 Create `#Preview`

- [x] Task 4: Create `AvatarSelectionView` (AC: #2)
  - [x] 4.1 Create view in `Features/Onboarding/Views/AvatarSelectionView.swift`
  - [x] 4.2 "This is you" header using `.homeTitleStyle()`
  - [x] 4.3 2-3 circular avatar options — SF Symbol placeholders: `person.circle.fill`, `person.circle`, `figure.mind.and.body`
  - [x] 4.4 Selection indicator: glow ring using `palette.avatarGlow` color token. Circle shape via `.clipShape(Circle())` — no `cornerRadius.avatar` token exists
  - [x] 4.5 Confirm button using `LinearGradient` from `palette.primaryActionStart` to `palette.primaryActionEnd` + `.primaryButtonStyle()` for text
  - [x] 4.6 44pt minimum touch targets on all interactive elements
  - [x] 4.7 VoiceOver: labels on each avatar option, hint on selection state
  - [x] 4.8 Create `#Preview`

- [x] Task 5: Create `CoachNamingView` (AC: #3)
  - [x] 5.1 Create view in `Features/Onboarding/Views/CoachNamingView.swift`
  - [x] 5.2 "Meet your coach" header
  - [x] 5.3 2-3 coach appearance options with portrait (SF Symbol placeholders) + name + personality hint
  - [x] 5.4 Custom coach name text input — pill-shaped (20pt radius), pre-filled with default name
  - [x] 5.5 Confirm button — on tap: save selections to `UserProfile` via ViewModel, crossfade transition (400-500ms `easeInOut`) to conversation
  - [x] 5.6 Reduce Motion: instant transition if `accessibilityReduceMotion`
  - [x] 5.7 VoiceOver: labels on coach options, text field `accessibilityLabel: "Name your coach"`
  - [x] 5.8 Create `#Preview`

- [x] Task 6: Create `OnboardingContainerView` (AC: #1-5)
  - [x] 6.1 Create view in `Features/Onboarding/Views/OnboardingContainerView.swift`
  - [x] 6.2 Switch on `viewModel.currentStep` to show the correct step view
  - [x] 6.3 Apply conversation theme for the container (earthy gradient background throughout)
  - [x] 6.4 Inject `CoachingTheme` via environment (use `themeFor(context: .home, ...)`)

- [x] Task 7: Update `RootView` and `AppState` navigation logic (AC: #1, #5)
  - [x] 7.1 Add `onboardingCompleted: Bool = false` property to `AppState`
  - [x] 7.2 Load `onboardingCompleted` from DB on app launch — in `RootView.onAppear` (or `SprintyApp`), read `UserProfile.current()` from DB and set `appState.onboardingCompleted`
  - [x] 7.3 Route: if authenticated AND NOT onboarded → show `OnboardingContainerView`; if authenticated AND onboarded → show `CoachingView`
  - [x] 7.4 On onboarding complete → update `appState.onboardingCompleted = true`, transition to `CoachingView` with crossfade
  - [x] 7.5 Wire up `ChatService` creation for the final onboarding step — extract `makeChatService()` from `RootView` so both `RootView` and `OnboardingContainerView` can use it (or move to a shared factory)

- [x] Task 8: Add cold-start first message content (AC: #4)
  - [x] 8.1 Update mock provider (`server/providers/mock.go`) — replace generic tokens with warm, cold-start capable opening that includes clinical boundary + privacy communication. Coach name is NOT injected server-side (mock doesn't have it) — the mock text should use a generic warm opener without `[coach name]` placeholder
  - [x] 8.2 In `OnboardingContainerView`, when step reaches `.complete`, create `CoachingViewModel` with same dependency wiring as `RootView.makeChatService()` and present `CoachingView` directly — no separate wrapper view needed. The coach name is stored in `UserProfile` and will be used by the real AI provider in Story 1.6
  - [x] 8.3 The first conversation IS the beginning of the continuous coaching thread — NOT a throwaway transcript

- [x] Task 9: Verify all tests pass (AC: #1-5)
  - [x] 9.1 Tests are written co-located with their tasks (Task 1.4 → `UserProfileTests`, Task 2.6 → `OnboardingViewModelTests`)
  - [x] 9.2 Add `RootView` routing logic test — verify onboarding gate conditions (authenticated + not onboarded → onboarding, authenticated + onboarded → coaching)
  - [x] 9.3 Run full test suite — all existing + new tests pass

- [x] Task 10: Regenerate Xcode project and verify build
  - [x] 10.1 Add all new files to `project.yml`
  - [x] 10.2 Run xcodegen to regenerate `.xcodeproj`
  - [x] 10.3 Build with Swift 6 strict concurrency — zero warnings
  - [x] 10.4 Run all tests (existing + new) — all pass

## Dev Notes

### Architecture Compliance

- **MVVM with @Observable:** `OnboardingViewModel` is `@MainActor @Observable final class` — owns all state and service calls. Views never call services directly.
- **Protocol-based DI:** `DatabaseManager` injected via init. No singletons, no service locators.
- **Swift 6 strict concurrency:** Zero warnings. `async/await` for DB operations. Check `Task.isCancelled` in the 3-second welcome timer.
- **No Combine:** Use `@Observable` macro. No `@Published`, no `ObservableObject`, no `Combine` imports.
- **Error handling:** Use `AppError` enum for all errors. Route global (auth, network) through `AppState`, local through ViewModel.
- **No force-unwrapping (`!`):** Use `guard let` / `if let` throughout.
- **No raw `print()`:** Use structured logging or omit for MVP.

### CoachingTheme Integration (from Story 1.3)

- Theme is a **struct**, not class — `struct CoachingTheme: Sendable`
- Environment injection: `@Environment(\.coachingTheme) private var theme`
- Palette: onboarding uses **home palette** (`themeFor(context: .home, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)`)
- Colors via `Color(hex:)` — NOT asset catalog color sets
- Typography via View modifiers: `.homeTitleStyle()`, `.homeGreetingStyle()`, `.primaryButtonStyle()`, `.coachVoiceStyle()`
- Spacing: `theme.spacing.screenMargin` (20pt/16pt adaptive), `theme.spacing.dialogueTurn` (24pt)
- Radius: `theme.cornerRadius.input` (20pt pill). NO `avatar` radius token — use `.clipShape(Circle())` for circular elements
- Pro Max cap: use `.contentColumn()` View modifier (390pt centered)
- SE detection: `GeometryReader` width check, NOT `UIScreen.main.bounds`
- Gradient construction: `ColorPalette` stores start/end colors — construct gradients manually
- Animation: `.easeInOut(duration: 0.4)` for standard transitions. Check `@Environment(\.accessibilityReduceMotion)` — if true, `.animation(.none)`
- colorScheme: read `@Environment(\.colorScheme)` and pass to `themeFor()`

### Database

- `UserProfile` goes in root `Models/` (shared GRDB record type, not feature-local)
- Standard conformances: `Codable + FetchableRecord + PersistableRecord + Identifiable + Sendable`
- Explicit `static let databaseTableName = "UserProfile"`
- Query extensions as static methods on the model type
- Migration must be idempotent — added as `v2` in `DatabaseMigrations`
- Column naming: camelCase (`avatarId`, `coachName`, `onboardingStep`, `createdAt`)
- Primary key: `id` (UUID)
- Booleans: `onboardingCompleted` (no `is` prefix needed since the field name is already clear)
- DB operations via `databaseManager.dbPool.read { }` and `databaseManager.dbPool.write { }` with `await`
- `dbPool` is a `let` property of type `DatabasePool` on `DatabaseManager`
- Include architecture-specified fields (`values`, `goals`, `personalityTraits`, `domainStates`) as nullable `String?` columns to avoid future migration in Story 3.3

### UserProfile Schema

The architecture defines UserProfile with fields for coaching intelligence (Story 3.3). This story creates the full table now to avoid a future migration, but only populates onboarding-relevant fields. Architecture fields default to empty/null.

```swift
struct UserProfile: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    // --- Onboarding fields (this story) ---
    var avatarId: String           // SF Symbol name or future asset ID
    var coachAppearanceId: String   // SF Symbol name or future asset ID
    var coachName: String           // User-chosen coach name
    var onboardingStep: Int         // 0=welcome, 1=avatar, 2=coach, 3=complete
    var onboardingCompleted: Bool
    // --- Architecture fields (populated in Story 3.3) ---
    var values: String?             // JSON-encoded [String], null until Story 3.3
    var goals: String?              // JSON-encoded [String], null until Story 3.3
    var personalityTraits: String?  // JSON-encoded [String], null until Story 3.3
    var domainStates: String?       // JSON-encoded dictionary, null until Story 3.3
    // --- Timestamps ---
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "UserProfile"
}
```

**Why include architecture fields now?** The architecture specifies `values`, `goals`, `personalityTraits`, `domainStates` on UserProfile. Creating them as nullable columns now avoids a painful migration in Story 3.3 when the coaching intelligence system needs them. SQLite `ALTER TABLE ADD COLUMN` is safe but GRDB record types must match the schema — better to have one migration.

**JSON-encoded arrays:** GRDB doesn't natively support `[String]` columns. Store as JSON-encoded `String?` and add computed properties for encode/decode convenience in Story 3.3.

### Onboarding Step Enum

Lives inside `OnboardingViewModel.swift` (only used by that ViewModel, not a shared model):

```swift
enum OnboardingStep: Int, Sendable {
    case welcome = 0
    case avatarSelection = 1
    case coachSelection = 2
    case complete = 3
}
```

### Placeholder Art Strategy

Story 4.6 provides real art. For this story, use SF Symbols:

**Avatar options:**
- Option 1: `person.circle.fill` — "Classic"
- Option 2: `person.circle` — "Minimal"
- Option 3: `figure.mind.and.body` — "Zen"

**Coach appearance options:**
- Option 1: `person.circle.fill` — "Sage" — "Warm and encouraging"
- Option 2: `brain.head.profile` — "Mentor" — "Focused and direct"
- Option 3: `leaf.circle.fill` — "Guide" — "Calm and grounding"

### Cold-Start First Message

The first coaching message must be:
- Warm, non-generic, personality-driven
- Cold-start capable (works with zero user context)
- Include clinical boundary: "I'm your coach, not your therapist"
- Include privacy assurance: "Your conversations stay on your device"
- NOT a questionnaire — a conversation opener
- This first conversation IS turn one of the continuous coaching thread — it lives forever

**Coach name is NOT available to the mock provider.** The mock returns static tokens — it doesn't read from the request. Coach name injection into the system prompt happens in Story 1.6 (real AI). For this story, the mock first message is generic but warm.

Example mock response (update `mock.go` tokens array):
> "Hey there — I'm your coach, not your therapist. Everything we talk about stays right here on your device, just between us. I'm here to help you figure things out, push back when you need it, and keep you moving. So... what's on your mind? Or if nothing specific, tell me a little about what brought you here."

**Current mock.go tokens:** `["I hear you. ", "Let's explore that together."]` — replace with the above split into 3-4 streaming chunks.

### Navigation Flow

Current `RootView` has simple conditional routing. Update to:

```
if !authenticated → loading/error screens (unchanged)
if authenticated && !onboardingCompleted → OnboardingContainerView
if authenticated && onboardingCompleted → CoachingView (unchanged)
```

**Bootstrap sequence:**
1. `AppState` gets new property: `var onboardingCompleted = false`
2. In `RootView`, when `appState.isAuthenticated` becomes true AND `databaseManager` is available, read `UserProfile.current()` from DB
3. If `UserProfile` exists and `onboardingCompleted == true` → set `appState.onboardingCompleted = true`
4. If no `UserProfile` exists → user has never onboarded → show `OnboardingContainerView`
5. `OnboardingContainerView` needs access to `makeChatService()` — extract from `RootView` into a shared location or pass as dependency

**Current `RootView.makeChatService()` creates:** `APIClient` → `AuthService` → `ChatService`. The same chain is needed when onboarding completes and transitions to `CoachingView`.

### Onboarding UX Design Rules

- **Very low density** — one decision per screen
- **Spacing:** generous, breathing room between elements
- **No time-based limits** except the 3-second welcome auto-advance
- **Touch targets:** minimum 44pt on all interactive elements
- **Gestures:** tap only. No swipe, long press, or pull-to-refresh
- **Force-quit resilience:** each step completion persisted immediately to DB

### Transition Animation

- Welcome → Avatar: instant (no animation needed, clean swap)
- Avatar → Coach: quick transition (0.25s)
- Coach → Conversation: crossfade with slight upward motion, 400-500ms `easeInOut`
- All transitions: `accessibilityReduceMotion` → instant cut

### Accessibility Checklist

- [x] Welcome wordmark: `accessibilityLabel: "sprinty — your personal coach"`
- [x] Avatar options: `accessibilityLabel: "[avatar name]"`, `accessibilityHint: "Double tap to select"`
- [x] Selected avatar: `accessibilityValue: "Selected"`
- [x] Coach options: `accessibilityLabel: "[coach name], [personality hint]"`
- [x] Coach name text field: `accessibilityLabel: "Name your coach"`
- [x] Confirm buttons: `accessibilityLabel: "Continue"`, 44pt touch target
- [x] Dynamic Type: all text uses semantic font tokens, scales through Accessibility XXXL
- [x] Reduce Motion: auto-advance still works (timer-based, not animation), crossfade transitions become instant
- [x] Color contrast: all text/background meets WCAG AA (4.5:1 body, 3:1 large text) — verified in Story 1.3 palette
- [x] VoiceOver navigation order: header → options → confirm button (top to bottom, logical flow)

### Existing Code to Reuse (DO NOT REINVENT)

| What | Where | How to Use |
|------|-------|------------|
| `AppState` | `App/AppState.swift` | Add `onboardingCompleted` property. Inject via `@Environment(AppState.self)` |
| `AppError` | `Core/Errors/AppError.swift` | Throw/catch for error routing |
| `DatabaseManager` | `Services/Database/DatabaseManager.swift` | `dbPool.read { }` and `dbPool.write { }` |
| `DatabaseMigrations` | `Services/Database/Migrations.swift` | Add `v2` migration for `UserProfile` table |
| `CoachingTheme` | `Core/Theme/CoachingTheme.swift` | `@Environment(\.coachingTheme)` for palette, spacing, radius |
| `themeFor()` | `Core/Theme/CoachingTheme.swift` | `themeFor(context: .home, colorScheme:, safetyLevel: .none, isPaused: false)` |
| Typography modifiers | `Core/Theme/TypographyScale.swift` | `.homeTitleStyle()`, `.homeGreetingStyle()`, `.primaryButtonStyle()` |
| `.contentColumn()` | `Core/Theme/SpacingScale.swift` | Pro Max 390pt centered column |
| `CopyStandards` | `Core/Utilities/CopyStandards.swift` | `assertCopyCompliance()` on hardcoded UI strings in DEBUG. Banned: "user", "session", "data", "error", "loading", etc. |
| `CoachingView` | `Features/Coaching/Views/CoachingView.swift` | Reuse for the final onboarding step (first conversation). Create `CoachingViewModel` in `OnboardingContainerView` using same pattern as `RootView` |
| `CoachingViewModel` | `Features/Coaching/ViewModels/CoachingViewModel.swift` | Requires `appState`, `chatService: ChatServiceProtocol`, `databaseManager: DatabaseManager` via init |
| `RootView` | `App/RootView.swift` | Modify to add onboarding gate. Extract `makeChatService()` so `OnboardingContainerView` can reuse it |
| Mock provider | `server/providers/mock.go` | Update tokens array — current: `["I hear you. ", "Let's explore that together."]` — replace with cold-start opener chunks |
| `ColorPalette` | `Core/Theme/ColorPalette.swift` | Primary button gradient uses `palette.primaryActionStart` → `palette.primaryActionEnd` (NOT a single `primaryAction` token). Avatar circles use `palette.avatarGlow` + `.clipShape(Circle())` |

### Anti-Patterns (DO NOT DO)

- No singletons or service locators for state management
- No `DispatchQueue.main.async` — use `@MainActor`
- No force-unwrapping (`!`)
- No `print()` — use structured logging
- No asset catalog color sets — use `Color(hex:)` per Story 1.3 pattern
- No `UIScreen.main.bounds` — use `GeometryReader`
- No calling services from View body — go through ViewModel
- No Combine (`@Published`, `ObservableObject`, `sink`)
- No hardcoded font sizes — use semantic typography tokens
- No `UserDefaults` for onboarding state — use GRDB `UserProfile` table for consistency with the rest of the data layer
- No separate "onboarding conversation" — the first conversation IS the continuous coaching thread

### Project Structure Notes

New files follow established project structure:

```
ios/
├── project.yml                                    # MODIFIED — add new source files
├── sprinty/
│   ├── Models/
│   │   └── UserProfile.swift                      # NEW — shared GRDB record (full arch schema)
│   ├── Features/
│   │   └── Onboarding/
│   │       ├── Views/
│   │       │   ├── OnboardingContainerView.swift  # NEW — step router + conversation transition
│   │       │   ├── OnboardingWelcomeView.swift    # NEW — brand moment
│   │       │   ├── AvatarSelectionView.swift      # NEW — avatar picker
│   │       │   └── CoachNamingView.swift          # NEW — coach + name picker
│   │       └── ViewModels/
│   │           └── OnboardingViewModel.swift      # NEW — flow state + persistence + OnboardingStep enum
│   ├── App/
│   │   ├── RootView.swift                         # MODIFIED — add onboarding gate + load onboarding state
│   │   └── AppState.swift                         # MODIFIED — add onboardingCompleted
│   └── Services/
│       └── Database/
│           └── Migrations.swift                   # MODIFIED — add v2 migration
└── Tests/
    ├── Features/
    │   └── OnboardingViewModelTests.swift         # NEW
    └── Models/
        └── UserProfileTests.swift                 # NEW
```

Server files:
```
server/
└── providers/
    └── mock.go                                    # MODIFIED — update first-message tokens
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.5 acceptance criteria, lines 558-591]
- [Source: _bmad-output/planning-artifacts/architecture.md — Onboarding feature structure, iOS project layout]
- [Source: _bmad-output/planning-artifacts/architecture.md — UserProfile schema, GRDB patterns, ViewModel pattern]
- [Source: _bmad-output/planning-artifacts/architecture.md — CoachingTheme, error taxonomy, accessibility patterns]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 1 onboarding flow, timing, error paths]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Typography scale, color palettes, spacing density]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Accessibility requirements, VoiceOver, Dynamic Type]
- [Source: _bmad-output/planning-artifacts/prd.md — FR23-FR25, FR30, FR62, FR80]
- [Source: _bmad-output/implementation-artifacts/1-4-conversation-view-with-mock-streaming.md — Previous story learnings, code patterns, file list]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Swift 6 strict concurrency fix: `var profile` captured in `@Sendable` closure required `let updated = profile` pattern before passing to `dbPool.write`
- project.yml: no changes needed — xcodegen auto-discovers sources from `sprinty/` directory

### Completion Notes List
- Task 1: `UserProfile` GRDB model with full architecture schema (14 columns), v2 migration, `current()` query extension. 8 unit tests.
- Task 2: `OnboardingViewModel` — `@MainActor @Observable`, OnboardingStep enum, per-step DB persistence, resume from last step, complete onboarding updates AppState. 12 unit tests.
- Task 3: `OnboardingWelcomeView` — centered wordmark + tagline, 3s auto-advance with Task.isCancelled, accessibilityLabel, reduceMotion support, #Preview.
- Task 4: `AvatarSelectionView` — 3 SF Symbol avatar options, glow ring selection, 44pt touch targets, VoiceOver labels/hints/values, gradient confirm button, #Preview.
- Task 5: `CoachNamingView` — 3 coach appearance options with name + personality hint, pill-shaped name input (20pt radius), auto-fills name on coach selection, VoiceOver, #Preview.
- Task 6: `OnboardingContainerView` — step router with animated transitions, earthy gradient background, CoachingTheme environment injection, creates CoachingViewModel on completion.
- Task 7: `AppState.onboardingCompleted` added, `RootView` updated with onboarding gate (checks DB on launch), `makeChatService()` passed to OnboardingContainerView.
- Task 8: Mock provider updated with 4-chunk cold-start message including clinical boundary and privacy communication.
- Task 9: 3 routing logic tests added. Full suite: 134 tests, 17 suites, all pass.
- Task 10: xcodegen regenerated, Swift 6 strict concurrency build — zero warnings, all 134 tests pass.

### Change Log
- 2026-03-18: Story 1.5 implemented — onboarding flow with UserProfile model, OnboardingViewModel, 4 views, RootView routing gate, cold-start mock message. 23 new tests added (134 total).
- 2026-03-18: Code review — fixed incorrect error routing in OnboardingViewModel.handleError() (M1), added assertionFailure guard in OnboardingContainerView.setupCoachingAndComplete() (M2), updated accessibility checklist (L4), added project.pbxproj to File List (L3).

### File List
- ios/sprinty/Models/UserProfile.swift (NEW)
- ios/sprinty/Features/Onboarding/ViewModels/OnboardingViewModel.swift (NEW)
- ios/sprinty/Features/Onboarding/Views/OnboardingWelcomeView.swift (NEW)
- ios/sprinty/Features/Onboarding/Views/AvatarSelectionView.swift (NEW)
- ios/sprinty/Features/Onboarding/Views/CoachNamingView.swift (NEW)
- ios/sprinty/Features/Onboarding/Views/OnboardingContainerView.swift (NEW)
- ios/sprinty/App/AppState.swift (MODIFIED)
- ios/sprinty/App/RootView.swift (MODIFIED)
- ios/sprinty/Services/Database/Migrations.swift (MODIFIED)
- ios/sprinty.xcodeproj/project.pbxproj (MODIFIED — xcodegen regenerated)
- ios/Tests/Models/UserProfileTests.swift (NEW)
- ios/Tests/Features/OnboardingViewModelTests.swift (NEW)
- ios/Tests/Features/OnboardingRoutingTests.swift (NEW)
- server/providers/mock.go (MODIFIED)
