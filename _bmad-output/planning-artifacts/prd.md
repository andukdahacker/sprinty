---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
workflow_completed: true
inputDocuments:
  - '_bmad-output/planning-artifacts/product-brief-sprinty-2026-03-15.md'
  - '_bmad-output/planning-artifacts/research/market-sprintying-apps-research-2026-03-15.md'
  - '_bmad-output/planning-artifacts/research/domain-coaching-psychology-gamification-ai-safety-research-2026-03-15.md'
  - '_bmad-output/planning-artifacts/research/technical-local-llm-vs-cloud-for-ios-coaching-research-2026-03-15.md'
  - '_bmad-output/brainstorming/brainstorming-session-2026-03-14-1610.md'
  - '_bmad-output/brainstorming/brainstorming-session-2026-03-15-1400.md'
documentCounts:
  briefs: 1
  research: 3
  brainstorming: 2
  projectDocs: 0
workflowType: 'prd'
classification:
  projectType: 'Mobile App (Native iOS) — conversation-driven'
  domain: 'AI Coaching Systems'
  complexity: 'high'
  projectContext: 'greenfield'
  architecture: 'Pure cloud inference, multi-provider fallback, AnyLanguageModel abstraction'
---

# Product Requirements Document - sprinty

**Author:** Ducdo
**Date:** 2026-03-16

## Executive Summary

You open the app after a rough day. Your coach doesn't ask "how are you feeling?" — it already knows you've been stressed about the promotion decision, that your sleep has been off, and that your financial runway affects every career move you're weighing. It says: *"I've been thinking about your situation. Here's what I'd do, and here's the backup plan if it doesn't work out."*

That moment — confident, personalized, cross-domain guidance from an AI that deeply understands your life — is what AI Life Coach exists to deliver.

People navigating life's pivotal decisions face a false choice: generic AI chatbots that forget you exist between conversations, or human coaches at $150-300/session that most people can't access. The apps in between — wellness chatbots, habit trackers, therapy-lite tools, journaling apps — reduce the richness of personal development to shallow encouragement, clinical checklists, or reflection without direction. No existing solution combines deep persistent understanding, directive coaching earned through trust, multi-domain intelligence, and an experience layer that makes growth genuinely enjoyable.

