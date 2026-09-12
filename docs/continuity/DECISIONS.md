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

## Android and Google Play release identity
- Permanent Android application ID and namespace: `com.thorne.mcqquizzer`, subject to final package registration/availability confirmation in the Owner's Play Console before the first upload.
- Treat the app as a new Google Play listing.
- Use Google Play App Signing with a distinct Owner-controlled upload key. Keystores, passwords, and signing environment values never enter Git.
- User quizzes, library, history, and ordinary settings may transfer through Android backup/device transfer where safe. Provider API keys and authentication state must not transfer and must be re-entered and re-verified.
- The public privacy policy will live at a stable HTTPS URL on an Owner-controlled domain.

## Release policy, audience, and reporting
- Target a general student/adult audience; the app is not specifically directed to children.
- Launch to all available countries, including the EU, only after applicable transparency, privacy, reporting, and operational requirements are complete.
- Treat EU AI Act Article 50 transparency as a release gate. Clearly identify AI interaction and AI-generated content; never imply generated medical or study material is authoritative.
- AI-content reports require a real in-app flow backed by an HTTPS endpoint, durable queue/log, and Owner support destination. A report UI must not claim success unless durable delivery succeeds.
- Default AI-content report retention is 90 days unless later legal/policy review approves another period.

## Engineering style
- Prefer small, reversible implementation commits, but reserve phone APK testing for complete feature checkpoints.
- Avoid unrelated refactors and blind dependency upgrades.
- Preserve existing working behavior during migrations through compatibility layers where reasonable, then remove transitional compatibility only after downstream callers are migrated and tested.
