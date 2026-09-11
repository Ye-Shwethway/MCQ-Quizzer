# Windows Gradle task discovery: cross-drive build directories

Date: 6 September 2026

## Reproduction and cause

The VS Code Gradle import failed while creating
`:flutter_plugin_android_lifecycle:compileDebugUnitTestSources`.
The same failure reproduced outside VS Code with Java 17:

```powershell
cd android
.\gradlew.bat :flutter_plugin_android_lifecycle:compileDebugUnitTestSources --dry-run --stacktrace --console=plain
```

Before the fix: `BUILD FAILED`; `GenerateTestConfig.TestConfigInputs` called
Kotlin's `toRelativeString` with plugin source on `C:` and relocated build
output on `D:`. Windows cannot construct a relative path across these roots.
This is task-creation failure, not a failing application unit test.

## Fix

`android/build.gradle.kts` retains Flutter's normal shared build directory
for projects whose source and output filesystem roots match. Cross-root
subprojects instead build under their own source directory at
`build/flutter-workspaces/<workspace UUID>`.

The deterministic workspace ID prevents two applications using the same
cached plugin from sharing output. No drive letters, username, or individual
plugin version is hardcoded. App output remains `build/app`, so Flutter's
APK discovery continues to work. Plugin sources and Pub configuration are
unchanged; only their generated output location changes.

Release verification exposed a related KGP incremental-cache failure:
plugin Kotlin sources on `C:` were relativized against the root app on `D:`.
The build recovered via fallback compilation. Incremental Kotlin compilation
is now disabled only for cross-root plugin tasks to avoid that failure;
compilation, tests, the Kotlin daemon, and same-root incremental builds remain
enabled. The tradeoff is fuller recompilation when those plugins change.

Follow-up: a fresh compiler rebuild during the toolchain upgrade showed that
the per-task override was insufficient across KGP versions/classpaths. It has
been replaced with `kotlin.incremental=false` in project Gradle properties.
This is broader (all project Kotlin compilation) but uses Kotlin's documented
configuration. See the toolchain research for verification and tradeoffs.

Cross-root builds require write access to the plugin cache, as normal local
Gradle builds do. Their generated files are outside the app's top-level
build directory: `flutter clean` alone does not remove those files. Use the
affected subproject's Gradle `clean` task if those outputs need cleaning;
do not delete the shared Pub cache or plugin source directories.

## Regression checks

- The exact dry-run command above now succeeds and realizes the task graph.
- `./gradlew.bat tasks --all --console=plain` checks broader task discovery
  used during IDE import. It does not prove the VS Code extension has refreshed.
- `flutter build apk --release --no-pub` checks release packaging; a dry run
  alone is not an application build or execution of plugin unit tests.

After this change, refresh Gradle projects in VS Code (or reload the window)
if the extension is still showing its previous failed import.

Verified after the fix: original task dry-run passed (3 seconds), full task
discovery passed, and release APK packaging passed (63.1 MB). The final release
log contains neither `different roots` nor `Daemon compilation failed`.
The resulting APK was installed with `adb install -r` and launched on
Medium Phone API 36. No app data was deliberately cleared. Logs are retained
in `build/gradle-task-regression.log`, `build/gradle-task-discovery.log`, and
`build/gradle-release-verification.log`.

## Separate follow-up

Update, 6 September: the project version declarations have since been upgraded
to Gradle 8.14.3 / AGP 8.11.1 / KGP 2.2.20. See
[toolchain research](android_toolchain_research.md) for remaining SDK/plugin
migration prerequisites. The paragraph below records the original baseline.

Flutter's warnings about Gradle 8.12, AGP 8.7.3, Kotlin 2.1.0, and future
built-in Kotlin migration were not the cause of this failure. They remain
visible and require a coordinated toolchain/plugin migration under the
production refinement plan. No validation bypass flag or test disabling
was added. Release-mode packaging still uses the existing signing setup;
production Play signing is a separate unfinished release requirement.
