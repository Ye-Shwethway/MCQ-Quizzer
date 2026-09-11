# New Chat Bootstrap

This file is the entry point for resuming MCQ Quizzer work in a new ChatGPT/Codex session.

## Read first
1. `AGENTS.md`
2. `docs/continuity/CURRENT_CHECKPOINT.md`
3. `docs/continuity/PROJECT_STATE.md`
4. `docs/continuity/DECISIONS.md`
5. The implementation document for the active feature, currently `docs/AI_PROVIDER_MULTI_MODEL_IMPLEMENTATION.md`
6. Your own `.agent/status/<agent>.md` and inbox file.

## Repository / branch rules
- Repository: `Ye-Shwethway/MCQ-Quizzer`
- `main` is Owner-approved stable only.
- DEDAL works on `dedal/*` branches.
- Codex works on `codex/*` branches.
- Neither agent merges to `main` without explicit Owner approval.
- Public repository: never commit credentials or API keys.

## Working loop
Implement a small coherent checkpoint -> push once -> let the automatic debug APK workflow finish -> inspect result/logs -> fetch and provide the APK artifact whenever green -> obtain phone feedback -> continue.

Do not create extra pushes while a build is running unless an urgent fix makes the in-progress run obsolete. Prefer one meaningful checkpoint per build.

## Current agent mode
Codex is temporarily unavailable due to usage limits. DEDAL is continuing implementation on `dedal/agent-work`. Codex should handshake later by reading `AGENTS.md`, `.agent/README.md`, and `.agent/inbox/codex.md` before touching app code.
