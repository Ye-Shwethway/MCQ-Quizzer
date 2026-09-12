# MCQ Quizzer — Product Evolution Implementation Roadmap

Status: **planning / discussion only**  
Owner: Product direction by Owner; DEDAL owns user-facing product/UX slices; Codex owns Android/release foundation unless explicitly handed over.  
Planning branch: `dedal/product-roadmap-v2`  
Baseline carried forward from validated quiz-session polish branch: `7b5c3f4125f971f6fe9e3b2ef484964858648db7`  
Current app version: `1.0.0+4`

## 1. Product direction

MCQ Quizzer should evolve from a local quiz-file player into a **personal adaptive exam-preparation system** while keeping the current strengths:

- offline-first/local-first study workflow
- user-owned question banks and attempt history
- bring-your-own AI provider/model architecture
- fast manual validation on emulator/phone
- simple, understandable UX instead of over-engineered automation
- no requirement that AI be used for ordinary quiz-taking

The target product loop is:

> Import / Generate → Organize → Practice → Review mistakes → Measure progress → Understand weaknesses → Generate targeted practice → Repeat.

The roadmap deliberately builds the data foundation before advanced AI coaching. AI should interpret reliable study signals, not invent them from loosely structured history.

---

## 2. Current-state observations that drive the roadmap

### 2.1 Home screen density

The phone home screen currently uses a one-column `GridView` with a low child aspect ratio, causing the two existing feature cards to consume more than one viewport. This will scale poorly when more entry points are added.

Direction:
- replace oversized feature cards with compact responsive tiles
- make 2-column the normal phone layout where width/text-scale permits
- use 1-column fallback for very narrow layouts or large accessibility text
- reserve home real estate for future entry points such as Practice, Mistakes, AI Coach, Documents, and Progress

### 2.2 Timer range

Current preset timer values stop at 120 minutes. Real exam simulations can run 3 hours or longer.

Direction:
- extend presets through 5 hours
- allow a bounded custom duration
- keep existing Practice vs Exam semantics
- avoid changing scoring/attempt persistence unless required

### 2.3 Dashboard/history coupling

The dashboard currently reconstructs history by enumerating current quiz sets and reading history for each set. The database also links history/progress/notes to quiz sets through cascading relationships.

Risk:
- deleting a quiz set can remove or hide historical learning evidence
- future AI analysis becomes unreliable if historical attempts disappear when library content is cleaned up

Direction:
- separate **library lifecycle** from **attempt-history lifecycle**
- archive/remove-from-library should not erase completed learning history
- destructive deletion of history must be explicit

### 2.4 Existing useful foundation

The database already contains `attempt_id` and `quiz_snapshot` support. This should be used to preserve historical attempt context independently of later edits to a quiz set.

### 2.5 AI and manual sources

The current dashboard does not intentionally exclude either AI-generated or manually uploaded sets; both participate when they exist in the library. Future reporting should retain source metadata and allow filters, not split the learning model into incompatible paths.

---

# 3. Delivery principles

1. **Small coherent slices.** Avoid giant migrations that mix UI, storage, AI, and release work.
2. **Manual acceptance first.** Normal loop remains implementation → analyzer → Codex local build/run → Owner emulator test → targeted fix.
3. **No broad test-suite gate.** Add focused tests only for high-value state/migration logic when justified.
4. **History is user data.** Library cleanup must not casually destroy learning history.
5. **AI is interpretation, not truth.** Deterministic local analytics should be the source of numeric performance facts.
6. **Source-preserving generation.** Document-generated questions should retain traceable source references where technically possible.
7. **No forced cloud account.** The app should remain useful offline/local without a proprietary backend account.
8. **Provenance compliance is unresolved.** Do not start machine-readable Article 50 provenance schema/export migrations until legal/technical role and standard are agreed.
9. **Release ownership separation.** DEDAL should not silently edit Codex-owned Android/release files; Codex should not silently edit DEDAL-owned product files.

---

# 4. Proposed implementation sequence

## Slice P1 — Compact Home + Extended Exam Timer

**Goal:** remove immediate UI friction and make the app ready for more feature entry points.

### Home

Proposed phone behavior:
- compact 2-column tiles on normal phones
- 1-column fallback on narrow widths / large text scale
- target compact visual height rather than large aspect-ratio cards
- icon + feature title + one short supporting line
- remove long repeated descriptions from the home surface
- preserve Material 3, light/dark themes, tap affordance, accessibility semantics

