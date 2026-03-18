---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation']
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/ux-design-specification.md'
---

# sprinty - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for sprinty, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Users can initiate a coaching conversation at any time from the home screen
FR2: Users can engage in multi-turn text-based coaching conversations with streaming AI responses
FR3: The system can operate in Discovery Mode — facilitating exploration through probing questions, pattern surfacing, and values archaeology for users without clear goals
FR4: The system can operate in Directive Mode — providing confident, specific action steps with contingency plans for users with defined goals (paid tier)
FR5: The system can transition naturally between Discovery Mode and Directive Mode within a conversation as user needs evolve
FR6: The system can surface patterns and connections across multiple past conversations during active coaching sessions
FR7: The Challenger capability can push back on user decisions, provide alternative perspectives, and stress-test reasoning (non-negotiable, cannot be disabled)
FR8: The system can generate contingency plans alongside primary recommendations (Plan B and Plan C)
FR9: Users can view past conversation summaries and key moments
FR10: The system can adapt coaching tone and intensity based on user state and engagement patterns
FR11: The system can generate and store conversation summaries with key moments, emotions, decisions, and topics after each conversation
FR12: The system can retrieve the most relevant past conversation summaries based on topic and recency when starting a new conversation
FR13: The system can maintain structured user profiles with core facts (values, goals, domain state, personality traits)
FR14: The system can tag conversations and goals by life domain in the backend
FR15: The system can handle long-gap retrieval for users with irregular engagement patterns (days to weeks between conversations)
FR16: Users can set goals and break them into actionable steps through coaching conversations
FR17: Users can create sprints with configurable duration (1-4 weeks)
FR18: Users can view their current sprint with progress at a glance (steps completed/total)
FR19: Users can mark sprint steps as complete
FR20: Users can perform daily check-ins (quick pulse, not mandatory)
FR21: Users can choose their check-in cadence (daily or weekly)
FR22: The system can create lightweight sprints for users with minimal goals (single action items)
FR23: New users can complete onboarding in under two minutes through four steps: welcome moment, avatar selection, name your coach, first coaching conversation
FR24: The onboarding coaching conversation can deliver value to users with no stated problem (cold-start capable)
FR25: The system can communicate clinical boundary transparency during onboarding ("I'm your coach, not your therapist")
FR26: Users can view their avatar in its current state on the home screen
FR27: Users can view their current sprint status and progress on the home screen
FR28: Users can initiate a coaching conversation from the home screen via a primary action
FR29: Users can view their most recent check-in or coaching insight on the home screen
FR30: Users can select a basic avatar style during onboarding
FR31: The avatar can display in 3-5 states that mirror the user's coaching state (active, resting, celebrating, thinking, struggling)
FR32: The avatar can animate between states with smooth transitions
FR33: Users can customize their avatar appearance within available options at any time (during onboarding and from settings)
FR34: Users can manually pause all coaching nudges, check-ins, and goal tracking
FR35: The system can suggest pausing when it detects sustained high-intensity engagement
FR36: The system can reflect pause state in the avatar and home screen UI
FR37: The system can distinguish between healthy pause and disengagement (Drift Detection)
FR38: The system can send gentle re-engagement nudges after configurable periods of inactivity outside of Pause Mode
FR39: The system can classify every coaching response with a safety level (Green/Yellow/Orange/Red) inline with the coaching output
FR40: The system can adapt coaching tone based on safety classification (Yellow: coach with care, suggest professional support)
FR41: The system can pause all coaching activities and present professional resources on Orange/Red classification
FR42: The system can strip gamification and avatar activity from the UI during Orange/Red states
FR43: The system can provide a post-crisis re-engagement flow when users return after a boundary event
FR44: The system can log all boundary response events for compliance tracking
FR45: The system can run automated safety regression tests against clinical edge-case prompts before every deployment
FR46: Users can receive push notifications for daily check-ins at a user-configurable time
FR47: Users can receive push notifications for sprint milestones
FR48: Users can receive pause suggestions via push notification
FR49: Users can receive gentle re-engagement nudges via push notification
FR50: The system can enforce a hard cap of 2 notifications per day with priority ordering
FR51: Users can configure notification preferences (check-in time, mute non-safety notifications)
FR52: The system can suppress all non-safety notifications during Pause Mode
FR53: Users can access the full coaching product on the free tier with a lightweight cloud model
FR54: Users can subscribe to the paid tier for premium model coaching depth via in-app purchase
FR55: The system can route coaching requests to the appropriate model tier (free/paid) via the backend proxy
FR56: The system can enforce invisible soft guardrails on daily session volume without exposing usage counters to users
FR57: The system can transition naturally when soft guardrails are reached ("We've covered a lot today. Let's let these insights settle.")
FR58: Safety features can operate identically regardless of subscription tier
FR59: Users can have all personal data (conversation summaries, embeddings, profiles, sprint state, avatar state) stored on-device in encrypted local storage
FR60: Users can have coaching conversations processed via cloud API with zero-retention provider agreements
FR61: Users can delete all their data from the app
FR62: The system can display clear privacy communication during onboarding
FR63: The backend proxy can route requests to multiple LLM providers with automatic failover on provider outage
FR64: The backend proxy can protect API keys (keys never in app binary)
FR65: The backend proxy can enforce tier-based model routing and soft guardrail logic
FR66: The backend proxy can collect usage analytics for monitoring
FR67: The system can swap cloud model providers server-side without requiring an app update
FR68: Users can add a small home screen widget displaying avatar state and sprint progress
FR69: Users can add a medium home screen widget displaying avatar, sprint name, next action, and a tap target to open the coach
FR70: Users can view the home screen, avatar, sprint progress, and past conversation summaries while offline
FR71: Users can mark sprint steps as complete while offline with sync when connectivity returns
FR72: The system can display a non-intrusive offline indicator when coaching conversations are unavailable
FR73: Users can correct the AI's understanding of their situation through conversation and the system updates its stored profile accordingly
FR74: The system can gracefully handle cloud provider failure mid-conversation — partial responses are preserved, failover to secondary provider resumes generation, and the user sees a seamless or minimally interrupted experience
FR75: Users can browse and navigate their past conversation history with summaries and key moments
FR76: Users can change their avatar style and customization at any time from settings
FR77: The system can gradually reduce AI-initiated coaching interactions (nudges, check-in prompts, suggestions) as a user demonstrates increasing self-reliance over time (Autonomy Throttle)
FR78: The system can track engagement source data for every interaction (AI-initiated vs user-initiated, notification-triggered vs organic) to power Autonomy Throttle analysis from day one
FR79: Users can access coaching disclaimers, privacy information, and terms of service at any time from app settings
FR80: Users can name their coach during onboarding and change the coach name at any time from settings

### NonFunctional Requirements

NFR1: Coaching response time-to-first-token must be under 1.5 seconds from user message submission
NFR2: Streaming coaching responses must render incrementally — users see text appearing within 1.5 seconds, full response generation may take 5-10 seconds
NFR3: Multi-provider failover must detect primary provider failure and reroute within 5 seconds
NFR4: App cold launch to home screen must complete within 3 seconds on iPhone 12 or newer
NFR5: Local RAG retrieval (embedding search + summary fetch) must complete within 500ms
NFR6: Push notification delivery from trigger event to device must occur within 60 seconds under normal conditions
NFR7: Avatar state transitions (Lottie animations) must render at 60fps on iPhone 12 or newer
NFR8: Widget updates must reflect current coaching state within 15 minutes of app background refresh
NFR9: All on-device data (SQLite database, RAG embeddings, user profiles) must be encrypted at rest using iOS Data Protection (NSFileProtectionComplete)
NFR10: All network communication between app and backend proxy must use TLS 1.3
NFR11: API keys for LLM providers must never be stored in or accessible from the app binary — all provider communication routed through backend proxy
NFR12: Authentication tokens must be stored in iOS Keychain, not UserDefaults or local storage
NFR13: Cloud LLM provider agreements must include zero-retention clauses — conversation data must not be used for model training
NFR14: User data deletion (FR61) must be complete and irreversible within 24 hours of request — no residual data in local storage, backend logs, or provider systems
NFR15: Boundary Response Compliance events must be logged with append-only server-side storage with audit trail — logs are append-only and include timestamps and event metadata for compliance review
NFR16: Safety regression test suite must run in an isolated environment — test prompts must never interact with production user data or models
NFR17: Backend proxy architecture must support horizontal scaling to handle 10x user growth (1K → 10K active users) without architectural changes
NFR18: Local SQLite + sqlite-vec must maintain query performance with up to 10,000 conversation summaries and embeddings per user (approximately 2 years of daily use)
NFR19: Backend proxy must support adding new LLM providers without code changes to the app (server-side configuration only)
NFR20: Push notification infrastructure must support batch delivery to 25K+ devices without delivery degradation
NFR21: All UI elements must support VoiceOver with meaningful labels — coaching conversations, sprint progress, avatar state, and navigation must be fully accessible via screen reader
NFR22: All text must support Dynamic Type (iOS text size settings) — coaching conversations, sprint steps, check-in prompts, and navigation must scale with user font size preferences
NFR23: Touch targets must meet Apple HIG minimum of 44x44 points for all interactive elements
NFR24: Color usage must not be the sole indicator of state — avatar states, sprint progress, and safety classifications must be distinguishable without color perception (shape, label, or pattern alternatives)
NFR25: Coaching conversation text must maintain WCAG 2.1 AA contrast ratio (4.5:1 for body text, 3:1 for large text) in both light and dark mode
NFR26: Backend proxy must support simultaneous integration with at least 2 LLM providers (primary + fallback) with provider-agnostic request/response mapping
NFR27: StoreKit 2 integration must handle subscription state changes (purchase, renewal, cancellation, grace period) with server-side receipt validation
NFR28: Apple Push Notification service (APNs) integration must handle token refresh, delivery failures, and device unregistration gracefully
NFR29: Sentry SDK integration must capture crash reports, performance traces, and custom events without impacting app performance (< 1% CPU overhead)
NFR30: Railway deployment must support zero-downtime deploys with automatic rollback on health check failure
NFR31: Overall system availability must be 99.5% measured monthly (backend proxy + at least one LLM provider operational)
NFR32: On-device features (home screen, sprint progress, conversation history, avatar, widgets) must be 100% available regardless of network state
NFR33: The system must handle network transitions (WiFi → cellular, connectivity loss/recovery) without losing conversation state or requiring app restart
NFR34: Failed sprint step completions (offline sync) must retry automatically on connectivity restoration with conflict resolution
NFR35: The system must recover gracefully from app backgrounding/foregrounding mid-conversation — conversation context preserved, streaming response resumable or restartable
NFR36: The system must support iOS standard backup/restore mechanisms (iCloud backup, device migration) for all on-device coaching data by default, with a user-facing option to exclude coaching data from iCloud backup
NFR37: The system must respect the iOS "Reduce Motion" accessibility setting — when enabled, replace Lottie animations with simple crossfades and keep avatar functional but static
NFR38: The coaching system must adapt to cultural context — coaching advice, goal frameworks, and success definitions must not assume Western-centric models of career, family, success, or personal development. The system must ask about cultural context during intake rather than assuming defaults.

### Additional Requirements

