# Refinement work checkpoint

Updated: 11 September 2026. Provider model-test bug prioritized by the user.

Current fix: [provider model-test verification](provider_model_test_fix.md).
The primary plan now checks off individually verified scoring and provider-test
substeps. Broad partial requirements remain unchecked.

Interrupted resume slice: shared `resumeQuizSet` loading is wired into Dashboard
and Library; failed resume no longer falls through to starting a new attempt,
and cancelling new-attempt settings no longer deletes saved progress. Its
provider/storage regression passed on 11 September. UI cancellation/route tests
and Home integration remain pending; do not mark shared resume complete yet.

## Implemented and focused-tested before the pause

- Provider credential clearing on endpoint/provider changes, stale test-result rejection,
  HTTPS-only base URLs, no automatic authenticated redirects, capability-shape handling,
  malformed catalog rejection, bounded pagination.
- Explicit question types, per-question selection/scoring, best-of-five 1/0 scoring,
  true/false completeness, partial-answer-safe scoring, separate position/completion.
- Actual score maximum and scoring version in history; legacy metadata migration.
- Practice elapsed-time pause/resume; Exam deadline and expiry answer locking;
  original duration/deadline persistence and cold-start expired-Exam tests.
- Timer setup/controls and lifecycle wiring added; device verification still pending.

Focused scoring/provider state suite: 44 passed. Timer/storage suite: 5 passed before
the next submission slice. Static analysis: no errors; existing warnings/lints remain.

## Submission and resume progress

The earlier interrupted slice is now implemented: attempt IDs, immutable answer
access, persisted question snapshots, idempotent transactional finalization,
saved-progress retirement, and a guard against late saves resurrecting completed
attempts. ResultsScreen no longer owns history writes. Focused migration and
repeated-submission tests pass; this is not completion of the entire lifecycle phase.

Two additional regressions were reproduced and fixed on 10 September:

- Starting an imported quiz now clears the previous library set identity; it
  cannot accidentally save progress/history against that unrelated set.
- Resuming uses the saved question snapshot's length for the current position,
  rather than the edited source quiz's length.

Both tests failed before their fixes and pass afterward. Current focused suite:
23 passing tests (`build/refinement-focused.log`). Full-suite and analysis results
are recorded separately; focused success is not a green whole-project release gate.
Full suite: 80 passed, 2 skipped, 36 failed/loading errors. Failures include
existing test files without `main`, compiler cascade errors, and widget
expectation/provider-fixture failures (`build/refinement-full-tests.log`). They
still need classification and repair; no claim that all 36 are harmless.
Analysis: no errors/warnings, 82 informational lint items.
Release APK with these two fixes built successfully (exit 0, 130.5 seconds,
63.8 MB; `build/refinement-release.log`). It remains debug-signed for testing,
not signed/configured for Play submission.

## Emulator and toolchain

See [migration verification](kotlin_migration_verification.md) for the pinned
Flutter/AGP/Kotlin toolchain and release-build evidence.

Medium Phone showed a black app surface despite successful activity startup.
It was closed without wiping data. The same release APK renders Home and the
drawer on `kiwi_tester` (Pixel 8a, API 36, Play Store image), cold-booted without
loading a snapshot. A transient Android System UI boot warning cleared after
Wait. Screenshot evidence: `build/emulator-check.png`, `build/pixel-ready.png`.
This is an emulator-specific workaround, not proof of a particular GPU root
cause or proof that all physical devices render correctly.

## Remaining scope

Complete submission/lifecycle/autosave/shared resume and failure recovery; then follow
the primary plan for library organization, AI trust/review, visual exploration,
study tools, monetization and production release gates. No whole-plan completion,
Play readiness, or production signing is claimed. No commits were made because the
workspace includes extensive pre-existing changes mixed with current work.

Next correctness slice: serialized autosave and shared resume loading from
Home/Dashboard/Library, with failure visibility and safe route/back behavior.
Also cover reset/finalization concurrency and malformed-progress atomic loading.

The user confirmed best-of-five 1/0 scoring and Practice background pause versus
Exam continuing through background/Save & Exit. These decisions need no reconfirmation.
