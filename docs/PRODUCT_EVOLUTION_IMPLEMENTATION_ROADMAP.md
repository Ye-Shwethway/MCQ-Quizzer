# MCQ Quizzer — Product Evolution Implementation Roadmap

Status: **architecture challenge closed; Owner-approved roadmap contract**
Owner: Product direction by Owner. DEDAL owns user-facing product/data slices unless explicitly coordinated. Codex owns Android/release foundation unless explicitly handed over.
Current implementation branch: `dedal/history-repair-v1`
Stable main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
Current app version: `1.0.0+4`

Canonical architecture decisions:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

## 1. Product direction

MCQ Quizzer evolves from a local quiz-file player into a personal adaptive exam-preparation system while preserving:
- offline-first/local-first usefulness
- user-owned question banks and history
- bring-your-own AI provider/model architecture
- deterministic local study facts
- small manually validated delivery slices
- simple practical architecture over generalized frameworks

Target loop:

> Import / Generate → Organize → Practice → Review mistakes → Measure progress → Understand weaknesses → Generate targeted practice → Repeat.

AI interprets reliable local facts; it does not invent or overwrite numeric history.

## 2. Delivery rules

1. Small coherent slices; do not combine UI, storage, AI, migration, and release work unnecessarily.
2. Normal loop: implementation → analyzer → Codex local emulator build when available OR meaningful APK → Owner phone test → targeted fixes → docs/handoff.
3. Do not restore broad automated tests as a delivery gate. Focused regression/migration checks are allowed when justified.
4. Do not merge to `main` without explicit Owner approval.
5. DEDAL and Codex keep ownership boundaries and coordinate high-conflict files.
6. Machine-readable Article 50 provenance/schema/export work remains decision-gated.

## 3. Current bounded repair gate — finish before roadmap expansion

Current branch already contains:
- accepted responsive Home layout
- timer presets through 300 minutes
- transitional history-preservation repair
- APK #32 Results overflow repair under Owner test

Before starting the larger roadmap:
1. Owner accepts APK #32 Results behavior.
2. Change Library wording from destructive `Delete` language to `Remove from Library`.
3. Explicitly state that completed history is preserved.
4. Manually validate:
   complete quiz → Dashboard history exists → Remove from Library → set disappears → completed history/statistics remain.
5. Owner accepts the bounded repair.
6. Owner chooses the next slice.

The current transitional source markers `archived_ai_generated` / `archived_uploaded` remain a bridge only. Do not add more marker variants.

## 4. Approved implementation sequence

### P1R — Timer persistence/process-death hardening

Home compact layout and timer presets are already implemented; only long-session durability remains unfinished.

When selected, harden:
- debounced durable checkpoints after meaningful answer/navigation changes
- serialized/upsert persistence by attempt ID
- Practice resume from last durable paused state
- Exam original duration + absolute UTC deadline persistence
- expired-away finalization exactly once
- focused validation for background/resume, lock/unlock, process kill/relaunch, Save & Exit, repeated resume, near-zero time

Do not rely only on lifecycle callbacks before process death.

### P2a — Durable Attempt History + Identity + FK-safe migration

Goal: completed attempts become independently readable from Library lifecycle.

Required direction:
- stable `attempt_id`
- complete versioned `quiz_snapshot`
- title/source snapshots sufficient for historical display
- answers + scoring version preserved
- stable question identity foundations
- direct all-attempt queries independent of active quiz-set enumeration
- safely rebuild history where needed so parent reference can be nullable / `ON DELETE SET NULL`
- explicitly enable SQLite foreign keys only after backfill/table-rebuild safety is complete
- transactional forward migration with row-count/integrity validation
- preserve pre-existing orphaned history where possible rather than silently dropping it

Do not put Remove-from-Library UI migration, analytics tables, and permanent-delete UI into this same slice.

### P2b — Permanent Remove-from-Library schema integration

V1 user-facing concept is **Remove from Library**, not Archive.

Long-term state field:
`removed_from_library_at`

Approved Remove from Library semantics:
- hidden from active Library
- completed history preserved
- notes preserved
- incomplete progress retired

A future true resumable Archive workspace, if ever approved, is a separate feature with separate semantics.

Permanent source deletion remains unreachable until P2a is proven. Future permanent deletion contract:
- completed immutable attempts survive
- incomplete progress is deleted
- set-scoped notes are deleted
- history deletion is a separate deliberate data-management action

### P3a — Rename

Expose existing rename support safely:
- trim/validate empty names
- rename from appropriate Library surface
- historical title display follows durable snapshot policy

### P4 — Practice Intelligence Foundation

