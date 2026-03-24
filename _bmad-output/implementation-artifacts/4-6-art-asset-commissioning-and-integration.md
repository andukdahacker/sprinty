# Story 4.6: Art Asset Commissioning & Integration

Status: done

## Story

As a user,
I want polished, warm character illustrations for my avatar and coach,
So that the app feels crafted and personal, not like placeholder art.

## Acceptance Criteria

1. **Art Style Direction** — Coach character uses semi-realistic/painterly watercolor-adjacent style with soft edges, organic textures, human warmth. Avatar uses simplified painterly style (same family, less detail) with emphasis on posture/silhouette. Gender-neutral default with 2-3 selectable variants for both.
2. **Coach Character Assets** — Five expression states delivered: Welcoming, Thinking, Warm (Discovery), Focused (Directive), Gentle (Safety). All distinguishable at 100pt display width. Assets at 100pt default (80pt at accessibility XL+) with 2x and 3x resolution. Portrait uses natural earth-tone clothing matching coaching palette.
3. **Avatar Assets** — Five state visuals delivered: Active, Resting, Celebrating, Thinking, Struggling. Assets in 5 states x 2-3 appearance variants x 2x/3x resolution.
4. **Asset Integration** — All views using SF Symbol placeholders update to final image assets. SwiftUI crossfade transitions work correctly with final assets. Reduce Motion fallback remains functional. No regressions in accessibility (VoiceOver, Dynamic Type, contrast).

## Tasks / Subtasks

