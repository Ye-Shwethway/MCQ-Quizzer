# New Chat Bootstrap

This file is the entry point for resuming MCQ Quizzer work in a new ChatGPT/Codex session.

## Read first
1. `AGENTS.md`
2. `.agent/README.md`
3. `docs/continuity/CURRENT_CHECKPOINT.md`
4. `docs/continuity/PROJECT_STATE.md`
5. `docs/continuity/DECISIONS.md`
6. `docs/QUIZ_UX_REFINEMENT.md`
7. `docs/AI_PROVIDER_MULTI_MODEL_IMPLEMENTATION.md` for the completed provider architecture background
8. Your own `.agent/status/<agent>.md` and inbox file.

## Repository / branch rules
- Repository: `Ye-Shwethway/MCQ-Quizzer`
- `main` is Owner-approved stable only.
- DEDAL works on `dedal/*` branches.
- Codex works on `codex/*` branches.
- Neither agent merges to `main` without explicit Owner approval.
- Public repository: never commit credentials or API keys.

## Working loop
The Owner-approved delivery loop is APK-first manual validation:
1. Pull the latest approved `main` checkpoint.
2. Create or reset your own agent branch from that checkpoint.
3. Implement one coherent slice with minimal unrelated refactoring.
4. Run `flutter analyze` as the normal automated gate.
5. Produce an arm64 debug APK for meaningful phone-testable checkpoints.
6. Let the Owner manually test the actual app behavior.
7. Fix observed regressions quickly; add targeted tests only when a real bug clearly benefits from one.
8. Update continuity/status/inbox docs before handoff.

Do not turn broad test-suite debugging into a delivery gate. If automated-test work becomes slower than building an APK and manually validating the slice, stay with APK-first validation.

## Current checkpoint / Codex return
Codex is available again as of 2026-09-12. DEDAL's current `1.0.0+4` refinement checkpoint has passed analyzer and APK build and the Owner reported the implemented behavior is acceptable. The intended handoff is to merge the approved DEDAL checkpoint to `main`, then have Codex pull that `main` state before doing any new work.

Codex handshake before touching app code:
1. `git fetch --all --prune`
2. switch to local `main`
3. `git pull --ff-only origin main`
4. read the files listed above plus `.agent/inbox/codex.md`
5. create/reset a `codex/*` branch from the pulled `main`
6. update `.agent/status/codex.md`
7. acknowledge the current checkpoint and proposed next slice in `.agent/inbox/dedal.md` or a handoff note before overlapping edits.
