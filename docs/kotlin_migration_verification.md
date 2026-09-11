# Kotlin migration verification — 2026-09-10

## Root cause and fix

The earlier migration was partial. AGP supplied Kotlin 2.2.10, below Flutter's
2.2.20 hard minimum. Adding a Kotlin dependency in the root build script did not
replace the version already loaded through the settings plugin classloader.

`android/settings.gradle.kts` now resolves Kotlin 2.4.20 alongside AGP with
`org.jetbrains.kotlin.jvm` **apply false**. This supplies the runtime without
applying either Kotlin JVM or legacy Kotlin Android to the app. The app uses
AGP-owned built-in Kotlin and Java/JVM target 17.

Pinned toolchain: Flutter 3.47.2 (official tag revision in
`flutter-toolchain.json`), AGP 9.1.1, Gradle 9.3.1, Kotlin 2.4.20, JDK 17.
Kotlin 2.4.20's published support range includes this AGP/Gradle pair; merely
using Flutter's warning floor would not cover the full pair in that matrix.

Sources: [AGP Kotlin runtime](https://developer.android.com/build/releases/agp-9-0-0-release-notes),
[Kotlin compatibility matrix](https://kotlinlang.org/docs/gradle-configure-project.html),
[Flutter migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

## Verified so far

- Reproduced the original 2.2.10 failure with `gradlew help` before the fix.
- Gradle configuration succeeds with the corrected settings-level resolution.
- `gradlew -I ../scripts/verify-built-in-kotlin.init.gradle verifyBuiltInKotlin`
  succeeds: app plus all 10 Android dependencies have built-in Kotlin enabled,
  a Kotlin extension present, and no legacy Kotlin Android plugin applied.
- 21 focused tests pass: attempt storage, timers, scoring, provider safety,
  and provider-editor stale-response protection.
- `flutter analyze --no-pub`: no errors or warnings, 82 informational lint items.
- First migrated release APK build succeeded (63.8 MB, 637.1 seconds). It
  reported the old NDK pin; that pin has now been replaced with
  `flutter.ndkVersion` (28.2.13676358 for this pinned SDK). Final rebuild also
  passed, exit code 0, in 34.6 seconds without the NDK mismatch warning.
  Installed with `adb install -r` (data retained) on Medium_Phone_API_36.0.
  Cold launch returned `Status: ok`; MainActivity is the top resumed activity,
  the app process remains alive, and Android's crash buffer is empty. This is
  a startup check, not a full feature or credential-migration smoke test.
  APK SHA-256: `9E8369098C739992C0CDA91BDA46D6C7FE5650741D59FC8542BE9360932BB557`.

Logs are under `build/`: `kotlin-minimum-before.log`,
`kotlin-runtime-verification.log`, `migration-tests.log`,
`migration-analysis.log`, `kotlin-runtime-release.log`, and
`kotlin-final-release.log` (final successful build).

## Remaining warnings and limits

Flutter 3.47.2's `FlutterPluginUtils.getSubprojectPluginState` scans source text
with regular expressions. It flags flutter_timezone 5.1.0's conditional
`apply plugin: 'kotlin-android'` fallback despite that branch not executing with
AGP 9 and `android.builtInKotlin=true`. The runtime verification above confirms
this distinction. No SDK or Pub-cache source was patched to hide the warning.

`android.newDsl=false` remains necessary for this Flutter SDK's legacy Android
extension accesses; new DSL migration is separate from built-in Kotlin.
Jetifier and other upstream Gradle deprecations also remain. The project is not
claimed to be warning-free or compatible with unreleased AGP/Gradle versions.

Secure storage stays on v10 to retain migration support for existing v9 data;
do not jump directly to v11, which removes the legacy readers. Native credential
migration, sharing/file picking, and timezone/reminder smoke tests remain.

The release build still uses debug signing and the example application ID;
it is not a Play Store submission artifact.

## Repeatable use

Use `scripts/flutter-project.ps1` for this repo's pinned Flutter SDK, or the
workspace VS Code SDK selection. Reload the Gradle project after settings
changes. Do not use dependency-validation bypass flags.

`scripts/New-FlutterProject.ps1` is a draft new-project bootstrap that resolves
official stable and gates on dependency solving, tests, analysis, and release
compilation. It is not globally installed or end-to-end verified. No automatic
global upgrade behavior has been enabled for existing projects.
