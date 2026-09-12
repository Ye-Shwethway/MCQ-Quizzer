# Quiz UX Refinement — AI-first tabs and smart question stem

Updated: 2026-09-12
Current branch: `dedal/quiz-session-polish`
Stable baseline: `main` at `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
Accepted phone checkpoint: `1.0.0+4`
Current refinement app commit: `c4477e47098fad1fc0b6a7b59435d3275be6ee5c`

## Previously Owner-approved scope

This line follows the successful manual validation of the multi-model provider and AI quiz generation flow. The goal remains refinement rather than a provider-model redesign.

### AI-first navigation
- Quiz Generation places **AI Generation** first and **Manual Upload** second.
- Quiz Library places **AI Generated** first and **Uploaded** second.
- The AI generation success action `View in Library` continues to navigate to `/library`; because the Library defaults to the first AI tab, the generated quiz opens in the expected section.
- The Uploaded empty state routes directly to `/upload`, while the AI empty state routes to `/generation`.

### Smart question-stem pane
- The full question stem remains in normal scroll content at the top of each question.
- The compact sticky pane now appears only after the original stem row has fully left the visible scroll viewport. The earlier fixed `offset > 120` trigger has been removed.
- The compact pane remains intentionally small: question number, two-line preview, and tap-to-open full stem.
- Tapping it opens a scrollable full-stem overlay so long clinical stems remain readable without permanently consuming the viewport.
- Moving Previous / Next / Go-to-question resets the question scroll to the top and hides the compact pane for the new question.

### Branch separation
- A subtle `outlineVariant` divider is inserted **between** branch answer rows.
- No trailing divider appears after the final E branch.
- Existing answer controls and scoring behavior are unchanged.

## Current validation policy

The dual-agent workflow now uses two validation levels:

`DEDAL implementation -> Agent Fast CI analyze -> Codex local PC build/run -> Owner emulator manual test -> targeted DEDAL fixes`

GitHub APK artifacts are reserved mainly for meaningful phone-test checkpoints, pre-merge/release-candidate checkpoints, or fallback when the PC/Codex path is unavailable. Real-phone APK testing remains milestone acceptance.

Broad historical test suites are not a delivery gate. Add targeted tests only when they clearly protect an observed regression.

## Emulator test checklist for this slice
1. Start a quiz with a short stem; confirm the compact pane does not appear prematurely.
2. Start a quiz with a long clinical stem and scroll slowly; confirm the compact pane appears only after the original stem row fully leaves the viewport.
3. Scroll slightly back upward; confirm the compact pane disappears when the original stem re-enters the viewport.
4. Tap the compact pane; verify the full stem opens in a readable scrollable overlay.
5. Confirm separators appear between A–E branches but not below the final branch.
6. Move Previous / Next / Go-to-question and verify the selected question returns to the top with compact state reset.
7. Smoke-check answer selection, Show Correct Answers, save/exit, and result navigation; scoring behavior should be unchanged.
