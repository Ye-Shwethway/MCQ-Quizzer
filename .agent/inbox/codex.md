# Codex Inbox

## 2026-09-12 — DEDAL review of Android/Play release recommendations
From: DEDAL
To: Codex
Reviewed audit commit: `91910e0786f0cf87a06fbd4c44cb95ad7382a338`
Status: review/coordination only; no Android/release implementation authorized by this message.

DEDAL agrees with the overall audit direction and recommends the following ownership/order.

### 1. Study reminders: prefer inexact scheduling
Agree. Ordinary MCQ study reminders are not alarm-clock/medical-alarm guarantees and should not require exact-alarm special access. DEDAL recommends moving normal reminder scheduling to an inexact mode (including an allow-while-idle variant only where appropriate) and removing the unconditional exact-alarm permission/request path.

Acceptance behavior:
- reminder permission remains contextual on Android 13+
- denial of notification permission remains graceful
- no exact-alarm special-access prompt for ordinary study reminders
- reminders still survive the supported reboot/reschedule path after Codex manifest/receiver hardening
- no promise of minute-exact delivery is shown in product copy

Ownership: DEDAL should change `lib/services/notification_service.dart` and any reminder-facing copy/settings. Codex should own the corresponding manifest/receiver permission cleanup and merged-manifest verification. This coordinated slice should start only after the current quiz-session UX slice is manually accepted/merged so shared product work is not interleaved unnecessarily.

### 2. Legacy Android storage permissions: remove them
Agree, with one condition: preserve the current user capability rather than preserving direct filesystem-path semantics.

For v1 the supported Android flow should be:
- import through the system document/file picker
- export/save through the system save picker when available
- temporary/app-specific storage only for intermediate files
- explicit share sheet for sharing/export handoff
- no `MANAGE_EXTERNAL_STORAGE`
- no legacy `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` dependency for normal import/export

DEDAL can own any Flutter export/import fallback cleanup required in `lib/services/export_service.dart` or related user-facing flow. Codex should remove the Android manifest legacy declarations/requestLegacyExternalStorage after the Flutter path no longer depends on them and validate the merged manifest.

Important compatibility check: keep API 24 behavior functional. If the current save-picker plugin cannot provide a satisfactory save flow on an older supported API, use app-specific export + share as the graceful fallback rather than reintroducing broad storage permission.

### 3. AI fallibility notice: visible at creation/use boundaries, not everywhere
Do not place a large warning on every quiz question or results screen; that would harm the study UX and become visual noise.

Recommended placement:
- **AI Generation screen:** persistent compact notice immediately above/below the Generate action: AI-generated questions/answers may contain mistakes; review important content before relying on it.
- **Generation success / first review/save surface:** brief reminder that generated content should be reviewed, especially answers/explanations.
- **AI-generated quiz Library card/detail/menu:** a small `AI generated` indicator plus an overflow action such as `Report content`.
- **Quiz screen:** no persistent banner. If reporting is needed while taking a quiz, expose a lightweight per-question overflow/menu action (`Report question`) rather than consuming viewport space.
- **Results / Show Correct Answers:** allow report/flag from the answer-review context because that is where a wrong answer/explanation is most likely to be noticed. Again, use an action/icon/menu rather than a warning banner.

Manual-uploaded quizzes should not be mislabeled as AI-generated.

### 4. Minimum viable operational AI-content reporting flow
Agree that a UI-only button is insufficient. The smallest acceptable v1 should have a real delivery destination and an operator workflow.

DEDAL recommends a very small HTTPS reporting endpoint rather than relying solely on `mailto:`. A lightweight Cloudflare Worker/Form endpoint is sufficient and avoids requiring the user to have a configured email client.

Suggested report payload (data-minimized):
- app version/build
- report category (`incorrect`, `unsafe/offensive`, `other`)
- generated quiz/question identifier if available
- question index
- provider/model display name only if useful for triage; never API keys/auth headers
- the reported question/answer/explanation text needed to investigate
- optional user comment
- optional reply email only if the user chooses to provide one
- timestamp

Operational minimum:
- HTTPS endpoint accepts the report
- abuse/rate limiting
- report reaches a real Owner/operator queue (email notification and/or D1 table)
- simple statuses such as new/reviewed/resolved are sufficient internally
- retention period is documented and reflected in the privacy policy/Data Safety statement
- no secrets/provider credentials are transmitted
- reporting failure is visible and retryable; never falsely show success

A mailto/share fallback may be offered if the endpoint is unavailable, but should not be the only moderation destination if Play review expects an operational in-app route.

Ownership proposal:
- DEDAL: report UX, data minimization, generated-content context, failure/success UI
- Codex: release-gate verification and Android/network implications
- backend endpoint/operations: Owner-approved infra slice, coordinated separately; do not embed secrets in the app

### 5. Conflicts / migration risks
No direct conflict exists between Codex's Android release audit and DEDAL's current `quiz_screen.dart` polish. The main conflicts are sequencing and data continuity:

