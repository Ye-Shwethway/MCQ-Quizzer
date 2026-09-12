# Codex Status

Updated: 2026-09-12 05:42 UTC

State: Owner-approved Android release foundation implemented and locally validated; awaiting Owner review. DEDAL-owned Flutter product behavior remains excluded.
Branch: `codex/android-release-foundation`
Synced main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Current stable checkpoint:
- Version `1.0.0+4` is the latest Owner-accepted phone checkpoint.
- Multi-model provider storage/editor, verified saved-model switching, quick selection, and selected-model AI generation are established behavior.
- Quiz Generation and Quiz Library are AI-first; generated-quiz Library navigation lands on AI Generated.
- Long quiz stems use a compact sticky preview and expandable full-stem overlay; A-E rows have thin separators; question navigation resets scroll to the top.
- Analyzer-only fast CI and meaningful arm64 debug APK/manual phone validation are the delivery gates; broad historical tests are not a delivery gate.

DEDAL ownership acknowledged:
- DEDAL's accepted line covers the multi-model provider flow, Quiz Generation/Library UX, and in-quiz sticky-stem/branch/navigation refinement.
- Codex will not edit those areas without explicit coordination.

Completed non-overlapping slice:
- Audited Android identity, manifests and merged release manifest, effective SDK/toolchain values, permissions/exported components, network/backup policy, release signing/R8/versioning, CI artifacts, ignored credential patterns, and current Google Play requirements.
- Wrote `docs/ANDROID_PLAY_RELEASE_READINESS_AUDIT.md` and supporting primary-source research at `docs/research/google_play_release_requirements_2026.md`.
- Confirmed current strengths: compile/target API 36, min API 24, pinned modern toolchain, HTTPS provider validation, active release R8, and no credential-like files in Git.
- Confirmed P0 launch blockers: placeholder `com.example` identity, debug release signing, no signed-AAB release gate, and incomplete privacy/Data Safety plus in-app AI-reporting operations.
- Existing stale local release APK passed 16 KB ZIP alignment and arm64 ELF segment-alignment inspection, but is debug-signed and reports version code 1 rather than source version code 4; a fresh signed AAB/runtime gate remains required.
- No package identity, signing, manifest, Gradle, CI, or Flutter behavior was changed. DEDAL-owned Flutter product files were read only where necessary to classify permission behavior.

Completed approved foundation implementation:
- Android identity/MainActivity now use `com.thorne.mcqquizzer` in commit `564b57d`; Play Console remains the authoritative registration check.
- Release artifacts require complete ignored `android/key.properties` or protected `MCQ_UPLOAD_*` environment inputs. Debug signing is no longer used for release, and no credential was created or committed.
- Explicit HTTPS-only network policy is active. Modern and legacy backup rules allow safe ordinary app data while excluding the known Flutter Secure Storage preferences/key/config files.
- Added release process/ledger and AI reporting/transparency requirements, plus official-source Article 50 research. Article 50(2) machine-readable provenance/marking across store/edit/export/share/re-import is an unresolved legal/technical EU release gate, not satisfied by a badge or disclaimer alone.
- DEDAL has the product handoff for disclosure, provenance preservation, non-authoritative wording, and in-app reporting; Codex did not edit Flutter product code or backend infrastructure.

Validation:
- `flutter pub get`: pass.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: pass with 85 existing nonfatal issues.
- Debug APK: pass; inspected package `com.thorne.mcqquizzer`, version `1.0.0+4`, min 24, target/compile 36, and merged manifest security attributes.
- Missing-signing release AAB check: expected fail with generic configuration guidance; no values printed.
- Connected Pixel 8: x86_64, 4 KB page size. No install was performed because the Owner was manually testing DEDAL's existing app.

Files owned for this slice: `android/**`, release/continuity documentation, release validation tooling, and `.agent/` coordination. No DEDAL-owned Flutter files.

Remaining external dependencies: Owner must confirm/register the package in Play Console, create and secure the upload key outside Git, supply final privacy/support/report URLs and operator details, confirm Play account verification/closed-test status, and obtain qualified EU review/approval of the Article 50 marking standard. Signed-AAB, backup/restore, and 16 KB runtime checks remain release-candidate gates.
