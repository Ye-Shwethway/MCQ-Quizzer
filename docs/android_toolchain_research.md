# Android toolchain research

Date: 2026-09-06. Scope: investigate the successful Gradle configuration's warnings; no application-feature changes in this research.

## Recommendation

Upgrade the project to **Gradle 8.14.3 / AGP 8.11.1 / Kotlin Gradle Plugin 2.2.20** as a bounded stabilization step. Preserve the cross-drive fix and existing plugin versions initially; verify task discovery and a release APK before proceeding with app refinement. This is a conservative supported intersection, not the newest possible toolchain.

Kotlin documents KGP 2.2.20–2.2.21 as fully supporting Gradle 7.6.3–8.14 and AGP 7.3.1–8.11.1. The existing KGP 2.1.0 is outside its fully supported range with Gradle 8.12. [Kotlin compatibility matrix](https://kotlinlang.org/docs/gradle-configure-project.html)

AGP 8.11 supports API 36, requires Gradle 8.13 or later and JDK 17. Keep Java/Kotlin bytecode targets aligned, and use a compatible installed JDK for Gradle. [Android compatibility table](https://developer.android.com/build/releases/agp-8-11-0-release-notes)

## Three distinct issues

1. **Previous cross-drive failure:** Windows plugin source/build paths on different drives; a separate issue from the warnings below. Retain and regression-test that repair.
2. **Project version deprecations:** the three Flutter minimum-version warnings can be addressed with the matrix above, without bypassing dependency validation.
3. **SDK-owned embedded Kotlin warning:** local `C:/flutter/packages/flutter_tools/gradle/build.gradle.kts` applies both `kotlin-dsl` and Kotlin JVM 2.2.20. This included build is separate from the app's KGP declaration. Gradle 8.12–8.14 embeds Kotlin 2.0.21; embedded 2.2.20 starts with Gradle 9.2. Changing only app KGP cannot align this. Do not patch the shared Flutter SDK, suppress the warning, or jump major Gradle versions merely to silence it. A successful release build provides a bounded compatibility check, not proof that the warning is meaningless. [Gradle embedded Kotlin matrix](https://docs.gradle.org/current/userguide/compatibility.html)

## Why not enable built-in Kotlin immediately?

The installed SDK's cache metadata reports **Flutter 3.44.0 / Dart 3.12.0**. Current Flutter documentation says 3.44 supports AGP 9 with built-in Kotlin disabled, while enabling built-in Kotlin requires **Flutter 3.47+**. Migration also requires compatible plugins, removal of the app KGP application and migration from `kotlinOptions` to `kotlin.compilerOptions`. Flutter's legacy compatibility flags should remain until that coordinated migration. [Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)

The installed SDK source/template defaults and cached version metadata should be treated separately: a newer template constant does not establish that all older project plugins support the new combination. Pin a verified SDK revision for future reproducible builds.

## Plugin migration inventory

Installed versions below come from this repository's `pubspec.lock`; available releases were checked against publisher changelogs.

| Plugin | Installed | Migration evidence / implications |
|---|---|---|
| `flutter_timezone` | 3.0.1 | 5.1.0 adds AGP 9 support. Version 5 changes returned values to `TimezoneInfo`, requiring a Dart call-site migration and reminder/timezone tests. [Changelog](https://pub.dev/packages/flutter_timezone/changelog) |
| `share_plus` | 7.2.2 | 13.2 adds built-in Kotlin; latest checked is 13.3.0. Version 12 already requires AGP >=8.12.1, so blindly upgrading conflicts with the conservative 8.11.1 target. Version 11 also refactors the sharing API. [Changelog](https://pub.dev/packages/share_plus/changelog) |
| `shared_preferences_android` | 2.4.13 | 2.4.24 adds built-in Kotlin; latest checked is 2.4.28. Current 2.4.13 inherits plugin build declarations raised to AGP 8.12.1 / Kotlin 2.2.10 in 2.4.12; actual root classpath resolution and compilation must be checked, not assumed from declared versions. [Changelog](https://pub.dev/packages/shared_preferences_android/changelog) |

All three have migration releases, so there is no need to file an upstream incompatibility issue now. Upgrade them in a separate coordinated Flutter/AGP migration, with dependency resolution and runtime coverage for sharing, timezone changes, reminders, and preference persistence. Do not hand-edit pub-cache packages.

## Verification gates

- Record effective Gradle/JVM and app plugin versions.
- Run IDE-equivalent Gradle task discovery with all warnings enabled.
- Re-run the original cross-drive task and build a **release**, not debug, APK.
- Install without clearing user data and launch on the Medium Phone emulator.
- Record remaining warnings and distinguish upstream warnings from project-owned deprecations.
- Before full AGP 9 migration, verify a pinned Flutter 3.47+ SDK, plugin native build sources, documented AGP/Gradle/JDK matrix, and a release APK/AAB. Never rely only on a successful configuration step.

Build/test results belong in the implementation handoff; this document establishes the researched recommendation, not a claim that an upgrade has already passed.

## Implementation record

Applied the recommended three-version upgrade and migrated the app's deprecated
`android.kotlinOptions` to `kotlin.compilerOptions`, retaining Java/Kotlin 11
bytecode targets and Java 17 as the build runtime. Kept the existing cross-drive
output handling and explicit legacy Kotlin/DSL flags. No shared SDK,
Pub-cache source, package versions, API-level declarations, or signing identity
was changed.

Pinned the wrapper distribution SHA-256 from Gradle's official
[checksum endpoint](https://services.gradle.org/distributions/gradle-8.14.3-all.zip.sha256):
`ed1a8d686605fd7c23bdf62c7fc7add1c5b23b2bbc3721e661934ef4a4911d7c`.
This protects future wrapper downloads; an already-extracted cache is not
revalidated by merely adding the checksum.

The original task-creation dry run passed on the upgraded toolchain. Logs:
`build/toolchain-configuration.log`, `build/toolchain-task-discovery.log`, and
`build/toolchain-release.log`. No Flutter dependency-validation bypass or
warning suppression was added. Warning-mode-all attributes remaining Groovy
assignment deprecations to dependency build scripts such as `file_picker`.

Remaining SDK-owned Kotlin and built-in migration warnings are consciously
deferred to a pinned Flutter 3.47+ / compatible AGP9 / plugin migration, not
declared resolved. The SDK is shared across projects: do not mutate its Kotlin
build script to hide the warning. These warnings do not by themselves prevent
starting the feature plan once release verification passes.

### Cross-drive cache refinement during verification

A fresh KGP 2.2.20 compilation reproduced Kotlin incremental-cache relative-path
errors despite the prior task-level override. Replaced that override with the
documented project property `kotlin.incremental=false`, which applies consistently
across plugin classpaths. This disables Kotlin incremental compilation for this
project (including same-drive Kotlin tasks), not tests or Gradle up-to-date
checks. Expect slower changed Kotlin builds. Revisit enabling it only after a
same-drive source layout or a compiler fix is verified with actual recompilation.
[Kotlin compilation/cache documentation](https://kotlinlang.org/docs/gradle-compilation-and-caches.html)

### Verified results

- Original lifecycle-plugin unit-test task graph: configuration/dry run passed.
- Full `tasks --all` discovery and build environment inspection: passed.
- Effective plugin classpath inspection: Gradle 8.14.3, AGP 8.11.1,
  KGP 2.2.20; Java 17.0.16 runtime.
- Forced `--rerun-tasks` release Kotlin compilation for `flutter_timezone`,
  `share_plus`, and `shared_preferences_android`: 22 tasks executed, successful
  in 42 seconds. No daemon-compilation failure or cross-drive error in this log.
- Final `flutter build apk --release --no-pub`: passed in 29.1 seconds,
  `build/app/outputs/flutter-apk/app-release.apk` (63.1 MB). Final log contains
  no old Flutter minimum-version warnings or cross-drive compiler failures.
- Additional logs: `build/toolchain-kotlin-recompile.log`,
  `build/toolchain-effective-versions.log`, `build/toolchain-release-final.log`.

This is build/toolchain verification, not a full app regression test or Play
readiness certification. Existing release signing remains unchanged. Feature
implementation can proceed on this baseline; full built-in Kotlin migration
remains a separately scoped SDK/plugin upgrade.