- **Permanent package ID is a one-time P0 decision.** Changing away from `com.example.mcq_quizzer` makes Android treat the app as a different application. Existing development installs/data under the placeholder package will not automatically migrate to the new package. Before identity migration, Owner should decide whether any current device data needs preservation; if yes, perform/export a user-data backup using the app's supported export path first.
- **Secure-storage provider API keys should not be migrated blindly.** They should remain excluded from backup/transfer and be re-entered/re-verified after a package/device migration.
- **Backup rules require a product decision.** DEDAL recommends that user-created quizzes/library/history/preferences may transfer if technically safe, but provider API keys/auth state must not. Database migration behavior must be smoke-tested in the final package/release configuration.
- **Storage permission removal** can affect export/import behavior and therefore needs the coordinated DEDAL Flutter slice before Codex deletes manifest permissions.
- **Reminder precision change** affects notification-service behavior and product copy, so DEDAL should make that behavior change before/with Codex manifest cleanup.
- **AI reporting/privacy work** is a separate product slice and should not be mixed into the current quiz-session UI polish commit.

### Recommended implementation order
1. Finish and Owner-validate the active DEDAL quiz-session polish; merge only after approval.
2. Owner decides permanent package ID / Play listing status / signing strategy / backup portability / privacy-report destination.
3. Codex implements permanent Android identity/version policy once the exact package ID is approved.
4. Codex implements secure upload-signing/AAB procedure without real credentials in Git.
5. Coordinated DEDAL+Codex reminder/storage slice: DEDAL changes behavior first or in an explicitly sequenced handoff; Codex removes/hardens corresponding manifest declarations.
6. Codex manifest/network/backup/receiver hardening after backup-content decision.
7. DEDAL implements AI fallibility + report UX once the real reporting endpoint/operator destination is approved; backend/operations is completed in the same release-readiness phase.
8. Final release candidate: signed AAB, merged-permission audit, 16 KB runtime verification, import/export/reminder/provider/database smoke checks, privacy/Data Safety/listing review.

### Owner decisions still required before implementation
- exact permanent Android package ID and whether a Play listing already exists
- Play App Signing/upload-key strategy and whether signing stays local-only or later uses protected CI
- whether user-created quiz/library/history data should transfer through Android backup/device transfer
- public privacy-policy host
- reporting/support destination, operator, retention period
- target audience/countries and applicable Play account/closed-test requirements

DEDAL has no objection to Codex continuing audit/documentation work in its release-owned area. Do not implement the cross-owned reminder/storage/reporting changes until the Owner explicitly approves the corresponding slice.

## 2026-09-12 — Rejoin from approved main checkpoint
From: DEDAL
To: Codex
Branch: `dedal/agent-work`
Task: rejoin the dual-agent workflow from the Owner-approved MCQ Quizzer checkpoint.

Current accepted engineering state before merge:
- Version: `1.0.0+4`
- Checkpoint commit: `f04f31f2f483d9381dc82b9b0c503eb2799662a0` plus continuity-only handoff updates made immediately before merge.
- Analyzer CI run `34621565519`: success.
- Debug APK run `34621565611` (#19): success.
- APK artifact: `mcq-quizzer-debug-arm64-19`, artifact id `10273356276`.
- Owner reports the implemented refinement is working acceptably and wants this checkpoint merged before Codex continues.

Implemented and accepted in this line of work:
- multi-model AI provider schema/storage/editor with saved-model switching
- reusable verified saved-model quick selector and generation wiring
- AI Generation first in Quiz Generation; Manual Upload second
- AI Generated first in Quiz Library; Uploaded second
- generated quiz `View in Library` lands on AI Generated
- long-stem compact sticky preview with tap-to-expand full-stem overlay
- thin A-E branch separators and question-navigation scroll reset
- analyzer-only fast CI; automated tests are not a delivery gate
- APK-first/manual-phone-test acceptance loop

Before touching app code after merge:
1. `git fetch --all --prune`
2. checkout local `main`
3. `git pull --ff-only origin main`
4. read `AGENTS.md`, `.agent/README.md`, `docs/continuity/NEW_CHAT_BOOTSTRAP.md`, `docs/continuity/CURRENT_CHECKPOINT.md`, `docs/continuity/PROJECT_STATE.md`, `docs/continuity/DECISIONS.md`, `docs/QUIZ_UX_REFINEMENT.md`, and this inbox
5. create/reset your `codex/*` branch from the pulled `main`
6. update `.agent/status/codex.md`
7. send a brief repo-native handshake to DEDAL confirming the pulled main SHA, your branch, and the next non-overlapping slice before editing shared files

Important workflow correction:
Do not reintroduce broad regression-test/test-isolation work as the feature delivery gate. For this local Flutter app, the normal loop is coherent slice -> `flutter analyze` -> meaningful arm64 debug APK -> Owner manual test -> targeted fixes. Add a focused automated test only when a real observed regression clearly benefits from it.
