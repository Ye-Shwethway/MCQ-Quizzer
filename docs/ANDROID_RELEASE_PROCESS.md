# Android release process

Status: foundation prepared for `com.thorne.mcqquizzer`; no production
credentials have been created or committed.

## Permanent identity

- Application ID and Android namespace: `com.thorne.mcqquizzer`.
- Play listing: new application.
- Before the first internal/closed-track upload, the Owner must confirm the
  package is available/registerable in Play Console. Public search is not an
  authoritative package reservation check.
- The previous development ID `com.example.mcq_quizzer` is a different Android
  application. Its emulator/phone data will not automatically migrate. Export
  anything worth preserving before uninstalling the development package.

## Signing architecture

Use Google Play App Signing with two distinct roles:

1. Google Play holds the app-signing key used for APKs delivered to users.
2. The Owner holds a separate upload key used to sign the AAB sent to Play.

The repository must never contain the upload keystore, passwords, private keys,
or real `key.properties`. The committed `android/key.properties.example` only
documents field names.

The Android build accepts either ignored local `android/key.properties`:

```properties
storeFile=C:/absolute/path/outside/the/repository/mcq-quizzer-upload.jks
storePassword=OWNER_SUPPLIED_VALUE
keyAlias=OWNER_SUPPLIED_ALIAS
keyPassword=OWNER_SUPPLIED_VALUE
```

Alternatively, protected CI may inject all four values without writing a
properties file:

- `MCQ_UPLOAD_STORE_FILE`
- `MCQ_UPLOAD_STORE_PASSWORD`
- `MCQ_UPLOAD_KEY_ALIAS`
- `MCQ_UPLOAD_KEY_PASSWORD`

Partial or missing release signing inputs fail release artifact builds with a
generic error that does not print values. Debug builds remain available without
production credentials.

The Owner—not an agent—creates the upload key, chooses its passwords/alias,
backs it up in protected storage, and configures Play App Signing. Do not paste
those values into chat, issues, documentation, terminal logs, or GitHub artifacts.

The first Play Console action must also confirm/register
`com.thorne.mcqquizzer`. A public web/package search found no obvious exact use,
but only the Owner's Play Console can establish availability for this listing.

## Version policy

`pubspec.yaml` is the source for Flutter `versionName+versionCode`. Every Play
upload must use a `versionCode` greater than every artifact previously uploaded
to any Play track. Record the version, Git commit, AAB SHA-256, upload date, and
track in the release log before upload. Never rebuild a different commit under a
previously uploaded version code.

## Build commands

Use the pinned project SDK:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter-project.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\scripts\flutter-project.ps1 analyze --no-fatal-infos --no-fatal-warnings
powershell -ExecutionPolicy Bypass -File .\scripts\flutter-project.ps1 build appbundle
```

The final command defaults to a release AAB and requires configured upload
signing. The Play artifact is:

`build/app/outputs/bundle/release/app-release.aab`

For local iteration without signing material, use a debug APK targeted to the
actual emulator ABI. GitHub APK artifacts remain reserved for meaningful phone
checkpoints and release candidates.

## Pre-upload verification

For every candidate:

1. Confirm the source branch/commit is Owner-approved and the worktree is clean.
2. Resolve dependencies and run the analyzer under the repository's nonfatal
   warning policy.
3. Build the signed AAB from a clean, pinned environment.
4. Verify AAB signing without printing or exporting private-key material.
5. Inspect the bundle/derived APK manifest for package ID, version, min/target
   SDK, permissions, exported components, and provider authorities.
6. Verify every 64-bit native library for 16 KB compatibility and run the
   Play-delivered build on a 16 KB device/emulator.
7. Retain the R8 mapping and native debug symbols in protected release storage;
   upload them to Play for deobfuscation/symbolication. Do not commit them.
8. Exercise install/upgrade, provider-key re-entry, database/library/history,
   backup/restore, import/export/share, notifications, AI disclosures/reporting,
   offline/error behavior, and supported ABI/API combinations.
9. Review Play pre-launch results, Data Safety, privacy policy, AI-content
   reporting, target audience, content rating, app access, ads, and store assets.
10. Record artifact hashes and upload only the verified AAB.

## Backup contract

Android cloud backup and device transfer may retain the SQLite quiz database,
ordinary SharedPreferences, and user documents where the platform considers
them eligible. Both modern and legacy backup rules explicitly exclude the
Flutter Secure Storage data, wrapped-key storage, and algorithm/migration
configuration files. Consequently, provider API keys/authentication state must
be re-entered and re-verified on the destination installation.

Re-test the exclusion names whenever `flutter_secure_storage` changes major
version or storage namespace/configuration. Backup success must never be inferred
only from a normal app upgrade.

## External release inputs still required

- Play Console package registration/availability and developer verification.
- Owner-created upload key and Play App Signing enrollment.
- Account type/creation date and any 12-testers/14-days production-access gate.
- Final public privacy-policy URL and support contact.
- Final AI-report endpoint, operator queue/support destination, abuse controls,
  and documented 90-day deletion job.
- Final v1 ads/purchase decision and corresponding Play declarations.
