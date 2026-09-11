# Built-in Kotlin migration readiness

Implementation status and verification results are now tracked in
[Kotlin migration verification](kotlin_migration_verification.md). The research
below describes the pre-migration state, not the current configuration.

Checked 2026-09-07. Research only; no SDK, dependency, or build configuration changes made by this investigation.

## Conclusion

A coordinated migration is feasible, but it is not a one-line warning removal. The installed Flutter 3.44 toolchain cannot enable built-in Kotlin: Flutter's official guide requires **Flutter 3.47+ and AGP 9+**. All three named packages now have publisher releases supporting AGP 9/built-in Kotlin. Verification effort includes dependency resolution, Gradle configuration, release compilation, and device smoke tests. [Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)

## Availability and constraints

| Component | Published evidence | Migration implication |
| --- | --- | --- |
| Flutter | Official 3.47.2 tag exists, dated August 26; docs reflect 3.47.2 | Select a pinned supported stable SDK, not a preview merely to silence warnings |
| AGP 9.0.x | Minimum Gradle 9.1.0, JDK 17, SDK Build Tools 36.0.0 | Existing Gradle 8.14.3 cannot serve as the AGP 9 wrapper |
| flutter_timezone | 5.1.0 adds AGP 9 support; 4.0 already required Java 17 | Upgrade and test timezone/reminder behavior; upgrading from pre-5 requires handling TimezoneInfo return values |
| share_plus | 13.2.0 adds built-in Kotlin; current published version 13.3.0 | Current requirements: Flutter >=3.38.1, Dart >=3.10, Java 17, AGP >=8.12.1, Gradle >=8.13; AGP 9 requirements supersede these floors |
| shared_preferences_android | 2.4.24 migrates to built-in Kotlin; current 2.4.28 | 2.4.24 required Flutter 3.44/Dart 3.12; 2.4.25 lowered the supported SDK floor to Flutter 3.38/Dart 3.10 |

Sources: [Flutter 3.47.2 tag](https://github.com/flutter/flutter/releases/tag/3.47.2), [AGP 9.0 compatibility](https://developer.android.com/build/releases/agp-9-0-0-release-notes), [timezone changelog](https://pub.dev/packages/flutter_timezone/changelog), [share changelog](https://pub.dev/packages/share_plus/changelog), [share requirements](https://pub.dev/packages/share_plus), [preferences changelog](https://pub.dev/packages/shared_preferences_android/changelog).

The official Windows release JSON endpoint returned `NoSuchKey` during direct HTTP checks, including a cache-busted retry. Therefore **Windows archive availability, archive checksum, and exact current-release metadata were not verified**. A GitHub release tag or documentation footer is not proof that a specific Windows SDK archive downloads successfully. The official stable branch's engine.version did match the engine identified by the 3.47.2 tag. Resolve archive acquisition before modifying this project's SDK selection. [SDK archive](https://docs.flutter.dev/install/archive), [attempted release metadata](https://storage.googleapis.com/flutter_infra_release/flutter/releases/releases_windows.json), [stable engine revision](https://raw.githubusercontent.com/flutter/flutter/stable/bin/internal/engine.version).

## Recommended execution boundary

1. Preserve existing feature work and capture a reproducible baseline; do not equate Gradle configuration success with a passing release build.
2. Acquire and verify a supported stable SDK side-by-side, pin it for this repository, and retain the existing shared SDK for other projects.
3. Upgrade the named dependencies and audit every resolved Android plugin, not just those in the current warning.
4. Migrate app/plugin application and compiler configuration following Flutter's guide; enable built-in Kotlin only with the supported SDK/AGP combination. Treat the new Android DSL as a separately verified compatibility change.
5. Run Gradle with all warnings exposed, distinguish project-owned deprecations from SDK/plugin-owned ones, and address causes rather than suppressing diagnostics.
6. Run analysis and tests, build the release APK, install/launch on the emulator, and smoke-test sharing, stored settings, timezone/reminders, and app startup. Document pinned versions and a repeatable build command.

This removes the identified migration debt once verified; no migration can guarantee compatibility with all future upstream releases.
