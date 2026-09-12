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
- **APK-first/manual acceptance is the project delivery loop for meaningful UI and behavior slices.**
- Agent Fast CI is analyzer-only (`flutter analyze --no-fatal-infos --no-fatal-warnings`); `flutter test` is not a delivery gate.
- Do not add tests for every feature or migration edge case. Add targeted automated tests later only when they clearly protect a real observed bug/regression and do not slow delivery.
- Batch related implementation into a meaningful phone-testable checkpoint, then build an arm64 debug APK and let the Owner test on device.
- If CI/test debugging would take longer than producing an APK for manual validation, switch to APK-first immediately.
- On `dedal/*` and `codex/*`, the Android APK job runs when a qualifying source push contains `[apk]` or when `workflow_dispatch` is used deliberately.
- `main` remains Owner-controlled; agents do not merge their own work without explicit approval.
- When an APK build is green, fetch the artifact and give the Owner a direct download link.
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

## Product roadmap architecture — Owner approved 2026-09-12
Canonical details:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

Durable decisions:
- The current v1 concept is **Remove from Library**, not a resumable Archive workspace.
- Current Remove from Library semantics: completed history preserved, notes preserved, incomplete progress retired.
- Future permanent removal state should use nullable `removed_from_library_at`; source type and removal state must be separate concepts.
- A true resumable Archive workspace may be designed later only through a new Owner decision.
- Completed immutable attempts survive future permanent source deletion.
- Future permanent source deletion removes incomplete saved progress and set-scoped notes.
- History deletion, if ever exposed, is a separate deliberate data-management action.
- `permanentlyDeleteQuizSet` remains unreachable from normal UI until durable history independence and SQLite foreign-key behavior are implemented and validated.
- P2a owns durable attempts/snapshots/direct history queries/stable identity/FK-safe migration; it must not absorb every later analytics concern.
- Question identity contract: `question_id + lineage_id + content_fingerprint + source_ref`; direct-parent ancestry is optional only when needed.
- `attempt_question_results` is deferred to P4, provided P2a preserves complete versioned snapshot/answer/scoring/identity data for deterministic backfill.
- Saved combined quizzes are self-contained copied durable sets; unsaved targeted practice may remain virtual/derived.
- Deterministic local analytics precede AI Coach.
- AI Coach default payload is aggregate-only; sending selected question/source text requires explicit opt-in.
- Document-to-Quiz MVP starts with pasted/plain text, text PDF and DOCX; PPTX and scanned/vision support are deferred.
- Syncfusion PDF license/community eligibility must be verified before Play release.
- Machine-readable Article 50 provenance/schema/export implementation remains decision-gated.
- The roadmap architecture challenge is closed. Reopen only if new implementation evidence invalidates a decision; do not restart the whole planning cycle by default.
