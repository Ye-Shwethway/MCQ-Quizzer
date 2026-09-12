# MCQ Quizzer — Approved Roadmap Architecture Decisions

Status: **Owner-approved architecture contract**
Date: 2026-09-12
Discussion closure: DEDAL + Codex roadmap challenge closed after Owner approval.

This document records the decisions that emerged from the roadmap challenge between DEDAL and Codex. It supersedes earlier open questions where explicitly stated below. It does not authorize implementation of the larger roadmap before the current repair checkpoint is accepted.

## 1. Current repair remains bounded

The current `dedal/history-repair-v1` implementation is a transitional, migration-free repair.

Current Remove from Library behavior:
- the set disappears from the active Library
- completed quiz history remains preserved
- notes remain preserved
- incomplete saved progress is retired
- delayed autosave cannot recreate progress for a removed set
- physical destructive deletion remains isolated behind `permanentlyDeleteQuizSet`

The transitional source markers remain temporarily:
- `archived_ai_generated`
- `archived_uploaded`

Do not add more source-marker variants. They are a bridge only and must not become the long-term schema.

## 2. Remove from Library is not Archive

For v1, the normal user-facing concept is **Remove from Library**, not a resumable Archive workspace.

Approved semantics:
- Remove from Library preserves completed history and notes.
- Remove from Library retires incomplete progress.
- A separate resumable Archive feature is not part of v1.

If a real resumable Archive workspace is approved later, it should be modeled and named separately rather than silently changing Remove from Library semantics.

## 3. Permanent removal-state field

When the transitional markers are replaced by a real schema field, the approved field direction is:

`removed_from_library_at`

Use a nullable timestamp rather than overloading the source field.

Do not use `archived_at` unless a separate true Archive feature is approved later.

## 4. Permanent source deletion contract

Permanent source deletion is an advanced future action and must remain unreachable from the normal Library flow until durable history independence and SQLite foreign-key behavior are implemented and validated.

Approved future contract:
- completed immutable attempts survive permanent source deletion
- incomplete saved progress is deleted
- set-scoped notes are deleted
- history deletion, if ever offered, is a separate deliberate data-management action

Dialogs must state these consequences precisely.

## 5. Durable attempt/history architecture

P2a must make completed attempts independently readable from source-set lifecycle.

Required direction:
- durable `attempt_id`
- complete versioned quiz snapshot for each completed attempt
- title/source metadata snapshots sufficient for historical display
- answers and scoring-version data preserved for deterministic reconstruction
- direct all-attempt queries independent of enumerating active Library sets
- `quiz_history.quiz_set_id` may become nullable with `ON DELETE SET NULL` after a safe table rebuild/backfill
- foreign-key enforcement must be explicitly enabled only after migration/backfill safety is established
- migration must be transactional, forward-only, preserve existing/orphaned history where possible, and validate row counts / foreign-key integrity

Do not enable foreign keys first and then rely on existing cascade declarations.

## 6. Question identity contract

Approved v1 identity concepts:
- `question_id`: UUID for the concrete question instance
- `lineage_id` (or equivalently named root-question identity): stable conceptual lineage across copied/combined/targeted-practice instances
- `content_fingerprint`: normalized content hash used only as a dedupe/similarity hint, never primary identity
- `source_ref`: optional document grounding metadata
- optional immediate-parent ancestry may be added later only if a concrete consumer requires it

Do not overload one `origin_question_id` field to mean both conceptual lineage and immediate ancestry.

Legacy immutable snapshots should not be randomly rewritten merely to insert UUIDs. Backfill/mapping must preserve deterministic lineage where required.

## 7. Combined and targeted practice architecture

Saved combined quizzes are durable, self-contained copied sets.

Rules:
- source sets remain untouched
- copied questions get new concrete `question_id` values
- copied questions retain `lineage_id`
- source metadata is informational, not a fragile required foreign-key dependency
- automatic dedupe is off by default in v1

Virtual/derived sessions are reserved for unsaved targeted practice such as Mistakes / Unanswered / Guessed. If the user chooses to save such a session, materialize a durable copied set.

## 8. Per-question result table timing

`attempt_question_results` is approved as a likely deterministic analytics structure, but it is deferred to P4 rather than inflating P2a.

P2a must therefore preserve enough complete, versioned data to allow deterministic later backfill:
- quiz snapshot
- answers
- scoring version
- question identity/lineage information or a deterministic legacy mapping

P4 may introduce the narrow result table when Mistakes/Guessed/Unanswered and repeated-miss analytics actually consume it.

## 9. Timer architecture

Timer presets through 5 hours are already implemented.

Production-grade long-session reliability remains a separate future bounded hardening slice.

Direction:
- debounced durable checkpoints after meaningful answer/navigation changes
- lifecycle flush as an additional best effort, not the only persistence mechanism
- serialize/upsert saves by attempt identity
- Practice resumes from the last durable paused state
- Exam preserves original duration plus absolute UTC deadline and recomputes remaining time on reload
- expired-away attempts must finalize exactly once
- process death, background/resume, lock/unlock, Save & Exit, repeated resume, and near-zero time need focused validation

## 10. Dashboard and AI Coach

Deterministic local analytics remain the factual source.

AI Coach order:
1. durable attempt/history foundation
2. stable question lineage
3. deterministic per-question/aggregate analytics
4. compact privacy-aware structured payload
5. AI interpretation/recommendation

Default AI Coach payload is aggregate-only.

Question/source text may be transmitted only through explicit opt-in where needed. API keys, credentials, private file paths, full documents, full snapshots, raw history, and unrelated identifiers must not be included by default.

## 11. Document-to-Quiz MVP

Approved initial scope:
- pasted/plain text
- text PDF
- DOCX

Deferred:
- PPTX
- scanned-PDF / vision fallback

Requirements include bounded file/page/character limits, graceful handling of encrypted/corrupt/oversized inputs, source-aware chunking, stable source references, safe Android document access, and explicit privacy disclosure before selected document text leaves the device.

Syncfusion PDF licensing/community-license eligibility must be verified before Play release.

## 12. Article 50 provenance

Machine-readable Article 50 provenance/schema/export implementation remains explicitly decision-gated.

Do not implement it until the technical standard, product role, migration impact, and qualified legal/compliance position are agreed.

Low-risk visible AI-generated disclosure/non-authoritative wording may proceed separately when the relevant repair/release slice is approved.

## 13. Roadmap ordering after current repair acceptance

The architecture challenge is closed, but implementation sequencing remains Owner-controlled.

Recommended dependency order:
1. finish and accept the current bounded repair/polish checkpoint
2. timer persistence/process-death hardening as a bounded slice when chosen
3. P2a durable attempt/history + identity + FK-safe migration
4. P2b Remove-from-Library permanent schema/policy integration
5. Rename and other low-risk Library improvements
6. P4 practice intelligence + `attempt_question_results`
7. Dashboard v2
8. AI Coach
9. broader Library combine/duplicate tools after identity foundations where appropriate
10. Document-to-Quiz MVP
11. engagement layer last

No larger roadmap implementation starts automatically from this document. The Owner chooses the next slice after the current repair is accepted.

## 14. Current acceptance gate

Before any larger roadmap implementation:
- APK #32 Results-screen repair must be Owner-accepted
- Library wording should move from destructive `Delete` language to `Remove from Library`
- UI must state that completed history is preserved
- manually validate:
  complete quiz -> confirm Dashboard history -> Remove from Library -> set disappears from Library -> completed history/statistics remain

Only after that bounded repair is accepted should the Owner choose the next roadmap slice.
