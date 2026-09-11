# AI Provider Multi-Model Implementation Plan

## Goal
Refactor AI provider settings so one saved provider connection owns one credential/configuration and can manage multiple saved models. Users should be able to switch between verified models without re-entering the provider API key.

## Current limitation
`AiProviderProfile` currently stores a single `selectedModelId`. In practice this makes one saved profile behave like one provider+model binding, which duplicates credentials/configuration when the user wants several models from the same provider.

## Target model
A provider profile represents the connection/account:
- provider definition
- display name
- base URL and API paths
- encrypted API key (stored separately in secure storage)
- catalog/cache metadata
- saved model bindings
- active model id
- provider active/inactive state

A saved model binding represents a reusable model under that provider:
- model id
- optional display name
- catalog scope
- inference route
- validation state
- validation timestamp
- last error category

The full provider catalog remains separate from saved models. Large providers such as NanoGPT or OpenRouter may expose hundreds of available models; only user-selected models should appear in the saved model list.

## User workflow
1. Add a provider once and enter its API key once.
2. Test the provider connection and fetch its model catalog.
3. Add one or more models from the catalog to the provider.
4. Test saved models independently.
5. Choose one saved verified model as the provider's active model.
6. Switch model later without re-entering the API key.
7. Remove saved models that are obsolete or no longer wanted without deleting the provider or API key.
8. Quiz generation should eventually expose a compact selector containing saved verified models grouped by provider.

## Saved model removal behavior
Saved models are user-managed shortcuts/bindings, not permanent catalog entries.
- Every saved model must have a Remove action in provider management UI.
- Removing a saved model deletes only that saved binding; it must not delete the provider, API key, or cached/live provider catalog.
- If the removed model is not active, the remaining active model is unchanged.
- If the removed model is the active model, require confirmation and clear `activeModelId` after removal. The provider remains connected but is not generation-ready until another verified saved model is selected.
- A model that still exists in the provider catalog can be added again later without re-entering the API key.
- If a provider no longer returns a saved model in its refreshed catalog, keep the saved binding but mark it unavailable/stale rather than silently deleting it. The user can then remove it explicitly.
- The UI should keep saved models compact and should not surface the full catalog outside the model-picker/add-model flow.

## Compatibility and migration
Schema v1 profiles use `selectedModelId`.

Schema v2 migration is intentionally backward compatible:
- existing `selectedModelId = X` becomes one saved model binding for X
- `activeModelId = X`
- existing catalog scope, inference route, validation state, validation timestamp, and last error are copied to that migrated binding
- encrypted API keys remain keyed by provider profile id and are not duplicated or rewritten
- old JSON can still be loaded safely

During migration, legacy call sites may continue reading/writing `selectedModelId` through a compatibility alias while UI/service code is moved to `activeModelId` and saved model bindings.

## Implementation checkpoints

### Checkpoint 1 - Data model and migration
- Add a saved model binding model.
- Add `savedModels` and `activeModelId` to `AiProviderProfile`.
- Preserve source compatibility for current `selectedModelId` callers.
- Serialize schema v2.
- Auto-migrate schema v1 JSON on read.
- Do not change visible UI behavior yet.

Acceptance criteria:
- existing provider profiles load without data loss
- existing active provider/model behavior still works
- a profile can round-trip multiple saved models in JSON
- no credential migration is required
- Flutter analyze/tests/build remain green

### Checkpoint 2 - Provider management UI
- Provider card shows saved model count and active model.
- Provider editor has a Models section.
- Add models from cached/live catalog without re-entering API key.
- Remove saved models with confirmation when removing the active model.
- Removing a model never deletes the provider/API key/catalog.
- Keep stale/obsolete saved models visible until the user explicitly removes them.
- Test each model independently.
- Set a verified saved model active.
- Refresh catalog remains distinct from saved model list.

Acceptance criteria:
- one provider/API key can retain multiple models
- changing active model requires no credential re-entry
- deleting a model does not delete the provider/API key
- active-model removal leaves the provider connected but not generation-ready until another verified model is selected
- removed models can be added again later from the provider catalog

### Checkpoint 3 - Quiz generation model selector
- Add compact provider/model selector on generation screen.
- Show saved verified models only.
- Group models by provider.
- Persist user selection appropriately while respecting the globally active provider/model state.

Acceptance criteria:
- model switching is fast and obvious
- generation uses the selected provider/model route correctly
- NanoGPT catalog scope/inference-route semantics remain correct

## Security rules
This repository is public.
- Never commit API keys, tokens, Authorization headers, `.env` secrets, keystores, or local credential files.
- API keys remain in secure storage only.
- Logs and handoff files must never contain raw credentials.

## Branch and review
Implementation is performed on `dedal/agent-work` while Codex is unavailable. No merge to `main` without explicit Owner approval. Each worthy checkpoint should trigger the automatic debug APK workflow for phone testing.
