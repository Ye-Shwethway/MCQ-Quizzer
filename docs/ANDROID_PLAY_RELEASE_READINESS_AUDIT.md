# Android and Google Play release-readiness audit

Audited: **2026-09-12**  
Baseline: `main` at `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`  
Audit branch: `codex/rejoin-fa5b6e9`  
Status: **not ready for Play submission**; proposal only, no release configuration changed.

This document is the current Android/release audit. The broader product review in
[`play_store_readiness_review.md`](play_store_readiness_review.md) remains useful,
while the current external-policy evidence is recorded separately in
[`research/google_play_release_requirements_2026.md`](research/google_play_release_requirements_2026.md).
Google Play requirements must be rechecked at release-candidate time.

## Executive result

The Android toolchain and SDK level are in good shape: the pinned Flutter 3.47.2
configuration resolves compile/target API 36, min API 24, AGP 9.1.1, Gradle
9.3.1, NDK 28.2, and Java 17. API 36 meets the current phone/tablet target
requirement. Application identity is internally consistent, HTTPS is validated
in the custom-provider flow, R8 is active for release builds through Flutter's
Gradle plugin, and credential-like files are ignored and absent from Git.

The project nevertheless has four launch-blocking areas:

1. It still uses the placeholder package identity `com.example.mcq_quizzer`.
2. Its `release` build explicitly uses the Android debug signing key.
3. There is no signed-AAB, version-controlled release procedure and artifact
   verification gate.
4. Play policy work outside the Android build is incomplete: a public privacy
   policy/Data Safety mapping and an operational in-app AI-content reporting and
   moderation flow are required before submission.

No keystore, password, API key, service credential, or signing secret was found
or added during this audit.

## Priority definitions

| Priority | Meaning |
| --- | --- |
| **P0** | Blocks the first Play upload/review or risks establishing the wrong permanent identity/signing lineage. |
| **P1** | High-priority security, reliability, or policy risk to resolve before release candidate. |
| **P2** | Production hardening or process quality; should be completed or explicitly accepted before launch. |

## Current configuration

| Area | Current state | Assessment |
| --- | --- | --- |
| Identity | `namespace`, `applicationId`, and `MainActivity` package all use `com.example.mcq_quizzer`. | Technically consistent, but the placeholder ID is **P0** and must be replaced once, before the first Play upload. |
| App name | Android resource label is `MCQ Quizzer`. | Acceptable technically; Owner should confirm final public name independently of package ID. |
| Version | Source declares `1.0.0+4`; Gradle consumes Flutter's `versionName`/`versionCode`. | Structure is correct. A monotonic release ledger/gate is missing. |
| SDK | Effective Flutter constants are compile 36, target 36, min 24. | Meets the current API 36 Play requirement. Min 24 is a product support choice, not a Play blocker. |
| Toolchain | Flutter 3.47.2, AGP 9.1.1, Gradle 9.3.1, built-in Kotlin runtime 2.4.20, NDK 28.2, Java 17. | Pinned and previously build-verified. The known source-scanner warning for `flutter_timezone` is not evidence that legacy KGP is applied at runtime. |
| Release signing | `signingConfig = signingConfigs.getByName("debug")`. | **P0**: not a production signing architecture. Existing APK certificate is `CN=Android Debug`. |
| Play artifact | CI creates a debug arm64 APK for selected checkpoints; no release AAB lane/procedure exists. | Debug APK is appropriate for fast tests, but **P0** before Play submission. New Play apps publish an AAB signed with an upload key. |
| Shrinking | Flutter's Gradle plugin enables R8 for release; a mapping file was produced by the existing local build. | No immediate blocker or custom keep rule is proven necessary. Preserve mapping/native symbols and regression-test plugin flows. |
| ABIs/native code | Existing universal release APK contains arm64-v8a, armeabi-v7a, and x86_64 Flutter/plugin libraries. | AAB will provide device splits. Current artifact's arm64 ELF LOAD alignment and APK 16 KB ZIP alignment pass, but a fresh AAB plus 16 KB runtime test remains a release gate. |
| Network | No explicit Network Security Configuration. Target 36 denies cleartext by default; provider editor/service reject non-HTTPS base URLs, credentials, query strings, and fragments. | Reasonably safe current default. Add an explicit cleartext-deny policy for auditable defense in depth; do not pin arbitrary custom providers. |
| Backup | No explicit `allowBackup`, `dataExtractionRules`, or `fullBackupContent`. Auto Backup therefore uses platform defaults. | **P1** because API keys/provider auth state and user quiz data need deliberate, tested rules. |
| Permissions | Internet/network state, notifications, exact alarm, boot, vibration, wake lock, and legacy read/write storage are declared. | Several declarations are broader or less deliberate than the current functionality requires; see findings. |
| Exported components | Launcher activity and notification boot receiver are exported. Dependency providers/internal receivers are non-exported; Profile Installer's exported receiver is protected by `android.permission.DUMP`. | Launcher export is required. The app-declared boot receiver should be aligned with the notification plugin's least-privilege setup. |
| Secrets policy | Root and Android `.gitignore` exclude keystores, `key.properties`, environment files, private keys, and credentials. No matching tracked/local project files were found. | Good baseline. Keep secrets outside Git and out of logs/artifacts. |
| Monetization SDKs | No ads or Play Billing SDK is currently declared. | Not a blocker for an unmonetized first release. They become release gates in the version that adds ads/Remove Ads. |

