# Current Checkpoint

Updated: 2026-09-11

## Active branch
`dedal/agent-work`

## Current feature
AI provider settings are being refactored from one-provider-profile/one-model into one provider connection with multiple saved model bindings.

Implementation plan: `docs/AI_PROVIDER_MULTI_MODEL_IMPLEMENTATION.md`

## Completed so far
- Dual-agent repository protocol merged to `main`.
- Automatic debug APK workflow validated.
- Multi-model implementation plan added.
- Checkpoint 1 data model started:
  - `AiProviderModelBinding`
  - `savedModels`
  - `activeModelId`
  - legacy `selectedModelId` compatibility/migration path
  - schema version 2 serialization
- Constructor compile regression fixed in commit `0559726093e72f67852c22a814f5125746e4b90c`.
- GitHub Actions run #11 built successfully and uploaded `mcq-quizzer-debug-11`.

## Immediate next work
1. Finish Checkpoint 1 validation, especially v1 -> v2 migration and JSON round-trip behavior.
2. Do not change visible UI behavior until Checkpoint 1 is stable.
3. Then implement Checkpoint 2 provider-management UI with add/remove/test/set-active model actions.
4. Later implement Checkpoint 3 quick model selection for quiz generation.

## Important model removal rule
A saved model may be removed without deleting the provider, credential, or catalog cache. Removing the active model clears `activeModelId` after confirmation. Obsolete/missing catalog entries are not silently deleted; the user decides whether to remove them.

## Build discipline
One meaningful checkpoint -> one push -> one Actions build. While a build is in progress, do not push docs-only/non-urgent changes. When green, fetch the artifact and provide a direct download to the Owner automatically.