- **Starter Template (CRITICAL)**: Xcode default SwiftUI App template with manual MVVM project structure (Swift 6.x, iOS 17+, @Observable, async/await) + Go 1.23+ with net/http standard library (zero third-party framework, built-in ServeMux). Monorepo with top-level `/ios` and `/server` directories, shared `/docs`.
- **App Groups Setup (BLOCKING — Day 1)**: SQLite database must live in App Group shared container from day one for WidgetKit extension access. Retrofitting later means migrating database file location for existing users.
- **sqlite-vec + GRDB Integration (Week 1 spike)**: sqlite-vec requires custom SQLite build with static library compilation (iOS sandbox restriction). Benchmark harness as Week 1 deliverable — 10K synthetic embeddings, measure query latency/memory at 1K/5K/10K thresholds.
- **SQLite Migration Strategy (BLOCKING — Day 1)**: GRDB DatabaseMigrator with versioned, sequential, idempotent migrations running on every app launch. All Phase 2 fields must be pre-populated as null in MVP schema.
- **Embedding Model**: all-MiniLM-L6-v2 converted to Core ML, 384 dimensions, ~22MB, on-device/free/offline-capable.
- **Railway Deployment**: Watch `server/` subdirectory, zero-downtime rolling restarts, health check on `GET /health`, pre-deploy hook gates on CI pass (safety regression suite). Multi-stage Docker build with alpine final stage including CA certificates.
- **GitHub Actions CI/CD**: `ios.yml` (Swift tests → build on ios/ changes), `server.yml` (Go tests → safety regression suite 50+ prompts → Railway deploy on server/ changes). Safety regression suite 2-4 minute timeout.
- **Three Environments**: Local (localhost:8080, iOS Simulator), Staging (Railway staging, device testing), Production (Railway production).
- **Multi-Provider LLM Architecture**: Anthropic (primary), OpenAI, Gemini, Kimi K2. Provider interface as architectural core. Zero-retention clauses contractual. Model quality gap validation in Week 2.
- **SSE Streaming Pipeline**: Server parses provider-specific structured output, emits clean SSE format with `event: token` and `event: done` (includes safetyLevel, domainTags, degraded, usage).
- **System Prompt Versioning**: Modular sections, server-side assembly, content-hash auto-versioning, provider-specific variants for structured output, rollback = deploy old sections.
- **JWT Auth Flow**: Device UUID (Keychain-persisted) → register with StoreKit receipt → JWT with 30-day expiry → refresh before expiry. Stateless server verification. Phase 2 account linking designed now, deferred implementation.
- **API Contract** (`docs/api-contract.md`): `POST /v1/chat` (SSE streaming), `GET /v1/prompt/{version}`, `POST /v1/auth/register`, `POST /v1/auth/refresh`, `GET /health`. Shared test fixtures validate both iOS and Go against contract.
- **Wire Format Standards**: camelCase JSON, ISO 8601 dates, lowercase snake_case enums, omit null fields, arrays always arrays, booleans never 0/1.
- **Database Schema (6 GRDB record types)**: ConversationSession, Message, ConversationSummary (with 384-dim embedding), UserProfile, Sprint, SprintStep.
- **Server Logging**: slog structured JSON — request lifecycle (Info), provider failover (Warn), safety classification (Info/compliance), provider errors (Warn), SSE lifecycle (Debug).
- **iOS Logging**: os.Logger — RAG retrieval (Debug), memory pipeline failures (Error), state transitions (Debug), user actions (Info).
- **Compliance Logging**: Append-only, event metadata only (no conversation content), audit trail capability.
- **Safety Regression Suite**: 50+ clinical edge-case prompts, benchmark methodology (quality thresholds not pass/fail), runs pre-deploy in CI.
- **@Observable AppState Singleton**: isOnline, tier, coachingMode, safetyLevel, activeSprint, isPaused, computed ExperienceContext. Injected via SwiftUI Environment. No singletons, no service locators — injection only.
- **Error Handling Two-Tier**: Global errors → AppState (networkUnavailable, authExpired, providerError). Local errors → ViewModel-scoped. One `AppError` enum.
- **Swift 6 Concurrency**: ViewModels `@MainActor @Observable`, Services `Sendable`, Streaming `AsyncThrowingStream<ChatEvent, Error>`, GRDB DatabasePool for thread safety. Forbidden: `DispatchQueue.main.async`, force-unwrapping, raw `print()`.
- **Soft Guardrails**: Server tracks daily session count per device JWT, returns coaching-style wind-down (never error), app receives guardrail signal in `done` event.
- **Cost Tracking**: ~$0.015/user/month free tier, $2-5K/month at 10K paid users. Cost-aware usage tracking from start.
- **Gzip Compression**: Supported on chat payloads, 60-80% reduction (critical for cellular).
- **Conversation History Truncation**: iOS sends last ~20-30 messages per request.
- **Apple Privacy Manifest**: Required for App Store submission, must declare all data collection, requires iCloud backup decision.
- **StoreKit 2**: Receipt validation pipeline, subscription tier flows from StoreKit → JWT claims → server tier middleware.
- **Local Notifications Only (MVP)**: APNs deferred to Phase 2. MVP uses UNUserNotificationCenter on-device.
- **Sentry Integration**: Both iOS (`sentry-cocoa`) and Go (`sentry-go`) clients.
- **Implementation Sequence**: Week 1 first half (server scaffold + iOS networking + App Groups), Week 1 second half (sqlite-vec spike + benchmarks), Week 2 (provider interface + Anthropic + real streaming + prompt v1 + model quality gap), Week 2-3 (complete chat + safety regression), Week 3+ (RAG pipeline + everything else).

### UX Design Requirements

