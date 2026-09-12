# Current Checkpoint

Updated: 2026-09-12

## Stable baseline
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`.
- `main` remains Owner-approved stable only.
- Do not merge any current branch without explicit Owner approval.

## Current DEDAL branch
`dedal/history-repair-v1`

Current implementation/test head before this documentation sync:
`deb22a2905cc13f29c230fc30d706948a80b0643`

Documentation-only architecture closure starts after that commit.

## Current phone checkpoint
Build Debug APK #32: success.
Run: `34686134055`.
Artifact: `mcq-quizzer-debug-arm64-32`, artifact id `10295752041`.
Build head: `deb22a2905cc13f29c230fc30d706948a80b0643`.

Owner is currently testing APK #32.

APK #32 contains:
- accepted responsive Home layout
- timer presets up to 5 hours
- bounded attempt/history preservation repair
- narrow-phone Quiz Results overflow repair
- narrow Correct Answers dialog wrapping repair

## Accepted Home state
The Owner accepted the corrected Home layout after APK #30.

Do not restore the rejected design that forced two narrow phone columns and fixed card height.

Accepted layout:
- phone layouts `< 600 logical px`: full-width compact horizontal cards
- wide/tablet layouts `>= 600 logical px`: two columns
- content-driven card height
- no fixed grid height used to hide overflow

## Quiz Results repair under test
The Owner reported repeated `BOTTOM OVERFLOWED BY 30 PIXELS` errors in Quiz Results.

Root cause was a fixed-height trailing area containing score text plus an eye `IconButton` in a vertical column.

Repair:
- remove the fixed-height trailing `ListTile` structure
- use content-driven row/column layout
- allow correct/wrong metrics to wrap on narrow phones
- harden the Correct Answers dialog by replacing a rigid horizontal answer-summary row with wrapping rich text

Analyzer passed for the final APK #32 build head.
A focused narrow-results widget regression test was added, but broad automated tests are not a delivery gate.

## Attempt/history repair v1
Implementation base commit:
`7496e7c0230da69d592430030b3186276d9ef871`

Current bounded behavior:
- normal Library removal does not physically delete the quiz-set row
- removed sets use transitional markers `archived_ai_generated` / `archived_uploaded`
- removed sets disappear from existing active Library views
- completed `quiz_history` remains preserved
- notes remain preserved
- incomplete `saved_progress` is retired
- delayed autosave cannot recreate progress for a removed set
- irreversible physical deletion is isolated behind `permanentlyDeleteQuizSet`

The transitional markers remain a migration-free bridge only. Do not introduce more archived source variants.

## Roadmap architecture challenge — CLOSED
DEDAL and Codex completed the discussion/challenge cycle and the Owner approved the converged architecture contract.

Codex roadmap review:
- branch `codex/android-release-foundation`
- review commit `21874f9e35b81eab69405de89e4eeb572c85538a`

Codex final reconciliation:
- commit `02f25f95e7fbca5ee99982e267b1657d12ec2334`

Owner-approved architecture decisions are canonicalized in:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

Key locked decisions:
- v1 user-facing concept is `Remove from Library`, not a resumable Archive workspace
- future permanent removal-state field: nullable `removed_from_library_at`
- completed immutable attempts survive future permanent source deletion
- future permanent source deletion removes incomplete progress and set-scoped notes
- `permanentlyDeleteQuizSet` remains unreachable until durable-history + SQLite FK behavior are implemented
- question identity: `question_id + lineage_id + content_fingerprint + source_ref`
- `attempt_question_results` is deferred to P4; P2a must preserve complete versioned data for deterministic backfill
- saved combined sets are self-contained durable copies; targeted practice can remain virtual until explicitly saved
- deterministic local analytics precede AI Coach
- AI Coach aggregate-only payload is default; transmitting selected question/source text requires explicit opt-in
- Document-to-Quiz MVP: plain text/pasted text + text PDF + DOCX; defer PPTX and vision/scanned-PDF support
- machine-readable Article 50 provenance implementation remains decision-gated

## Immediate acceptance gate
Do not begin the larger roadmap yet.

First finish the current bounded repair:
1. Owner accepts APK #32 Results behavior.
2. Change Library wording from destructive `Delete` language to `Remove from Library`.
3. Explicitly communicate that completed history is preserved.
4. Manually validate:
   complete quiz -> confirm Dashboard history -> Remove from Library -> set disappears from Library -> completed history/statistics remain.
5. Owner accepts the repair.
6. Owner chooses the next roadmap slice.

## Delivery discipline
Normal loop:
coherent slice -> analyzer -> Codex local emulator build when available OR meaningful APK artifact -> Owner manual phone test -> targeted fixes -> docs/handoff.

Do not restore broad automated tests as a delivery gate.
Do not merge to `main` without explicit Owner approval.
