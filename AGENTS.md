# Agent Collaboration Rules

This repository is maintained by the Owner with two coding agents: Codex and DEDAL.

## Branch ownership
- `main` is Owner-approved stable source of truth. Agents must not merge to `main` without explicit Owner approval.
- Codex works on `codex/*` branches.
- DEDAL works on `dedal/*` branches.
- Do not push code to another agent's active branch unless the Owner explicitly requests it.

## Coordination
All agent-only coordination lives under `.agent/` so it stays separate from application code.
- Read `.agent/README.md` before substantial work.
- Check the other agent's inbox/status before touching overlapping areas.
- Use `.agent/inbox/` for requests or review questions.
- Use `.agent/status/` for the current checkpoint and files being touched.
- Write a handoff under `.agent/handoffs/` for meaningful completed work or when transferring ownership.
- Keep coordination concise and factual. The Owner has final authority.

## Change discipline
- Prefer the smallest targeted patch. Do not over-engineer.
- Preserve working behavior unless the task explicitly changes it.
- Avoid simultaneous edits to the same files. Coordinate first when overlap is likely.
- A worthy checkpoint is a state that compiles and is useful for phone testing or review.

## Public repository / secrets
This is a public repository. Never commit API keys, access tokens, passwords, signing secrets, private certificates, authorization headers, private URLs containing credentials, `.env` files, local credential stores, or secret-bearing debug dumps/logs.
- Use placeholders in examples.
- Redact provider responses/logs when they might contain credentials.
- GitHub Actions builds must not require app-provider credentials for ordinary debug APK generation.
- If a secret is ever required for CI, it must come from GitHub Actions Secrets and must never be echoed.

## Validation
Before a worthy checkpoint, run the relevant lightweight validation. Existing CI runs Flutter analyze/tests. APK workflow builds a debug APK automatically on agent branch pushes.

## Merge policy
Agents may prepare branches and PRs, discuss, review, and revise. Final merge to `main` happens only after explicit Owner approval.