- [x] Task 1: Add commissioned art assets to asset catalog (AC: #1, #2, #3)
  - [x] 1.1 Create `Assets.xcassets/Avatars/` — 15 image sets (5 states x 3 variants), each containing 2x + 3x PNG files (30 files total), plus 3 selection thumbnail image sets (3 variants in default pose)
  - [x] 1.2 Create `Assets.xcassets/Coach/` — 15 image sets (5 expressions x 3 variants), each containing 2x + 3x PNG files (30 files total), plus 3 selection thumbnail image sets
  - [x] 1.3 Add image set entries to asset catalog with proper naming convention
  - [x] 1.4 Update `project.yml` if XcodeGen needs explicit resource references — N/A, Assets.xcassets already included

- [x] Task 2: Update AvatarOptions to reference image asset names instead of SF Symbols (AC: #4)
  - [x] 2.1 Change `avatarOptions` IDs from SF Symbol names to asset catalog names (e.g., `"avatar_classic"`, `"avatar_minimal"`, `"avatar_zen"`)
  - [x] 2.2 Change `coachOptions` IDs from SF Symbol names to asset catalog names (e.g., `"coach_sage"`, `"coach_mentor"`, `"coach_guide"`)
  - [x] 2.3 Add helper to map avatar ID + AvatarState to the correct state-specific asset name

- [x] Task 3: Update AvatarView to render custom images (AC: #4)
  - [x] 3.1 Replace `Image(avatarId)` — currently loads as named image — with state-aware asset lookup
  - [x] 3.2 Build asset name from `avatarId` + `state` (e.g., `"avatar_classic_active"`, `"avatar_zen_celebrating"`)
  - [x] 3.3 Keep `.saturation()` modifier as enhancement layer on top of art (art already encodes saturation differences, modifier adds programmatic reinforcement)
  - [x] 3.4 Verify crossfade animation still works with image swap via `.id(state)` + `.transition(.opacity)`
  - [x] 3.5 Update previews with real asset names

- [x] Task 4: Thread coachAppearanceId to CoachCharacterView (AC: #2, #4)
  - [x] 4.1 Add `coachAppearanceId: String` property to CoachingViewModel (load from UserProfile in init/load, same DB read pattern as HomeViewModel)
  - [x] 4.2 Add `coachAppearanceId` parameter to CoachCharacterView (currently only takes `expression: CoachExpression`)
  - [x] 4.3 Update CoachingView.swift:22 to pass `viewModel.coachAppearanceId` to CoachCharacterView
  - [x] 4.4 Update CoachExpression: replace `sfSymbolName` with `func assetName(for variant: String) -> String` that builds `"coach_{variant}_{expression}"` (e.g., `"coach_sage_thinking"`)
  - [x] 4.5 In CoachCharacterView: replace `Image(systemName: expression.sfSymbolName)` with `Image(expression.assetName(for: coachAppearanceId))` using `.resizable().scaledToFill().frame(width: portraitSize, height: portraitSize)`
  - [x] 4.6 Remove the gradient Circle ZStack background (art provides its own visual treatment)
  - [x] 4.7 Ensure expression crossfade animation still works with `.id(expression)` + `.transition(.opacity)`

- [x] Task 5: Update all selection views for custom images (AC: #4)
  - [x] 5.1 **AvatarSelectionView** (onboarding): Replace `Image(systemName: option.id)` with `Image(option.id).resizable().scaledToFill().frame(width: 48, height: 48)`. Keep circular clip and glow ring.
  - [x] 5.2 **SettingsAvatarSelectionView**: Same pattern — replace `Image(systemName: option.id)` with `Image(option.id).resizable().scaledToFill().frame(width: 48, height: 48)`
  - [x] 5.3 **SettingsCoachAppearanceView**: Replace `Image(systemName: option.id)` with `Image(option.id).resizable().scaledToFill().frame(width: 40, height: 40)`. Remove Circle `.fill(insightBackground)` if art provides its own background.
  - [x] 5.4 **CoachNamingView** (onboarding): Replace `Image(systemName: option.id)` at line 50 with `Image(option.id).resizable().scaledToFill().frame(width: 40, height: 40)`. Remove Circle fill background.
  - [x] 5.5 **SettingsView** thumbnails: Replace `Image(systemName: viewModel.avatarId)` and `Image(systemName: viewModel.coachAppearanceId)` with `Image(viewModel.avatarId).resizable().scaledToFill().frame(width: 20, height: 20)` and same for coach.
  - [x] 5.6 Remove `.font(.system(size: N))` modifiers from all updated image views (only applies to SF Symbols)
  - [x] 5.7 Verify glow ring overlay renders correctly around custom images in all views

- [x] Task 6: Update default values in ViewModels (AC: #4)
  - [x] 6.1 `SettingsViewModel.swift:9` — change default `avatarId` from `"person.circle.fill"` to `"avatar_classic"`
  - [x] 6.2 `SettingsViewModel.swift:10` — change default `coachAppearanceId` from `"person.circle.fill"` to `"coach_sage"`
  - [x] 6.3 `HomeViewModel.swift:11` — change default `avatarId` from `"avatar_default"` to `"avatar_classic"`
  - [x] 6.4 `HomeViewModel.swift:173` — update preview factory default from `"avatar_default"` to `"avatar_classic"`

- [x] Task 7: Database migration for avatar/coach IDs (AC: #4)
  - [x] 7.1 Add migration `"v7"` in `Migrations.swift` (next after existing `v6`)
  - [x] 7.2 Run two separate UPDATE statements — one for `avatarId`, one for `coachAppearanceId` — because `"person.circle.fill"` maps to different targets per column
  - [x] 7.3 Avatar column mapping: `"person.circle.fill"` → `"avatar_classic"`, `"person.circle"` → `"avatar_minimal"`, `"figure.mind.and.body"` → `"avatar_zen"`
  - [x] 7.4 Coach column mapping: `"person.circle.fill"` → `"coach_sage"`, `"brain.head.profile"` → `"coach_mentor"`, `"leaf.circle.fill"` → `"coach_guide"`
  - [x] 7.5 Handle empty string default — map `""` → `"avatar_classic"` / `"coach_sage"`

- [x] Task 8: Write/update tests (AC: #4)
  - [x] 8.1 Update AvatarStateTests if they reference SF Symbol names — no changes needed, no SF Symbol refs
  - [x] 8.2 Update HomeViewModelAvatarTests for new asset ID format — updated default from "avatar_default" to "avatar_classic"
  - [x] 8.3 Update SettingsViewModelCustomizationTests for new IDs
  - [x] 8.4 Add tests for avatar ID + state → asset name mapping
  - [x] 8.5 Add test for CoachExpression.assetName(for:) mapping
  - [x] 8.6 Add test for database migration from SF Symbol IDs to asset IDs
  - [x] 8.7 Test CoachingViewModel loads coachAppearanceId from database
  - [x] 8.8 Run full test suite — all 434 tests pass (15 new tests added)

- [ ] Task 9: Manual verification (AC: #1, #2, #3, #4)
  - [ ] 9.1 Verify all 5 avatar states render correctly in AvatarView (light + dark)
  - [ ] 9.2 Verify all 5 coach expressions render correctly in CoachCharacterView
  - [ ] 9.3 Verify onboarding avatar and coach selection flows
  - [ ] 9.4 Verify settings customization flows
  - [ ] 9.5 Verify Reduce Motion: instant state transitions, no animation
  - [ ] 9.6 Verify VoiceOver labels still announce correctly
  - [ ] 9.7 Verify Dynamic Type XL/XXXL doesn't clip images
  - [ ] 9.8 Check 60fps performance on crossfade transitions

## Dev Notes

### Critical Context: Current Placeholder System

The app currently uses **SF Symbols** (system icons) as placeholder art. There are NO custom image assets — `Assets.xcassets/` only contains AppIcon.

**How images are currently rendered (two different patterns):**
- `AvatarView.swift:12` uses `Image(avatarId)` — **named image lookup**, NOT `Image(systemName:)`. It already expects asset catalog images. Currently receives `"avatar_default"` from HomeViewModel default or an SF Symbol name from DB (which would fail to render as a named image).
- All **selection views** and **SettingsView thumbnails** use `Image(systemName: option.id)` — SF Symbol rendering that must change to `Image(option.id)`.
- `CoachCharacterView.swift:26` uses `Image(systemName: expression.sfSymbolName)` — SF Symbol rendering.

**Current SF Symbol ID mappings stored in database/code:**
- Avatar options: `"person.circle.fill"` (Classic), `"person.circle"` (Minimal), `"figure.mind.and.body"` (Zen)
- Coach options: `"person.circle.fill"` (Sage), `"brain.head.profile"` (Mentor), `"leaf.circle.fill"` (Guide)
- Coach expressions: `"person.circle.fill"` (welcoming), `"brain.head.profile"` (thinking), `"heart.circle.fill"` (warm), `"eye.circle.fill"` (focused), `"leaf.circle.fill"` (gentle)

**Hardcoded defaults that need updating:**
- `SettingsViewModel.swift:9` — `avatarId = "person.circle.fill"` → `"avatar_classic"`
- `SettingsViewModel.swift:10` — `coachAppearanceId = "person.circle.fill"` → `"coach_sage"`
- `HomeViewModel.swift:11` — `avatarId = "avatar_default"` → `"avatar_classic"`
- `HomeViewModel.swift:173` — preview factory default `"avatar_default"` → `"avatar_classic"`

### Asset Naming Convention

Use this naming pattern for asset catalog entries:

**Avatar assets:** `avatar_{variant}_{state}`
- Examples: `avatar_classic_active`, `avatar_zen_celebrating`, `avatar_minimal_resting`
- Variants: `classic`, `minimal`, `zen`
- States: `active`, `resting`, `celebrating`, `thinking`, `struggling`

**Coach assets:** `coach_{variant}_{expression}`
- Examples: `coach_sage_welcoming`, `coach_mentor_thinking`, `coach_guide_gentle`
- Variants: `sage`, `mentor`, `guide`
- Expressions: `welcoming`, `thinking`, `warm`, `focused`, `gentle`

**Selection thumbnails** (for picker views): `avatar_{variant}` and `coach_{variant}` (default/welcoming state)

### Architecture Compliance

- **MVVM + @Observable** — no Combine, no ObservableObject
- **Swift Testing** (`@Test`, `@Suite`, `#expect()`) — NOT XCTest
- **XcodeGen** — `project.yml` is source of truth; asset catalog changes may need entries there
- **Feature-first structure** — files stay in their existing feature folders
- **Theme via environment** — `@Environment(\.coachingTheme)` — never hardcode colors
- **GRDB** for database — async read/write patterns with `databaseManager.dbPool`

### Key Files to Modify

| File | Change |
|------|--------|
| `ios/sprinty/Resources/Assets.xcassets/` | Add Avatars/ and Coach/ image sets |
| `ios/sprinty/Core/Utilities/AvatarOptions.swift` | Change IDs from SF Symbols to asset names |
| `ios/sprinty/Core/State/AvatarState.swift` | Add asset name helper method |
| `ios/sprinty/Features/Home/Views/AvatarView.swift` | State-aware image loading (already uses `Image(avatarId)`, just needs state-aware name) |
| `ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift` | Update default avatarId from `"avatar_default"` to `"avatar_classic"` |
| `ios/sprinty/Features/Coaching/Views/CoachCharacterView.swift` | Add coachAppearanceId param, custom image, remove gradient background |
| `ios/sprinty/Features/Coaching/Views/CoachingView.swift` | Pass coachAppearanceId to CoachCharacterView |
| `ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift` | Add coachAppearanceId property, load from DB |
| `ios/sprinty/Features/Coaching/Models/CoachExpression.swift` | Replace `sfSymbolName` with `assetName(for:)` method |
| `ios/sprinty/Features/Onboarding/Views/AvatarSelectionView.swift` | Image() instead of Image(systemName:) |
| `ios/sprinty/Features/Onboarding/Views/CoachNamingView.swift` | Image() instead of Image(systemName:), remove Circle fill |
| `ios/sprinty/Features/Settings/Views/SettingsAvatarSelectionView.swift` | Image() instead of Image(systemName:) |
| `ios/sprinty/Features/Settings/Views/SettingsCoachAppearanceView.swift` | Same + remove Circle fill |
| `ios/sprinty/Features/Settings/Views/SettingsView.swift` | Thumbnail images |
| `ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift` | Update default avatarId/coachAppearanceId values |
| `ios/sprinty/Services/Database/Migrations.swift` | Add v7 migration for ID remapping |

### Database Migration Strategy

Users who installed with SF Symbol IDs need migration. Register as `"v7"` (next after existing `v6`) in `Migrations.swift`. Use separate UPDATE statements per column because `"person.circle.fill"` maps to different targets:
```swift
migrator.registerMigration("v7") { db in
    // Avatar column: SF Symbol → asset catalog name
    try db.execute(sql: "UPDATE UserProfile SET avatarId = 'avatar_classic' WHERE avatarId IN ('person.circle.fill', '')")
    try db.execute(sql: "UPDATE UserProfile SET avatarId = 'avatar_minimal' WHERE avatarId = 'person.circle'")
    try db.execute(sql: "UPDATE UserProfile SET avatarId = 'avatar_zen' WHERE avatarId = 'figure.mind.and.body'")
    // Coach column: SF Symbol → asset catalog name
    try db.execute(sql: "UPDATE UserProfile SET coachAppearanceId = 'coach_sage' WHERE coachAppearanceId IN ('person.circle.fill', '')")
    try db.execute(sql: "UPDATE UserProfile SET coachAppearanceId = 'coach_mentor' WHERE coachAppearanceId = 'brain.head.profile'")
    try db.execute(sql: "UPDATE UserProfile SET coachAppearanceId = 'coach_guide' WHERE coachAppearanceId = 'leaf.circle.fill'")
}
```

### CoachCharacterView Data Flow (New Plumbing Required)

Currently `CoachCharacterView` only receives a `CoachExpression` — it has no idea which coach variant (sage/mentor/guide) the user selected. The variant is needed to build asset names like `"coach_sage_thinking"` vs `"coach_mentor_thinking"`.

**Required data flow:**
1. `CoachingViewModel` — add `coachAppearanceId: String` property, loaded from `UserProfile` via the same DB read pattern used by `HomeViewModel.loadUserProfile()`
2. `CoachingView.swift:22` — change `CoachCharacterView(expression:)` to `CoachCharacterView(expression:, coachAppearanceId:)`
3. `CoachCharacterView` — accept `coachAppearanceId` parameter, use it in `expression.assetName(for: coachAppearanceId)`

### Image Rendering Differences from SF Symbols

SF Symbols auto-scale with `.font(.system(size:))`. Custom images need explicit `.frame(width:height:)` sizing:
- AvatarView: already uses `frame(width: size, height: size)` — works as-is
- CoachCharacterView: uses `portraitSize` (100pt / 80pt at XL+) — works as-is
- Selection views: currently use `.font(.system(size: 48))` for SF Symbols — change to `.frame(width: 48, height: 48)` with `.resizable().scaledToFill()`
- Settings thumbnails: use `.font(.system(size: 20))` — change to `.frame(width: 20, height: 20)` with `.resizable().scaledToFill()`

### Placeholder Art Files for Development

If commissioned art is not yet delivered, create solid-color circle placeholder PNGs at correct resolutions so the code integration can proceed. The placeholder files will be swapped with final art when delivered. Use distinctly different colors per state/expression so visual correctness is verifiable.

### Art Spec Summary (For Commissioning Brief)

**Avatar specs:**
- 5 states (active, resting, celebrating, thinking, struggling) x 3 variants
- Simplified painterly style, posture/silhouette emphasis
- 120pt display width (provide 2x: 240px, 3x: 360px)
- Earthy warm palette, gender-neutral
- Each state differs in posture and saturation level

**Coach specs:**
- 5 expressions (welcoming, thinking, warm, focused, gentle) x 3 variants
- Semi-realistic/painterly watercolor-adjacent style
- 100pt display width (provide 2x: 200px, 3x: 300px)
- Natural earth-tone clothing
- Thinking is highest-priority (displays every streaming turn)

### What NOT To Do

- Do NOT use Lottie animations — the architecture mentions it but current implementation uses SwiftUI crossfade with static images. Keep it simple.
- Do NOT use `Image(systemName:)` for any avatar/coach art — all must become `Image("assetName")` from asset catalog
- Do NOT add Combine or ObservableObject
- Do NOT change the AvatarState enum cases or CoachExpression enum cases
- Do NOT remove saturation modifiers from AvatarView — they add programmatic emphasis on top of art
- Do NOT break the CoachExpression(mood:) initializer used by the streaming pipeline
- Do NOT name the migration anything other than `"v7"` — GRDB migrations must be sequential
- Do NOT forget to handle empty-string avatar/coach IDs in migration (onboarding creates profiles with `""` defaults)

### Previous Story Intelligence

**From Story 4.5 (Avatar Customization):**
- AvatarOptions shared constants are in `Core/Utilities/AvatarOptions.swift` — this is the single source of truth for option IDs
- Database updates go through `SettingsViewModel.updateAvatar()` and `SettingsViewModel.updateCoachAppearance()`
- WidgetCenter reload is triggered automatically on avatar/coach change
- CoachNamingView already uses `AvatarOptions.coachOptions` for shared constants
- `@State private var viewModel` pattern used in Settings (not @StateObject)
- Guards prevent re-selecting the same option (no unnecessary DB writes)

**From Git History (Stories 4.1-4.5):**
- Commit pattern: `feat: Story 4.X — Description with code review fixes`
- All avatar state logic is in `AvatarState.swift` with `saturationMultiplier` computed property
- AvatarView uses `.id(state)` + `.transition(.opacity)` for crossfade
- CoachCharacterView uses `.id(expression)` + `.transition(.opacity)` for crossfade
- 419 tests passing as of Story 4.5

### Performance Considerations

- Image assets should be optimized PNGs (not oversized) — target under 50KB per asset at 3x
- At ~60 avatar + ~30 coach assets, total bundle size increase should be under 3MB
- SwiftUI `Image()` from asset catalog is GPU-cached — no performance concern for crossfade
- 60fps requirement (NFR7) — crossfade between two static images is trivially smooth

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.6 lines 1223-1253]
- [Source: _bmad-output/planning-artifacts/architecture.md — Avatar System, Asset Management]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR14-21, Avatar States, Art Direction]
- [Source: _bmad-output/planning-artifacts/prd.md — FR31-33, FR76, NFR7, NFR24, NFR37]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Build compilation error: v7 migration placed outside `registerMigrations()` function body. Fixed indentation.
- Migration test failure: profile inserted after v7 already ran. Fixed by using partial migrator (v1-v6), inserting old data, then running full migrations.
- 434 tests passing after all fixes.

### Completion Notes List
- **Task 1:** Created 36 image sets (18 avatar + 18 coach) with colored-circle placeholder PNGs at correct 2x/3x resolutions. Avatar: 15 state-specific + 3 thumbnails. Coach: 15 expression-specific + 3 thumbnails. project.yml unchanged (Assets.xcassets already included).
- **Task 2:** Updated AvatarOptions IDs from SF Symbols to asset catalog names. Added `AvatarOptions.assetName(for:state:)` helper for state-aware asset lookup.
- **Task 3:** Updated AvatarView to build state-specific asset name via `AvatarOptions.assetName()`. Kept saturation modifier, crossfade animation (.id/.transition) unchanged. Updated previews from "avatar_default" to "avatar_classic".
- **Task 4:** Added `coachAppearanceId` property to CoachingViewModel, loaded from UserProfile in `loadMessagesAsync()`. Added parameter to CoachCharacterView. Replaced `sfSymbolName` computed property on CoachExpression with `assetName(for:)` method. Removed gradient Circle ZStack — art provides its own visual treatment. Crossfade animation preserved via `.id(expression)`.
- **Task 5:** All 5 selection views updated: AvatarSelectionView, SettingsAvatarSelectionView, SettingsCoachAppearanceView, CoachNamingView, SettingsView thumbnails. Replaced `Image(systemName:)` with `Image()`, removed `.font(.system(size:))`, added `.resizable().scaledToFill().frame()`. Glow ring overlays preserved.
- **Task 6:** Updated defaults — SettingsViewModel: "avatar_classic"/"coach_sage", HomeViewModel: "avatar_classic" (both field and preview factory).
- **Task 7:** Added v7 migration in Migrations.swift. 6 UPDATE statements map all SF Symbol IDs → asset catalog names for both columns. Empty string default handled.
- **Task 8:** Updated 5 existing test files (OnboardingViewModelTests, OnboardingRoutingTests, UserProfileTests, SettingsViewModelCustomizationTests, HomeViewModelTests) to use new asset IDs. Created ArtAssetIntegrationTests.swift with 15 new tests covering asset name mapping, CoachExpression.assetName, migration correctness, and CoachingViewModel loading. All 434 tests pass.
- **Task 9:** Manual verification items — require simulator/device testing by developer.

### Change Log
- 2026-03-24: Story 4.6 implementation complete (Tasks 1-8). Placeholder art assets created, all SF Symbol references migrated to asset catalog names, v7 database migration added, 15 new tests, all 434 tests passing.
- 2026-03-24: Code review fixes — OnboardingViewModelTests:135 used avatar ID as coach appearance (fixed to "coach_sage"), HomeViewModelTests createProfile helper used non-standard defaults (fixed to "avatar_classic"/"coach_sage"), added project.pbxproj to File List.

### File List
- ios/sprinty/Resources/Assets.xcassets/Avatars/ (new — 18 image sets with 36 PNGs + Contents.json)
- ios/sprinty/Resources/Assets.xcassets/Coach/ (new — 18 image sets with 36 PNGs + Contents.json)
- ios/sprinty/Core/Utilities/AvatarOptions.swift (modified — new asset IDs + assetName helper)
- ios/sprinty/Features/Home/Views/AvatarView.swift (modified — state-aware image loading, preview updates)
- ios/sprinty/Features/Home/ViewModels/HomeViewModel.swift (modified — default avatarId)
- ios/sprinty/Features/Coaching/Models/CoachExpression.swift (modified — sfSymbolName → assetName(for:))
- ios/sprinty/Features/Coaching/Views/CoachCharacterView.swift (modified — custom image, removed gradient)
- ios/sprinty/Features/Coaching/Views/CoachingView.swift (modified — pass coachAppearanceId)
- ios/sprinty/Features/Coaching/ViewModels/CoachingViewModel.swift (modified — coachAppearanceId property)
- ios/sprinty/Features/Onboarding/Views/AvatarSelectionView.swift (modified — custom image)
- ios/sprinty/Features/Onboarding/Views/CoachNamingView.swift (modified — custom image)
- ios/sprinty/Features/Settings/Views/SettingsAvatarSelectionView.swift (modified — custom image)
- ios/sprinty/Features/Settings/Views/SettingsCoachAppearanceView.swift (modified — custom image)
- ios/sprinty/Features/Settings/Views/SettingsView.swift (modified — thumbnail images)
- ios/sprinty/Features/Settings/ViewModels/SettingsViewModel.swift (modified — default IDs)
- ios/sprinty/Services/Database/Migrations.swift (modified — v7 migration)
- ios/sprinty.xcodeproj/project.pbxproj (modified — added ArtAssetIntegrationTests.swift)
- ios/Tests/Features/ArtAssetIntegrationTests.swift (new — 15 tests)
- ios/Tests/Features/OnboardingViewModelTests.swift (modified — updated IDs)
- ios/Tests/Features/OnboardingRoutingTests.swift (modified — updated IDs)
- ios/Tests/Features/Home/HomeViewModelTests.swift (modified — updated default)
- ios/Tests/Features/Settings/SettingsViewModelCustomizationTests.swift (modified — updated IDs)
- ios/Tests/Models/UserProfileTests.swift (modified — updated IDs)