Initial cards remain:
- Quiz Generation
- Quiz Library

Architecture should make later cards easy to add without redesigning the screen.

Likely future cards:
- Practice
- Mistakes
- AI Coach
- Documents
- Progress

### Timer

Preset proposal:
- 15 min
- 30 min
- 45 min
- 60 min
- 90 min
- 120 min
- 180 min
- 240 min
- 300 min
- Custom

Custom rules:
- maximum 5 hours
- clear hour/minute presentation
- reject zero/invalid values
- keep Practice pause behavior
- keep Exam deadline/background-continuation behavior

### Acceptance

- both current home cards fit comfortably in one normal phone viewport
- no card text clipping on small phone layout
- tablet layout remains sensible
- a 180-minute and a 300-minute exam session can be started
- timer formatting remains readable for durations above two hours
- existing timer persistence/resume semantics are unchanged

### Ownership

DEDAL.

---

## Slice P2 — Durable Attempt History + Archive Semantics

**Goal:** make study history independent from routine library cleanup.

This is the most important structural slice before advanced analytics.

### Product behavior

Replace destructive-first library removal with:

- **Archive / Remove from Library** — default safe action
  - hides the set from normal active library views
  - completed attempt history remains available
  - saved snapshots remain available for historical review
- **Permanent Delete** — explicit advanced/destructive action
  - user must understand whether attempts/history will also be removed

Recommended destructive choices if technically justified:
- delete library set, keep historical attempts
- delete library set and all associated history

Never silently erase history merely because a set is no longer wanted in the Library.

### Data model direction

Evaluate one of these designs during implementation planning:

**Preferred direction:** attempts become durable records with snapshot/title/source metadata sufficient for dashboard/history even if source set is archived/deleted.

Potential additions:
- `archived_at` or `is_archived` on `quiz_sets`
- durable `quiz_title_snapshot`
- source snapshot (`uploaded`, `ai`, `combined`, `document`, `practice`)
- subject/tag snapshot when topic metadata exists
- preserve `quiz_snapshot`

Avoid a migration that rewrites all historical quiz content unnecessarily.

### Dashboard changes

Dashboard must query historical attempts directly rather than requiring the parent quiz set to remain active.

History cards should still be renderable when:
- the source set is archived
- the source set was renamed later
- the source set has been removed from active Library

### Acceptance

- archive a completed quiz set → Dashboard stats/history remain unchanged
- archive an in-progress set → behavior is explicitly defined and safe
- permanent deletion prompts accurately describe consequences
- old history records remain readable after title changes
- AI/manual source metadata remains available

### Ownership

DEDAL data/product slice. Coordinate before any Android backup-rule assumptions change.

---

## Slice P3 — Library Power Tools

**Goal:** make the Library useful for a growing question bank.

### 3A. Rename

Backend rename support already exists; expose reliable UI.

Requirements:
- rename from card/menu/detail
- trim/validate empty names
- history displays historical or current title according to the P2 decision

### 3B. Multi-select

Add Library selection mode:
- select multiple quiz sets
- select all / clear selection where useful
- selection count in app bar/action area
- actions are disabled when incompatible

### 3C. Combine as a new set

Default combine behavior:

> original sets remain untouched; a **new quiz set** is created.

Possible options:
- keep source order
- shuffle questions
- choose all questions
- choose random N questions
- future: filter by mistakes/unanswered/tags

Metadata for a combined set should retain source set IDs/titles where possible without creating fragile hard dependencies.

Source label proposal: `combined`.

### 3D. Duplicate / Archive

Useful supporting actions:
- Duplicate
- Archive / Restore
- Permanent Delete

### Acceptance

- combining A+B creates C and leaves A+B unchanged
- C is independently renameable/attemptable/deletable
- selection mode works with AI and manual sets
- duplicate questions do not crash combine; optional dedupe is a later enhancement
- Dashboard records attempts on combined sets correctly

### Ownership

DEDAL.

---

## Slice P4 — Practice Intelligence Foundation

**Goal:** convert raw attempts into reusable study queues before adding AI interpretation.

### Signals to track

At minimum distinguish:
- correct
- wrong
- unanswered
- partially answered where question type supports it
- user-marked guessed/unsure

Proposed lightweight confidence action:
- `Sure`
- `Unsure / Guessed`

