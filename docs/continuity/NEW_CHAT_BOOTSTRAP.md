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
9. `docs/AI_GENERATION_ADAPTIVE_PERFORMANCE_PLAN.md`
10. `.agent/status/dedal.md`
11. `.agent/inbox/codex.md` and `.agent/inbox/dedal.md`

## Repository / branch rules
- Repository: `Ye-Shwethway/MCQ-Quizzer`
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
- `main` is Owner-approved stable only.
- Current DEDAL branch: `dedal/history-repair-v1`
- DEDAL works on `dedal/*` branches.
- Codex works on `codex/*` branches.
- Neither agent merges to `main` without explicit Owner approval.
- Public repository: never commit credentials, signing secrets, API keys, or private files.

## First action in a new chat
Inspect the live branch HEAD from GitHub before making changes. Do not rely only on chat memory or the SHA in this document, because continuity-document commits may have advanced the branch.

Latest app implementation checkpoint before continuity-only commits:
`590b346ad62d717039de62377a4026dc71dd03a4`

## Latest phone checkpoint — APK #51

Build Debug APK #51 succeeded from:
`ca5850d1964494db2da34bdc19ef283086a4a246`

Artifact:
`mcq-quizzer-debug-arm64-51`

Owner tested it on the real phone and **accepted the P1G refinement**.

Observed:
- `Mode: Parallel ×2 • 10 + 10 stems` appeared during real concurrent work.
- mode changed dynamically to `Mode: Serial refill for unique stems` during refill.
- 20 generated stems contained no observed duplicates.
- total speed was only modestly better because serial uniqueness refill still takes time, but Owner accepts the quality/speed tradeoff.

Do not weaken uniqueness merely to make the progress dialog finish faster.

## Accepted P1G contract
Keep:
- capability-aware adaptive generation
- no free-vs-paid key classification
- conservative unknown-capability fallback
- bounded concurrency, maximum 2 only when provider/model capability supports it
- true provider streaming where supported
- non-streaming fallback
- boundary-aware parser
- progress only after complete valid question objects
- truthful runtime execution-mode UI
- domain-agnostic complementary lane coverage
- local near-duplicate filtering across stem/phrase/containment signals plus answer-concept similarity
- same uniqueness gate in parallel merge, serial refill, and final safety fill
- serial downgrade/recovery after provider/runtime pressure

P1G can be treated as **closed / Owner-accepted** unless a regression appears.

## Other accepted phone state
- responsive Home repair accepted after APK #30
- Results narrow-phone overflow repair accepted after APK #32
- P1Q seamless compact-stem overlay accepted; no bounce feeling
- Manual Upload narrow-phone selector repair accepted
- true incremental streaming progress accepted after APK #47

## Current Library behavior
Current branch retains reversible Library removal:
- AI Generated / Uploaded / Removed states
- `Remove from Library`
- `Restore to Library`
- completed history preserved
- notes preserved
- incomplete saved progress retired
- removed sets remain exportable
- transitional markers remain `archived_ai_generated` / `archived_uploaded`

Do not add more transitional marker variants.
Permanent source deletion remains gated behind P2a durable history and FK-safe migration.

## Small export filename fix already applied
Commit:
`590b346ad62d717039de62377a4026dc71dd03a4`

Normal exports no longer append millisecond timestamps to default filenames.

Example:
- old: `Renal System MCQ_questions_1789227852631.docx`
- new: `Renal System MCQ_questions.docx`

This is a tiny cosmetic change. Smoke-check it with the next worthy phone APK; do not create a standalone APK solely for this filename change unless the Owner asks.

## Recommended next implementation slice

### P1R — Timer persistence / process-death hardening

P1Q and P1G are accepted. P1R is the recommended next bounded reliability slice before the larger P2a schema/history migration.

Target scope:
- debounced durable checkpoints after meaningful answer/navigation changes
- serialized/upsert persistence by attempt ID
- Practice resume from the last durable paused state
- Exam original duration + absolute UTC deadline persistence
- expired-away finalization exactly once
- focused checks for background/resume, lock/unlock, process kill/relaunch, Save & Exit, repeated resume, near-zero time

Do not rely only on lifecycle callbacks before process death.

After P1R acceptance, the natural larger structural candidate is:
**P2a — Durable Attempt History + Identity + FK-safe migration**.
Do not start P2a automatically without Owner confirmation.

## Architecture challenge — CLOSED
Canonical decisions:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

Do not reopen the architecture challenge unless new implementation evidence invalidates a locked decision.

## Working loop
Normal delivery loop:
1. implement one coherent bounded slice
2. run analyzer under current non-fatal warning/info policy
3. prefer Codex local emulator build/install when available and useful; otherwise use a meaningful arm64 debug APK checkpoint
4. poll build to completion and retrieve the artifact in the same turn when possible
5. Owner manually tests real behavior
6. perform targeted fixes
7. sync continuity/status docs

Do not reintroduce broad automated testing as a delivery gate.
