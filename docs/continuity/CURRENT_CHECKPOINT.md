# Current Checkpoint

Updated: 2026-09-11

## Active branch
`dedal/agent-work`

## Current feature
AI provider settings are being refactored from one-provider-profile/one-model into one provider connection with multiple saved model bindings.

Implementation plan: `docs/AI_PROVIDER_MULTI_MODEL_IMPLEMENTATION.md`

## Completed so far
- Dual-agent repository protocol merged to `main`.
- Continuity bootstrap/checkpoint/state/decision docs are present under `docs/continuity/`.
- Multi-model schema v2 exists with `AiProviderModelBinding`, `savedModels`, `activeModelId`, and legacy `selectedModelId` migration compatibility.
- Constructor compile regression was fixed and validated by GitHub Actions.
- Provider editor now preserves multiple saved models, supports selecting/using/removing them, and keeps the provider credential separate.
- Run #13 built the new arm64 debug APK successfully.
- APK packaging was changed from universal debug to arm64-only debug for phone testing.
- CI policy is now checkpoint-based:
  - ordinary agent-branch code pushes run fast CI (`flutter analyze` + `flutter test`)
  - APK build on agent branches requires `[apk]` in the pushed checkpoint commit message, or deliberate `workflow_dispatch`
  - `main` may still build automatically after Owner-approved changes

## Immediate next work
1. Continue the current multi-model provider slice without producing another APK for every micro-fix.
2. Finish saved-model persistence/switch/remove behavior and provider-card summary.
3. Add/finish schema and behavior tests, especially v1 -> v2 migration and multiple-model round trip.
4. Inspect generation call sites and implement the saved-model quick selector only after provider management is stable.
5. When the next meaningful phone-testable slice is ready, push a checkpoint commit containing `[apk]`, wait for Actions, fetch the artifact, verify actual APK size, and provide the direct APK link.

## Important model removal rule
A saved model may be removed without deleting the provider, credential, or catalog cache. Removing the active model clears `activeModelId` after confirmation. Obsolete/missing catalog entries are not silently deleted; the user decides whether to remove them.

## Build discipline
Implementation commits can be frequent and small. Phone APK builds are intentionally infrequent. The normal loop is now: implement several related changes -> fast CI -> complete feature checkpoint -> `[apk]` build -> phone test -> batch feedback -> next checkpoint.