Do not force an extra tap for every answer; confidence marking should be optional and fast.

### Derived queues

- Mistakes
- Unanswered
- Guessed/Unsure
- Bookmarked
- Mixed review

### Custom Practice builder

Build a practice session from:
- one or more source sets
- mistakes only
- unanswered only
- guessed only
- selected tags/topics later
- random N
- optional shuffle

A practice session creates a new attempt without mutating the source question banks.

### Acceptance

- wrong questions from completed attempts can be reopened as a targeted practice session
- original sets remain unchanged
- repeated practice contributes new attempts, not overwritten scores
- confidence state is optional and backward compatible

### Ownership

DEDAL.

---

## Slice P5 — Progress Dashboard v2

**Goal:** make the dashboard a real longitudinal study tool.

### Core deterministic analytics

Compute locally:
- total attempts
- total questions attempted
- accuracy
- recent accuracy trend
- best/recent score
- average time per question where data exists
- repeated misses
- unanswered rate
- guessed/unsure rate
- mistake recovery rate

### Filters

Plan for:
- all sources
- AI-generated
- uploaded/manual
- combined/practice
- date range
- quiz set
- subject/topic when tags exist

### Mastery-oriented views

Use simple categories rather than fake precision:
- Strong
- Developing
- Needs Review

Potential mastery criteria must be deterministic and documented.

### Source coverage

Dashboard should cover attempts regardless of whether the originating set was:
- AI-generated
- manually uploaded
- combined
- document-generated
- targeted-practice generated

### Acceptance

- deleting/archiving active library content does not unexpectedly erase aggregate progress
- filters reconcile to all-attempt totals
- statistics are computed locally from stored attempt data
- no AI call is required to view dashboard analytics

### Ownership

DEDAL.

---

## Slice P6 — AI Coach / Adaptive Study Analysis

**Goal:** turn reliable progress data into useful personalized recommendations.

### Architecture

Do **not** send raw database history to an LLM and ask it to invent an analysis.

Pipeline:

1. Local deterministic analytics produce structured signals.
2. Select only relevant context, such as repeated missed questions and topic metadata.
3. Build a compact privacy-aware analysis payload.
4. User selects a verified AI provider/model.
5. LLM explains weaknesses and recommends study actions.

### Suggested AI Coach output

- strongest areas
- weakest areas
- recurring misconceptions
- areas with low confidence despite correct answers
- recent improvement/regression
- recommended next topics
- suggested review order

### High-value action

`Generate Targeted Practice`

This should feed a generation flow with structured objectives such as:
- focus on 2 weak topics
- avoid exact duplicates unless requested
- match selected difficulty
- generate N questions
- preserve source/provenance metadata already supported by the product

### Guardrails

- show that analysis is AI-generated
- do not present medical/study recommendations as authoritative truth
- local metrics remain the factual source
- AI should not rewrite historical scores
- user can inspect why a recommendation was made

### Acceptance

- same deterministic stats produce consistent numeric inputs independent of model
- AI failure does not damage dashboard/history
- targeted practice can be generated from a selected recommendation
- provider/model selection uses the existing verified saved-model flow

### Ownership

DEDAL product/AI slice. Coordinate report/disclosure requirements with release/compliance work.

---

## Slice P7 — Document-to-Quiz

**Goal:** generate tailored question sets from user study materials, not prompt text alone.

### Supported source plan

Initial candidates:
- PDF
- DOCX
- PPTX
- plain text / pasted notes

Later candidates:
- images/scans
- audio/video transcripts

### Extraction strategy

Prefer local/native text extraction first:

`document → extracted text → structure/chunks → LLM`

Use vision only when needed:

`scan/image-heavy page → image → vision-capable model`

Do not require a vision model for a normal text PDF.

### Generation controls

- question count
- question type
- difficulty
- selected chapters/pages/sections when feasible
- include/exclude topics
- optionally prefer high-yield concepts

### Grounding

Generated questions should retain source references where feasible:
- document ID/title
- page number
- section/chapter
- extracted chunk locator

Review UI should surface source references so the user can verify questionable answers.

### Large-document strategy

Avoid sending an entire large document in one request.

Pipeline proposal:
- extract
- normalize
- chunk
- optionally summarize/index
- select relevant chunks
- generate in batches
- validate JSON/schema
- merge into one quiz set

### Privacy

Explain clearly that selected document content may be sent to the user-selected AI provider when generation is performed.

