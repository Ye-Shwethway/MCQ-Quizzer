# Agent Workspace

This directory is coordination infrastructure only. Application source belongs in the normal Flutter project folders.

## Layout
- `inbox/codex.md` — requests addressed to Codex.
- `inbox/dedal.md` — requests addressed to DEDAL.
- `status/codex.md` — Codex's current work/checkpoint.
- `status/dedal.md` — DEDAL's current work/checkpoint.
- `handoffs/` — immutable-ish handoff notes for meaningful completed work.
- `locks/` — lightweight overlap notices for files/areas that should not be edited concurrently.

## Message format
Use this compact format when useful:

```md
## YYYY-MM-DD HH:MM UTC — short title
From: DEDAL | Codex | Owner
To: DEDAL | Codex | Owner
Branch: branch/name
Task: one-line goal
Files/Area: likely touched files or subsystem
Request/Result: concise details
Blockers: none | details
```

## Workflow
1. Read `AGENTS.md`, both status files, and your inbox before substantial work.
2. Update your status before editing a broad/shared area.
3. Add a lightweight lock only when concurrent edits would be risky.
4. Implement on your own branch namespace.
5. At a worthy checkpoint, push. GitHub Actions automatically builds a debug APK for phone testing.
6. Record a handoff when work is ready for the other agent or Owner review.
7. Do not merge to `main` without explicit Owner approval.

## Security
This repository is public. Coordination notes must never contain API keys, tokens, credentials, raw Authorization headers, private signing material, or secret-bearing logs.
