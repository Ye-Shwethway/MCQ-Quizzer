# New Chat Bootstrap

This file is the entry point for resuming MCQ Quizzer work in a new ChatGPT/Codex session.

## Read first
1. `AGENTS.md`
2. `.agent/README.md`
3. `docs/continuity/CURRENT_CHECKPOINT.md`
4. `docs/continuity/PROJECT_STATE.md`
5. `docs/continuity/DECISIONS.md`
6. `docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`
7. `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`
8. `docs/QUIZ_UX_REFINEMENT.md`
9. `.agent/status/dedal.md`
10. `.agent/inbox/codex.md` and `.agent/inbox/dedal.md`

## Repository / branch rules
- Repository: `Ye-Shwethway/MCQ-Quizzer`
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
- `main` is Owner-approved stable only.
- DEDAL works on `dedal/*` branches.
- Codex works on `codex/*` branches.
- Neither agent merges to `main` without explicit Owner approval.
- Public repository: never commit credentials, signing secrets, API keys, or private files.

## Current DEDAL state
Branch: `dedal/history-repair-v1`

Current implementation/test head before documentation-only architecture closure:
`deb22a2905cc13f29c230fc30d706948a80b0643`

Current phone artifact:
- Build Debug APK #32
- run `34686134055`: success
- artifact `mcq-quizzer-debug-arm64-32`, id `10295752041`

Owner is currently testing APK #32.

APK #32 contains:
- accepted responsive Home layout
- timer presets up to 5 hours
- bounded Remove-from-Library/history-preservation repair
- narrow Quiz Results overflow repair
- narrow Correct Answers dialog wrapping repair

## Accepted Home behavior
Do not restore the failed compact-card design.

Accepted behavior:
- phone `< 600 logical px`: full-width compact horizontal cards
- wide/tablet `>= 600`: two columns
- content-driven height
- no fixed card height to hide overflow

## Current bounded Remove-from-Library repair
Current transitional behavior:
- temporary source markers `archived_ai_generated` / `archived_uploaded`
- completed history preserved
- notes preserved
- incomplete saved progress retired
- delayed autosaves cannot recreate progress
- destructive physical deletion isolated behind `permanentlyDeleteQuizSet`

These source markers are a bridge only. Do not add more marker variants.

## Architecture challenge — CLOSED
DEDAL and Codex completed the roadmap challenge/reconciliation and the Owner approved the converged decisions.

Canonical decision doc:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

Codex commits:
- initial review: `21874f9e35b81eab69405de89e4eeb572c85538a`
- final reconciliation: `02f25f95e7fbca5ee99982e267b1657d12ec2334`

Locked decisions include:
- v1 uses `Remove from Library`, not a resumable Archive workspace
- future permanent removal state uses `removed_from_library_at`
- completed immutable attempts survive future permanent source deletion
- future permanent source deletion removes set notes + incomplete progress
- question identity: `question_id + lineage_id + content_fingerprint + source_ref`
- `attempt_question_results` begins in P4, not P2a, provided P2a preserves deterministic backfill data
- saved combined quizzes are self-contained copied sets
- deterministic local analytics precede AI Coach
- aggregate-only AI Coach payload by default
- Document-to-Quiz MVP starts with plain/pasted text, text PDF, DOCX; PPTX/vision deferred
- Article 50 machine-readable provenance remains decision-gated

Do not reopen the full architecture challenge unless new implementation evidence invalidates a locked decision.

## Working loop
Normal delivery loop:
1. implement one coherent bounded slice
2. run analyzer under current non-fatal warning/info policy
3. while Codex/PC is available, prefer Codex local emulator build/install where useful
4. otherwise produce a meaningful arm64 debug APK checkpoint
5. Owner manually tests real behavior
6. perform targeted fixes
7. update continuity/status/inbox docs

Do not reintroduce broad automated testing as a delivery gate.

## Immediate workflow
At the beginning of a new chat/session:
1. inspect the live branch HEAD from GitHub; do not rely only on chat memory
2. read `CURRENT_CHECKPOINT.md` and the architecture decision doc
3. ask the Owner for APK #32 test result if not already known
4. if APK #32 is accepted, continue only with bounded repair polish:
   - rename destructive `Delete` wording to `Remove from Library`
   - explicitly state completed history is preserved
   - manually validate complete quiz -> Dashboard history -> Remove from Library -> set disappears -> history/statistics remain
5. do not start P2a or any larger roadmap slice until the repair is accepted and the Owner chooses the next slice