Never transmit saved provider API keys in generated report/content payloads.

### Acceptance

- text PDF can generate questions without a vision model
- scanned PDF clearly requests a vision-capable model or compatible fallback
- large files fail gracefully or batch safely
- generated set records document source metadata
- source references are viewable during review

### Ownership

DEDAL, with plugin/platform review from Codex only if Android file-access changes are required.

---

## Slice P8 — Engagement Layer

**Goal:** make studying feel alive without turning a serious exam-prep app into a noisy game.

### Suitable features

- subtle session-complete animation
- personal-best animation
- study streaks
- 3/7/14/30-day milestones
- mastery progress ring
- mistake-recovery count
- contextual encouraging copy
- optional haptics/sound

Example copy:
- `Strong recovery in Pharmacology.`
- `12 missed questions recovered this week.`
- `Three topics still need review.`
- `New personal best.`

### Avoid

- speed-based XP as the primary reward
- distracting animation during timed exams
- punishment/shame for broken streaks
- random celebratory UI after incorrect answers
- anything that blocks results or study content

### User control

Add a `Focus Mode` / reduced celebration option if the engagement layer grows.

### Acceptance

- timed quiz flow remains distraction-free
- animations respect reduced-motion/accessibility behavior where possible
- engagement state never affects scoring
- app remains fully usable with engagement features disabled

### Ownership

DEDAL.

---

# 5. Cross-cutting data model proposal

The following concepts should be considered before P2–P6 implementation.

## Quiz set source type

A stable source field should be able to represent:
- uploaded
- ai_generated
- combined
- document_generated
- targeted_practice

Migration must preserve current `uploaded` / AI-generated behavior.

## Attempt identity

`attempt_id` remains the stable identifier for one study attempt.

Attempt records should be self-describing enough for historical display even if source library state changes.

## Question identity

Future mistake recovery and combine/dedupe features benefit from stable question identity.

Options to evaluate:
- generated UUID at import/generation time
- deterministic content hash as secondary duplicate hint

Do not rely only on list index across edited sets.

## Topic/tag metadata

AI Coach becomes much more useful if questions can carry optional metadata such as:
- subject
- system
- topic
- difficulty
- source reference

This can be added incrementally; do not block P1/P2 on a perfect taxonomy.

## Derived practice sets

Where possible distinguish:
- durable library set
- temporary/generated practice session

Avoid multiplying copied quiz sets solely for every filtered practice run unless the Owner explicitly saves one.

---

# 6. AI disclosure, reporting, and provenance boundary

Visible disclosure/reporting remains planned, but it should not be mixed into the next basic UX slice.

Current agreed direction:
- compact AI fallibility disclosure at generation/review boundaries
- `AI generated` identification on appropriate Library/review surfaces
- lightweight per-question/content report actions, not a permanent warning banner during quiz-taking
- reports require a real HTTPS destination and operator workflow before shipping as successful reporting

Machine-readable Article 50 provenance remains **research/decision gated**.

Do not implement schema/export/re-import provenance migrations until:
- legal role is determined
- a concrete applicable standard is selected
- Owner approves the compatibility/migration cost

---

# 7. Suggested milestone grouping

## Milestone A — UI and exam usability
- P1 compact Home
- P1 extended timer

## Milestone B — trustworthy study data
- P2 durable history/archive
- P3 Library power tools

## Milestone C — adaptive practice
- P4 practice intelligence
- P5 Dashboard v2

## Milestone D — AI-guided learning
- P6 AI Coach

## Milestone E — content ingestion
- P7 Document-to-Quiz

## Milestone F — retention/polish
- P8 Engagement layer

Release/compliance work from Codex proceeds in parallel where non-overlapping.

---

# 8. Recommended immediate next action

Before coding more large features, ask Codex to independently review this roadmap and challenge:

- ordering
- data migration risks
- SQLite/history architecture
- timer edge cases
- archive/delete semantics
- combined-set representation
- question identity strategy
- dashboard scalability
- AI Coach privacy/context strategy
- document parsing/plugin/platform risks
- Android storage implications
- accessibility/performance implications
- areas where two agents can work safely in parallel

Codex should return **discussion/proposal only** first. No roadmap slice implementation should begin from that review unless the Owner explicitly approves it.

After joint review, update this roadmap with the agreed plan, then begin **P1 — Compact Home + Extended Exam Timer** as the next implementation slice.