### Artifact caveat

The existing local `app-release.apk` is not proof of the current branch's version:
its manifest reports `1.0.0` (`versionCode` 1), while current source declares
`1.0.0+4`. It is also debug-signed. This looks like a stale artifact rather than
a defect in the current Gradle mapping, but it demonstrates why every release
must be built cleanly and have package, version, SDK, permissions, signer, and
hash inspected before distribution.

## Findings and recommended changes

| Priority | Finding and risk | Recommendation | Owner confirmation |
| --- | --- | --- | --- |
| **P0** | Placeholder application ID. A Play package identity is permanent for updates, and changing it after publication creates a different app. | Select a unique reverse-domain ID, check Play/package-registration availability, then migrate `applicationId`, `namespace`, Kotlin package/path, provider authorities generated from the ID, and validation commands together. | **Required:** exact package ID; whether this is a new or existing Play listing; any off-Play history using that ID. |
| **P0** | Release explicitly uses debug signing. This cannot establish the production update lineage. | Use Play App Signing with a distinct upload key. Load local signing inputs from an ignored file/environment; make release AAB builds fail clearly when inputs are absent. Keep the keystore/passwords outside Git and protected backups. | **Required:** Google-generated app-signing key is recommended; confirm if cross-store distribution instead requires an Owner-supplied app-signing key. Owner creates/controls credentials. |
| **P0** | No reproducible signed-AAB release procedure or metadata gate. Existing CI only produces debug APKs. | Add a documented local release command and later a protected/manual CI option if desired. Verify AAB signature, package ID, version, SDKs, merged permissions, native libraries, hashes, mapping, and native symbols. Never expose signing material in logs or public artifacts. | Required before deciding whether signing is local-only or also available to protected CI. |
| **P0** | Play privacy/Data Safety and AI-generated-content obligations are not release-complete. The app sends topics/imported source material to user-selected providers, and no in-app offensive-content reporting flow was found. | Publish an accurate policy and data-flow inventory; add an in-app report/flag route plus real moderation handling. Retain the AI fallibility disclaimer, but do not treat it as a replacement for reporting/filtering. This is DEDAL/product ownership with Codex release-gate review. | **Required:** public privacy-policy host, support/report destination and operator, retention policy, target countries/audience. |
| **P0 external** | Developer identity/package registration and possibly closed-test access depend on the Owner's Play account. Current Google guidance sets package-registration verification for September 30, 2026. New personal accounts created after November 13, 2023 generally need 12 closed testers continuously opted in for 14 days. | Confirm the account status in Play Console now; record applicable requirements and start the closed test early if required. | **Required:** account type/date, verification status, package registration, new/existing listing, tester availability. |
| **P1** | `SCHEDULE_EXACT_ALARM` is requested whenever notification permission is requested, and all study reminders use `exactAllowWhileIdle`. Fresh installs usually lack this special access; ordinary study reminders do not appear to require exact timing, and no inexact fallback was found. | Recommended: use inexact scheduling and remove special access. If exact timing is declared core, request it only in context, check/recheck grants, handle revocation/denial, and degrade safely. Requires a coordinated DEDAL behavior slice plus Codex manifest review. | **Required:** approve inexact study reminders (recommended) or define the exact-time product guarantee. |
| **P1** | Legacy `READ_EXTERNAL_STORAGE`/`WRITE_EXTERNAL_STORAGE` and `requestLegacyExternalStorage` remain. Export already attempts a system save picker and can use app-specific storage/share; `requestLegacyExternalStorage` is ineffective for this target. | Coordinate removal of the legacy permission request/fallback with DEDAL, then remove manifest declarations and test import/export on API 24, 29/30, and 36. Do not add `MANAGE_EXTERNAL_STORAGE`. | Only if the Owner requires direct shared-storage paths instead of system picker/share behavior. |
| **P1** | Backup behavior is accidental. Secure storage contains provider API keys, while the database/preferences contain quizzes, attempts, provider metadata, and settings. Restoring encrypted material without the correct Keystore state can also fail. | Explicitly set backup policy and add both modern and legacy rules. Exclude secure-storage files/API keys/auth state from cloud and device transfer. Decide whether database/library/preferences should transfer, and test reinstall/device migration. | **Required:** should user-created quiz/library/history data transfer to a new device? API keys should not. |
| **P1** | `ScheduledNotificationBootReceiver` is exported `true` and includes `LOCKED_BOOT_COMPLETED`, but is not direct-boot aware. The plugin's own current example uses a non-exported receiver and also handles package replacement. | Align with the plugin's supported least-privilege declaration, validate reboot/app-update rescheduling, and inspect the merged manifest again. Do not expose a receiver merely to accept vendor quick-boot broadcasts. | No product decision unless reminder rescheduling requirements differ. |
| **P1** | 16 KB checks passed only on an existing stale APK: APK ZIP alignment passed, and arm64 `libapp.so`/`libflutter.so` use 64 KB alignment while `libdatastore_shared_counter.so` uses 16 KB alignment. No 16 KB runtime test or current signed AAB check exists. | Repeat checks on the final AAB-derived APKs and run core provider/database/import/export/reminder flows on a 16 KB emulator/device (`PAGE_SIZE=16384`). Current enforcement for affected API 35+ updates begins February 1, 2027, but compatibility should be a launch gate. | None. |
| **P2** | No explicit network security XML exists. Platform defaults and Dart URL validation currently block cleartext, but the policy is implicit. | Add a release-wide cleartext deny configuration and keep platform CAs. If development ever needs custom/user CAs, scope them to a debug-only override. Avoid certificate pinning for user-configured providers. | Confirm no supported provider requires private/self-signed CAs (recommended assumption: none). |
| **P2** | `ACCESS_NETWORK_STATE`, app-declared `VIBRATE`, and `WAKE_LOCK` have no clearly proven app-owned need; vibration is already contributed by the notification plugin. | Verify final dependency behavior, remove redundant/unused declarations, and compare the merged manifest before/after. | None. |
| **P2** | `showWhenLocked` and `turnScreenOn` are enabled on the main quiz activity, copied from notification-style examples. A study app normally should not surface its whole activity over the lock screen. | Remove unless a specifically approved alarm UI needs it; ordinary notifications do not. | Required only if lock-screen activity behavior is intentionally desired. |
| **P2** | Release mapping/native symbols are produced locally but have no retention/upload procedure. | Archive mapping and native debug symbols per version in protected release storage and upload them to Play for deobfuscation/symbolication. Do not commit them. | Choose protected release storage/retention. |
| **P2** | Root package description remains `A new Flutter project.` and store-listing/app-content materials are not finalized. | Replace placeholder metadata where it is user/reviewer-facing and prepare listing text, screenshots, feature graphic, support contact, content rating, app access instructions, and licenses. | Final brand, category, audience, support contact, licensed content/assets. |

