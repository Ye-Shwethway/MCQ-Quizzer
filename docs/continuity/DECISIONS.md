# Decisions

These are durable project decisions unless the Owner explicitly changes them.

## Source of truth and ownership
- GitHub is the engineering source of truth.
- `main` contains Owner-approved stable work only.
- DEDAL uses `dedal/*`; Codex uses `codex/*`.
- Agents do not merge their own work to `main` without explicit Owner approval.

## Agent collaboration
- Coordination is repo-native via `AGENTS.md` and `.agent/` inbox/status/handoff files.
- No separate orchestration server is required.
- Codex and DEDAL should avoid overlapping edits where practical and leave clear handoffs.

## Build/test workflow
- Use fast CI for ordinary agent-branch code pushes: `flutter analyze` + `flutter test`.
- Do not build/install an APK for every micro-fix.
- Batch related implementation and fixes into a meaningful, phone-testable checkpoint.
- On `dedal/*` and `codex/*`, the slow Android APK job runs only when the pushed checkpoint commit message contains `[apk]` or when `workflow_dispatch` is used deliberately.
- `main` remains allowed to build an APK automatically after Owner-approved changes.
- APK artifacts are arm64 debug builds for the primary phone-test workflow.
- When an APK build is green, fetch the artifact, verify the actual APK size, and give the Owner a direct download link without waiting to be asked.
- While an APK build is running, avoid unnecessary replacement pushes. Cancel/replace only when a newer urgent fix invalidates that build.
- Docs-only and coordination-only changes must not trigger APK builds.

## AI provider model
- Provider connection/configuration and credential are provider-level.
- One provider may own multiple saved models.
- Saved models are a curated child list; fetched catalog is separate discovery/cache data.
- Switching saved models must not require re-entering the API key.
- Models can be removed independently from the provider/API key.
- Removing the active model clears active selection; do not silently choose a replacement.
- Catalog disappearance/obsolescence must not silently delete saved models.
- Existing schema-v1 `selectedModelId` data must migrate without credential loss.

## Security
- Repository is public.
- Never commit API keys, tokens, Authorization headers, keystores, `.env` secrets, or raw credentials in logs/docs/handoffs.
- Provider API keys remain in secure storage keyed to provider profile identity.

## Engineering style
- Prefer small, reversible implementation commits, but reserve phone APK testing for complete feature checkpoints.
- Avoid unrelated refactors and blind dependency upgrades.
- Preserve existing working behavior during migrations through compatibility layers where reasonable, then remove transitional compatibility only after downstream callers are migrated and tested.