Introduce stable per-question study signals and targeted queues:
- correct
- wrong
- partial
- unanswered
- optional guessed/unsure

This is the approved point to introduce a narrow `attempt_question_results` table if needed.

P2a must preserve enough versioned snapshot/answer/scoring/identity data for deterministic P4 backfill.

Targeted queues:
- Mistakes
- Unanswered
- Guessed/Unsure
- Bookmarked
- Mixed review

Virtual sessions are preferred for unsaved targeted practice; saving materializes a durable copied set.

### P5 — Progress Dashboard v2

Compute deterministic local analytics:
- attempts/questions answered
- accuracy and trend
- repeated misses
- unanswered/guessed rates
- recovery rate
- time-per-question where valid

Start with practical filters such as date/source/set. Use documented mastery bands with minimum evidence and `insufficient data` rather than fake precision.

Do not require AI to view numeric analytics.

### P6 — AI Coach

Pipeline:
1. local deterministic analytics
2. compact structured aggregate payload
3. chosen verified AI provider/model
4. AI interpretation/recommendation

Aggregate-only is the default payload.

Do not include by default:
- API keys/auth
- provider endpoint secrets
- user notes
- private file names/paths
- full source documents
- full quiz snapshots
- raw answer history
- unrelated identifiers

Selected question/source text may be sent only with explicit opt-in and bounded preview.

### P3b — Library combine / duplicate / multi-select

May proceed after stable identity foundations and need not block P4-P6.

Saved combined set architecture:
- full self-contained copied durable set
- originals unchanged
- new concrete `question_id` for copied membership
- retained `lineage_id`
- informational source metadata, not fragile required foreign keys
- automatic dedupe off by default in v1

### P7 — Document-to-Quiz MVP

Initial approved scope:
- pasted/plain text
- text PDF
- DOCX

Deferred:
- PPTX
- scanned PDF / vision fallback

Requirements:
- Android system document access; avoid broad storage permissions
- bounded bytes/pages/extracted characters
- graceful encrypted/corrupt/oversized failure
- source-aware chunking and stable source references
- avoid whole-document upload merely because it fits memory
- explicit privacy disclosure before selected document content leaves device
- verify Syncfusion PDF license/community eligibility before Play release

### P8 — Engagement layer

Last, restrained and optional:
- subtle completion/personal-best feedback
- recovery counts
- optional streak/milestone concepts only after timezone/grace/opt-out policy is defined
- reduced-motion/accessibility support
- no distraction during timed exams
- no punishment/shaming mechanics

## 5. Cross-cutting data model contract

### Question identity

Approved concepts:
- `question_id`: concrete instance UUID
- `lineage_id`: conceptual/root lineage across copies and targeted practice
- `content_fingerprint`: dedupe/similarity hint only
- `source_ref`: optional document grounding
- optional immediate-parent ID only when a real consumer needs it

Do not rely on list index as durable identity.

### Attempt identity

`attempt_id` remains the stable identifier for one attempt. Completed attempts must become self-describing enough to survive source-set lifecycle changes.

### Quiz-set source type

Source and removal state are separate concepts. Future source values may include:
- uploaded
- ai_generated
- combined
- document_generated
- targeted_practice

Do not encode removal state into source values after the transitional bridge is retired.

## 6. AI disclosure / reporting / provenance boundary

Low-risk visible AI-generated disclosure and non-authoritative wording may move independently when an approved slice calls for it.

Reporting UI must not claim successful reporting without a real HTTPS endpoint/operator workflow.

Machine-readable Article 50 marking/provenance remains on hold until:
- role is clarified
- interoperable standard is selected
- migration/export implications are agreed
- qualified legal/compliance review is available where required

## 7. Ownership / collision map

High-conflict areas require serialized ownership:
- `database_service.dart`
- quiz/question models
- `quiz_provider.dart`
- Dashboard/Library screens
- `export_service.dart`
- `pubspec.yaml` / lockfile
- Android manifest/plugin changes
- provenance/export migrations

Safe pattern:
- DEDAL implements product/data slices
- Codex reviews Android/release/platform/privacy implications and can act as local build operator
- neither agent silently edits the other's active ownership area

## 8. Challenge closure

Roadmap challenge is closed.

Codex review commit:
`21874f9e35b81eab69405de89e4eeb572c85538a`

Codex reconciliation commit:
`02f25f95e7fbca5ee99982e267b1657d12ec2334`

Owner approved the converged decisions on 2026-09-12.

Do not reopen the same architecture discussion unless new implementation evidence invalidates a decision. New facts may trigger a narrowly scoped challenge, not a full roadmap reset.