## Manifest assessment

### Permissions to retain when verified

- `INTERNET`: required for user-selected AI providers.
- `POST_NOTIFICATIONS`: required only when reminders are enabled; request it in
  context on Android 13+.
- `RECEIVE_BOOT_COMPLETED`: reasonable if scheduled reminders must survive a
  reboot and the receiver is declared according to current plugin guidance.
- `VIBRATE`: supplied by `flutter_local_notifications`; avoid duplicate app
  ownership.

### Permissions/configuration to challenge

- `SCHEDULE_EXACT_ALARM`: prefer inexact reminders.
- legacy read/write external storage: prefer Storage Access Framework/system
  picker, app-specific files, and explicit sharing.
- `ACCESS_NETWORK_STATE` and `WAKE_LOCK`: retain only with a documented caller or
  dependency requirement.
- `requestLegacyExternalStorage`: remove; it is not a modern storage strategy.

### Exported-component result

- `MainActivity`: exported `true` is correct because it owns the launcher intent.
- scheduled notification receiver: exported `false` is correct.
- boot receiver: external/system broadcast handling is needed, but the current
  exported surface and actions should be replaced with the plugin-supported
  least-privilege declaration and verified on reboot/update.
- Share Plus provider/receiver and URL Launcher activity: merged as non-exported.
- AndroidX Profile Installer receiver: exported but protected by the platform
  `DUMP` permission; dependency-owned, not an obvious app vulnerability.

