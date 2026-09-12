# MCQ Quizzer — Approved Roadmap Architecture Decisions

Status: **Owner-approved architecture contract**
Date: 2026-09-12
Discussion closure: DEDAL + Codex roadmap challenge closed after Owner approval.

This document records the approved product/data architecture decisions. Later Owner decisions override earlier wording where explicitly noted.

## 1. Current repair remains bounded

The current `dedal/history-repair-v1` implementation is a transitional, migration-free repair.

Current Remove from Library behavior:
- the set disappears from its active AI Generated / Uploaded Library list
- the set remains stored locally under the transitional removed marker
- completed quiz history remains preserved
- notes remain preserved
- incomplete saved progress is retired
- delayed autosave cannot recreate progress for a removed set

The transitional source markers remain temporarily:
- `archived_ai_generated`
- `archived_uploaded`

Do not add more source-marker variants. They are a bridge only and must not become the long-term schema.

## 2. Remove from Library, Restore, and Archive semantics

The Owner approved a reversible **Remove from Library** workflow.

Approved Remove semantics:
- Remove hides the set from the normal active Library views.
- The quiz-set/source data remains on device.
- Completed history remains preserved.
- Set-scoped notes remain preserved.
- Incomplete saved progress is retired.
- The set appears in a **Removed** Library surface and can be restored later.

Approved Restore semantics:
- Restore returns the set to its original active source category (`ai_generated` or `uploaded`).
- Completed history and notes remain associated with the set.
- Previously retired incomplete progress is **not** recreated or resumed.

This reversible Removed surface is not a resumable Archive workspace. If a true Archive feature is ever approved, model and name it separately.

This decision intentionally protects user-owned quiz sets, including AI-generated sets that may have cost money to create. Export is useful but is not a substitute for reversible in-app removal.

## 3. Permanent removal-state field

When transitional source markers are replaced by a real schema field, the approved field direction remains:

`removed_from_library_at`

Use a nullable timestamp rather than overloading the source field.

Do not use `archived_at` unless a separate true Archive feature is approved later.

Restore clears `removed_from_library_at`.

## 4. Permanent Delete contract

The Owner also approved a separate future **Delete Permanently** action. It is intentionally different from Remove from Library.

Permanent Delete is user-controlled and irreversible for the source quiz set.

Approved future contract:
- the quiz set/source is physically deleted
- set-scoped notes are deleted
- incomplete saved progress is deleted
- completed immutable attempts/history survive
- deleting completed history, if ever offered, is a separate deliberate data-management action
- confirmation copy must clearly state that the source quiz set cannot be restored after permanent deletion

Permanent Delete must remain unreachable from the current Library UI until P2a durable-history independence and SQLite foreign-key behavior are implemented and validated. Do not expose the low-level `permanentlyDeleteQuizSet` method as a user action before that gate is satisfied.

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

## 13. Roadmap ordering

Implementation remains Owner-controlled.

Current practical sequence:
1. validate the reversible Remove / Removed / Restore Library slice
2. P1Q seamless compact-stem overlay when selected
3. P1G adaptive + streaming AI generation when selected
4. P1R timer persistence/process-death hardening when selected
5. P2a durable attempt/history + identity + FK-safe migration
6. enable the separately approved Delete Permanently UI only after P2a is proven
7. P2b permanent removal-state schema integration
8. Rename / combine / practice intelligence / Dashboard v2 / AI Coach according to the approved roadmap dependencies

Do not merge to `main` without explicit Owner approval.

## 14. Current acceptance gate

APK #32 Results-screen overflow repair is Owner-accepted.

The current Library checkpoint must now validate:
- active quiz set offers **Remove from Library**, not misleading Delete wording
- confirmation explains that completed history and notes are kept
- confirmation explains that unfinished progress is discarded
- removed set disappears from its active source tab
- removed set appears in the **Removed** tab
- removed set can be restored
- restored set returns to its original AI Generated / Uploaded category
- retired unfinished progress does not reappear after restore
- completed Dashboard history/statistics remain intact across remove and restore
- export remains available for removed sets
- Delete Permanently is not yet exposed

After this bounded checkpoint is accepted, continue with the Owner-selected implementation slice.
