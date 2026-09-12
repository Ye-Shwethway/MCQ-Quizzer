# DEDAL Status

State: active Owner-approved quiz-session UX refinement slice; not ready for `main` until Owner manual validation.
Branch: `dedal/quiz-session-polish`
Baseline main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
Current app commit: `c4477e47098fad1fc0b6a7b59435d3275be6ee5c`
Current task: polish long-stem quiz behavior without changing answer/scoring logic.

Implemented in this slice:
- compact stem now appears only when the original stem row has fully left the scroll viewport instead of using a fixed `>120` offset
- compact pane is slightly tighter and labels the tap action as full-stem access
- A–E separators remain between branches but no divider is rendered after the final branch
- Previous / Next / Go-to-question scroll-reset behavior remains unchanged

Ownership:
- DEDAL owns user-facing product/UX work, especially provider/generation/library/in-quiz behavior
- Codex owns Android/Play release-readiness and PC-side local build/emulator validation
- Codex may pull this branch for build/test operation but should not silently edit DEDAL-owned source files

Validation policy:
- Agent Fast CI analyzer remains the automated gate for this branch
- no GitHub APK artifact is requested for this iteration
- after analyzer success, Codex should pull the exact DEDAL commit, build/run locally on the PC, install/launch on the emulator, and hand the emulator to the Owner for manual testing
- real-phone APK remains a milestone/pre-merge acceptance checkpoint, not every-iteration output

Next: complete analyzer validation, hand exact branch/commit to Codex for local emulator build, then apply only targeted Owner feedback before proposing merge.