## Release build, R8, and artifacts

Flutter 3.47.2's Gradle plugin enables release minification and supplies its
optimized default rules. The current build produced `mapping.txt`, so adding a
second blanket shrink configuration is unnecessary. Before the release candidate:

- run provider setup, file import/export/share, notifications, database upgrade,
  and secure-storage migration in a minified release build;
- add a narrow keep rule only if a reproduced reflection/serialization failure
  requires it;
- retain each build's mapping file and native symbols outside public Git;
- use AAB for Play and APK only for direct/manual installation;
- validate the Play-delivered build through internal sharing/bundle explorer, not
  only a locally assembled universal APK.

## Proposed implementation slices

Implementation must not begin until the Owner approves a slice. Slices are
ordered to avoid locking in the wrong identity or signing lineage.

| Order | Slice and acceptance result | Expected files/areas | Coordination / decision |
| --- | --- | --- | --- |
| **0** | Owner decisions and Play Console facts recorded. | This audit, continuity/decision docs, `.agent/` handoff files. | Final package ID, listing status, signing strategy, backup portability, reminder precision, audience/countries, privacy/report contacts. |
| **1** | Permanent Android identity and version policy. Clean build reports the approved ID and `1.0.0+4` or a newly approved version code. | `android/app/build.gradle.kts`; `android/app/src/main/kotlin/**/MainActivity.kt` and directory; release docs/scripts; possibly platform test references. | Codex-owned. Do not change until the exact ID is approved. |
| **2** | Secure upload-signing architecture and deterministic local release command. Release without credentials fails safely; a valid local configuration produces a signed AAB without exposing secrets. | `android/app/build.gradle.kts`, `.gitignore`/`android/.gitignore` if needed, a non-secret example/template, `scripts/` release validation, release documentation; optional protected workflow later. | Owner creates/protects key and passwords. Decide local-only versus protected CI. Never commit real values. |
| **3A** | Codex-only manifest hardening: explicit TLS and backup policy, least-privilege receivers/activity flags, merged-manifest inspection. | `android/app/src/main/AndroidManifest.xml`; new `android/app/src/main/res/xml/network_security_config.xml`; backup-rule XML for API 31+ and legacy devices. | Backup content decision required. Coordinate receiver behavior with DEDAL. |
| **3B** | Coordinated permission behavior: inexact reminders and modern import/export paths work without exact-alarm or legacy storage access. | DEDAL-owned `lib/services/notification_service.dart`, `lib/services/export_service.dart`, relevant settings UI/tests; Codex-owned manifest. | Must be explicitly handed to DEDAL for product code. Codex validates the Android result and does not silently edit these files. |
| **4** | Release-candidate artifact gate: clean signed AAB, derived APK inspection, 16 KB runtime, representative API/ABI smoke tests, hashes/symbols recorded. | `scripts/` validation tooling, release checklist/docs, optional manual GitHub workflow; no secrets. | Requires external signing input and emulator/Play Console access. |
| **5** | Policy/listing gate complete. | DEDAL-owned reporting/disclaimer/product flows; privacy and store documents; Play Console declarations outside Git. | Owner/DEDAL/Codex coordination. Ads/Billing are separate future slices if not in v1. |

## Owner decisions required before implementation

1. **Permanent package ID:** provide the exact reverse-domain identifier and
   confirm it is available/owned. Recommended pattern only (not a decision):
   `com.<owner-or-studio>.mcqquizzer`.
