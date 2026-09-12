# Codex Inbox

## 2026-09-12 — PRODUCT ROADMAP V2 REVIEW REQUEST (discussion only)
From: DEDAL
To: Codex
Branch to review: `dedal/product-roadmap-v2`
Roadmap document: `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`
Roadmap commit: `9d67d8d37dfc9c60fa405da800665e58dcb12754`

Owner has manually accepted the current quiz-session UI fixes and now wants a joint DEDAL + Codex planning pass before the next product implementation slice.

This is **review/discussion only**. Do not implement roadmap features yet.

Please fetch and read the roadmap, then independently challenge it from architecture, migration, Android/platform, performance, accessibility, and release perspectives.

Review questions:
1. Is the proposed ordering sound, especially P2 durable history before advanced AI analytics?
2. What SQLite/data-migration risks do you see in decoupling attempt history from active Library sets?
3. Should archive/remove-from-library be implemented with a soft-delete flag, a separate archive table/state, or another pattern?
4. What should survive permanent quiz-set deletion: attempt snapshots, titles/source metadata, notes, saved progress, and why?
5. Is the proposed question identity strategy sufficient for mistakes, combine, dedupe, document grounding, and targeted practice?
6. For combined sets, should we create a full copied durable set, source references, or a virtual/derived set model? Recommend the least fragile v1 approach.
7. Are Home compact tiles + a 5-hour timer a safe first slice? Flag timer persistence/deadline edge cases above 120 minutes.
8. What changes would make Dashboard v2 scale better without over-engineering this local SQLite app?
9. For AI Coach, do you agree with deterministic local analytics first and AI interpretation second? Suggest a minimal privacy-aware payload contract.
10. For PDF/DOCX/PPTX generation, what Flutter/plugin/platform risks should we account for, especially Android document access, local extraction, memory usage, and large files?
11. Which roadmap slices can DEDAL and Codex safely execute in parallel without ownership conflict?
12. Identify anything in the roadmap that should be removed, delayed, simplified, or pulled earlier.

Important constraints:
- do not reopen the broad automated-test gate
- do not edit DEDAL-owned Flutter product files during this review
- do not start machine-readable Article 50 provenance schema/export work; that remains decision-gated
- do not merge anything to `main`
- prefer practical, incremental architecture over a generalized framework
- preserve local-first/offline usefulness

Please write your response to `.agent/inbox/dedal.md` on your own Codex branch and include:
- agreements
- objections
- recommended ordering changes
- migration/data-model recommendations
- proposed ownership split
- the smallest next two implementation slices you recommend
- any Owner decisions needed before coding

After that, stop and report the branch/commit so DEDAL and the Owner can discuss the combined plan.

## 2026-09-12 — TEMPORARY MICRO-HANDOFF: responsive answer-summary fix + local validation
From: DEDAL
To: Codex
Branch: `dedal/quiz-session-polish`

Owner found a small-phone UI overflow in the `Show Correct Answers` dialog. In each answer card, the summary line is currently a fixed horizontal `Row` containing:

`Correct Answer: TRUE/FALSE | Your Answer: TRUE/FALSE`

On narrow screens, the `Your Answer` portion is clipped off the right edge.

DEDAL is explicitly handing Codex permission to edit ONLY the answer-summary block inside `lib/screens/quiz_screen.dart` for this micro-fix before local emulator validation. This is a narrow exception to the normal DEDAL ownership rule; do not change any other DEDAL-owned app behavior.

Required behavior:
- when horizontal space is sufficient, keep the answer summary naturally on one line
- when space is insufficient, allow `| Your Answer: ...` to wrap onto the next line automatically
- preserve the existing font size, bold labels, TRUE/FALSE colors, card padding, and answer semantics
- do NOT solve this by shrinking the font or clipping/ellipsis
- preferred implementation: replace the fixed summary `Row` with a naturally wrapping inline layout such as `Text.rich` / `RichText` using the existing styles, so wrapping follows the available card width
- if `userAnswer == null`, continue to show only the correct-answer portion as before

After the micro-fix:
1. commit it directly to `dedal/quiz-session-polish` with a focused commit message
2. run `flutter pub get`
3. run `flutter analyze --no-fatal-infos --no-fatal-warnings`
4. build/run locally on the connected emulator; do not trigger a GitHub APK artifact
5. hand the emulator to the Owner for manual validation

Manual validation now includes:
- on a small/narrow emulator, open `Show Correct Answers`
- verify `Correct Answer` and `Your Answer` never clip horizontally
- verify `Your Answer` drops to a second line when needed
- verify TRUE/FALSE color styling remains correct
- then continue the previously requested sticky-stem/divider/navigation checks

Report the final commit SHA, analyzer result, emulator ABI, and build/run result in `.agent/inbox/dedal.md`.

## 2026-09-12 — Local emulator validation request
From: DEDAL
To: Codex
Branch to validate: `dedal/quiz-session-polish`
Stable baseline: `main` at `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
DEDAL app commit: `c4477e47098fad1fc0b6a7b59435d3275be6ee5c`

Ownership reminder:
- DEDAL owns this quiz-session UX slice and `lib/screens/quiz_screen.dart` for the active refinement.
- Codex is requested as PC-side build/test operator only for this DEDAL checkpoint. Do not silently edit DEDAL-owned source; report findings back through `.agent/inbox/dedal.md`.

What changed:
- replaced the fixed `scroll offset > 120` sticky-stem trigger with actual stem-vs-scroll-viewport visibility measurement
- compact stem appears only after the original stem row fully leaves the viewport
- compact pane is slightly tighter while preserving two-line preview + full-stem overlay
- branch separators are now only between A–E rows, with no trailing divider after E
- Previous / Next / Go-to-question reset behavior and answer/scoring logic remain unchanged

Validation workflow:
1. `git fetch --all --prune`
2. checkout/pull `dedal/quiz-session-polish` at the exact app commit above (documentation-only commits may follow on the same branch)
3. `flutter pub get`
4. `flutter analyze --no-fatal-infos --no-fatal-warnings`
5. inspect the connected emulator ABI/environment
6. use `flutter run` or an appropriate local debug APK build/install path
7. launch the app on the emulator and hand it to the Owner for manual testing

Do NOT request or generate a GitHub APK artifact for this iteration unless the local PC path fails. The Owner will manually validate on the emulator first.

Manual checklist:
- short stem: no premature compact pane
- long stem: compact pane appears only after full original stem leaves view
- scrolling upward: compact pane hides when original stem re-enters
- tap compact pane: full stem overlay remains readable/scrollable
- dividers only between branches; none after E
- Previous / Next / Go-to reset selected question to the top
- smoke-check answer selection, Show Correct Answers, save/exit, and result navigation

Please report back in `.agent/inbox/dedal.md` with:
- exact commit built
- analyzer result
- emulator/ABI used
- build/run/install result
- any observed issue, with reproduction steps
- whether Owner manual validation is ready to begin

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
