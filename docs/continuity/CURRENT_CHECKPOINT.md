# Current Checkpoint

Updated: 2026-09-12

## Stable baseline
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`.
- `main` remains Owner-approved stable only.
- Do not merge current work without explicit Owner approval.

## Current DEDAL branch
`dedal/history-repair-v1`

Latest app implementation checkpoint:
`238c35289988acf8b0be15a1af575820f8d7b12e`

Documentation commits continue after that app checkpoint.

## Current phone-test checkpoint — APK #33

Build Debug APK #33: **success**.
Run: `34689579321`.
Artifact: `mcq-quizzer-debug-arm64-33`.
Artifact id: `10296362572`.
Artifact digest: `sha256:5cf2d1e0c3e2cc85a81855c6b420defac6e6854ebecc2cb4958ed13893d6e324`.
Build head: `238c35289988acf8b0be15a1af575820f8d7b12e`.

Agent Fast CI #23 for the same head: **success**.

Actual extracted APK size: `95,856,417` bytes.

APK #33 is the first reversible Remove/Restore Library checkpoint and is awaiting Owner phone validation.

## Previously accepted phone state

APK #32 Results repair was Owner-tested and accepted: no observed narrow-phone RenderFlex overflow remains.

Accepted earlier behavior includes:
- corrected responsive Home cards
- timer presets through 300 minutes
- quiz Results content-driven layout
- wrapping Correct Answers summary
- smart compact stem functionality (smoothness refinement still pending)

## APK #33 — reversible Remove / Restore slice

Implemented without a database migration, using the existing transitional source markers.

Active Library now has three source/state tabs:
- AI Generated
- Uploaded
- Removed

### Remove from Library

Active quiz-set menus/details now use **Remove from Library**, not misleading destructive Delete wording.

Confirmation explicitly states:
- completed attempt history is kept
- notes are kept
- unfinished saved progress is discarded
- the set can be restored later

After removal:
- the set disappears from its active AI Generated / Uploaded tab
- the set remains stored locally with `archived_ai_generated` or `archived_uploaded`
- it appears in the Removed tab
- completed history and notes remain
- saved incomplete progress remains retired

A post-remove SnackBar also offers immediate Restore.

### Removed tab / Restore

Removed sets:
- remain inspectable
- remain exportable as Questions / Answer Key / Both
- expose **Restore to Library**
- cannot be started or edited while removed

Restore maps transitional state back to the original source category:
- `archived_ai_generated` -> `ai_generated`
- `archived_uploaded` -> `uploaded`

Restore does **not** recreate unfinished progress that was retired during removal.

### Permanent Delete

The Owner approved a separate future **Delete Permanently** action, but it is intentionally **not exposed in APK #33**.

Permanent Delete contract:
- source quiz set is physically deleted and cannot be restored
- set-scoped notes are deleted
- incomplete progress is deleted
- completed immutable attempt history survives

The low-level `permanentlyDeleteQuizSet` method remains unreachable from normal UI until P2a durable-history independence and SQLite foreign-key behavior are implemented and validated.

Canonical policy:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

## APK #33 phone acceptance checklist

Validate on the real phone:
1. Library shows AI Generated / Uploaded / Removed tabs without overflow.
2. Active set menu/details says **Remove from Library**, not Delete.
3. Remove confirmation wording is understandable.
4. Remove a set with completed history; it disappears from the active source tab.
5. The same set appears under Removed.
6. Dashboard completed history/statistics remain after removal.
7. Notes remain available after restore.
8. Export from the Removed tab still works.
9. Restore the set; it returns to its original AI Generated / Uploaded tab.
10. Any unfinished progress discarded during removal does not reappear after restore.
11. No permanent-delete action is exposed yet.
12. Narrow phone / dark mode show no overflow or unreachable actions.

If APK #33 is accepted, this bounded reversible-removal repair can close.

## Approved next candidate slices

### P1Q — seamless compact-stem overlay
The current smart stem works, but the Owner observed a backward/forward bounce when the compact pane changes layout height.

Approved refinement:
- stable scroll viewport geometry
- compact stem rendered as overlay/pinned layer
- opacity/tiny translation only; no layout-height insertion
- small show/hide hysteresis band

Detailed plan:
`docs/QUIZ_UX_REFINEMENT.md`

### P1G — adaptive + streaming AI generation
Approved future direction:
- capability-aware dynamic batch sizing
- no free-key/paid-key classification
- bounded adaptive concurrency
- fallback after 429/context/output/timeout/truncation signals
- provider streaming where supported
- boundary-aware incremental parsing
- progress such as `Generating 1 / 20...` only after a complete valid question object is confirmed

Detailed plan:
`docs/AI_GENERATION_ADAPTIVE_PERFORMANCE_PLAN.md`

### P1R — timer persistence/process-death hardening
Still approved as a separate bounded reliability slice.

## Larger roadmap foundations

Roadmap challenge remains closed. Canonical architecture decisions remain in:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

Important locked foundations include:
- future real removal field `removed_from_library_at`
- question identity `question_id + lineage_id + content_fingerprint + source_ref`
- P2a durable attempts/history + FK-safe migration before physical deletion UI
- `attempt_question_results` deferred to P4
- deterministic local analytics before AI Coach
- aggregate-only AI Coach payload by default
- Document-to-Quiz MVP = plain/pasted text + text PDF + DOCX
- Article 50 machine-readable provenance remains decision-gated

## Delivery discipline

Current no-Codex-at-home workflow:
coherent DEDAL slice -> Agent Fast CI/analyzer -> worthy `[apk]` checkpoint -> poll build to completion -> download/extract artifact -> Owner phone test -> targeted fixes -> docs/handoff.

Do not restore broad automated tests as a delivery gate.
Do not merge to `main` without explicit Owner approval.
