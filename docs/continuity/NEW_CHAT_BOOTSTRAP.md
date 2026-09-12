# New Chat Bootstrap

This file is the entry point for resuming MCQ Quizzer work in a new ChatGPT/Codex session.

## Read first
1. `AGENTS.md`
2. `.agent/README.md`
3. `docs/continuity/CURRENT_CHECKPOINT.md`
4. `docs/continuity/PROJECT_STATE.md`
5. `docs/continuity/DECISIONS.md`
6. `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`
7. `docs/QUIZ_UX_REFINEMENT.md`
8. `docs/AI_PROVIDER_MULTI_MODEL_IMPLEMENTATION.md` for completed provider background
9. `.agent/status/dedal.md`
10. `.agent/inbox/codex.md` and, when Codex is active again, `.agent/inbox/dedal.md`

## Repository / branch rules
- Repository: `Ye-Shwethway/MCQ-Quizzer`
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
- `main` is Owner-approved stable only.
- DEDAL works on `dedal/*` branches.
- Codex works on `codex/*` branches.
- Neither agent merges to `main` without explicit Owner approval.
- Public repository: never commit credentials, signing secrets, API keys, or private files.

## Current active DEDAL state
Branch: `dedal/history-repair-v1`
Latest phone-test checkpoint commit: `7bc46c5641dd55c87f62533c7c295f69c774c707`
Build Debug APK run: `34684036798` (#29), success.
Artifact: `mcq-quizzer-debug-arm64-29`, artifact id `10294314335`.

The Owner was downloading/testing APK #29 when the previous chat ended.

APK #29 contains:
- corrected responsive Home cards
- timer presets up to 5 hours
- current bounded attempt/history preservation repair

Important: the first compact Home attempt failed on a real narrow phone with a RenderFlex bottom overflow. Do not restore that design. The corrected phone design uses full-width compact horizontal cards and content-driven height; two columns are reserved for wide/tablet layouts.

## Current bounded attempt/history repair
Normal Library removal currently archives rather than physically deleting a quiz set so completed history remains visible to the Dashboard.

Current transitional semantics:
- archived quiz source markers: `archived_ai_generated` / `archived_uploaded`
- completed `quiz_history` preserved
- notes preserved
- incomplete `saved_progress` retired
- delayed autosaves cannot resurrect progress for archived sets
- permanent destructive deletion is isolated behind `permanentlyDeleteQuizSet`

This is intentionally migration-free while Codex review is unavailable. Do not expand it into a new schema migration without explicit Owner approval or the pending Codex architecture review.

## Working loop
Normal delivery loop:
1. implement one coherent bounded slice
2. run analyzer under current non-fatal warning/info policy
3. while Codex/PC is available, prefer Codex local emulator build/install for fast iterations
4. otherwise produce a meaningful arm64 debug APK checkpoint
5. Owner manually tests real behavior
6. perform targeted fixes
7. update continuity/status/inbox docs

Do not reintroduce broad automated-test debugging as a delivery gate.

## Codex state
Codex completed Android release-foundation work on `codex/android-release-foundation` and has a separate roadmap review request waiting, but it became rate-limited before performing that review.

When Codex returns, it should:
1. finish/read its existing state without disturbing DEDAL product work
2. read `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`
3. read the latest `docs/continuity/CURRENT_CHECKPOINT.md`
4. review the attempt/history transitional archive design and proposed future migration
5. challenge roadmap ordering/data architecture as requested in `.agent/inbox/codex.md`
6. reply through `.agent/inbox/dedal.md`
7. not implement roadmap features or Article 50 machine-readable provenance before Owner + DEDAL review

## Immediate new-chat workflow
At the beginning of the next ChatGPT chat:
1. inspect `dedal/history-repair-v1` and confirm the latest branch head rather than relying only on chat memory
2. read this file and `CURRENT_CHECKPOINT.md`
3. ask the Owner for APK #29 test results first
4. if Home is accepted, continue only with bounded repair/polish work such as Library wording (`Remove from Library`) and manual history-preservation validation
5. do not start large new roadmap features until the current repair is accepted and the Owner chooses the next slice