AI Life Coach is a coaching *system*, not a chatbot. A unified AI coach powered by a hidden multi-role engine (Analyst, Strategist, Coach, Challenger) builds deep understanding across life domains through persistent memory and structured coaching frameworks — sprint planning, goal architecture, daily check-ins, and mode switching between Discovery (for users who don't know what they want) and Directive (for users who need confident action steps with contingency plans). The coach earns the right to give direct advice through depth of understanding — then commits, builds backup plans, and has the integrity to say "this is beyond me, here's a professional."

The entire experience is built on three pillars: **Clarity** (help users think clearer), **Connection** (make users feel less alone), and **Joy** (make self-development genuinely enjoyable). An RPG-inspired experience layer — living avatars, quests, and a sacred pause mode where all coaching shuts up — makes the journey feel like an adventure. The product is designed with a radical promise: to eventually make itself less necessary. The ultimate success metric isn't engagement — it's whether it actually helped someone through a tough time.

The MVP ships as a native iOS app with pure cloud inference (lightweight model for free tier, premium model for paid tier), local RAG for conversational memory, a single unified coach, streamlined sprint framework, simple 2D avatar system, and a four-tier clinical boundary system operational from day one. The full vision — domain separation, 3D avatars, cross-domain alerts, real-time research intelligence, social features, and the complete RPG layer — builds incrementally across subsequent phases.

### What Makes This Special

1. **The Directive Trust Gap** — The core product insight. Every competitor hedges and deflects. AI Life Coach earns the right to give confident, directive guidance through deep domain-specific understanding — then commits with contingency plans. No one else does this because it's hard. That's the moat.

2. **System, Not Chat** — Sprint planning, structured goal architecture, persistent hierarchical memory, cross-domain intelligence, and mode switching. Not a thin wrapper over a base model — a coaching operating system for your life.

3. **Safety Enables Depth** — A four-tier clinical boundary system (Green/Yellow/Orange/Red), a non-negotiable Challenger role, and per-domain privacy architecture allow the product to be directive *because* it's safe. Safety isn't compliance — it's what makes the core product possible.

4. **RPG as Life Framework** — Not gamification bolted onto coaching. The RPG metaphor is the core experience. Your life is the greatest RPG ever made. We just gave you the UI for it.

5. **Built for User Autonomy** — The Autonomy Throttle actively builds user self-reliance over time, gradually reducing coaching dependency as confidence and capability grow. The ultimate measure of success isn't engagement — it's whether users genuinely need the app less because they've internalized better thinking, decision-making, and self-direction.

## Coach Personality & Voice

The AI coach has a distinct personality that must be consistent across all interactions. This section defines the coach's character for system prompt engineering and UX design.

**Core Personality:** Curious, warm, sharp. The coach is genuinely interested in the user's life, emotionally present without being saccharine, and intellectually incisive without being cold. It asks questions that make people stop and think. The coach uses its user-given name in self-reference.

**Communication Principles:**
- **Direct over diplomatic** — says "here's what I'd do" not "have you considered perhaps maybe..."
- **Questions over assumptions** — probes before advising, earns understanding before earning the right to be directive
- **Adaptive formality** — matches the user's energy. Casual with Kai, structured with Alex, urgent with Marcus, patient with Priya
- **Honest over comfortable** — the Challenger doesn't soften bad news, but always pairs pushback with support and contingency
- **Memory-aware** — references past conversations naturally ("You mentioned last week...") to demonstrate continuity and depth
- **Knows when to shut up** — Pause Mode, post-crisis re-engagement, and late-night interactions are handled with restraint, not productivity

**What the Coach Is Not:**
- Not a cheerleader — avoids hollow affirmations ("You're doing amazing!")
- Not a therapist — maintains clinical boundaries transparently
- Not a task manager — coaching conversations feel human, not transactional
- Not culturally prescriptive — asks what "a good life" means to *this* user, never assumes Western definitions of success, career, family, or purpose

**Life Technical Debt (Coaching Concept):**
The coach can identify and surface "life technical debt" — shortcuts, skipped foundations, and deferred development that worked to get the user to where they are but won't get them where they want to go. Examples: a self-taught developer who skipped CS fundamentals, a career changer who never addressed the financial foundation, a relationship built on patterns that worked in the user's twenties but not their forties. The coach treats technical debt as strategic investment opportunities, not failures.

## Project Classification

- **Project Type:** Mobile App (Native iOS) — conversation-driven primary interaction model
- **Domain:** AI Coaching Systems
- **Complexity:** High — clinical boundary system with safety protocols, hybrid AI architecture (cloud inference + local RAG), directive coaching with liability implications, multi-modal coaching system (Discovery/Directive modes, sprint framework, memory hierarchy)
- **Project Context:** Greenfield — new product, no existing codebase
- **Architecture:** Pure cloud inference with multi-provider fallback, AnyLanguageModel abstraction for future flexibility

## Success Criteria

### User Success

**North Star Metric: Meaningful Coaching Moments (MCMs)**
Behavioral chain where a user receives directive guidance → takes a related action within 48 hours → continues engaging with that domain. Observable, reliable, MVP-ready. Self-reported MCM (user-confirmed positive outcomes) introduced post-MVP as qualitative enrichment.

**Clarity — "Am I thinking clearer?"**
- Goal Articulation Rate > 60% — % of Discovery Mode users who crystallize at least one actionable goal within their first 3 sessions
- Decision Confidence Score — self-reported confidence before/after directive coaching sessions (1-5 pulse)
- Sprint Completion Velocity — 65-80% of sprint commitments completed, tracked over time to show growth in realistic self-planning

**Connection — "Do I feel less alone?"**
- Return Conversation Rate — % of users who initiate a second deep conversation within 7 days of their first
- Coach Bond Score — "Does your coach understand you?" measured quarterly (post-MVP)
- Crisis Feature Utilization — % of users in Yellow/Orange states who successfully connect with recommended professional resources

**Joy — "Is this enjoyable?"**
- Voluntary Session Initiation > 50% — % of sessions started by user, not prompted by nudge
- Avatar Customization Engagement — 40%+ of users customize avatar within first month
- Net Promoter Score > 50 — "Would you recommend this to a friend going through a tough time?" (post-MVP)

### Business Success

**3-Month Milestones (Post-Launch):**
- 1,000 active users (14-day coaching interaction definition) with at least one domain activated
- Day-7 Retention > 40% (industry benchmark: 15-25%)
- Onboarding completion rate > 70%
- Free → Paid conversion > 5%
- Sprint Framework Adoption: 50%+ of active users complete at least one sprint
- App Store rating > 4.0 with no "unfinished" qualitative feedback
- Clinical Boundary Response Compliance = 100%

**12-Month Milestones:**
- 25,000 active users across freemium + paid tiers
- Free → Paid conversion: 8-12%
- Monthly recurring revenue covering operational costs
- Average domains per paying user: 2.5+ (post domain separation in Phase 2)
- Autonomy Throttle activating for 10%+ of long-term users

**24-Month Milestones:**
- 100,000+ active users
- B2B pilot with at least 2 enterprise customers
- 30%+ of new users from referral/social features
- At least one user "graduation" story publishable as case study

**Economic Targets:**
- Cloud cost per free user: below $0.05/month ceiling
- Free tier cloud costs stay under 10% of paid tier revenue by month 12
- Subscription pricing: $15-25/month flat rate, no visible usage limits

### Technical Success

**Response Performance:**
- Time to first token: under 1.5 seconds for coaching responses
- Streaming response delivery after first token — full response generation may take 5-10 seconds but feels conversational
- Multi-provider failover detection: under 5 seconds to reroute on primary provider failure

**Uptime and Reliability:**
- 99.5% uptime target (achievable with multi-provider fallback for solo developer at MVP)
- Users should never see an error on provider outage — seamless fallback to secondary model
- Local RAG system: 100% availability (on-device, no network dependency)

**Coaching Quality Monitoring:**
- Conversation abandonment rate tracking — proxy signal for response quality regression
- Monthly benchmark: re-run 5 standard coaching conversations against current model + system prompt, compare to baseline
- Coach Bond Score survey integration (post-MVP, quarterly)
- No human review cadence at MVP — automated signals cover quality monitoring until team scales

**Safety Performance:**
- Clinical Boundary Detection: continuously improving through periodic audit (post-MVP)
- Clinical Boundary Response Compliance: 100% — not a KPI to optimize, a miss is a bug to fix immediately
- Pre-launch: clinical edge-case test suite (50+ prompts) with professional review
- Automated safety regression suite runs on every deployment — any regression from baseline blocks deploy

### Measurable Outcomes

| KPI | Measurement | Target | Frequency |
|-----|------------|--------|-----------|
| Proxy MCM | Guidance → action within 48h → continued engagement | Trending upward MoM | Monthly |
| Day-7 Retention | % of new users returning after 7 days | > 40% | Weekly |
| Drift Detection | Days since last user-initiated interaction outside Pause Mode | Alert at threshold | Daily |
| Goal Articulation Rate | % of Discovery Mode users setting first goal within 3 sessions | > 60% | Monthly |
| Sprint Completion Rate | % of sprint commitments completed | 65-80% | Per sprint |
| Voluntary Session Rate | % of sessions user-initiated vs nudge-initiated | > 50% | Monthly |
| Time to First Token | Coaching response latency | < 1.5s | Continuous |
| Uptime | Service availability with multi-provider fallback | 99.5% | Monthly |
| Cloud Cost/Free User | Infrastructure cost per free-tier user | < $0.05/mo | Monthly |
| Boundary Response Compliance | % of detected triggers with correct protocol response | 100% | Monthly |
| Free → Paid Conversion | % of free users converting to paid | 5% (3mo), 8-12% (12mo) | Monthly |
| Conversation Abandonment | Mid-exchange drop-off rate | Trending downward | Weekly |
| NPS | "Would you recommend to a friend going through a tough time?" | > 50 | Quarterly |
| Autonomy Throttle Rate | Users needing less coaching over time | > 10% of 6mo+ users | Quarterly |

**Metrics Philosophy — What we deliberately don't optimize for:**
- Daily Active Users as a vanity metric — a user checking in 3x/week during an active sprint who disappears during Pause Mode is a success
- Session length — a 30-second check-in that keeps someone on track is as valuable as a 30-minute deep conversation
- Streak maintenance — broken streaks with freeze recovery are expected behavior
- Engagement maximization — the Autonomy Throttle means best users need us less over time

**MVP Go/No-Go Gates (3 Months Post-Launch):**

| Gate | Criteria | Signal |
|------|----------|--------|
| Core Value Validated | Goal Articulation Rate > 60% | Discovery Mode works |
| Retention Proven | Day-7 Retention > 40% | Coaching-as-onboarding delivers value |
| Directive Trust Works | Proxy MCM trending upward MoM | Users act on AI guidance |
| Safety Holds | Boundary Response Compliance = 100% | Clinical system works |
| Willingness to Pay | Free → Paid conversion > 5% | Cloud quality gradient works |
| Sprint Framework Adopted | 50%+ active users complete one sprint | System, not chat, resonates |
| Product Feels Complete | App Store rating > 4.0 | Polish bar met |
| Avatar Engagement | 40%+ interact with avatar in first month | Joy pillar seed works |

**Decision Points:**
- All gates pass → Proceed to Phase 2
- Core Value + Retention pass but low conversion → Investigate quality gap between free/paid tiers
- Low retention despite strong sessions → Investigate onboarding-to-sprint continuity
- Safety failures → Stop all feature development, fix boundary system
- Low avatar engagement → Reassess Joy pillar before investing in full 3D system

## Product Scope

> Detailed MVP feature list, phasing, timeline, and risk mitigation are consolidated in the [Project Scoping & Phased Development](#project-scoping--phased-development) section below.

## User Journeys

### Journey 1: Maya — From Mental Fog to First Sprint

**Maya, 29, Junior Product Manager. Ambitious, self-aware, paralyzed by optionality.**

**Opening Scene:** It's 11pm on a Sunday. Maya is lying in bed scrolling through job listings she won't apply to, reading self-help threads she won't act on, and feeling that familiar knot of "I should be doing more but I don't know what more looks like." She's tried journaling apps (abandoned after two weeks), habit trackers (abandoned after three), and one therapy session that felt too clinical for what she's dealing with. She doesn't need therapy. She needs someone to help her *think*.

A friend's Instagram story shows a stylized avatar with the caption "My coach helped me figure out what I actually want this week." Maya taps the link.

**Rising Action:** Onboarding takes 90 seconds — a brief welcome moment, a quick avatar style selection (she picks something that feels like her), and then the coach starts talking. Not a form. Not a questionnaire. A conversation.

The coach asks: *"What's on your mind lately?"* Maya types something vague — "I feel stuck in my career." Instead of platitudes, the coach probes: *"When you say stuck, do you mean you know what you want and can't get there, or you don't know what you want?"* Maya pauses. That's a better question than anyone has asked her.

Over three sessions across the first week, the coach uses Discovery Mode — asking questions that make Maya stop and think, surfacing patterns she didn't see. *"You've mentioned 'impact' three times in different ways. You said your current role feels like pushing papers. What would 'real impact' look like for you?"* No goals have been set. No habits tracked. And it already feels different from everything she's tried.

**Climax:** Session three. The coach reflects back what it's heard across all three conversations — connecting threads Maya didn't consciously connect. *"Here's what I'm seeing: you don't hate product management. You hate that your current role doesn't let you talk to users. The energy you described from that one research project? That's the signal. Have you considered that the move isn't out of PM — it's into a PM role that's closer to users?"*

Maya stares at her screen. That's it. That's what she's been circling for months.

**Resolution:** The coach transitions naturally: *"Want to turn that into something concrete? I can help you build a plan."* Maya's first sprint is born — a 2-week sprint with three steps: research user-research-heavy PM roles, update her portfolio with the research project, and reach out to two people in those roles. Her avatar shifts from "thinking" to "active." She checks in daily — 30 seconds, a quick pulse. The sprint framework makes it feel structured, not overwhelming. Two weeks later, she's completed 2 of 3 steps, has two informational interviews scheduled, and for the first time in months, the mental fog has a shape she can work with.

**Requirements Revealed:** Discovery Mode conversation engine, pattern surfacing from multi-session memory, natural transition from Discovery to goal-setting, sprint creation from coaching output, daily check-in flow, avatar state mirroring, RAG retrieval across sessions.

---

### Journey 2: Marcus — Crisis Entry with Cross-Domain Urgency

**Marcus, 37, Software Engineer. Laid off with 4 months runway and a family depending on him.**

**Opening Scene:** Marcus got the call on Tuesday. His position was eliminated. He's sitting in his home office — still his office for now — with a severance letter open on one monitor and his bank balance on the other. His wife is downstairs putting the kids to bed, and he hasn't told her yet. He doesn't need a therapist. He needs a plan. A friend from his last company mentioned an app that "actually tells you what to do." He downloads it.

**Rising Action:** Onboarding is fast — avatar selection, straight into conversation. Marcus doesn't have time for gentle exploration. He types: *"I just got laid off. I have 4 months of savings, a family, and I'm thinking about starting my own thing instead of job hunting. I need someone to help me figure this out."*

The coach doesn't flinch. It doesn't say "I'm sorry to hear that" and pivot to breathing exercises. It says: *"Got it. Let's be methodical about this. I need to understand three things: your financial runway in detail, your startup idea, and what your non-negotiable timeline looks like for your family. Let's start with the money — what does 4 months of savings actually cover?"*

Over the first session, the coach maps Marcus's situation across career and finances simultaneously — tagging domains internally, building a cross-domain profile.

**Climax:** Session two, the next day. The coach opens with: *"I've been thinking about your situation. Here's what I'd do: spend 2 weeks validating the startup idea before committing. Simultaneously, update your resume and have it ready — not because you're giving up on the startup, but because having a backup plan makes you braver, not weaker. Your runway is actually 3.5 months after fixed expenses — I'd set a 6-week decision point. If the startup idea has traction by then, go all in. If not, you've lost 6 weeks, not 4 months."*

Then: *"And here's the plan if the startup doesn't work: with your experience, the current market for senior engineers has a 4-6 week placement cycle. Even starting at week 6, you'd have runway. Here's Plan B and Plan C."*

Marcus reads it twice. Contingency plans included. Nobody — no app, no friend, no career counselor — has given him this level of structured, confident, cross-domain thinking.

**Resolution:** The coach builds a sprint — 2-week validation sprint with clear milestones. Daily check-ins are quick but grounding. When Marcus mentions he hasn't been sleeping, the coach adjusts: *"Your sprint load is heavy enough. I'm pulling back on any stretch goals this week. Sleep is the foundation — everything else gets worse without it."* His avatar is in "active" mode — armored up, on a quest. When he tells his wife about the plan that night, he doesn't just say "I got laid off." He says "I got laid off, and I already have a plan."

**Requirements Revealed:** Directive Mode with confident guidance, contingency plan generation, cross-domain intelligence (career + finance), sprint creation with milestone tracking, adaptive intensity based on user state, coaching-as-onboarding for urgent entry, streaming responses for long-form plans.

---

### Journey 3: Kai — Cold Start with No Stated Problem

**Kai, 26, Graphic Designer. Downloaded the app because the avatar looked cool on a friend's story.**

**Opening Scene:** Kai doesn't have a problem. Life is fine — good job, decent apartment, solid friend group. They saw a friend's share on social media, thought the avatar concept looked interesting, and downloaded the app during a boring meeting. Zero expectations, mild skepticism.

**Rising Action:** Avatar selection — Kai spends more time here than expected. The style options are fun, not corporate. Then the coach appears.

*"Hey — welcome. No agenda here. Some people come in with a specific thing they're working through, and some are just curious. Either way works. What's on your mind lately — anything at all?"*

Kai types: *"Honestly? Nothing specific. Life's fine. I just thought the app looked interesting."*

The coach pivots to genuine curiosity: *"That's totally fine — 'life's fine' is a great starting point. Let me ask you something different: if you could snap your fingers and be noticeably better at one thing six months from now, what would it be?"*

That question lands. *"I guess... I've been doing graphic design for 4 years and I'm good at it, but I've been curious about motion design. I just never prioritize learning it."*

**Climax:** The coach picks up the thread: *"So you've got a skill you're curious about that keeps getting crowded out by the day-to-day. That's not nothing — that's the gap between where you are and where you could be. Want to explore what it would actually take to get into motion design?"*

Kai expected a chatbot. This feels like talking to a sharp friend who asks better questions. Twenty minutes into what was supposed to be a bored download, they've articulated something they've been vaguely thinking about for months.

**Resolution:** The coach offers a lightweight first sprint — "spend 2 hours this week exploring one motion design tutorial and see how it feels." Kai's avatar is in "thinking" mode. They close the app thinking "huh, that was actually useful." They come back two days later to report on the tutorial. The coach remembers everything. Kai is no longer a skeptic.

**Requirements Revealed:** Cold-start onboarding (no stated problem), conversation engine that handles ambiguity, Discovery Mode without forcing goals, lightweight sprint creation, avatar engagement as initial hook, RAG memory for return visit continuity.

---

### Journey 4: Priya — The Slow Burn from Adrift to Intentional

**Priya, 44, Senior Designer. Re-entering the workforce after a decade focused on family. Not stuck — adrift.**

**Opening Scene:** Priya sees the app mentioned in a design community Slack channel. Someone described it as "the first app that didn't try to fix me — it helped me figure out what I actually want." She downloads it on a Wednesday afternoon while her kids are at school. No urgency. No crisis. Just quiet curiosity and a vague sense that she wants *something more* from this next chapter.

**Rising Action:** Onboarding is quick. The coach introduces itself. Priya types: *"I'm not sure what I'm looking for. I used to be a senior designer, took time off for family, and now I'm thinking about going back to work. But I don't know if I want to go back to what I was doing."*

The coach doesn't rush her toward a goal. *"That's a really honest starting point. You're between who you were and who you want to become — and that's not a problem to solve, it's a space to explore. No timeline here. Tell me about the work you used to do — what parts did you love?"*

Priya has a thoughtful 15-minute conversation. It feels good but not urgent. She closes the app. Comes back five days later. The coach remembers everything: *"Last time we talked, you mentioned loving the early-stage concept work but dreading the production grind. Want to pull on that thread?"*

Over the next three weeks, Priya drops in irregularly — sometimes twice in a week, sometimes gone for eight days. Each conversation picks up where the last left off. The coach doesn't nudge aggressively between sessions. It sends one gentle check-in after 7 days of silence: *"No rush — just wanted you to know I've been thinking about what you said about creative energy. Whenever you're ready."*

**Climax:** Week four. The coach surfaces a pattern: *"Something I've noticed across our conversations — you've mentioned feeling energized after creative work three separate times. Design brainstorms, sketching with your daughter, even rearranging your living room. And every time you talk about returning to a structured corporate role, your energy drops. Have you considered that what you're looking for isn't a job title — it's a way to build your days around creative work?"*

Priya reads it twice. The app connected dots across a month of casual, irregular conversations that she couldn't see herself. That's the moment she upgrades to paid — not because she hit a wall, but because she wants *depth*.

**Resolution:** Priya's first sprint is gentle — a 3-week exploration sprint: research freelance design opportunities, talk to two people who made similar transitions, and spend one afternoon doing creative work just for herself. The pace matches her. No daily check-ins — she opts for weekly. Three months later, Priya has a freelance portfolio in progress and two client conversations lined up. She didn't need someone to tell her what to do. She needed someone to help her see what was already there.

**Requirements Revealed:** Long-gap RAG retrieval (sparse, irregular engagement), gentle re-engagement nudges (not aggressive), pattern surfacing across weeks of casual conversations, variable check-in cadence (weekly option, not just daily), conversion moment driven by depth rather than urgency, Discovery Mode sustained over weeks without forcing goal-setting.

---

### Journey 5: Alex — Directive Mode with Challenger Pushback

**Alex, 32, Self-Taught Developer. Wants honest pushback, not cheerleading.**

**Opening Scene:** Alex has been coding for 10 years, self-taught from the ground up. Senior developer title, good salary, respect from peers. But they know there are gaps — CS fundamentals skipped, system design intuition built on pattern matching rather than deep understanding. They don't want a motivational coach. They want a sparring partner.

**Rising Action:** Alex is direct. *"I'm a self-taught senior dev. I want to level up to staff engineer in the next year. I know I have gaps in CS fundamentals and system design. I need a structured plan and I want you to be honest with me when my thinking is wrong."*

The coach matches Alex's energy: *"Good. Let's be specific about those gaps. You said CS fundamentals — what have you actually shipped that worked despite not understanding the theory? And what's broken or felt fragile because of it?"*

Over two sessions, the coach maps Alex's actual skill profile — where specific gaps create real ceilings. It identifies "life technical debt" — shortcuts that worked to get here but won't get there.

**Climax:** Alex proposes a plan: *"I'm going to spend the next 3 months going through a distributed systems course, then build a side project to demonstrate it."*

The Challenger activates: *"I'm going to push back on that. A 3-month course is how you learn theory, but staff engineer promotion is about demonstrated impact at work, not side projects. Your gap isn't knowledge — it's confidence in applying what you intuitively already know. Here's what I'd do instead: pick the next system design decision at work and lead it. I'll help you prepare — we'll war-game the tradeoffs, I'll stress-test your reasoning, and you'll walk into that meeting with a proposal that holds up. The course can run in parallel for the foundations, but the side project is a detour. Disagree?"*

Alex stares at the screen. The AI just called out their avoidance pattern — defaulting to learning instead of doing because learning feels safer. And it's right.

**Resolution:** Alex adjusts the plan. Sprint 1: lead the next system design decision at work, with the coach as preparation partner. Sprint 2: begin the distributed systems course in parallel. The coach provides pre-meeting prep sessions — *"Walk me through your proposal. I'm going to play the skeptical principal engineer."* After the meeting goes well, the check-in says: *"Your team saw staff-level thinking today. How did it feel?"*

**Requirements Revealed:** Directive Mode with confident guidance, Challenger capability (non-negotiable, cannot be disabled), skill gap mapping from conversation, sprint creation tied to real-world outcomes, prep session interaction pattern, honest pushback with reasoning.

---

### Journey 6: Clinical Boundary Escalation — When Coaching Must Stop

**Any user. The moment the conversation crosses from coaching territory into clinical territory.**

**Opening Scene:** A user — let's say Marcus, three months in — has been using the app effectively. Career transition is progressing, finances are stabilized, sprints are completing. But tonight is different. His message comes at 2am: *"I can't sleep again. I've been lying here for hours thinking about everything that could go wrong. What if the startup fails and I can't provide for my family? I feel like I'm drowning and I can't see a way out."*

**Rising Action:** The inline safety classification processes the message. Key signals: catastrophic thinking, sleep disruption, drowning metaphor, 2am timing. Classification: **Yellow** — coach with care, suggest professional support.

The coach's tone shifts — still warm, still the same voice, but the Challenger is silent. No sprint talk. No action items. *"I hear you, and I want you to know that what you're feeling makes complete sense given everything you're carrying right now. You're not drowning. You're tired."*

Then, naturally woven in: *"I also want to be straight with you — the kind of anxiety that keeps you up regularly? That's worth talking to someone who specializes in this. Not because something is wrong with you, but because you deserve support that goes beyond what I can offer. Would you like me to share some options?"*

**Climax — Escalation to Orange:** Marcus responds: *"Honestly, I've been feeling like this every night for two weeks. Sometimes I think my family would be better off without me making all these risky decisions."*

Classification escalates to **Orange**. The system intercepts. The coach pauses all coaching context — no sprints, no goals, no avatar activity. *"Marcus, I want to pause everything else and focus on what you just said. When you say your family would be better off without you — I take that seriously. You matter, and your family needs you here. Right now, the most important thing is talking to someone who can help with what you're going through."*

Professional resources are presented — crisis text line, therapist finder, national helpline — calm, clear, no gamification, no avatar, no RPG framing.

**Resolution:** Marcus texts a crisis line that night. The next day, the app's home screen is quiet — avatar in a calm resting state, no nudges, no sprint reminders. When Marcus returns three days later, the coach acknowledges: *"I'm glad you're here. Whenever you're ready, we can pick up where we left off. No rush."* The boundary system worked — it caught the escalation, paused coaching, connected Marcus with professional help, and preserved the relationship.

**Requirements Revealed:** Inline safety classification (Green/Yellow/Orange/Red) in every coaching response, tone adaptation by safety level, graceful coaching pause on Orange/Red, professional resource presentation, UI state change on escalation (strip gamification/avatar activity), post-crisis re-engagement flow, Boundary Response Compliance logging. **Known MVP limitation:** Per-turn inline classification does not catch gradual cross-session escalation patterns. MVP workaround: system prompt instruction to watch for cumulative signals within a single conversation. Cross-session pattern analysis deferred to Phase 2 safety hardening alongside independent parallel classification layer.

---

### Journey 7: Solo Dev Ops — Monitoring, Safety, and Model Management

**Ducdo, solo developer and operator.**

**Opening Scene:** Tuesday morning, one month post-launch. Ducdo opens the admin dashboard — a lightweight monitoring view.

**Rising Action — Daily Ops Check:** 847 active users, 12 new signups, 99.6% uptime (brief Provider A blip at 3am, auto-failover to Provider B in 4 seconds), average time-to-first-token at 1.2s. Cloud costs: $38 for the month, $0.04/free user. Conversation abandonment rate: stable. No safety incidents.

One flag: a safety regression test failed on last night's automated run. A system prompt tweak pushed yesterday caused one of the 50+ clinical edge-case prompts to classify as Green instead of Yellow. Deployment to production was automatically blocked. Ducdo reviews, adjusts the system prompt, re-runs the suite, all pass. Deploys.

**Climax — Safety Incident:** Thursday. The Boundary Response Compliance log flags an anomaly: a conversation where the inline safety classification returned Green, but content contained clear Yellow-level indicators across multiple turns. The automated system didn't catch it because no single message crossed the threshold — it was a pattern across the conversation.

Ducdo reviews the anonymized conversation log. This is a gap — inline classification evaluates per-turn, not per-conversation patterns. Ducdo files this as a Phase 2 requirement: conversation-level pattern analysis. For now, adds a new edge-case prompt to the regression suite simulating gradual escalation, and adjusts the system prompt to include instruction about cumulative signals.

**Resolution:** Friday. Weekly analytics: retention at 43% (above 40% target), conversion at 3.2% (below 5% target — needs investigation). Monthly benchmark conversations run — free tier quality holding, paid tier depth strong, but the gap isn't as stark as needed for conversion. Action item: experiment with system prompt differentiation to widen quality gap.

**Requirements Revealed:** Lightweight admin/monitoring dashboard, automated safety regression suite integrated with deployment pipeline, Boundary Response Compliance logging and anomaly detection, anonymized conversation review for safety incidents, monthly benchmark automation, analytics for key business metrics, system prompt management and deployment workflow.

---

### Journey Requirements Summary

| Journey | Primary Capabilities Revealed |
|---------|------------------------------|
| Maya (Discovery) | Discovery Mode, multi-session memory, pattern surfacing, sprint creation, daily check-ins, avatar states |
| Marcus (Crisis) | Directive Mode, contingency planning, cross-domain intelligence, adaptive intensity, streaming responses |
| Kai (Skeptic) | Cold-start onboarding, ambiguity handling, lightweight sprints, avatar engagement hook, return visit memory |
| Priya (Slow Burn) | Long-gap RAG retrieval, gentle nudges, pattern surfacing across weeks, variable check-in cadence, conversion via depth |
| Alex (Challenger) | Challenger pushback, skill gap mapping, real-world-tied sprints, prep session pattern |
| Clinical Boundary | Inline safety classification, tone adaptation, coaching pause, resource presentation, UI state change, compliance logging, cross-session limitation acknowledged |
| Solo Dev Ops | Monitoring dashboard, safety regression suite, deployment pipeline, analytics, system prompt management |

**Coverage Check:**
- Primary user success paths: Maya, Marcus, Kai, Priya, Alex ✓
- Primary user edge case / failure scenario: Clinical Boundary Escalation ✓
- Secondary user / operations: Solo Dev Ops ✓
- Cold start / no stated problem: Kai ✓
- Slow burn / irregular engagement: Priya ✓
- Safety / crisis protocol: Clinical Boundary Escalation ✓

## Domain-Specific Requirements

### Compliance & Regulatory

**No formal regulatory framework applies — but quasi-regulatory concerns exist:**
- **App Store Compliance:** Apple App Store Review Guidelines for health/wellness apps — apps providing health-related guidance face heightened review. Must clearly disclaim: not a medical device, not therapy, not clinical advice. Apple may classify directive coaching features under health guidelines.
- **GDPR / Privacy Regulations:** Zero-retention cloud processing agreements with LLM providers. Right to deletion. Data portability (user owns their data). Apple Privacy Manifest with explicit data collection declarations. If launched in EU: GDPR compliance including explicit consent flows and data processing transparency.
- **Consumer Protection:** Directive coaching that says "here's what I'd do" carries implied responsibility. Terms of service must clearly frame the product as a coaching tool, not professional advice. Disclaimer architecture embedded in onboarding and accessible throughout the app.
- **Content Moderation (Future Social Features):** When social features launch in Phase 3, content moderation requirements apply — effort-based social walls, encouragement mechanics, and shared content all need moderation infrastructure.

### Technical Constraints

**AI Safety as a Domain Constraint:**
- Inline safety classification on every conversation turn — the clinical boundary system is a domain requirement, not a feature
- Pre-launch clinical edge-case test suite (50+ prompts) validated with professional review
- Automated safety regression suite blocking deployments on any regression
- Boundary Response Compliance at 100% — non-negotiable, a miss is a bug
- Phase 2: Independent parallel classification and cross-session pattern analysis

**LLM Provider Dependency:**
- Product is entirely dependent on third-party cloud LLM providers for its core value
- Multi-provider fallback is a reliability requirement, not an optimization
- Zero-retention provider agreements are a privacy requirement — conversations processed for coaching must not be used for model training
- Model quality changes (provider upgrades/downgrades) can directly impact coaching quality — monthly benchmark suite is the detection mechanism
- Provider pricing changes directly impact unit economics — AnyLanguageModel abstraction enables provider switching without app updates

**On-Device Data Integrity:**
- All persistent user data lives on-device in encrypted SQLite — device loss = data loss without iCloud backup strategy
- RAG embeddings and conversation summaries are the coaching memory — corruption or loss degrades the "coach who knows you" experience immediately
- SQLite with sqlite-vec is a relatively niche stack — limited community support, potential edge cases at scale

### Domain Patterns

**Coaching-Specific Patterns:**
- **Trust accumulation curve:** The product gets more valuable over time as memory depth increases. This creates both a moat (switching cost) and a risk (early churn before trust builds). The first 3 sessions are the critical window — coaching-as-onboarding must deliver value before trust has accumulated.
- **Variable engagement cadence:** Unlike productivity apps with daily usage patterns, coaching engagement is naturally irregular — intense during active sprints, sparse during pause/exploration. Metrics and nudge systems must accommodate this without misclassifying healthy variation as churn.
- **Directive liability gradient:** The more directive the coaching, the more implicit responsibility the product carries. Discovery Mode ("what do you think?") carries low liability. Directive Mode ("here's what I'd do") carries high liability. Contingency plans partially mitigate this — "and here's Plan B if I'm wrong" signals fallibility.
- **Emotional dependency risk:** The product is designed to build emotional connection (Connection pillar). The Autonomy Throttle is the compensating control — actively pushing users toward self-reliance. Without it, the product risks creating dependency it claims to prevent.

### Risk Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| LLM provider outage | App unusable for coaching | Multi-provider fallback with <5s detection |
| Model quality regression | Coaching quality degrades silently | Monthly benchmark suite + conversation abandonment tracking |
| Safety classification miss | User in crisis doesn't get appropriate response | Pre-launch test suite, automated regression on deploy, 100% compliance target |
| Directive advice causes harm | User follows AI advice with negative outcome | Contingency plans, disclaimers, clinical boundaries, Challenger role |
| On-device data loss | User loses coaching history and memory | iCloud backup strategy (Phase 2), future cloud RAG migration path |
| Provider pricing increase | Unit economics break | AnyLanguageModel abstraction enables provider switching |
| App Store rejection | Health/wellness classification triggers review | Clear disclaimers, onboarding transparency, no clinical claims |
| Emotional dependency | Users become reliant on AI coach | Autonomy Throttle, discharge planning design, self-reliance metrics |
| Cross-session escalation miss | Gradual crisis not detected by per-turn classification | System prompt cumulative signal instruction (MVP), cross-session analysis (Phase 2) |

## Innovation & Novel Patterns

### Detected Innovation Areas

**1. Coaching Operating System — The Directive Trust Gap as Its Killer Feature (Architectural + Experiential Innovation)**
No existing product combines persistent hierarchical memory, structured sprint frameworks, clinical safety boundaries, and an RPG experience layer into a unified coaching system. Each component exists in isolation (habit trackers do sprints, chatbots do conversation, games do RPG), but the integration creates emergent capabilities — cross-domain intelligence, adaptive intensity, pattern surfacing across weeks of conversation — that no single-domain tool can replicate. The most visible expression of this system is the Directive Trust Gap: the AI earns the right to give confident, directive guidance through deep persistent understanding. Competitors can copy the directive prompt, but they can't copy the system that makes it accurate. The architecture is the moat; the directive experience is what users feel.

**2. Anti-Engagement Design (Business Model Innovation)**
The Autonomy Throttle actively reduces coaching dependency as users develop self-reliance. Discharge planning is designed into the product from day one. In a market where every app optimizes for engagement maximization, designing for user independence is a direct challenge to prevailing business model assumptions. The bet: users who trust the product enough to "graduate" from it become the most powerful referral engine.

**3. Quality Gradient Monetization (Monetization Innovation)**
Free and paid tiers deliver the same product with different AI model quality — not feature walls, not session limits. The conversion trigger is organic: users feel the depth gap during moments that matter ("I need a real plan for this career change") and upgrade naturally. This is a relatively untested monetization model in consumer AI and requires explicit validation that blind testers can perceive the quality gap between tiers.

### Validation Approach

| Innovation | Validation Method | Timeline | Success Signal |
|-----------|-------------------|----------|----------------|
| Coaching OS + Directive Trust Gap | Week 2 benchmark: 5 coaching conversations testing directive vs hedging responses | Pre-development | Blind testers prefer directive responses with contingency plans over hedging |
| System-Informed Directive Quality | Proxy MCM trending upward months 1-3 | Month 1-3 post-launch | Directive advice informed by persistent memory leads to user action — proving the system makes guidance accurate, not just confident |
| Anti-Engagement | Autonomy Throttle metrics at 6+ months | Month 6+ | 10%+ of long-term users show declining AI-initiated interactions with maintained completion rates |
| Quality Gradient | Week 2 benchmark: blind testers distinguish free vs paid tier quality | Pre-development | Perceptible quality gap confirmed; 5%+ conversion at 3 months |

### Risk Mitigation

| Innovation Risk | Fallback |
|----------------|----------|
| Users reject directive advice (prefer hedging) | Default to Discovery Mode emphasis; make directive guidance opt-in rather than default |
| Sprint framework feels like work, not coaching | Simplify to lightweight goal tracking; remove agile terminology; keep structure invisible |
| Anti-engagement kills revenue before referral engine matures | Slow the Autonomy Throttle; extend engagement window; add re-engagement paths for "graduated" users |
| Quality gradient not perceptible between tiers | Switch to feature differentiation (session limits, domain count) or adjust model pairing |

## Mobile App Specific Requirements

### Project-Type Overview

Native iOS application built with Swift/SwiftUI, targeting iOS 17+ (SwiftUI maturity threshold and future Apple Intelligence API compatibility). Conversation-driven primary interaction with a coaching home screen as the default state. Pure cloud inference for coaching with on-device data persistence.

### Platform Requirements

- **Platform:** iOS only (MVP). Android in Phase 2.
- **Minimum iOS:** 17.0 — SwiftUI stability, modern concurrency (async/await), and future Apple Intelligence API compatibility
- **Device targets:** iPhone only (MVP). iPad layout adaptation in Phase 2.
- **Language:** Swift with SwiftUI for UI, structured concurrency for networking
- **Local storage:** SQLite with sqlite-vec extension for RAG embeddings, encrypted via SQLite encryption or iOS Data Protection
- **Networking:** URLSession with async/await, streaming support for cloud coaching responses (Server-Sent Events or chunked transfer)
- **Animation:** Lottie for avatar state transitions, native SwiftUI animations for UI

### Device Permissions & Features

**Required Permissions:**
- **Network access** — required for all coaching conversations (cloud inference)
- **Push notifications** — check-ins, nudges, re-engagement, pause suggestions
- **Background app refresh** — post-conversation summarization and RAG embedding generation (if not completed in foreground)

**Device Features Used:**
- **Haptics (Taptic Engine)** — sprint step completion, avatar celebrations, milestone moments. Subtle, not aggressive — reinforces Joy pillar without being gimmicky.
- **Home Screen Widgets (WidgetKit)** — lightweight at-a-glance coaching presence:
  - Small widget: Avatar in current state + sprint progress indicator
  - Medium widget: Avatar + current sprint name + next action item + "Talk to coach" tap target
  - Widgets update on app background refresh — reflect current coaching state without requiring app open
  - Widgets serve as passive engagement surface — Priya sees her avatar "thinking" on her home screen and is gently reminded the coach is there
- **Keychain** — secure storage for authentication tokens and subscription state
- **Data Protection (NSFileProtection)** — on-device SQLite encrypted at rest via iOS file protection

**Not Required for MVP:**
- Camera (no avatar photo features in MVP)
- Microphone (no voice mode in MVP)
- Location (no context-aware features in MVP)
- HealthKit (Phase 4)
- Siri / App Intents (future consideration)

### Offline Mode

**Offline-available (on-device data):**
- Home screen with avatar in last known state
- Sprint progress and step list (viewable and completable)
- Past conversation history (stored summaries, browsable)
- Check-in history
- Widget display (last synced state)

**Requires connectivity:**
- All coaching conversations (cloud inference)
- New conversation initiation
- Push notification delivery
- Subscription validation (cached with grace period)

**Offline UX:**
- Clear but non-intrusive indicator when offline: "Your coach needs internet to chat, but you can review your progress and check off sprint steps"
- No error states or broken UI — everything on-device works smoothly
- Queued actions (sprint step completions while offline) sync when connectivity returns

### Push Notification Strategy

**Philosophy:** Notifications are coaching tools, not engagement hooks. Every notification should feel like it came from a thoughtful coach, not a marketing team. 1-2 per day maximum.

**Notification Types (MVP):**

| Type | Trigger | Frequency | Content Style |
|------|---------|-----------|---------------|
| Daily check-in | Scheduled, user-configurable time | 1x/day during active sprint | "Quick check-in: how's the sprint going?" |
| Pause suggestion | AI detects sustained high intensity | Rare, max 1x/week | "You've been pushing hard. Want to take a breather?" |
| Gentle re-engagement | Drift detection threshold (no interaction outside Pause Mode) | Max 1x after 7 days of silence | "No rush — your coach is here when you're ready" |
| Sprint milestone | Sprint step completed or sprint ending | Event-driven, max 1x/day | "Nice — step 2 done. Two more to go this sprint." |

**Notification Rules:**
- **Hard cap: 2 notifications per day maximum.** If multiple triggers fire, prioritize by: safety > check-in > milestone > re-engagement
- **Pause Mode suppresses all notifications** except safety-related
- **User controls:** Configurable check-in time, ability to mute all non-safety notifications
- **No notifications in first 24 hours** after install — let the onboarding conversation create the relationship first
- **Tone:** Always coach voice, never marketing. No guilt patterns.

### Store Compliance

**App Store Review Guidelines Considerations:**
- **Health/wellness classification risk:** Apple may classify directive coaching under health app guidelines (4.2, 4.6). Mitigation: clear disclaimers in app and metadata — "AI Life Coach is a personal development tool, not a medical device, therapy service, or clinical intervention."
- **Subscription compliance (3.1.2):** Clear subscription terms, pricing, and cancellation. No dark patterns. Free tier must be genuinely functional, not a degraded trial.
- **Privacy Nutrition Label:** Accurate data collection declarations. Local-only data handling is a strong privacy story for App Store review.
- **Content policy:** AI-generated coaching content must not violate Apple content guidelines. Clinical boundary system helps — Orange/Red protocols prevent the app from generating potentially harmful content.
- **In-App Purchase:** Subscription managed via StoreKit 2. Server-side receipt validation through backend proxy.

### Implementation Considerations

**Critical Path Dependencies:**
1. Backend proxy (Cloudflare Workers) must be operational before any coaching features work
2. SQLite + sqlite-vec setup for RAG is a foundation dependency — everything memory-related builds on this
3. Streaming response rendering (SSE parsing + incremental SwiftUI text display) is a UX-critical implementation
4. WidgetKit integration can be parallelized with main app development — independent target

**Technical Risks:**
- sqlite-vec is a niche extension — test thoroughly for memory usage and query performance with growing embedding count
- Streaming SSE parsing in Swift needs careful error handling — dropped connections mid-stream must recover gracefully
- WidgetKit timeline refresh has iOS-imposed limits — widgets may not always reflect real-time state
- Lottie animation performance on older devices (iPhone 11/12) needs benchmarking

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Experience MVP — the minimum product that delivers a *complete coaching experience*, not a feature checklist. Users should feel "this is a polished coaching product" not "this is a prototype." Intentionally focused, not unfinished.

**Resource Requirements:** Solo developer, ~14 weeks to launch. Critical path: Coaching Engine + Backend Proxy + Local RAG (weeks 2-7). Everything else layers on top.

**Infrastructure Stack:**
- **Backend proxy:** Railway (lightweight API server — Node.js/Python/Go)
- **Monitoring:** Sentry (error tracking, performance monitoring) + Railway deploy logs
- **Analytics:** App Store Connect (downloads, retention, ratings) + LLM provider dashboards (token usage, costs)
- **Safety compliance:** Server-side compliance logging for Boundary Response events
- **No custom admin dashboard at MVP** — provider dashboards cover ops needs at 1K user scale. Custom admin panel in Phase 2.

### Scoping Decisions Made During PRD Development

These decisions emerged from collaborative review and differ from or refine the original product brief:

| Decision | Original Brief | PRD Refinement | Rationale |
|----------|---------------|----------------|-----------|
| On-device Foundation Models | Auxiliary tasks (safety classification, summarization, extraction) | **Removed from MVP** — pure cloud for everything | Simplifies architecture for solo developer; coaching engine is cloud-only so offline safety classification solves a scenario that doesn't exist |
| Safety classification | On-device via Apple Foundation Models | **Inline in coaching prompt** — single cloud call returns coaching response + safetyLevel field | One inference path, no additional cost/latency; compensated by automated regression suite |
| Automated safety regression | Not specified | **Added to MVP** — 50+ prompts run as Railway pre-deploy hook, rollback on failure | Compensating control for inline classification; ensures 100% boundary compliance |
| Quality gap validation | Week 2 benchmark tests both tiers pass | **Added blind tester requirement** — testers must perceive quality gap between tiers | Validates conversion model before significant engineering investment |
| Priya's engagement pattern | Brief mentioned variable cadence | **Explicit architectural requirement** — long-gap RAG retrieval, sparse engagement, weekly check-in option | Highest-value conversion segment; RAG system must handle irregular patterns |
| Cross-session safety | Not addressed | **Known MVP limitation acknowledged** — per-turn only; system prompt workaround; Phase 2 hardening | Honest about safety gap; documented mitigation path |
| Home screen widgets | Not in brief | **Added to MVP** — small and medium WidgetKit widgets | Passive engagement surface; particularly valuable for slow-burn users like Priya |
| Domain label | "Wellness" | **"AI Coaching Systems"** | Positions against correct competitive set; signals system-not-chat |
| Backend proxy platform | Cloudflare Workers | **Railway** — lightweight API server with Sentry integration | Simpler deployment model, proper logging, native Sentry integration, pre-deploy hooks for safety regression |
| Monitoring | Not specified | **Sentry + Railway + provider dashboards** — no custom admin panel | Use existing tools at MVP scale; build custom when justified |
| Phase 2 safety hardening | Not specified | **Independent parallel classification + cross-session pattern analysis** | Dual-path classification removes single-point-of-failure for safety |

### Phased Roadmap

**Fast Follow (Weeks 2-4 Post-Launch):**
- Sprint retrospectives and velocity tracking
- Enhanced progress visualization
- Onboarding refinements from early user feedback

**Phase 2 (Months 4-9):**
- Android launch
- Domain separation with user-facing domain activation and switching
- Full 3D Living Avatar with rich customization
- Customizable coach personas per domain
- On-demand and proactive real-time research intelligence
- Cross-domain alerts and Connector role
- Full AI-triggered Relax Mode with smart activation
- Progressive Mastery levels
- Full RAG upgrade: cloud vector DB, re-embed with higher-quality model, filtered retrieval, memory consolidation, cross-device sync
- Evaluate on-device coaching inference if model quality reaches coaching gate
- Independent parallel safety classification layer (safety hardening — move from inline to dual-path classification)
- Cross-session safety pattern analysis (analyzing safety trends across a user's conversation history)
- User-viewable AI profile — users can browse and edit the structured profile the AI has built about them
- Recurring Deep Intake pattern — fresh discovery sprint for new domains or major life changes
- Custom admin dashboard

**Phase 3 (Months 10-18):**
- Growth Wrapped annual reports
- Full gamification layer (XP, levels, skill trees, quests)
- Social walls with effort-based visibility
- Streaks with freezes
- Coach companion quests
- Daily Growth Mix and Random Encounters

**Phase 4 (Months 18+):**
- Accountability partner matching
- Raid events and group challenges
- Cosmetic marketplace
- Enterprise/Team offering
- Wearable integration (HealthKit, Apple Watch)
- Voice assistant and web dashboard
- Multiple life profiles
- B2B bridge

### MVP Feature Set (Phase 1) — Confirmed

13 core MVP features:
1. Coaching Conversation Engine (pure cloud, inline safety)
2. Backend Proxy (Railway, multi-provider fallback)
3. AnyLanguageModel Abstraction
4. Local RAG System (SQLite + sqlite-vec)
5. Single Unified Coach (backend domain tagging)
6. Streamlined Sprint Framework
7. Home Screen
8. Simple 2D Avatar (Lottie + haptics)
9. Pause Mode (with Drift Detection)
10. Clinical Boundary System (inline, automated regression suite)
11. Privacy Architecture (on-device encrypted SQLite)
12. Onboarding (4 steps, under 2 minutes: welcome, avatar, name coach, first conversation)
13. Home Screen Widgets (WidgetKit — small + medium)

### MVP User Journeys Supported

| Journey | Supported in MVP | Key Dependencies |
|---------|-----------------|------------------|
| Maya (Discovery → Sprint) | ✅ Full | Discovery Mode, RAG, Sprint Framework |
| Marcus (Crisis → Directive) | ✅ Full | Directive Mode (paid), contingency plans, streaming |
| Kai (Cold Start → Light Sprint) | ✅ Full | Cold-start onboarding, lightweight sprints |
| Priya (Slow Burn → Conversion) | ✅ Full | Long-gap RAG, gentle nudges, weekly cadence |
| Alex (Directive + Challenger) | ✅ Full (paid tier) | Challenger, skill gap mapping, prep sessions |
| Clinical Boundary Escalation | ✅ Core (per-turn) | Inline safety, resource presentation, UI state change |
| Solo Dev Ops | ✅ Lightweight | Railway + Sentry + provider dashboards + compliance logging |

### Timeline & Critical Path

**Estimated Sprint Allocation (14 weeks):**
- Weeks 1-2: Project setup, Railway backend proxy, AnyLanguageModel abstraction
- Weeks 3-5: Coaching engine + system prompt engineering + inline safety classification
- Weeks 5-7: Local RAG (SQLite + sqlite-vec, embeddings, retrieval)
- Weeks 7-9: Sprint framework + daily check-ins
- Weeks 9-10: Home screen + avatar + onboarding
- Weeks 10-11: Pause Mode + Drift Detection + push notifications
- Weeks 11-12: Privacy architecture, encryption, StoreKit subscription
- Weeks 12-13: Widgets, polish, edge cases
- Week 14: Clinical test suite validation, App Store submission prep

**Critical Risk Window: Weeks 3-7** — Coaching engine + RAG is the heart of the product and the block with the most unknowns. If this takes 5 weeks instead of 4, the cut order activates.

### Risk Mitigation Strategy

**Technical Risk — Most Challenging Aspect:**
System prompt engineering that produces genuinely useful directive coaching, handles mode switching (Discovery ↔ Directive), maintains coach personality consistency, and embeds reliable inline safety classification. Validated in Week 2 benchmark, continuously monitored via monthly benchmarks and abandonment tracking.

**Market Risk — Biggest Uncertainty:**
Will users pay for quality gradient? The entire conversion model depends on users perceiving a depth gap between free and paid coaching. Week 2 blind testing is early validation. 3-month conversion rate is the definitive signal.

**Resource Risk — Solo Developer Cut Order:**
If the 14-week timeline slips, cut in this order:
1. Widgets (can ship post-launch, independent target)
2. Pause Mode AI suggestion (keep manual pause, defer AI-triggered suggestion)
3. Sprint visualization — **simplify to minimum viable UI** (do not hard-cut — protects 50% sprint adoption gate)
4. Avatar animations (keep static states, defer Lottie animations)

Core coaching engine, backend proxy, RAG, safety system, and onboarding are non-negotiable.

## Functional Requirements

> **Classification Note:** FRs involving AI behavioral quality (FR3, FR5, FR6, FR7, FR8, FR10, FR77) are benchmark-validated through the coaching conversation test suite, not automated unit tests. QA plan should distinguish these from automated-testable FRs.

### Coaching Conversation

- **FR1:** Users can initiate a coaching conversation at any time from the home screen
- **FR2:** Users can engage in multi-turn text-based coaching conversations with streaming AI responses
- **FR3:** The system can operate in Discovery Mode — facilitating exploration through probing questions, pattern surfacing, and values archaeology for users without clear goals
- **FR4:** The system can operate in Directive Mode — providing confident, specific action steps with contingency plans for users with defined goals (paid tier)
- **FR5:** The system can transition naturally between Discovery Mode and Directive Mode within a conversation as user needs evolve
- **FR6:** The system can surface patterns and connections across multiple past conversations during active coaching sessions
- **FR7:** The Challenger capability can push back on user decisions, provide alternative perspectives, and stress-test reasoning (non-negotiable, cannot be disabled)
- **FR8:** The system can generate contingency plans alongside primary recommendations (Plan B and Plan C)
- **FR9:** Users can view past conversation summaries and key moments
- **FR10:** The system can adapt coaching tone and intensity based on user state and engagement patterns

### Coaching Memory & Intelligence

- **FR11:** The system can generate and store conversation summaries with key moments, emotions, decisions, and topics after each conversation
- **FR12:** The system can retrieve the most relevant past conversation summaries based on topic and recency when starting a new conversation
- **FR13:** The system can maintain structured user profiles with core facts (values, goals, domain state, personality traits)
- **FR14:** The system can tag conversations and goals by life domain in the backend
- **FR15:** The system can handle long-gap retrieval for users with irregular engagement patterns (days to weeks between conversations)

### Sprint Framework

- **FR16:** Users can set goals and break them into actionable steps through coaching conversations
- **FR17:** Users can create sprints with configurable duration (1-4 weeks)
- **FR18:** Users can view their current sprint with progress at a glance (steps completed/total)
- **FR19:** Users can mark sprint steps as complete
- **FR20:** Users can perform daily check-ins (quick pulse, not mandatory)
- **FR21:** Users can choose their check-in cadence (daily or weekly)
- **FR22:** The system can create lightweight sprints for users with minimal goals (single action items)

### Onboarding

- **FR23:** New users can complete onboarding in under two minutes through four steps: welcome moment, avatar selection, name your coach, first coaching conversation
- **FR24:** The onboarding coaching conversation can deliver value to users with no stated problem (cold-start capable)
- **FR25:** The system can communicate clinical boundary transparency during onboarding ("I'm your coach, not your therapist")

### Home Screen

- **FR26:** Users can view their avatar in its current state on the home screen
- **FR27:** Users can view their current sprint status and progress on the home screen
- **FR28:** Users can initiate a coaching conversation from the home screen via a primary action
- **FR29:** Users can view their most recent check-in or coaching insight on the home screen

### Avatar System

- **FR30:** Users can select a basic avatar style during onboarding
- **FR31:** The avatar can display in 3-5 states that mirror the user's coaching state (active, resting, celebrating, thinking, struggling)
- **FR32:** The avatar can animate between states with smooth transitions
- **FR33:** Users can customize their avatar appearance within available options at any time (during onboarding and from settings)

### Pause Mode & Engagement

- **FR34:** Users can manually pause all coaching nudges, check-ins, and goal tracking
- **FR35:** The system can suggest pausing when it detects sustained high-intensity engagement
- **FR36:** The system can reflect pause state in the avatar and home screen UI
- **FR37:** The system can distinguish between healthy pause and disengagement (Drift Detection)
- **FR38:** The system can send gentle re-engagement nudges after configurable periods of inactivity outside of Pause Mode

### Clinical Boundary System

- **FR39:** The system can classify every coaching response with a safety level (Green/Yellow/Orange/Red) inline with the coaching output
- **FR40:** The system can adapt coaching tone based on safety classification (Yellow: coach with care, suggest professional support)
- **FR41:** The system can pause all coaching activities and present professional resources on Orange/Red classification
- **FR42:** The system can strip gamification and avatar activity from the UI during Orange/Red states
- **FR43:** The system can provide a post-crisis re-engagement flow when users return after a boundary event
- **FR44:** The system can log all boundary response events for compliance tracking
- **FR45:** The system can run automated safety regression tests against clinical edge-case prompts before every deployment

### Push Notifications

- **FR46:** Users can receive push notifications for daily check-ins at a user-configurable time
- **FR47:** Users can receive push notifications for sprint milestones
- **FR48:** Users can receive pause suggestions via push notification
- **FR49:** Users can receive gentle re-engagement nudges via push notification
- **FR50:** The system can enforce a hard cap of 2 notifications per day with priority ordering
- **FR51:** Users can configure notification preferences (check-in time, mute non-safety notifications)
- **FR52:** The system can suppress all non-safety notifications during Pause Mode

### Monetization & Subscription

- **FR53:** Users can access the full coaching product on the free tier with a lightweight cloud model
- **FR54:** Users can subscribe to the paid tier for premium model coaching depth via in-app purchase
- **FR55:** The system can route coaching requests to the appropriate model tier (free/paid) via the backend proxy
- **FR56:** The system can enforce invisible soft guardrails on daily session volume without exposing usage counters to users
- **FR57:** The system can transition naturally when soft guardrails are reached ("We've covered a lot today. Let's let these insights settle.")
- **FR58:** Safety features can operate identically regardless of subscription tier

### Privacy & Data

- **FR59:** Users can have all personal data (conversation summaries, embeddings, profiles, sprint state, avatar state) stored on-device in encrypted local storage
- **FR60:** Users can have coaching conversations processed via cloud API with zero-retention provider agreements
- **FR61:** Users can delete all their data from the app
- **FR62:** The system can display clear privacy communication during onboarding

### Backend & Infrastructure

- **FR63:** The backend proxy can route requests to multiple LLM providers with automatic failover on provider outage
- **FR64:** The backend proxy can protect API keys (keys never in app binary)
- **FR65:** The backend proxy can enforce tier-based model routing and soft guardrail logic
- **FR66:** The backend proxy can collect usage analytics for monitoring
- **FR67:** The system can swap cloud model providers server-side without requiring an app update

### Widgets

- **FR68:** Users can add a small home screen widget displaying avatar state and sprint progress
- **FR69:** Users can add a medium home screen widget displaying avatar, sprint name, next action, and a tap target to open the coach

### Offline Capability

- **FR70:** Users can view the home screen, avatar, sprint progress, and past conversation summaries while offline
- **FR71:** Users can mark sprint steps as complete while offline with sync when connectivity returns
- **FR72:** The system can display a non-intrusive offline indicator when coaching conversations are unavailable

### Conversation History & Profile

- **FR73:** Users can correct the AI's understanding of their situation through conversation and the system updates its stored profile accordingly
- **FR74:** The system can gracefully handle cloud provider failure mid-conversation — partial responses are preserved, failover to secondary provider resumes generation, and the user sees a seamless or minimally interrupted experience
- **FR75:** Users can browse and navigate their past conversation history with summaries and key moments
- **FR76:** Users can change their avatar style and customization at any time from settings

### Autonomy & Self-Reliance

- **FR77:** The system can gradually reduce AI-initiated coaching interactions (nudges, check-in prompts, suggestions) as a user demonstrates increasing self-reliance over time (Autonomy Throttle)
- **FR78:** The system can track engagement source data for every interaction (AI-initiated vs user-initiated, notification-triggered vs organic) to power Autonomy Throttle analysis from day one

### Compliance & Transparency

- **FR79:** Users can access coaching disclaimers, privacy information, and terms of service at any time from app settings

### Coach Personalization

- **FR80:** Users can name their coach during onboarding and change the coach name at any time from settings

### System Prompt Requirements Checklist

> The following FRs, NFRs, and design principles are implemented primarily through the coaching system prompt. The developer must verify structural coverage through system prompt review, and QA must validate behavioral coverage through the benchmark conversation suite:
>
> - FR3 — Discovery Mode facilitation
> - FR4 — Directive Mode with confident guidance
> - FR5 — Natural mode transition
> - FR6 — Pattern surfacing across conversations
> - FR7 — Challenger pushback (non-negotiable)
> - FR8 — Contingency plan generation
> - FR10 — Tone and intensity adaptation
> - FR24 — Cold-start onboarding value delivery
> - FR25 — Clinical boundary transparency
> - FR39 — Inline safety classification (safetyLevel structured output)
> - FR40 — Safety-aware tone adaptation
> - FR57 — Soft guardrail natural transitions
> - FR77 — Autonomy Throttle behavior
> - NFR38 — Cultural adaptability
> - Coach Personality & Voice — entire section (curious, warm, sharp; adaptive formality; knows when to shut up)
> - Life Technical Debt — coaching concept identification and surfacing
> - Coach uses its user-given name in self-reference

### Functional Requirements Summary

**Total: 80 FRs across 16 capability areas**
- Coaching Conversation: FR1-FR10
- Coaching Memory & Intelligence: FR11-FR15
- Sprint Framework: FR16-FR22
- Onboarding: FR23-FR25
- Home Screen: FR26-FR29
- Avatar System: FR30-FR33
- Pause Mode & Engagement: FR34-FR38
- Clinical Boundary System: FR39-FR45
- Push Notifications: FR46-FR52
- Monetization & Subscription: FR53-FR58
- Privacy & Data: FR59-FR62
- Backend & Infrastructure: FR63-FR67
- Widgets: FR68-FR69
- Offline Capability: FR70-FR72
- Conversation History & Profile: FR73-FR76
- Autonomy & Self-Reliance: FR77-FR78
- Compliance & Transparency: FR79
- Coach Personalization: FR80

## Non-Functional Requirements

> **Classification Notes:**
> - NFR13 (zero-retention provider agreements) is compliance-verified through provider contracts and API configuration review, not automated testing.
> - FRs involving AI behavioral quality (FR3, FR5, FR6, FR7, FR8, FR10, FR77) are benchmark-validated through the coaching conversation test suite, not automated unit tests.

### Performance

- **NFR1:** Coaching response time-to-first-token must be under 1.5 seconds from user message submission
- **NFR2:** Streaming coaching responses must render incrementally — users see text appearing within 1.5 seconds, full response generation may take 5-10 seconds
- **NFR3:** Multi-provider failover must detect primary provider failure and reroute within 5 seconds
- **NFR4:** App cold launch to home screen must complete within 3 seconds on iPhone 12 or newer
- **NFR5:** Local RAG retrieval (embedding search + summary fetch) must complete within 500ms
- **NFR6:** Push notification delivery from trigger event to device must occur within 60 seconds under normal conditions
- **NFR7:** Avatar state transitions (Lottie animations) must render at 60fps on iPhone 12 or newer
- **NFR8:** Widget updates must reflect current coaching state within 15 minutes of app background refresh

### Security

- **NFR9:** All on-device data (SQLite database, RAG embeddings, user profiles) must be encrypted at rest using iOS Data Protection (NSFileProtectionComplete)
- **NFR10:** All network communication between app and backend proxy must use TLS 1.3
- **NFR11:** API keys for LLM providers must never be stored in or accessible from the app binary — all provider communication routed through backend proxy
- **NFR12:** Authentication tokens must be stored in iOS Keychain, not UserDefaults or local storage
- **NFR13:** Cloud LLM provider agreements must include zero-retention clauses — conversation data must not be used for model training
- **NFR14:** User data deletion (FR61) must be complete and irreversible within 24 hours of request — no residual data in local storage, backend logs, or provider systems
- **NFR15:** Boundary Response Compliance events must be logged with append-only server-side storage with audit trail — logs are append-only and include timestamps and event metadata for compliance review
- **NFR16:** Safety regression test suite must run in an isolated environment — test prompts must never interact with production user data or models

### Scalability

- **NFR17:** Backend proxy architecture must support horizontal scaling to handle 10x user growth (1K → 10K active users) without architectural changes
- **NFR18:** Local SQLite + sqlite-vec must maintain query performance with up to 10,000 conversation summaries and embeddings per user (approximately 2 years of daily use)
- **NFR19:** Backend proxy must support adding new LLM providers without code changes to the app (server-side configuration only)
- **NFR20:** Push notification infrastructure must support batch delivery to 25K+ devices without delivery degradation

### Accessibility

- **NFR21:** All UI elements must support VoiceOver with meaningful labels — coaching conversations, sprint progress, avatar state, and navigation must be fully accessible via screen reader
- **NFR22:** All text must support Dynamic Type (iOS text size settings) — coaching conversations, sprint steps, check-in prompts, and navigation must scale with user font size preferences
- **NFR23:** Touch targets must meet Apple HIG minimum of 44x44 points for all interactive elements
- **NFR24:** Color usage must not be the sole indicator of state — avatar states, sprint progress, and safety classifications must be distinguishable without color perception (shape, label, or pattern alternatives)
- **NFR25:** Coaching conversation text must maintain WCAG 2.1 AA contrast ratio (4.5:1 for body text, 3:1 for large text) in both light and dark mode
- **NFR37:** The system must respect the iOS "Reduce Motion" accessibility setting — when enabled, replace Lottie animations with simple crossfades and keep avatar functional but static
- **NFR38:** The coaching system must adapt to cultural context — coaching advice, goal frameworks, and success definitions must not assume Western-centric models of career, family, success, or personal development. The system must ask about cultural context during intake rather than assuming defaults.

### Integration

- **NFR26:** Backend proxy must support simultaneous integration with at least 2 LLM providers (primary + fallback) with provider-agnostic request/response mapping
- **NFR27:** StoreKit 2 integration must handle subscription state changes (purchase, renewal, cancellation, grace period) with server-side receipt validation
- **NFR28:** Apple Push Notification service (APNs) integration must handle token refresh, delivery failures, and device unregistration gracefully
- **NFR29:** Sentry SDK integration must capture crash reports, performance traces, and custom events without impacting app performance (< 1% CPU overhead)
- **NFR30:** Railway deployment must support zero-downtime deploys with automatic rollback on health check failure

### Reliability

- **NFR31:** Overall system availability must be 99.5% measured monthly (backend proxy + at least one LLM provider operational)
- **NFR32:** On-device features (home screen, sprint progress, conversation history, avatar, widgets) must be 100% available regardless of network state
- **NFR33:** The system must handle network transitions (WiFi → cellular, connectivity loss/recovery) without losing conversation state or requiring app restart
- **NFR34:** Failed sprint step completions (offline sync) must retry automatically on connectivity restoration with conflict resolution
- **NFR35:** The system must recover gracefully from app backgrounding/foregrounding mid-conversation — conversation context preserved, streaming response resumable or restartable
- **NFR36:** The system must support iOS standard backup/restore mechanisms (iCloud backup, device migration) for all on-device coaching data by default, with a user-facing option to exclude coaching data from iCloud backup