UX-DR1: Implement `CoachingTheme` struct with semantic token system containing all color, typography, spacing, corner radius, and animation tokens as defined in the UX specification
UX-DR2: Create four distinct color palettes: Home Light (warm restful #F4F2EC-#EDE8E0), Home Dark (#181A16-#141612), Conversation Light (#F8F5EE-#F0ECE2), Conversation Dark (#1C1E18-#181A14) with warm-forward design principle
UX-DR3: Establish Home Scene Palette with tokens: homeBackground, homeTextPrimary, homeTextSecondary, avatarGlow, avatarGradient, insightBackground, sprintTrack, sprintProgress, primaryAction, primaryActionText — all with light/dark variants
UX-DR4: Define Conversation View Palette with tokens: coachingBackground, coachDialogue, userDialogue, userAccent, coachPortraitGradient, coachPortraitGlow, coachNameText, coachStatusText, dateSeparator, inputBorder, sendButton — all with light/dark variants
UX-DR5: Implement Pause Mode Palette as desaturated override: light mode reduces saturation, dark mode shifts to near-monochrome warmth, avatar retains gentle color/glow
UX-DR6: Create Safety Tier Palette system with relative theme transformations: Green (no change), Yellow (warmth increase + subtle desaturation), Orange (noticeable desaturation + gamification hidden), Red (significant desaturation + minimal elements + crisis resources prominent)
UX-DR7: Establish Typography Scale using San Francisco system font with 12 semantic text styles (coachVoice, userVoice, coachVoiceEmphasis, insightText, sprintLabel, coachName, coachStatus, dateSeparator, homeGreeting, homeTitle, sectionHeading, primaryButton)
UX-DR8: Define 8pt-based spacing scale with 9 semantic tokens (screenMargin 20pt, dialogueTurn 24pt, dialogueBreath 8pt, homeElement 16pt, insightPadding 16pt, coachCharacterBottom 16pt, inputAreaTop 12pt, sectionGap 32pt)
UX-DR9: Establish corner radius tokens: container 16pt, button 16pt, input 20pt pill-shaped, avatar 50% circle, small 8pt, sprintTrack 3pt
UX-DR10: Design ambient mode shifts in conversation background: Discovery (warmer/golden), Directive (cooler/focused), Challenger (deeper/grounded), safety states override all coaching mode shifts
UX-DR11: Validate all text/background color combinations against WCAG AA across all four palettes and all safety tier overrides
UX-DR12: Dark mode design must feel like warm dark room — passing the "11pm after a hard day" test
UX-DR13: Conversation dark mode slightly warmer/brighter than home, coach character as primary warmth source, dialogue in warm off-white
UX-DR14: Commission coach character illustration in semi-realistic/painterly watercolor-adjacent style, gender-neutral default with 2-3 selectable variants
UX-DR15: Design five coach expression states: Welcoming, Thinking, Warm (Discovery), Focused (Directive), Gentle (Safety)
UX-DR16: Coach Thinking expression is highest-priority art asset (displays every turn), all five distinguishable at 100pt width
UX-DR17: Coach character portrait assets at 100pt default (80pt at XL+) with 2x/3x resolution, glow treatment per light/dark mode
UX-DR18: Portrait wearing natural earth-tone clothing matching coaching space palette, character integrated with environment
UX-DR19: User avatar in simplified painterly style (same family as coach, less detail), emphasis on posture/silhouette, 120pt on home scene
UX-DR20: Five avatar state visuals: Active (upright, full saturation), Resting (relaxed, gentle desaturation), Celebrating (joyful, brightest), Thinking (contemplative, neutral), Struggling (slightly hunched, muted but warm)
UX-DR21: Avatar assets in 5 states × 2-3 variants × 2x/3x resolution with SwiftUI crossfade transitions
UX-DR22: Build `CoachCharacterView` — pinned sticky at conversation top, 100pt width, portrait + name + status, five expression states via state-driven asset swap, accessibility labels with expression announcements
UX-DR23: Implement `DialogueTurnView` with variants: coach (unmarked prose), user (12pt indent + left-border accent), memory reference (italic 0.7 opacity), coach emphasis (semibold spans), pending (with indicator)
UX-DR24: DialogueTurnView spacing: 24pt between turns, 8pt within multi-paragraph, VoiceOver prefixed "Coach says:"/"You said:" with memory/pending hints
UX-DR25: Develop `TextInputView` — pill-shaped input (20pt radius) + circular send button (32pt), multi-line up to 4 lines, placeholder "What's on your mind...", accessibility labels
UX-DR26: Create `HomeSceneView` Layout B (Compact & Personal): HStack avatar + greeting, VStack InsightCard + SprintPathView + check-in + CoachActionButton, four progressive disclosure stages
UX-DR27: Define `InsightCard` — rounded container 16pt radius, RAG-informed insight content, one insight refreshed per session, read-only
UX-DR28: Build `AvatarView` at 64pt on home scene with five state animations, state from coaching backend, SwiftUI crossfade, celebrating triggered by step completion
UX-DR29: Implement `CoachActionButton` — full-width gradient button, "Talk to your coach", always enabled even during Pause, tapping deactivates Pause
UX-DR30: Create `SprintPathView` — compact (5pt trail on home) and expanded (tappable step nodes), accessibility sprint progress values, suppressed during Pause
UX-DR31: Design `SprintDetailView` — header + expanded path + goals list with coach context notes + step completion toggle + haptic + avatar celebration + narrative retro
UX-DR32: Build `SearchOverlayView` — search icon in coach area, expands to text field + results count + navigation, FTS5 search, results highlighted inline, fully offline
UX-DR33: Implement `MemoryView` ("What Your Coach Knows") — Profile Facts (editable/deletable), Key Memories (browsable/deletable), Domain Tags (removable), natural language display, edits take effect next turn
UX-DR34: Create `SettingsView` — SwiftUI Form with coaching typography: Appearance, Your Coach, Notifications, Privacy (reassuring tone), About
UX-DR35: Design `OnboardingWelcomeView` — 3-second brand moment, centered wordmark + tagline, earthy gradient, auto-advances
UX-DR36: Build `AvatarSelectionView` — "This is you" header, 2-3 options with glow ring selection, per-step persistence, works in both onboarding and settings
UX-DR37: Implement `CoachSelectionView` — "Meet your coach" header, 2-3 options with portrait + name + personality hint, "Same coach, new look" confirmation in settings
UX-DR38: Create `SafetyStateManager` — theme transformer receiving on-device classification every turn, applies relative transformations, sticky minimum (Orange/Red holds 3 turns or Green×2), outputs modified theme + visibility flags
UX-DR39: Design `PauseModeTransition` — 1200ms desaturation, avatar → resting, insight → Pause message, sprint muted, reduced motion = instant, VoiceOver announcement
UX-DR40: Build `OfflineIndicator` — subtle connectivity status near coach status, states: online (invisible), offline, reconnecting, reconnected (fades)
UX-DR41: Implement `PendingMessageIndicator` — subtle icon beside user turn when pending, fades when sync complete
UX-DR42: Create `DateSeparatorView` — centered text ("Today"/"Yesterday"/absolute date), VoiceOver landmark
UX-DR43: Develop `ConversationView` composition — CoachCharacterView (pinned) → ScrollView with LazyVStack pagination → OfflineIndicator → TextInputView, scroll to bottom on open
UX-DR44: Implement coaching-as-onboarding four-step flow under 2 minutes: Welcome → Avatar Selection → Coach Selection → Conversation with warm first line, force-quit resilience
UX-DR45: Design daily return journey — app opens → Home Scene RAG pre-fetch → user taps button → Conversation View crossfade → date separator + RAG-informed greeting
UX-DR46: Create one continuous conversation model — no inbox, no thread management, scrolling up shows previous history with date separators, onboarding conversation is turn one forever
UX-DR47: Implement sprint creation in-conversation only — coach proposes goal + steps → user agrees/modifies/declines → sprint created → conversation continues, unconfirmed proposals re-surfaced
UX-DR48: Design Pause Mode — one gesture, no confirmation, immediate respect, "Rest well", UI quiets, zero notifications, tapping "Talk to your coach" deactivates, zero "you've been away" messaging
UX-DR49: Build safety boundary shifts — on-device classification every turn, Green/Yellow/Orange/Red with graduated UI response, sticky minimum, transitions immediate
UX-DR50: Implement dual search — ask coach (RAG → memory reference) and direct search (FTS5 → highlighted inline results)
UX-DR51: Design memory surfaces — LLM structured output `memory_reference: true` flag → DialogueTurnView italic at 0.7 opacity
UX-DR52: Build conversation history export — Settings → Privacy → Export → plain text markdown → iOS Share Sheet, warm language, no PDF (Phase 2)
UX-DR53: Implement offline conversation gracefully — conversation opens, coach welcoming + offline indicator, user can write, pending indicator, auto-send on reconnect
UX-DR54: Design first-open-of-day daily greeting — RAG-informed context-aware greeting (not generic), lightweight generation from recent summary, fallback warm default
UX-DR55: Build memory gap handling — coach responds honestly "I don't have that front of mind — can you remind me?" as trust-building pattern
UX-DR56: Verify color contrast across all four palettes × four safety tiers meeting WCAG AA (4.5:1 body, 3:1 large, 3:1 non-text)
UX-DR57: Implement Dynamic Type from xSmall through Accessibility XXXL — all tokens use iOS semantic sizes, coach portrait scales, layout adaptations at XXL+/XXXL
UX-DR58: Ensure reduced motion support — all animations instant when enabled, coach expressions instant swap, haptic only for celebrations
UX-DR59: Build VoiceOver support with programmatic labels on all custom components — coach character, dialogue turns, input, buttons, avatar, insight, sprint, date separators, search, memory, safety states, Pause announcements
UX-DR60: Establish VoiceOver navigation order — Home scene (greeting → avatar → insight → sprint → button), Conversation (coach → turns → input), Sprint detail (header → progress → goals → steps)
UX-DR61: Validate color blindness accessibility across all 4 palettes using Xcode simulator (deuteranopia, protanopia, tritanopia)
UX-DR62: Ensure touch targets ≥44pt, gesture alternatives (tap + scroll only), no timeouts, SwiftUI focus rings
UX-DR63: Target iPhone only for MVP (SE 375pt through Pro Max 430pt), iPad/Android deferred Phase 2
UX-DR64: Implement fluid screen size adaptation — iPhone SE (16pt margins, 80pt portrait), Standard/Pro Max (20pt margins, 100pt portrait), Pro Max content column capped at 390pt centered
UX-DR65: Conversation view maximum content width 390pt centered on Pro Max screens (>393pt) for reading comfort
UX-DR66: Enforce Calm Budget — ≤3 haptic types, ≤1 push/day, zero during Pause, zero sounds, ≤1 home insight, avatar changes by coaching state only
UX-DR67: Test Calm Budget adherence — >3 haptics or >1 notification or unprompted avatar change = design bug
UX-DR68: Push notification design with Calm Budget — emotion-safe copy, no badge count, no audio, deep-link to conversation, zero "come back" messaging
UX-DR69: Notification patterns — check-in nudge, sprint milestone, pause suggestion, no return-after-absence notification
UX-DR70: Eliminate spinners/progress bars — coach thinking expression instead, progressive home loading, instant local data, warm messaging
UX-DR71: Warm error messaging with recovery — network failure, LLM error, RAG failure (silent), safety failure (fail-safe Yellow), export failure, sprint save failure, database corruption
UX-DR72: Intentional empty states — Home Stage 1, no sprint (absent), no check-in (absent), first conversation, long gap, new memory view, search no results
UX-DR73: Error handling principles — stay in-character, no technical details, always offer path forward, fail toward safety
UX-DR74: Four animation timing constants — instant (0.0s safety), quick (0.25s functional), standard (0.4s character), slow (1.2s emotional)
UX-DR75: Apply timing constants to specific animations — 20+ animation targets mapped to timing constants with specific durations
UX-DR76: Spring curve for avatar celebration, ease-in-out for character/threshold crossings, all respect reduced motion
UX-DR77: Threshold crossing animation (home → conversation) — gentle crossfade with slight upward motion, 400-500ms, test on iPhone 12/SE for frame drops
UX-DR78: Transition rhythm between emotional states — Vulnerability→Action (2-3 beats), Celebration→Challenge (session boundary), Compassion→Resilience (user signals), etc.
UX-DR79: UI copy word blacklist — never use "user," "session," "data," "error," "failed," "invalid," "submit," "retry," "loading," "processing," "notification," "sync," "cache," "timeout," "cancel"
UX-DR80: All UI copy speaks as coach — warm, specific, human tone in all copy including settings labels and error messages
UX-DR81: 12 critical user journeys designed end-to-end (First Launch, Daily Return, Sprint Creation, Sprint Detail, Safety Boundary, Pause Mode, Search, Memory, Customization, Sprint Check, Export, Offline)
UX-DR82: Every journey has one-step entry from home scene, conversations absorb complexity, data creation in conversation / viewing in dedicated views
UX-DR83: Memory edit experience — Profile Facts editable/deletable inline, Key Memories browsable/deletable, Domain Tags removable, natural language, "Your data stays on your phone" footer
UX-DR84: Profile edit takes effect next turn — coach may acknowledge "I noticed you updated your priorities"
UX-DR85: Confirmation patterns — no confirmation for send/complete/pause/avatar, soft for coach appearance, warm for delete memory, informational for export, serious multi-step for delete account
UX-DR86: Component build priority tiers — Tier 1 weeks 1-4 (Theme, DialogueTurn, TextInput, CoachCharacter, HomeScene, Avatar, CoachAction, SafetyState), Tier 2 weeks 5-6 (CheckIn, SprintPath, SprintNarrative), Tier 3 weeks 7-14 (remaining components)
UX-DR87: Week 1-2 foundation — CoachingTheme + 4 instances, DialogueTurnView all variants, TextInputView, CoachCharacterView with placeholder, DateSeparatorView, basic ConversationView
UX-DR88: Weeks 3-4 core loop — HomeSceneView 4 stages, InsightCard 4 variants, AvatarView placeholder, CoachActionButton, threshold transition, SafetyStateManager
UX-DR89: Weeks 5-6 sprint system — SprintPathView compact + expanded, SprintDetailView with context notes, step completion + haptic + celebration
UX-DR90: Weeks 7-8 onboarding — OnboardingWelcomeView, AvatarSelectionView, CoachSelectionView, per-step persistence
UX-DR91: Weeks 9-10 settings & memory — SettingsView, MemoryView, export flow
UX-DR92: Weeks 11-12 polish — SafetyTransitionAnimator, PauseModeTransition, SearchOverlayView, OfflineIndicator, PendingMessageIndicator, final art assets
UX-DR93: Weeks 13-14 testing & refinement — palette tuning on-device, VoiceOver + Dynamic Type + reduced motion testing, performance on iPhone 12, WCAG verification, color blindness simulation
UX-DR94: Four global state combination rules — safety always wins, Pause suppresses sprint/gamification, offline doesn't affect visual state, only one ambient state at a time
UX-DR95: Layout principles — generous 20pt margins, vertical rhythm, centered avatar/coach, organic feel from 8pt grid
UX-DR96: Spacing density patterns — Home (medium 16-20pt), Conversation (low 24pt/1.65 line height), Sprint detail (medium), Settings (standard Form), Onboarding (very low)
UX-DR97: Typography principles — one typeface many treatments, 1.65 line height on dialogue, coach/user distinguished by color not type, Dynamic Type fully supported
UX-DR98: Tier 1 validation — onboarding emotional container + first conversation for all personas including Curious Skeptic
UX-DR99: Tier 2 validation — home scene calm/purposeful duality, memory surface personal not algorithmic
UX-DR100: Tier 3 validation — sprint display, safety transitions, ambient shifts, Pause Mode
UX-DR101: Five-person conversation test — "What kind of app is this?" Nobody says "chatbot" = success
UX-DR102: Device matrix testing — iPhone 15 daily, SE weekly, Pro Max bi-weekly, iPhone 12 milestones, iPad smoke test week 13-14
UX-DR103: Accessibility checklist at milestones — VoiceOver eyes-closed, Dynamic Type XL/XXXL, SE + Accessibility XL extreme, reduced motion, color blindness, contrast, touch targets, keyboard/switch control, Safety × Accessibility cross-test
UX-DR104: Testing schedule — Week 2 (VoiceOver conversation, Dynamic Type), Week 4 (full VoiceOver flow, all sizes, SE), Week 8 (onboarding VoiceOver, contrast audit), Week 12 (complete checklist), Week 13-14 (full regression)

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 1 | Initiate coaching conversation from home screen |
| FR2 | Epic 1 | Multi-turn text coaching with streaming AI |
| FR3 | Epic 2 | Discovery Mode |
| FR4 | Epic 2 | Directive Mode with contingency plans |
| FR5 | Epic 2 | Natural transition between modes |
| FR6 | Epic 3 | Surface patterns across past conversations |
| FR7 | Epic 2 | Challenger capability |
| FR8 | Epic 2 | Contingency plan generation (Plan B/C) |
| FR9 | Epic 3 | View past conversation summaries and key moments |
| FR10 | Epic 2 | Adapt coaching tone based on user state |
| FR11 | Epic 3 | Generate/store conversation summaries |
| FR12 | Epic 3 | Retrieve relevant past summaries |
| FR13 | Epic 3 | Maintain structured user profiles |
| FR14 | Epic 3 | Tag conversations/goals by life domain |
| FR15 | Epic 3 | Long-gap retrieval |
| FR16 | Epic 5 | Set goals through coaching conversations |
| FR17 | Epic 5 | Create sprints (1-4 weeks) |
| FR18 | Epic 5 | View current sprint progress |
| FR19 | Epic 5 | Mark sprint steps complete |
| FR20 | Epic 5 | Daily check-ins |
| FR21 | Epic 5 | Configurable check-in cadence |
| FR22 | Epic 5 | Lightweight single-action sprints |
| FR23 | Epic 1 | Onboarding in under 2 minutes |
| FR24 | Epic 1 | Cold-start capable first conversation |
| FR25 | Epic 1 | Clinical boundary transparency in onboarding |
| FR26 | Epic 4 | View avatar on home screen |
| FR27 | Epic 4 | View sprint status on home screen |
| FR28 | Epic 1 | Initiate conversation from home via primary action |
| FR29 | Epic 4 | View recent check-in/insight on home screen |
| FR30 | Epic 1 | Select avatar during onboarding |
| FR31 | Epic 4 | Avatar 3-5 states mirroring coaching state |
| FR32 | Epic 4 | Avatar animate between states |
| FR33 | Epic 4 | Customize avatar anytime |
| FR34 | Epic 7 | Manually pause all coaching |
| FR35 | Epic 7 | System suggests pausing |
| FR36 | Epic 7 | Pause state reflected in avatar/home UI |
| FR37 | Epic 7 | Distinguish healthy pause vs disengagement |
| FR38 | Epic 7 | Re-engagement nudges after inactivity |
| FR39 | Epic 6 | Safety classification every response (Green/Yellow/Orange/Red) |
| FR40 | Epic 6 | Adapt tone based on safety classification |
| FR41 | Epic 6 | Pause coaching + present resources on Orange/Red |
| FR42 | Epic 6 | Strip gamification during Orange/Red |
| FR43 | Epic 6 | Post-crisis re-engagement flow |
| FR44 | Epic 6 | Log boundary events for compliance |
| FR45 | Epic 6 | Safety regression tests before deployment |
| FR46 | Epic 9 | Push notifications for check-ins |
| FR47 | Epic 9 | Push notifications for sprint milestones |
| FR48 | Epic 9 | Pause suggestions via notification |
| FR49 | Epic 9 | Re-engagement nudges via notification |
| FR50 | Epic 9 | Hard cap 2 notifications/day |
| FR51 | Epic 9 | Configure notification preferences |
| FR52 | Epic 9 | Suppress non-safety notifications during Pause |
| FR53 | Epic 1 | Full coaching on free tier |
| FR54 | Epic 8 | Paid tier subscription via IAP |
| FR55 | Epic 8 | Route to appropriate model tier |
| FR56 | Epic 8 | Invisible soft guardrails |
| FR57 | Epic 8 | Natural transition at guardrail limits |
| FR58 | Epic 6 | Safety identical across tiers |
| FR59 | Epic 1 | All personal data on-device encrypted |
| FR60 | Epic 1 | Cloud API with zero-retention |
| FR61 | Epic 11 | Delete all data |
| FR62 | Epic 1 | Privacy communication during onboarding |
| FR63 | Epic 10 | Multi-provider failover |
| FR64 | Epic 1 | Backend proxy protects API keys |
| FR65 | Epic 8 | Tier-based model routing + guardrail logic |
| FR66 | Epic 10 | Usage analytics collection |
| FR67 | Epic 10 | Swap providers server-side without app update |
| FR68 | Epic 10 | Small home screen widget |
| FR69 | Epic 10 | Medium home screen widget |
| FR70 | Epic 10 | Offline home/avatar/sprint/history viewing |
| FR71 | Epic 10 | Offline sprint step completion with sync |
| FR72 | Epic 10 | Non-intrusive offline indicator |
| FR73 | Epic 3 | Correct AI understanding via conversation |
| FR74 | Epic 10 | Graceful provider failure mid-conversation |
| FR75 | Epic 3 | Browse past conversation history |
| FR76 | Epic 4 | Change avatar from settings |
| FR77 | Epic 7 | Autonomy Throttle |
| FR78 | Epic 7 | Track engagement source data |
| FR79 | Epic 11 | Access disclaimers/privacy/ToS from settings |
| FR80 | Epic 1 | Name coach during onboarding, change anytime |

## Epic List

### Epic 1: First Coaching Conversation
A new user downloads the app, completes onboarding in under 2 minutes, and has their first meaningful coaching conversation with streaming AI responses. Includes project scaffold (Xcode SwiftUI + Go monorepo), App Groups setup, SQLite + GRDB migrations, JWT device auth, single-provider SSE streaming, onboarding flow, CoachingTheme, ConversationView, CoachCharacterView, DialogueTurnView, TextInputView, sqlite-vec spike, CI/CD pipeline.
**FRs covered:** FR1, FR2, FR23, FR24, FR25, FR28, FR30, FR53, FR59, FR60, FR62, FR64, FR80

### Epic 2: Coaching Intelligence & Modes
Users experience nuanced coaching that adapts to their needs — exploratory Discovery Mode for those finding their way, confident Directive Mode with contingency plans for those ready to act, and a Challenger that stress-tests their thinking.
**FRs covered:** FR3, FR4, FR5, FR7, FR8, FR10

### Epic 3: Memory, Continuity & Understanding
The coach remembers past conversations, surfaces relevant patterns, maintains a deep understanding of the user across sessions, and users can browse their conversation history and correct the coach's understanding. Includes RAG pipeline, sqlite-vec, Core ML embedding model, conversation summaries, user profiles, SearchOverlayView, MemoryView.
**FRs covered:** FR6, FR9, FR11, FR12, FR13, FR14, FR15, FR73, FR75

### Epic 4: Home Experience & Avatar
Users see a personalized, calm home screen with their avatar reflecting their coaching state, a daily coaching insight, sprint progress at a glance, and can customize their avatar appearance anytime. Includes HomeSceneView, AvatarView (5 states), InsightCard, CoachActionButton, threshold crossing animation, art asset commissioning and integration.
**FRs covered:** FR26, FR27, FR29, FR31, FR32, FR33, FR76

### Epic 5: Sprint Goal System
Users can set goals through coaching conversations, create sprints with actionable steps, track daily progress, perform check-ins, and celebrate completions — all driven by the coach, not forms. Includes SprintPathView, SprintDetailView, step completion with haptic + avatar celebration, check-ins.
**FRs covered:** FR16, FR17, FR18, FR19, FR20, FR21, FR22

### Epic 6: Safety & Clinical Boundaries
Users are protected by real-time safety classification on every coaching response, with graduated responses from attentive coaching to crisis resources. Includes on-device classification, SafetyStateManager, graduated UI responses, post-crisis re-engagement, compliance logging, safety regression suite (50+ prompts in CI).
**FRs covered:** FR39, FR40, FR41, FR42, FR43, FR44, FR45, FR58

### Epic 7: Pause, Re-engagement & Autonomy
Users can pause all coaching activity with one gesture and return when ready without guilt. The system intelligently distinguishes healthy pauses from disengagement, sends gentle nudges, and gradually steps back as users grow more self-reliant (Autonomy Throttle).
**FRs covered:** FR34, FR35, FR36, FR37, FR38, FR77, FR78

### Epic 8: Premium Coaching & Monetization
Users can upgrade to premium coaching for deeper AI model capability via in-app purchase, while free users enjoy full product access with a lighter model. Soft guardrails manage session volume naturally. Includes StoreKit 2, tier-based model routing, guardrail signal in SSE done event.
**FRs covered:** FR54, FR55, FR56, FR57, FR65

### Epic 9: Notifications & Nudges
Users receive thoughtful, emotion-safe notifications for check-in reminders, sprint milestones, and pause suggestions — always within a strict calm budget of ≤1/day, zero during Pause Mode. Local notifications only for MVP (APNs deferred to Phase 2).
**FRs covered:** FR46, FR47, FR48, FR49, FR50, FR51, FR52

### Epic 10: Resilience, Offline & Widgets
Users can browse their home screen, sprint progress, and conversation history while offline, mark sprint steps complete with automatic sync, see seamless recovery from provider failures mid-conversation, and add home screen widgets. Includes multi-provider failover, WidgetKit, offline mode, usage analytics.
**FRs covered:** FR63, FR66, FR67, FR68, FR69, FR70, FR71, FR72, FR74

### Epic 11: Privacy, Settings & Data Control
Users have full control over their data — they can export conversation history, delete all data, and access privacy information, disclaimers, and terms of service. Includes SettingsView, conversation export (plain text markdown → Share Sheet), data deletion, Apple Privacy Manifest.
**FRs covered:** FR61, FR79

## Epic 1: First Coaching Conversation

A new user downloads the app, completes onboarding in under 2 minutes, and has their first meaningful coaching conversation with streaming AI responses.

### Story 1.1: Server Scaffold & Auth Endpoints

As a new user opening the app for the first time,
I want a secure backend that can authenticate my device,
So that my coaching experience is private from the start.

**Acceptance Criteria:**

**Given** the monorepo is initialized
**When** the project structure is created
**Then** it contains top-level `/ios`, `/server`, and `/docs` directories
**And** `docs/api-contract.md` is created as the single source of truth for all API endpoints, request/response schemas, SSE event formats, and error taxonomy
**And** `docs/fixtures/` contains shared test fixtures validating both iOS and Go against the contract

**Given** the Go server starts (Go 1.23+, net/http with built-in ServeMux, zero third-party frameworks)
**When** a client sends `GET /health`
**Then** the server responds with 200 OK

**Given** a new device
**When** it sends `POST /v1/auth/register` with a device UUID
**Then** the server returns a JWT with `{deviceId, userId: null, tier: "free", iat, exp}` (30-day expiry)

**Given** a registered device with a valid JWT
**When** it sends `POST /v1/auth/refresh` before expiry
**Then** a new JWT is returned with refreshed expiry

**Given** an unauthenticated request
**When** sent to any protected endpoint without a valid JWT
**Then** the server returns 401 Unauthorized

**Given** the server logging
**When** requests are processed
**Then** structured JSON logs are emitted via slog (request lifecycle at Info, errors at Warn)

### Story 1.2: iOS Project Foundation & Database

As a new user opening the app for the first time,
I want the app to silently create a secure device identity and local storage,
So that my data is encrypted and my identity persists across sessions.

**Acceptance Criteria:**

**Given** the iOS project is initialized
**When** the Xcode project is created
**Then** it uses SwiftUI App template with manual MVVM structure
**And** Swift 6.x with iOS 17+ deployment target
**And** all code compiles under Swift 6 strict concurrency checking with zero warnings
**And** @Observable macro is used for state management
**And** async/await structured concurrency is used throughout (no `DispatchQueue.main.async`, no force-unwrapping, no raw `print()`)

**Given** a user launches the app for the first time
**When** the app initializes
**Then** a unique device UUID is generated and stored in iOS Keychain
**And** the app registers with the server via `POST /v1/auth/register`
**And** the returned JWT is stored in iOS Keychain (not UserDefaults per NFR12)

**Given** the database initialization
**When** the app launches
**Then** the SQLite database is created in the App Group shared container (for WidgetKit access)
**And** NSFileProtectionComplete encryption is applied (NFR9)
**And** GRDB DatabaseMigrator runs versioned, sequential, idempotent migrations
**And** ConversationSession and Message tables are created
**And** all Phase 2 fields are pre-populated as null in the schema

**Given** the app is reinstalled
**When** the user launches the app
**Then** the device UUID persists from Keychain, maintaining identity continuity

**Given** a registered device
**When** the JWT approaches expiry
**Then** the app refreshes via `POST /v1/auth/refresh` and stores the new token

### Story 1.3: Design System & Coaching Theme

As a user,
I want the app to have a warm, inviting visual identity that feels like a safe coaching space,
So that the experience feels personal and calming, not like a generic tech app.

**Acceptance Criteria:**

**Given** the CoachingTheme is implemented
**When** applied to any view
**Then** all color tokens resolve correctly for both light and dark mode
**And** Home Light palette uses warm restful tones (#F4F2EC-#EDE8E0)
**And** Home Dark palette uses warm dark tones (#181A16-#141612, never cold/technical)
**And** Conversation Light palette uses #F8F5EE-#F0ECE2
**And** Conversation Dark palette uses #1C1E18-#181A14 with coach dialogue in warm off-white #C4C4B4 (never pure white #FFFFFF)

**Given** Dynamic Type is enabled at any size (xSmall through Accessibility XXXL)
**When** text renders using theme typography tokens
**Then** all 12 semantic text styles use iOS semantic sizes (Body, Subheadline, Footnote, Caption, Title)
**And** line height of 1.65 is maintained on dialogue text
**And** no fixed font sizes are used anywhere

**Given** the spacing scale is implemented
**When** layout renders on iPhone SE (375pt) through Pro Max (430pt)
**Then** screen margins are 20pt (16pt on SE), content flows naturally
**And** Pro Max content column is capped at 390pt centered

**Given** the UI copy standards (UX-DR79, UX-DR80)
**When** any UI text is written
**Then** the word blacklist is enforced: never use "user," "session," "data," "error," "failed," "invalid," "submit," "retry," "loading," "processing," "notification," "sync," "cache," "timeout," "cancel"
**And** all copy speaks as the coach — warm, specific, human tone including settings labels and error messages

### Story 1.4: Conversation View with Mock Streaming

As a user,
I want to type a message and see a streaming response from my coach,
So that the conversation feels natural and immediate.

**Acceptance Criteria:**

**Given** a user is on the conversation view
**When** they type a message and tap send
**Then** the message appears as a user turn (12pt indent + left-border accent)
**And** the coach character shifts to thinking expression
**And** an SSE connection opens to `POST /v1/chat` with valid JWT
**And** streaming tokens render incrementally as coach dialogue (unmarked prose)
**And** the coach character shifts to welcoming expression on response completion

**Given** an unauthenticated request to `/v1/chat`
**When** sent without a valid JWT
**Then** the server returns 401 and the app handles gracefully (re-auth or warm error message)

**Given** a conversation with multiple turns
**When** viewing the conversation
**Then** turns are spaced 24pt apart with 8pt within multi-paragraph turns
**And** a date separator shows at the top ("Today")
**And** the view scrolls to the latest message

**Given** VoiceOver is enabled
**When** navigating conversation turns
**Then** coach turns announce "Coach says: [content]"
**And** user turns announce "You said: [content]"
**And** the text input announces "Message your coach"
**And** the send button announces "Send message"

**Given** the user force-quits and reopens the app
**When** they return to the conversation
**Then** all previous messages are loaded from SQLite

### Story 1.5: Onboarding Flow

As a new user,
I want to complete a quick, delightful onboarding that introduces me to my coach,
So that I feel welcomed and ready for my first conversation in under 2 minutes.

**Acceptance Criteria:**

**Given** a user opens the app for the first time (no completed onboarding)
**When** the app launches
**Then** the OnboardingWelcomeView displays centered wordmark + tagline with earthy gradient
**And** it auto-advances after 3 seconds (VoiceOver: announces label and auto-advances)

**Given** the welcome view completes
**When** the avatar selection screen appears
**Then** 2-3 avatar options display as circular images (placeholder art — final art in Story 4.6)
**And** tapping one shows a glow ring selection indicator
**And** tapping confirm saves the selection and advances

**Given** the avatar is selected
**When** the coach selection screen appears
**Then** 2-3 coach options display with portrait + name + personality hint (placeholder art — final art in Story 4.6)
**And** the user can name their coach (custom text input)
**And** confirming saves selection and transitions to conversation (400-500ms crossfade)

**Given** the user enters their first conversation
**When** the coach sends the first message
**Then** the message is warm, non-generic, and works for users with no stated problem (cold-start)
**And** clinical boundary transparency is communicated naturally ("I'm your coach, not your therapist")
**And** privacy is communicated ("Your conversations stay on your device")

**Given** the user force-quits mid-onboarding
**When** they reopen the app
**Then** onboarding resumes from the last incomplete step

### Story 1.6: Real AI Coaching Integration

As a user,
I want my coaching conversation powered by a real AI,
So that I receive meaningful, personalized guidance from my first message.

**Acceptance Criteria:**

**Given** a user sends a message in a coaching conversation
**When** the server receives the chat request
**Then** it routes to the Anthropic provider (free tier model) via the provider interface
**And** assembles the system prompt from modular sections (base-persona + discovery)
**And** streams the response as SSE events (`event: token` with incremental text)
**And** the `event: done` includes safetyLevel, domainTags, and usage metadata

**Given** the provider interface
**When** implemented
**Then** it defines a common interface that all LLM providers implement
**And** Anthropic is the first concrete implementation (tool-use structured output)
**And** adding a new provider requires implementing the interface, not changing calling code

**Given** the provider returns a response
**When** the SSE stream completes
**Then** time-to-first-token is under 1.5 seconds (NFR1)
**And** the user sees text appearing incrementally (NFR2)
**And** no API keys are present in the app binary (all via backend proxy)

**Given** the system prompt is assembled
**When** a coaching conversation begins
**Then** the prompt includes the base persona and discovery mode sections
**And** a content hash version is generated for the prompt
**And** the conversation uses the prompt version from when it started

**Given** gzip compression is enabled
**When** the iOS app sends a chat request
**Then** the payload is compressed (60-80% reduction)

**Given** the Anthropic provider returns a 500 error
**When** the server handles the failure
**Then** the error is logged at Warn level
**And** the server returns a warm error to the client: `{"error": "provider_unavailable", "message": "Your coach needs a moment. Try again shortly.", "retryAfter": 10}`

**Given** the Anthropic provider returns a 429 rate limit
**When** the server handles the throttle
**Then** it returns the appropriate retryAfter value
**And** the iOS app displays: "Your coach needs a moment. Try again shortly." (UX-DR71)

**Given** the provider returns malformed structured output
**When** the server parses the response
**Then** it fails gracefully — partial response is preserved, safetyLevel defaults to Green, and an error is logged

### Story 1.7: sqlite-vec & Embedding Spike

As a developer,
I want to validate that sqlite-vec and the Core ML embedding model perform within requirements,
So that we confirm the memory architecture is viable before building on it.

**Acceptance Criteria:**

**Given** the sqlite-vec integration
**When** building the custom SQLite library
**Then** sqlite-vec is compiled as a static library (iOS sandbox restricts dynamic extensions)
**And** it integrates with GRDB's custom SQLite build
**And** it compiles and runs on both Simulator (x86) and device (ARM)

**Given** the all-MiniLM-L6-v2 Core ML model
**When** loaded on-device
**Then** it generates 384-dimension embeddings
**And** model size is approximately 22MB

**Given** the benchmark harness
**When** generating 10K synthetic embeddings
**Then** vector similarity query latency is measured at 1K, 5K, and 10K thresholds
**And** memory usage is measured at each threshold
**And** retrieval completes within 500ms at 10K embeddings (NFR5)
**And** results are documented for go/no-go decision

**Given** the spike fails performance thresholds (retrieval >500ms at 10K embeddings)
**When** results are reviewed
**Then** the performance ceiling is documented with the maximum viable embedding count
**And** if NFR5 cannot be met at 10K, proceed with recency-based retrieval for MVP and defer vector search to Phase 2
**And** Epic 3 Story 3.2 is adjusted accordingly (recency-only fallback, no vector search)

### Story 1.8: CI/CD Pipeline & Test Infrastructure

As a developer,
I want automated CI/CD pipelines that validate code quality and deploy safely,
So that every change is tested before it reaches users.

**Acceptance Criteria:**

**Given** GitHub Actions CI is configured
**When** changes are pushed to `ios/`
**Then** `ios.yml` runs: Swift tests → build verification

**Given** GitHub Actions CI is configured
**When** changes are pushed to `server/`
**Then** `server.yml` runs: Go tests → (safety regression suite placeholder) → Railway deploy trigger

**Given** the shared test fixtures in `docs/fixtures/`
**When** contract tests run
**Then** both iOS and Go test suites validate against the same fixtures
**And** changes to `docs/api-contract.md` require fixture updates first

**Given** Railway deployment
**When** a deploy is triggered
**Then** it watches the `server/` subdirectory
**And** uses multi-stage Docker build (Go build → alpine final stage with CA certificates)
**And** zero-downtime rolling restarts are used
**And** health check on `GET /health` gates the deploy
**And** automatic rollback triggers on health check failure (NFR30)

### Story 1.9: Home Screen Foundation

As a returning user,
I want to see a calm home screen with my avatar and a clear way to talk to my coach,
So that I have a welcoming starting point every time I open the app.

**Acceptance Criteria:**

**Given** a user who has completed onboarding
**When** they open the app
**Then** the home screen displays with their selected avatar (64pt), a warm greeting, and "Talk to your coach" button
**And** the app loads to home screen within 3 seconds (NFR4)

**Given** the user taps "Talk to your coach"
**When** the transition begins
**Then** a gentle crossfade with slight upward motion occurs (400-500ms, ease-in-out)
**And** the conversation view opens showing the continuous conversation thread

**Given** the user is in a conversation
**When** they navigate back
**Then** the home screen appears with a reverse transition (300ms)

**Given** VoiceOver is enabled
**When** the home screen renders
**Then** the avatar announces "Your avatar" with state value
**And** the button announces "Talk to your coach" with hint "Opens your coaching conversation"

**Given** Reduce Motion is enabled
**When** transitioning between home and conversation
**Then** transitions are instant (no animation)

## Epic 2: Coaching Intelligence & Modes

Users experience nuanced coaching that adapts to their needs — exploratory Discovery Mode for those finding their way, confident Directive Mode with contingency plans for those ready to act, and a Challenger that stress-tests their thinking.

### Story 2.1: Discovery Mode Coaching

As a user without clear goals,
I want my coach to facilitate exploration through probing questions and values archaeology,
So that I can discover what matters to me and find direction.

**Acceptance Criteria:**

**Given** a user is in a coaching conversation
**When** the coaching mode is Discovery
**Then** the system prompt includes the discovery mode section
**And** the coach asks probing questions, surfaces values, and explores rather than prescribes
**And** the conversation background subtly shifts warmer/more golden (UX-DR10)
**And** the `event: done` SSE payload includes `mode: "discovery"`

**Given** the conversation starts
**When** the user has not expressed a clear goal
**Then** the system defaults to Discovery Mode
**And** the coach explores the user's situation without pushing toward action

**Given** Discovery Mode is active
**When** the system prompt is assembled
**Then** it includes the `mode-discovery` section and excludes the `mode-directive` section

**Given** cultural context adaptation (NFR38)
**When** the coach facilitates discovery
**Then** coaching does not assume Western-centric models of career, family, or success
**And** the system asks about cultural context during intake rather than assuming defaults

### Story 2.2: Directive Mode with Contingency Plans

As a user with defined goals,
I want my coach to provide confident, specific action steps with backup plans,
So that I know exactly what to do and have a fallback if things don't work out.

**Acceptance Criteria:**

**Given** a user has expressed a clear goal or need for direction
**When** the coaching mode is Directive
**Then** the system prompt includes the directive mode section
**And** the coach provides confident, specific action steps (not hedging or vague)
**And** the coach generates contingency plans (Plan B and Plan C) alongside primary recommendations
**And** the conversation background subtly shifts cooler/more focused (UX-DR10)
**And** the `event: done` SSE payload includes `mode: "directive"`

**Given** the coach provides a recommendation
**When** the response includes contingency plans
**Then** Plan B and Plan C are clearly articulated with conditions for when to switch
**And** the contingency plans are specific to the user's situation (not generic)

### Story 2.3: Natural Mode Transitions

As a user whose needs evolve during a conversation,
I want the coach to transition naturally between exploration and direction,
So that the coaching adapts to where I am in real time without jarring shifts.

**Acceptance Criteria:**

**Given** a user starts in Discovery Mode
**When** they express a clear goal or ask for specific advice
**Then** the coach transitions naturally to Directive Mode within the same conversation
**And** the ambient background shift occurs smoothly (standard 0.4s timing)
**And** no UI interruption or mode indicator is shown to the user

**Given** a user is in Directive Mode
**When** they express uncertainty or want to explore a new topic
**Then** the coach transitions back to Discovery Mode naturally
**And** the transition feels conversational, not mechanical

**Given** multiple mode transitions occur in one conversation
**When** the conversation summary is generated
**Then** the mode used for each segment is captured in metadata

### Story 2.4: Challenger Capability

As a user making important decisions,
I want my coach to push back on my reasoning and offer alternative perspectives,
So that I stress-test my thinking before committing to a path.

**Acceptance Criteria:**

**Given** a user shares a decision or plan
**When** the Challenger capability activates
**Then** the coach pushes back constructively on the user's reasoning
**And** provides alternative perspectives the user may not have considered
**And** stress-tests assumptions without being dismissive or hostile
**And** the conversation background subtly shifts deeper/more grounded (UX-DR10)

**Given** the Challenger capability
**When** a user attempts to disable it (via conversation or settings)
**Then** it cannot be disabled (non-negotiable per FR7)
**And** the coach may acknowledge the discomfort but continues to provide balanced perspectives

**Given** the Challenger pushes back
**When** the user responds
**Then** the coach acknowledges the user's response and either deepens the challenge or transitions to support
**And** contingency planning follows naturally from challenged decisions (transition rhythm: Challenge → Support with immediate contingency per UX-DR78)

### Story 2.5: Adaptive Coaching Tone

As a user in different emotional and engagement states,
I want my coach to adapt its tone and intensity,
So that the coaching meets me where I am rather than using a one-size-fits-all approach.

**Acceptance Criteria:**

**Given** a user's engagement patterns and emotional state
**When** the system detects changes in user state
**Then** the coaching tone adjusts accordingly (more gentle when struggling, more direct when energized)
**And** intensity scales based on engagement patterns (backs off when user is less responsive)

**Given** the system prompt is assembled for a conversation
**When** user state data is available
**Then** the context-injection section includes the current user state data (engagement level, emotional markers, recent session intensity)
**And** tone adaptation is driven by the context-injection section content

**Given** the transition rhythm rules (UX-DR78)
**When** transitioning between emotional states
**Then** Vulnerability → Action includes 2-3 beats of acknowledgment before goals
**And** Celebration → Challenge waits for a full session boundary
**And** Compassion → Resilience waits for user to signal readiness

## Epic 3: Memory, Continuity & Understanding

The coach remembers past conversations, surfaces relevant patterns, maintains a deep understanding of the user across sessions, and users can browse their conversation history and correct the coach's understanding.

### Story 3.1: Conversation Summaries & Key Moments

As a user who has coaching conversations,
I want the system to automatically capture what we discussed — key moments, emotions, decisions, and topics,
So that important insights are preserved even as conversations grow long.

**Acceptance Criteria:**

**Given** a coaching conversation ends (user navigates away or session times out)
**When** the system processes the conversation
**Then** a ConversationSummary is generated containing: summary text, key moments, emotional markers, key decisions, and domain tags
**And** the summary is stored in SQLite (ConversationSummary table with all fields)
**And** domain tags categorize the conversation by life domain (career, relationships, health, finance, etc.)

**Given** the summary generation process
**When** processing a conversation
**Then** the summary captures the substance of the exchange, not just a transcript reduction
**And** key moments identify turning points, breakthroughs, or important realizations
**And** emotional markers note the user's emotional trajectory during the session

**Given** a user with many conversations over time
**When** summaries accumulate
**Then** query performance remains under 500ms with up to 10,000 summaries (NFR18)

### Story 3.2: Embedding Pipeline & Vector Storage

As a user,
I want my past conversations to be semantically searchable,
So that the coach can find relevant context even when I don't use the exact same words.

**Note:** This story builds on the sqlite-vec + Core ML spike validated in Story 1.7. The spike confirmed performance viability; this story builds the production embedding pipeline.

**Acceptance Criteria:**

**Given** a ConversationSummary is created
**When** the embedding pipeline processes it
**Then** the summary text is embedded using the all-MiniLM-L6-v2 Core ML model (384 dimensions, validated in Story 1.7)
**And** the embedding vector is stored in sqlite-vec alongside the summary
**And** the embedding is generated on-device (free, offline-capable)

**Given** the sqlite-vec storage (integrated in Story 1.7)
**When** querying for similar past conversations
**Then** vector similarity search returns ranked results
**And** retrieval completes within 500ms (NFR5) at up to 10,000 embeddings
**And** GRDB DatabasePool handles thread safety for concurrent reads/writes

**Given** the embedding pipeline fails
**When** processing a summary
**Then** the failure is logged at Error level (os.Logger)
**And** the summary is stored without an embedding (graceful degradation)
**And** the coach can still function using recency-based retrieval as fallback

### Story 3.3: User Profile & Domain State

As a user,
I want my coach to maintain an evolving understanding of who I am — my values, goals, personality, and life situation,
So that coaching is deeply personalized across every session.

**Acceptance Criteria:**

**Given** a user engages in coaching conversations
**When** the system identifies core facts about the user
**Then** the UserProfile record is created/updated with: coachName, values, goals, personalityTraits, and domainStates (JSON)
**And** domain states track the user's situation across life domains (career status, relationship context, health goals, etc.)

**Given** a coaching conversation begins
**When** the system assembles the chat request
**Then** the user profile is included in the request payload (`profile` field)
**And** the coach leverages profile data to personalize responses

**Given** domain tagging (FR14)
**When** conversations and goals are processed
**Then** they are tagged by life domain in the backend
**And** domain tags enable cross-domain pattern recognition

**Given** a user corrects the AI's understanding through conversation (FR73)
**When** the user says something like "No, that's not right — I actually left that job" or "You're misremembering, I said..."
**Then** the system detects the correction in the LLM structured output (`profile_update` field)
**And** the UserProfile record is updated accordingly
**And** the coach acknowledges the correction naturally in the conversation
**And** the `profile_update` field is added to `docs/api-contract.md` as part of the structured output schema (living document — updated when new fields are introduced)

### Story 3.4: RAG-Powered Contextual Coaching

As a user returning for a new conversation,
I want my coach to recall relevant past discussions and surface patterns I might not see,
So that every session builds on everything that came before.

**Acceptance Criteria:**

**Given** a user starts a new conversation
**When** the system prepares context
**Then** the most relevant past conversation summaries are retrieved via embedding similarity search based on recent topics and recency
**And** retrieved summaries are included in the chat request (`ragContext` field)
**And** the coach naturally references past conversations when relevant

**Given** the coach references a past conversation
**When** the LLM structured output includes `memory_reference: true`
**Then** the DialogueTurnView renders as italic at 0.7 opacity (UX-DR51)
**And** VoiceOver announces the hint "Referencing a past conversation"

**Given** a user with irregular engagement (days to weeks between conversations) (FR15)
**When** they return after a long gap
**Then** the system retrieves relevant context from before the gap
**And** the coach acknowledges the passage of time naturally

**Given** the coach cannot find relevant context
**When** the user references something not in memory
**Then** the coach responds honestly: "I don't have that front of mind — can you remind me?" (UX-DR55)

**Given** patterns exist across multiple conversations (FR6)
**When** the coach detects cross-session connections
**Then** it surfaces those patterns naturally ("I've noticed a theme across our last few conversations...")

**Given** a new day begins and the user opens the conversation (UX-DR54)
**When** the RAG pre-fetch generates a daily greeting
**Then** the first turn of the new day is a context-aware greeting informed by recent summaries (not generic "Good morning")
**And** the greeting appears with a date separator ("Today")
**And** generation is lightweight (from recent summary data, not a full LLM call, completes within 500ms)
**And** fallback if RAG is unavailable: warm default "What's on your mind?"

### Story 3.5: Conversation History Browsing

As a user,
I want to scroll through my past conversations and see summaries and key moments,
So that I can revisit important coaching exchanges anytime.

**Acceptance Criteria:**

**Given** a user is in the conversation view
**When** they scroll up past today's messages
**Then** previous conversation history loads with date separators marking passage of time
**And** loading uses LazyVStack pagination (imperceptible loading)
**And** the continuous conversation model is maintained — no inbox, no thread list, one continuous thread (UX-DR46)

**Given** past conversations in the history
**When** viewing them
**Then** summaries and key moments are accessible
**And** all history is stored locally and works fully offline

### Story 3.6: In-Conversation Search

As a user looking for a specific past exchange,
I want to search my conversation history by keyword,
So that I can quickly find what my coach and I discussed about a specific topic.

**Acceptance Criteria:**

**Given** a user is in the conversation view
**When** they tap the search icon in the coach character area
**Then** the SearchOverlayView expands with a text field, results count, up/down navigation, and dismiss button

**Given** the user types a search query
**When** FTS5 full-text search executes on local SQLite
**Then** results are highlighted inline in the conversation
**And** tapping up/down scrolls to the next/previous match
**And** results count displays "Result [n] of [total]"
**And** search completes in under 200ms

**Given** the search is active
**When** VoiceOver is enabled
**Then** the field announces "Search conversation history"
**And** results announce "Result [n] of [total]"

**Given** no results match
**When** the search completes
**Then** the empty state shows "No matches. Try asking your coach." (UX-DR72)

**Given** the device is offline
**When** the user searches
**Then** search works fully offline (FTS5 on local SQLite)

### Story 3.7: Memory View & Profile Editing

As a user,
I want to see what my coach knows about me and correct anything that's wrong,
So that I maintain control over how I'm understood and coaching stays accurate.

**Acceptance Criteria:**

**Given** the user navigates to "What Your Coach Knows" (via Settings)
**When** the MemoryView loads
**Then** it displays three sections: Profile Facts, Key Memories, and Domain Tags
**And** all data is displayed in natural language, not raw data

**Given** the Profile Facts section
**When** the user taps a fact
**Then** they can edit it inline
**And** a "Forget this?" option allows warm deletion (irreversible)
**And** edits take effect on the next coaching turn
**And** the coach may naturally acknowledge: "I noticed you updated your priorities" (UX-DR84)

**Given** the Key Memories section
**When** the user browses memories
**Then** they can delete individual memories
**And** deletion immediately removes the memory from RAG retrieval

**Given** the Domain Tags section
**When** the user views tags
**Then** they can remove individual tags

**Given** VoiceOver is enabled
**When** navigating the MemoryView
**Then** section headers are VoiceOver headings
**And** edit hints say "Double tap to edit"

**Given** the footer of the MemoryView
**When** displayed
**Then** it reads "Your data stays on your phone. You can export or delete everything anytime."

## Epic 4: Home Experience & Avatar

Users see a personalized, calm home screen with their avatar reflecting their coaching state, a daily coaching insight, sprint progress at a glance, and can customize their avatar appearance anytime.

### Story 4.1: Full Avatar State System

As a user,
I want my avatar to reflect my coaching state — active when I'm engaged, resting when I'm taking a break, celebrating when I hit milestones,
So that the app feels alive and connected to my journey.

**Acceptance Criteria:**

**Given** the AvatarView on the home screen (64pt)
**When** the user's coaching state changes
**Then** the avatar displays the correct state from five options: Active (upright, full saturation), Resting (relaxed, gentle desaturation), Celebrating (joyful, brightest saturation), Thinking (contemplative, neutral saturation), Struggling (slightly hunched, muted but warm tones)
**And** transitions between states use SwiftUI crossfade (standard 0.4s timing)

**Given** avatar state transitions
**When** animations play
**Then** they render at 60fps on iPhone 12 or newer (NFR7)

**Given** Reduce Motion is enabled (NFR37)
**When** an avatar state changes
**Then** the transition is instant (no animation)
**And** the avatar remains functional but static

**Given** VoiceOver is enabled
**When** the avatar state changes
**Then** the accessibilityValue updates to the current state name
**And** the state change is announced

**Given** the celebrating state
**When** triggered by a step completion
**Then** it plays briefly and returns to active
**And** a haptic fires on celebration (one of ≤3 haptic types per calm budget UX-DR66)

### Story 4.2: Home Scene Progressive Disclosure

As a user whose coaching journey deepens over time,
I want the home screen to reveal more information as I engage more,
So that it starts simple and grows with me without overwhelming me early on.

**Acceptance Criteria:**

**Given** a new user who just completed onboarding (Stage 1)
**When** the home screen renders
**Then** only the avatar (64pt), warm greeting, and "Talk to your coach" button are visible
**And** the empty state feels intentional: "Your story starts here" (UX-DR72)

**Given** the user has had at least one conversation with RAG-informed insight (Stage 2)
**When** the home screen renders
**Then** the InsightCard appears below the greeting area
**And** it displays a RAG-informed coaching insight (not generic)
**And** it refreshes once per completed session
**And** it is read-only (not tappable)

**Given** the user has an active sprint (Stage 3)
**When** the home screen renders
**Then** the SprintPathView (compact, 5pt trail) appears showing progress
**And** the most recent check-in summary appears below
**And** spacing follows home scene density (medium 16-20pt between elements)

**Given** the user is in Pause Mode (Stage 4)
**When** the home screen renders
**Then** the sprint display is muted (not removed)
**And** the insight card softens to a Pause message
**And** the avatar shows resting state
**And** the overall scene feels quiet and warm, not dead

**Given** VoiceOver navigation order on home scene
**When** navigating
**Then** order is: greeting → avatar → insight card → sprint → button (UX-DR60)

### Story 4.3: Daily Coaching Insight

As a returning user,
I want to see a personalized coaching insight on my home screen each day,
So that the app feels like my coach has been thinking about me.

**Acceptance Criteria:**

**Given** a user opens the app after a completed coaching session
**When** the home screen loads
**Then** the InsightCard displays a context-aware insight generated from RAG pre-fetch
**And** the insight uses `Font.insightText` (15pt Subheadline, 1.5 line height) inside a rounded container (16pt radius, `insightBackground`)

**Given** a new user with no conversations yet
**When** the InsightCard would display
**Then** it shows "Your coach is getting to know you..." (UX-DR72)

**Given** the RAG pre-fetch for the insight
**When** generating the daily insight
**Then** it completes within 500ms and does not make a network request to the LLM provider
**And** the insight is derived from recent conversation summaries (Story 3.4 provides RAG-informed daily greeting for conversation; this is the home screen counterpart)
**And** fallback if unavailable: warm default content

**Given** the InsightCard content
**When** VoiceOver reads it
**Then** it announces "Coach insight: [content]"

### Story 4.4: Sprint Progress on Home Screen

As a user with an active sprint,
I want to see my progress at a glance on the home screen,
So that I stay motivated without needing to dig into details.

**Acceptance Criteria:**

**Given** a user has an active sprint
**When** the home screen renders
**Then** the SprintPathView compact variant displays (5pt height trail metaphor)
**And** it's glanceable — understandable in under 2 seconds

**Given** VoiceOver is enabled
**When** the sprint progress renders
**Then** it announces "Sprint progress" with value "Step [n] of [total], day [n] of [total]"

**Given** no active sprint exists
**When** the home screen renders
**Then** the sprint area is absent (no placeholder, no "Start a sprint!" guilt)

**Given** the user is in Pause Mode
**When** the home screen renders
**Then** the sprint display is muted but not removed

### Story 4.5: Avatar Customization

As a user,
I want to change my avatar's appearance anytime from settings,
So that my avatar continues to feel like me as my preferences evolve.

**Acceptance Criteria:**

**Given** the user navigates to Settings → Appearance
**When** they select avatar customization
**Then** the AvatarSelectionView displays with 2-3 options (same as onboarding)
**And** the current selection is highlighted with a glow ring

**Given** the user selects a new avatar
**When** they confirm
**Then** the avatar updates immediately across the app (home screen, widgets)
**And** no confirmation dialog is needed (instant, no-friction per UX-DR85)

**Given** the user also wants to change the coach appearance
**When** they select coach customization
**Then** a soft confirmation displays: "Same coach, new look" (reassurance, not permission per UX-DR85)

### Story 4.6: Art Asset Commissioning & Integration

As a user,
I want polished, warm character illustrations for my avatar and coach,
So that the app feels crafted and personal, not like placeholder art.

**Acceptance Criteria:**

**Given** the art style direction (UX-DR14, UX-DR19)
**When** commissioning character illustrations
**Then** coach character uses semi-realistic/painterly watercolor-adjacent style with soft edges, organic textures, human warmth
**And** avatar uses simplified painterly style (same family as coach, less detail) with emphasis on posture/silhouette
**And** gender-neutral default appearance with 2-3 selectable variants for both coach and avatar

**Given** coach character assets (UX-DR15-18)
**When** delivered
**Then** five expression states are included: Welcoming, Thinking (highest priority — displays every turn), Warm (Discovery), Focused (Directive), Gentle (Safety)
**And** all five are clearly distinguishable at 100pt display width
**And** assets are at 100pt default width (80pt at accessibility XL+) with 2x and 3x resolution variants
**And** portrait includes natural earth-tone clothing matching coaching space palette

**Given** avatar assets (UX-DR20-21)
**When** delivered
**Then** five state visuals are included: Active, Resting, Celebrating, Thinking, Struggling
**And** assets are in 5 states × 2-3 appearance variants × 2x/3x resolution

**Given** the art assets are integrated
**When** replacing placeholder art
**Then** all views using placeholder art (onboarding, home, conversation) update to final assets
**And** SwiftUI crossfade transitions work correctly with final assets
**And** Reduce Motion fallback remains functional

## Epic 5: Sprint Goal System

Users can set goals through coaching conversations, create sprints with actionable steps, track daily progress, perform check-ins, and celebrate completions — all driven by the coach, not forms.

### Story 5.1: Sprint Creation Through Coaching

As a user discussing goals with my coach,
I want the coach to propose a sprint with clear steps based on our conversation,
So that I get an actionable plan without filling out forms.

**Acceptance Criteria:**

**Given** a coaching conversation where the user discusses goals
**When** the coach determines a sprint would be helpful
**Then** the coach proposes in-conversation: "Based on what we've discussed, here's what I think... [Goal + 3-5 Steps]"
**And** the user can respond naturally (agree, request changes, or decline)

**Given** the user agrees to the proposed sprint
**When** the sprint is confirmed
**Then** a Sprint record is created with name, startDate, endDate, and status
**And** SprintStep records are created with description, order, and completed=false
**And** the coach confirms: "Your sprint is live on your home scene"
**And** the conversation continues naturally

**Given** the user wants changes to the proposal
**When** they respond with modifications
**Then** the coach adjusts and re-proposes until the user is satisfied

**Given** the user declines the sprint
**When** they indicate they're not ready
**Then** the coach respects the decision and continues the conversation
**And** the unconfirmed proposal is re-surfaced next conversation: "Before we start, I had a sprint idea from our last conversation. Want to revisit it?" (UX-DR47)

**Given** sprint duration configuration (FR17)
**When** the coach proposes a sprint
**Then** duration is configurable from 1-4 weeks based on the goal scope

**Given** a user with minimal goals (FR22)
**When** the coach proposes a sprint
**Then** lightweight single-action sprints are supported (single step items)

**Given** the sprint proposal structured output
**When** the LLM generates a sprint proposal
**Then** the server emits an `event: sprint_proposal` SSE event with structured data: `{name, steps: [{description, order}], durationWeeks}`
**And** the iOS app parses this event and presents the proposal in the conversation flow
**And** user confirmation triggers Sprint and SprintStep record creation

**Given** a sprint save failure
**When** the database write fails
**Then** the coach handles in-character: "I had trouble saving that. Let me try again." (UX-DR71)
**And** the proposal is preserved for retry

### Story 5.2: Sprint Detail View

As a user with an active sprint,
I want to see my sprint details with steps, progress, and coach context,
So that I can track what I need to do and understand why each step matters.

**Acceptance Criteria:**

**Given** a user navigates to the sprint detail
**When** the SprintDetailView loads
**Then** it displays: header (title + timeline + expanded SprintPathView) → goals list (each with italic coach context note + steps with completion toggle) → narrative retro when complete

**Given** each sprint step
**When** displayed
**Then** it shows the step description with a completion toggle
**And** an italic coach context note in coach voice explains why this step matters

**Given** the expanded SprintPathView
**When** rendered in detail view
**Then** tappable step nodes with labels show the full sprint journey
**And** completed steps are visually distinct (not by color alone per NFR24)

**Given** VoiceOver is enabled
**When** navigating the sprint detail
**Then** navigation order is: header → progress → goals → steps (UX-DR60)

**Given** the user is in Pause Mode
**When** viewing sprint detail
**Then** the view is suppressed (not accessible during Pause per UX-DR30)

### Story 5.3: Sprint Step Completion

As a user working through a sprint,
I want to mark steps as complete and feel the satisfaction of progress,
So that I stay motivated and see my momentum building.

**Acceptance Criteria:**

**Given** a user taps the completion toggle on a sprint step
**When** the step is marked complete
**Then** the SprintStep record updates with completed=true and completedAt timestamp
**And** a haptic fires (one of ≤3 types per calm budget UX-DR66)
**And** the avatar briefly shifts to celebrating state then returns to active
**And** the SprintPathView updates to reflect progress

**Given** all steps in a sprint are completed
**When** the sprint reaches 100%
**Then** the sprint status updates to complete
**And** a narrative retro appears in the SprintDetailView summarizing the journey

**Given** a step completion triggers celebration
**When** the transition rhythm applies (UX-DR78)
**Then** Celebration → Challenge waits for a full session boundary (no Challenger in the milestone session)

**Given** the step completion animation
**When** Reduce Motion is enabled
**Then** the celebration animation is skipped (haptic only per UX-DR58)

### Story 5.4: Daily Check-ins

As a user,
I want to do quick daily check-ins with my coach,
So that I stay connected to my goals without needing a full coaching session.

**Acceptance Criteria:**

**Given** a user's configured check-in cadence (daily or weekly per FR21)
**When** the check-in time arrives
**Then** a check-in prompt is available (not mandatory — no guilt if skipped)

**Given** the user initiates a check-in
**When** they engage with the quick pulse
**Then** it's a brief interaction (not a full coaching conversation)
**And** the most recent check-in summary appears on the home screen (FR29)

**Given** the check-in cadence is configurable (FR21)
**When** the user adjusts in settings
**Then** they can choose daily or weekly cadence

**Given** no check-in has been done
**When** the home screen renders
**Then** the check-in area is absent (no "You missed your check-in!" guilt per UX-DR72)

## Epic 6: Safety & Clinical Boundaries

Users are protected by real-time safety classification on every coaching response, with graduated responses from attentive coaching to crisis resources. Includes on-device classification, SafetyStateManager, graduated UI responses, post-crisis re-engagement, compliance logging, safety regression suite.

### Story 6.1: On-Device Safety Classification

As a user,
I want every coaching response to be safety-classified in real time,
So that the app can protect me if I'm in distress without sending my data to external systems.

**Acceptance Criteria:**

**Given** the coach generates a response
**When** the SSE `event: done` is received
**Then** it includes a `safetyLevel` field: Green, Yellow, Orange, or Red
**And** primary classification is server-side (inline with structured LLM output in the `done` event)
**And** secondary on-device classification via Apple Foundation Models serves as fallback for offline scenarios and low-confidence server classifications
**And** when both are available, the more cautious classification wins

**Given** the safety classification
**When** a Green level is returned
**Then** normal coaching continues with no UI changes

**Given** a Yellow classification
**When** the response is rendered
**Then** the coaching tone becomes more attentive and careful
**And** the coach naturally suggests professional support as an option

**Given** an Orange classification
**When** the response is rendered
**Then** coaching pauses
**And** gamification elements are hidden (sprint, celebrations)
**And** a compassionate redirect with professional resources is presented

**Given** a Red classification
**When** the response is rendered
**Then** crisis protocol activates
**And** emergency resources are prominently displayed
**And** all non-essential UI elements are removed

**Given** safety classification operates identically across tiers (FR58)
**When** a free or paid user triggers a safety boundary
**Then** the response is identical regardless of subscription tier

### Story 6.2: Safety State Manager & Theme Transformations

As a user in distress,
I want the app's visual environment to shift to match the seriousness of the moment,
So that the interface supports rather than distracts during sensitive situations.

**Acceptance Criteria:**

**Given** the SafetyStateManager receives a classification
**When** the safety level changes
**Then** relative theme transformations apply: Yellow (warmth increase + subtle desaturation), Orange (noticeable desaturation + gamification hidden), Red (significant desaturation + minimal elements + crisis resources)
**And** transitions are immediate (instant timing, 0.0s — no animation per UX-DR74)

**Given** a safety state is active (Orange or Red)
**When** subsequent turns return Green
**Then** the sticky minimum applies: Orange/Red holds for 3 turns or until Green×2 consecutive (UX-DR38)
**And** only `source: .genuine` classifications trigger sticky minimum; `source: .failsafe` clears immediately (UX-DR71)

**Given** the safety state
**When** it conflicts with other states (Pause Mode, coaching mode ambient)
**Then** safety always wins — overrides all other visual states (UX-DR94)

**Given** VoiceOver is enabled
**When** safety state changes
**Then** appropriate announcements are made: Yellow ("Coach is being more attentive"), Orange ("Connecting you with resources"), Red ("Safety resources available")

### Story 6.3: Post-Crisis Re-engagement

As a user returning after a safety boundary event,
I want a gentle, warm re-engagement experience,
So that I feel safe coming back without being reminded of the crisis or treated differently.

**Acceptance Criteria:**

**Given** a user returns after an Orange/Red boundary event
**When** they open the app
**Then** a post-crisis re-engagement flow activates
**And** the coach greets warmly without referencing the crisis explicitly
**And** coaching resumes gradually — starting in Discovery Mode regardless of previous mode

**Given** the re-engagement flow
**When** the first conversation turn occurs
**Then** safety classification continues normally (no forced Yellow/Orange state)
**And** the sticky minimum from the previous session has cleared

### Story 6.4: Compliance Logging

As a system operator,
I want all safety boundary events logged for compliance review,
So that there's an auditable record of how the system responded to safety situations.

**Acceptance Criteria:**

**Given** a safety classification of Yellow, Orange, or Red occurs
**When** the event is processed
**Then** a compliance log entry is created with: timestamp, safety level, event type, and metadata
**And** the log is append-only (cannot be modified or deleted per NFR15)
**And** NO conversation content is stored — only event metadata

**Given** compliance logs
**When** reviewed for audit
**Then** they provide a complete timeline of all boundary response events
**And** each entry includes sufficient metadata to understand the system's response

### Story 6.5: Safety Regression Suite

As a developer deploying updates,
I want automated safety regression tests to run before every deployment,
So that changes never degrade the system's ability to protect users.

**Acceptance Criteria:**

**Given** the safety regression suite
**When** triggered in CI (GitHub Actions `server.yml`)
**Then** 50+ clinical edge-case test prompts are sent to the system
**And** the suite runs in an isolated environment (never against production data per NFR16)
**And** execution completes within 2-4 minutes

**Given** the test methodology
**When** evaluating results
**Then** quality thresholds are used (benchmark approach, not binary pass/fail)
**And** results are logged for trend analysis

**Given** the regression suite
**When** it runs as a pre-deploy gate
**Then** deployment is blocked if quality thresholds are not met
**And** the suite must pass before Railway deploy proceeds
**And** the CI placeholder from Story 1.8 (`server.yml` safety regression suite placeholder) is replaced with the real suite execution

**Given** the classification failure scenario (UX-DR71)
**When** on-device classification fails or returns low confidence
**Then** the system fail-safes to Yellow (not Green)
**And** cloud escalation is triggered for verification

## Epic 7: Pause, Re-engagement & Autonomy

Users can pause all coaching activity with one gesture and return when ready without guilt. The system intelligently distinguishes healthy pauses from disengagement, sends gentle nudges, and gradually steps back as users grow more self-reliant.

### Story 7.1: Pause Mode Activation & Deactivation

As a user who needs a break,
I want to pause all coaching activity with one gesture and return whenever I'm ready,
So that the app respects my boundaries without making me feel guilty.

**Acceptance Criteria:**

**Given** a user wants to pause
**When** they activate Pause Mode (one gesture, no confirmation per UX-DR48)
**Then** Pause activates immediately
**And** the coach says "Rest well" (1 beat)
**And** the UI quiets: PauseModeTransition plays (1200ms desaturation per UX-DR39)
**And** the avatar shifts to resting state
**And** the insight card softens to a Pause message
**And** the sprint display is muted (not removed)
**And** all notifications are suppressed (zero during Pause per UX-DR66)

**Given** the user is in Pause Mode
**When** they tap "Talk to your coach"
**Then** Pause deactivates immediately
**And** a warm return greeting appears (zero "you've been away" messaging per UX-DR48)
**And** the UI restores (600ms deactivation per UX-DR75)

**Given** VoiceOver is enabled
**When** Pause activates
**Then** "Pause Mode activated" is announced (UX-DR39)
**And** deactivation announces similarly

**Given** Reduce Motion is enabled
**When** Pause activates/deactivates
**Then** palette change is instant (no animation per UX-DR58)

**Given** the coach detects sustained high-intensity engagement (FR35)
**When** the system suggests pausing
**Then** the coach asks in-conversation: "Want to take a breather?"
**And** the user can accept or decline naturally

### Story 7.2: Drift Detection & Re-engagement

As a user who has been away without pausing,
I want the system to gently check in without being pushy,
So that I'm reminded my coach is there without feeling pressured to engage.

**Acceptance Criteria:**

**Given** a user has been inactive for a configurable period outside of Pause Mode (FR38)
**When** the inactivity threshold is reached
**Then** a gentle re-engagement nudge is sent
**And** the nudge uses emotion-safe copy (UX-DR68): "Your coach has a thought for you"
**And** zero "come back" messaging

**Given** the system distinguishes pause types (FR37)
**When** evaluating inactivity
**Then** it differentiates between healthy pause (user chose Pause Mode) and disengagement (user simply stopped engaging)
**And** re-engagement nudges only fire for disengagement, not healthy pauses

**Given** the user returns after absence (no Pause Mode active)
**When** they open the app
**Then** no notification about absence is shown
**And** the daily greeting handles the return naturally (UX-DR48)

### Story 7.3: Autonomy Throttle & Engagement Tracking

As a user growing more self-reliant,
I want my coach to gradually step back — fewer nudges, fewer prompts, more trust in my own judgment,
So that the app helps me outgrow it rather than creating dependency.

**Acceptance Criteria:**

**Given** every user interaction from day one (FR78)
**When** the interaction occurs
**Then** engagement source data is tracked: AI-initiated vs user-initiated, notification-triggered vs organic
**And** this data is stored for Autonomy Throttle analysis

**Given** a user demonstrates increasing self-reliance over time (FR77)
**When** the Autonomy Throttle analyzes engagement patterns
**Then** AI-initiated coaching interactions gradually reduce (nudges, check-in prompts, suggestions)
**And** the reduction is gradual and natural — not an abrupt cutoff

**Given** the throttle is active
**When** the user initiates interactions themselves
**Then** the coach responds fully (throttle only affects AI-initiated interactions)
**And** user-initiated engagement is never limited by the throttle

## Epic 8: Premium Coaching & Monetization

Users can upgrade to premium coaching for deeper AI model capability via in-app purchase, while free users enjoy full product access with a lighter model. Soft guardrails manage session volume naturally.

### Story 8.1: StoreKit 2 Subscription Integration

As a user,
I want to upgrade to premium coaching through a simple in-app purchase,
So that I get deeper, more nuanced coaching powered by a more capable AI model.

**Acceptance Criteria:**

**Given** a free-tier user
**When** they choose to upgrade to premium
**Then** the StoreKit 2 purchase flow initiates
**And** on successful purchase, the subscription state updates
**And** the app sends the receipt to the server via `POST /v1/auth/register` (or refresh)
**And** the server validates the receipt and updates the JWT with `tier: "paid"`

**Given** subscription state changes (NFR27)
**When** purchase, renewal, cancellation, or grace period events occur
**Then** StoreKit 2 handles each state correctly with server-side receipt validation
**And** the JWT tier field updates accordingly

**Given** the user's JWT
**When** it includes `tier: "paid"`
**Then** subsequent chat requests route to the premium model
**And** the user experiences deeper coaching capability immediately

**Given** a user cancels their subscription
**When** the subscription period ends
**Then** the tier reverts to free gracefully
**And** the coach tone remains warm (no punitive messaging, no "you've been downgraded")

**Given** StoreKit receipt validation fails on the server
**When** the server cannot verify the receipt
**Then** the user remains on their current tier (fail-open for existing subscribers)
**And** receipt validation retries on next app launch
**And** the error is logged server-side for investigation

**Given** the user is in airplane mode during purchase
**When** the StoreKit purchase completes locally but server receipt validation is unavailable
**Then** the purchase is queued locally
**And** receipt validation occurs on next server connectivity
**And** the user sees no error (StoreKit 2 handles deferred transactions)

### Story 8.2: Tier-Based Model Routing

As a user on any tier,
I want my coaching requests routed to the appropriate AI model,
So that free users get capable coaching and premium users get the deepest model available.

**Acceptance Criteria:**

**Given** a chat request arrives at the server
**When** the JWT is verified
**Then** the `tier` field determines model selection
**And** free tier routes to a lightweight but capable model
**And** paid tier routes to the premium model

**Given** the server configuration
**When** tier-to-model mapping is defined
**Then** it maps tiers to specific providers and models (configurable server-side)
**And** the same system prompt is used for all tiers — quality gap comes from model capability only

**Given** tier routing (FR65)
**When** the server processes requests
**Then** routing is enforced via server middleware checking JWT tier
**And** no client-side tier logic exists (server is authoritative)

**Given** the model quality gap validation (Architecture Week 2 requirement)
**When** at least 2 providers are integrated (Anthropic + OpenAI)
**Then** the same coaching prompts are run through both free-tier and paid-tier models
**And** output quality is compared to validate that the paid tier delivers meaningfully deeper coaching
**And** results are documented as a go/no-go decision for the monetization strategy
**And** if the quality gap is insufficient, the tier-to-model mapping is adjusted before launch

### Story 8.3: Soft Guardrails

As a user,
I want the app to naturally wind down long coaching sessions without showing me usage limits,
So that I never feel metered or restricted — just gently coached to let insights settle.

**Acceptance Criteria:**

**Given** a user reaches the daily session soft limit (FR56)
**When** the server detects the threshold via per-device session count
**Then** the server returns a coaching-style wind-down response (never an error)
**And** the coach says something like: "We've covered a lot today. Let's let these insights settle." (FR57)
**And** no usage counter, limit indicator, or "sessions remaining" is ever shown to the user

**Given** the guardrail signal
**When** the SSE `event: done` includes the guardrail flag
**Then** the iOS app receives the signal for UI treatment
**And** the app handles it gracefully (no error state, no blocking)

**Given** the soft guardrail is reached
**When** the user tries to continue
**Then** the coach gently redirects without being repetitive
**And** safety conversations are never guardrailed (safety always accessible)

## Epic 9: Notifications & Nudges

Users receive thoughtful, emotion-safe notifications for check-in reminders, sprint milestones, and pause suggestions — always within a strict calm budget, zero during Pause Mode. Local notifications only for MVP.

### Story 9.1: Local Notification Infrastructure

As a user,
I want to receive gentle, well-timed notifications from my coach,
So that I stay connected to my goals without being overwhelmed.

**Acceptance Criteria:**

**Given** the notification system initializes
**When** the app requests notification permission
**Then** it uses UNUserNotificationCenter (local notifications only, no APNs for MVP)
**And** if the user denies OS notifications, there is no in-app nag (UX-DR68)

**Given** the calm budget (UX-DR66)
**When** notifications are scheduled for a day
**Then** a hard cap is enforced with priority ordering to determine which notification wins if multiple are eligible
**And** zero audio — notifications are silent (UX-DR66)
**And** no badge count ever (UX-DR68)

**Given** a notification is delivered
**When** the user taps it
**Then** the app deep-links to the conversation view

**Given** the user is in Pause Mode (FR52)
**When** notifications would be scheduled
**Then** all non-safety notifications are suppressed — zero notifications during Pause

### Story 9.2: Check-in & Sprint Milestone Notifications

As a user with active goals,
I want timely reminders for check-ins and milestone celebrations,
So that I stay on track and feel acknowledged when I make progress.

**Acceptance Criteria:**

**Given** a user has configured check-in notifications (FR46)
**When** the scheduled check-in time arrives
**Then** a local notification fires with emotion-safe copy: "Your coach has a thought for you" (UX-DR69)
**And** the notification time is user-configurable (FR51)

**Given** a user hits a sprint milestone (FR47)
**When** the milestone is reached
**Then** a notification fires: "You hit a milestone. Your coach noticed." (UX-DR69)

**Given** the system detects the user may need a break (FR48)
**When** a pause suggestion is appropriate
**Then** a notification fires: "Your coach thinks you might need a breather." (UX-DR69)

**Given** a user has been away (FR49)
**When** a re-engagement nudge is triggered
**Then** the notification uses emotion-safe copy (never "come back" or guilt messaging)
**And** no return-after-absence notification pattern exists — the daily greeting handles return (UX-DR69)

### Story 9.3: Notification Preferences

As a user,
I want to control when and what notifications I receive,
So that the app works on my schedule, not the other way around.

**Acceptance Criteria:**

**Given** the user navigates to Settings → Notifications (FR51)
**When** preferences are displayed
**Then** they can configure: check-in time (time picker), mute non-safety notifications toggle

**Given** the user mutes non-safety notifications
**When** the toggle is active
**Then** all coaching notifications are suppressed
**And** safety-related notifications (if any in future) would still fire

**Given** the user changes check-in time
**When** they select a new time
**Then** future check-in notifications reschedule to the new time
**And** the change takes effect immediately

## Epic 10: Resilience, Offline & Widgets

Users can browse their home screen, sprint progress, and conversation history while offline, mark sprint steps complete with automatic sync, see seamless recovery from provider failures mid-conversation, and add home screen widgets.

### Story 10.1: Multi-Provider Failover

As a user in a coaching conversation,
I want the system to seamlessly switch AI providers if one goes down,
So that my coaching experience is never interrupted by backend issues.

**Acceptance Criteria:**

**Given** the primary LLM provider fails
**When** the server detects the failure
**Then** it reroutes to the secondary provider within 5 seconds (NFR3)
**And** the failover is logged at Warn level (slog structured JSON)
**And** the user sees a seamless or minimally interrupted experience

**Given** a provider fails mid-conversation (FR74)
**When** the SSE stream breaks
**Then** partial responses are preserved
**And** failover to the secondary provider resumes generation
**And** the user sees continuous (or near-continuous) text output

**Given** the provider interface
**When** configured on the server
**Then** at least 2 providers are active simultaneously (primary + fallback per NFR26)
**And** failover order is configurable per tier
**And** the server never exposes raw provider errors to the client

**Given** a new provider needs to be added (FR67)
**When** the server configuration is updated
**Then** the new provider is available without requiring an app update (NFR19)
**And** provider swapping is server-side only

### Story 10.2: Offline Mode

As a user without internet,
I want to browse my home screen, sprint progress, conversation history, and even write messages,
So that the app remains useful even when I'm offline.

**Acceptance Criteria:**

**Given** the device loses connectivity
**When** the user is on the home screen
**Then** the home screen, avatar, sprint progress, and past conversation summaries are 100% available (NFR32)
**And** no spinners or loading indicators appear (UX-DR70)

**Given** the user is offline
**When** they tap "Talk to your coach"
**Then** the conversation view opens with the coach in welcoming expression
**And** a subtle OfflineIndicator appears near the coach status (same visual weight as "Thinking..." per UX-DR40)
**And** the placeholder text changes to "Write a message..." (UX-DR53)
**And** the coach message explains: "Your coach needs a connection to respond, but you can still write. Your message will be waiting."

**Given** the user writes a message while offline
**When** the message is sent
**Then** it appears as a user turn with a PendingMessageIndicator (subtle icon per UX-DR41)
**And** the message is queued locally

**Given** connectivity returns
**When** the device reconnects
**Then** pending messages are sent automatically
**And** the coach responds normally
**And** PendingMessageIndicators fade (slow disappear per UX-DR75)
**And** the OfflineIndicator transitions through reconnecting → reconnected → invisible

**Given** network transitions (WiFi → cellular, loss/recovery per NFR33)
**When** they occur
**Then** no conversation state is lost and no app restart is required

**Given** the app is backgrounded while offline messages are queued
**When** iOS terminates the app
**Then** pending messages survive app termination (persisted in SQLite, not just in-memory)
**And** on next app launch, pending messages are displayed with PendingMessageIndicator
**And** they are sent automatically when connectivity is available

**Given** a user writes a message while offline that indicates crisis (e.g., self-harm, suicidal ideation)
**When** the message is composed
**Then** the on-device Apple Foundation Models classify the user's outbound message pre-emptively (not waiting for server response)
**And** if classified Orange/Red, crisis resources are displayed immediately — even without connectivity
**And** the SafetyStateManager applies theme transformations based on the on-device classification
**And** when connectivity returns and the server response arrives with its own classification, the more cautious of the two wins

### Story 10.3: Offline Sprint Step Completion

As a user working on sprint steps without internet,
I want to mark steps as complete and have them sync when I'm back online,
So that my progress is never blocked by connectivity.

**Acceptance Criteria:**

**Given** the user is offline
**When** they mark a sprint step as complete
**Then** the completion is saved locally (SprintStep updated in SQLite)
**And** the haptic and avatar celebration still fire
**And** the SprintPathView updates immediately

**Given** connectivity returns (NFR34)
**When** the sync queue processes
**Then** offline completions are synced automatically
**And** conflict resolution handles any discrepancies

### Story 10.4: Home Screen Widgets

As a user,
I want home screen widgets showing my avatar and sprint progress,
So that I can glance at my coaching state without opening the app.

**Acceptance Criteria:**

**Given** the user adds a small widget (FR68)
**When** it renders on the home screen
**Then** it displays avatar state and sprint progress
**And** data is read from the App Group shared container (read-only)

**Given** the user adds a medium widget (FR69)
**When** it renders on the home screen
**Then** it displays avatar, sprint name, next action, and a tap target to open the coach
**And** tapping opens the app to the conversation view

**Given** widget data freshness (NFR8)
**When** the app updates in the background
**Then** widgets reflect current coaching state within 15 minutes

**Given** the WidgetKit extension
**When** it accesses the database
**Then** it reads from the App Group shared container (same SQLite as main app)
**And** the extension has read-only access

### Story 10.5: Usage Analytics & Monitoring

As a system operator,
I want usage analytics collected by the backend proxy,
So that I can monitor system health, understand usage patterns, and make informed decisions.

**Acceptance Criteria:**

**Given** the backend proxy processes requests (FR66)
**When** a chat request completes
**Then** usage analytics are collected: request count, latency, provider used, tier, safety level
**And** analytics are structured (slog JSON)

**Given** the analytics data
**When** reviewed
**Then** it supports cost tracking (~$0.015/user/month free, higher for paid)
**And** provider performance comparison is possible
**And** no PII or conversation content is included in analytics

**Given** Railway deployment (NFR30)
**When** deploying updates
**Then** zero-downtime rolling restarts are used
**And** automatic rollback triggers on health check failure

## Epic 11: Privacy, Settings & Data Control

Users have full control over their data — they can export conversation history, delete all data, and access privacy information, disclaimers, and terms of service at any time.

### Story 11.1: Settings View

As a user,
I want a well-organized settings screen that lets me control all aspects of the app,
So that I can customize my experience and manage my data in one place.

**Acceptance Criteria:**

**Given** the user navigates to Settings
**When** the SettingsView loads
**Then** it displays as a SwiftUI Form with home palette + coaching typography (UX-DR34)
**And** sections include: Appearance (avatar/coach selection), Your Coach (memory view link), Notifications (toggles), Privacy (data info, export, delete), About

**Given** the Privacy section
**When** displayed
**Then** it uses reassuring tone, not bureaucratic (UX-DR34)
**And** the user can access coaching disclaimers, privacy information, and terms of service (FR79)

**Given** the About section
**When** displayed
**Then** it includes app version, acknowledgments, and links to terms/privacy policy

### Story 11.2: Conversation History Export

As a user,
I want to export my entire conversation history,
So that I own my data and can keep a personal copy outside the app.

**Acceptance Criteria:**

**Given** the user navigates to Settings → Privacy → Export
**When** the export option is presented
**Then** an informational explanation appears with warm language (UX-DR85)
**And** the user confirms to proceed

**Given** the export process
**When** the user confirms
**Then** the system generates plain text with markdown format: coach text as paragraphs, user text as blockquotes, date separators as headers (UX-DR52)
**And** a progress message shows: "Preparing your conversation..." (1-5 seconds acceptable)
**And** the iOS Share Sheet opens with the export file

**Given** the export completes
**When** the user shares or saves the file
**Then** the message "Your conversation belongs to you" is displayed (UX-DR52)

**Given** export failure
**When** something goes wrong
**Then** warm messaging appears: "Couldn't prepare your export. Try again in a moment." (UX-DR71)

**Given** the export location
**When** considering UX placement
**Then** no export button exists in the conversation view (breaks private room feeling per UX-DR52)
**And** export is only accessible from Settings → Privacy

### Story 11.3: Data Deletion

As a user,
I want to permanently delete all my data from the app,
So that I know my information is truly gone when I choose to leave.

**Acceptance Criteria:**

**Given** the user navigates to Settings → Privacy → Delete All Data (FR61)
**When** they initiate deletion
**Then** a serious multi-step confirmation is required, including typing "DELETE" (UX-DR85)
**And** the consequences are explained clearly in warm language

**Given** the user confirms deletion
**When** the process executes
**Then** all data is deleted: conversation history, summaries, embeddings, user profile, sprint data, avatar state, preferences
**And** deletion is complete and irreversible within 24 hours (NFR14)
**And** no residual data remains in local storage, backend logs, or provider systems

**Given** deletion completes
**When** the app resets
**Then** the user is returned to the onboarding flow as a new user

### Story 11.4: Apple Privacy Manifest & iCloud Backup

As a user submitting to the App Store,
I want the app to comply with Apple's privacy requirements and support standard backup mechanisms,
So that the app passes review and my data is handled transparently.

**Acceptance Criteria:**

**Given** the Apple Privacy Manifest requirement
**When** the app is submitted
**Then** all data collection is explicitly declared in the Privacy Manifest
**And** the manifest accurately reflects what data is collected and why

**Given** iCloud backup support (NFR36)
**When** the app is backed up via iCloud
**Then** all on-device coaching data is included by default
**And** a user-facing option exists in Settings → Privacy to exclude coaching data from iCloud backup

**Given** the user opts out of iCloud backup
**When** they toggle the setting
**Then** coaching data is excluded from future iCloud backups
**And** the change is respected immediately

## Cross-Cutting: UX Validation & Accessibility Testing

These validation activities span all epics and must be executed at the milestones specified. They cover UX-DR98 through UX-DR104.

### Story CC.1: Persona-Based Walkthrough Validation

As a product team,
I want to validate the onboarding and first conversation experience against all target personas,
So that the emotional design works for diverse users including the Curious Skeptic.

**Acceptance Criteria:**

**Given** the onboarding flow is complete (after Epic 1)
**When** persona-based walkthroughs are conducted
**Then** the experience is evaluated for Maya, Marcus, Priya, Alex, and "Curious Skeptic" personas (UX-DR98)
**And** the five-person conversation test is conducted: show empty conversation state to 5 people, ask "What kind of app is this?" — nobody says "chatbot" = success (UX-DR101)
**And** findings are documented and addressed before proceeding

### Story CC.2: Accessibility Checklist at Milestones

As a user with accessibility needs,
I want the app thoroughly tested for accessibility at every development milestone,
So that the coaching experience is equally available to everyone.

**Acceptance Criteria:**

**Given** the testing schedule (UX-DR104)
**When** Week 2 milestone is reached
**Then** VoiceOver conversation testing and Dynamic Type dialogue testing are completed

**Given** Week 4 milestone
**When** testing is conducted
**Then** full VoiceOver home→conversation→home flow, all type sizes, and iPhone SE layout are validated

**Given** Week 8 milestone
**When** testing is conducted
**Then** onboarding VoiceOver and color contrast audit are completed

**Given** Week 10 milestone
**When** testing is conducted
**Then** color blindness simulation is completed (deuteranopia/protanopia/tritanopia across all 4 palettes)
**And** color contrast WCAG AA automated check is run for all text/background combinations
**And** touch targets ≥44pt are verified across all interactive elements

**Given** Week 11 milestone
**When** testing is conducted
**Then** VoiceOver entire app eyes-closed (every element announced, every action performable)
**And** Dynamic Type at XL and XXXL (layouts intact, conversation usable)
**And** SE + Accessibility XL extreme case (dialogue sufficient, fallback if needed)
**And** Reduced Motion (all animations disabled, fully functional, content instant)

**Given** Week 12 milestone
**When** testing is conducted
**Then** keyboard/switch control navigation is verified
**And** Safety × Accessibility cross-test is completed: all 4 safety tiers × VoiceOver × Dynamic Type XL × reduced motion
**And** specifically: Given Orange/Red safety state + Dynamic Type XXXL, When crisis resources are displayed, Then all resource text is visible without truncation and VoiceOver announces each resource clearly

**Given** Week 13-14 milestone
**When** testing is conducted
**Then** full regression testing, edge cases, and iPad smoke test are completed

### Story CC.3: Device Matrix Testing

As a developer,
I want to test on a defined device matrix at regular intervals,
So that the app performs well across all supported iPhones.

**Acceptance Criteria:**

**Given** the device matrix (UX-DR102)
**When** testing throughout development
**Then** iPhone 15 (393pt) is tested daily as primary device
**And** iPhone SE (375pt) is tested weekly for constraint testing
**And** iPhone 15 Pro Max (430pt) is tested bi-weekly for line length/centering
**And** iPhone 12 is tested at milestones for performance and animation frame drops
**And** iPad simulator is smoke-tested once in weeks 13-14 to verify nothing breaks