2. **Listing/account:** new or existing Play listing; personal or organization
   account; creation date; developer verification/package-registration status;
   whether the closed-test rule applies.
3. **Signing:** approve Google-generated Play App Signing keys plus a separate
   Owner-controlled upload key (recommended), or explain a cross-store need for
   another strategy. Choose local-only or protected-CI signing.
4. **Backup:** recommended default is to exclude API keys/auth state while
   allowing deliberately selected quiz/library data to transfer. Confirm whether
   attempts/history/settings should transfer too.
5. **Reminders:** approve inexact delivery (recommended) or define why a study
   reminder must fire at an exact minute and accept the special-access UX.
6. **Privacy/policy:** target countries and age groups, public privacy-policy
   host, support contact, AI-report destination/operator, retention/deletion
   rules, and reviewer access plan.
7. **Launch monetization:** confirm whether v1 is unmonetized or includes ads and
   one-time Remove Ads. If included, Billing 8+ and the ads SDK/data disclosures
   become release-critical; they are not present today.

## Recommended implementation order

1. Resolve the Owner decisions and Play Console account/package facts.
2. Migrate the permanent package identity and establish monotonic versioning.
3. Add secret-safe upload signing and a clean signed-AAB procedure.
4. Harden manifest/network/backup configuration; coordinate reminder and storage
   behavior changes with DEDAL.
5. Complete privacy, AI reporting/moderation, and store declarations.
6. Produce a release candidate; inspect the merged manifest and signer; validate
   API 36, 16 KB, representative older API/ABI behavior, upgrades, backups,
   notifications, provider access, and Play pre-launch reports.

## Release checklist

### Identity and account

- [ ] Permanent package ID and public app name approved.
- [ ] Play package availability/registration and developer verification confirmed.
- [ ] Account-specific closed-test/production-access requirements recorded.

### Build and signing

- [ ] Upload key created and backed up outside Git; Play App Signing configured.
- [ ] Release builds fail safely when signing inputs are missing.
- [ ] `versionCode` is greater than every Play artifact; `versionName` is intended.
- [ ] Clean signed AAB built; signature, package, SDKs, permissions, and hash verified.
- [ ] R8 mapping and native symbols stored in protected release storage/uploaded.

### Android security and compatibility

- [ ] Merged release manifest reviewed; only necessary permissions/components remain.
- [ ] Cleartext denied explicitly; custom providers remain HTTPS-only.
- [ ] Backup/device-transfer rules tested; API keys/auth state excluded.
- [ ] Reminder denial/reboot/app-update paths verified without crashes.
- [ ] Import/export/share works without broad storage access.
- [ ] Final AAB-derived artifacts pass 16 KB checks and run on a 16 KB environment.
- [ ] Release-mode upgrade tested without clearing real-phone user data.

### Play policy and listing

- [ ] Public/in-app privacy policy and accurate Data Safety form complete.
- [ ] AI fallibility warning plus in-app offensive-content report/flag and handling process verified.
- [ ] Target audience, content rating, ads, app access, and permission declarations complete.
- [ ] Store text, screenshots, feature graphic, icon, support contact, reviewer instructions, and licenses ready.
- [ ] If applicable, 12 testers remain opted in continuously for 14 days and production access is approved.
- [ ] If monetized, supported Billing, entitlement restoration/refunds, ads consent/caps, Contains ads, and audience rules are validated.

## Primary references

- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Android application ID configuration](https://developer.android.com/build/configure-app-module)
- [Android App Bundle requirement](https://support.google.com/googleplay/android-developer/answer/9844279?hl=en)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en)
- [Flutter Android release guide](https://docs.flutter.dev/deployment/android)
- [Android 16 KB page-size guidance](https://developer.android.com/guide/practices/page-sizes)
- [Android backup security](https://developer.android.com/privacy-and-security/risks/backup-best-practices)
- [Android Network Security Configuration](https://developer.android.com/privacy-and-security/security-config)
- [Android exact-alarm guidance](https://developer.android.com/develop/background-work/services/alarms)
- [Google Play Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Google Play AI-generated content policy](https://support.google.com/googleplay/android-developer/answer/13985936?hl=en)
- [New personal-account testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Play Billing deprecation schedule](https://developer.android.com/google/play/billing/deprecation-faq)

