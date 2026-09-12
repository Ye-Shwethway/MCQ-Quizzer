# Quiz UX Refinement — AI-first tabs and smart question stem

Updated: 2026-09-11
Branch: `dedal/agent-work`
Phone checkpoint: `1.0.0+4`
App commit: `f04f31f2f483d9381dc82b9b0c503eb2799662a0`

## Owner-approved scope

This slice follows the successful manual phone test of the multi-model provider and AI quiz generation flow in `1.0.0+2`. The goal is refinement rather than a provider-model redesign.

### AI-first navigation
- Quiz Generation places **AI Generation** first and **Manual Upload** second.
- Quiz Library places **AI Generated** first and **Uploaded** second.
- The AI generation success action `View in Library` continues to navigate to `/library`; because the Library now defaults to the first AI tab, the generated quiz opens in the expected section instead of Uploaded.
- The Uploaded empty state routes directly to `/upload`, while the AI empty state routes to `/generation`.

### Smart question-stem pane
- The full question stem remains in the normal scroll content at the top of each question.
- Once the user scrolls beyond the stem area, a compact sticky pane appears above the branch-answer scroll region.
- The compact pane is intentionally small: question number, a two-line stem preview, and a tap-to-expand affordance.
- Tapping it opens a scrollable full-stem overlay so long clinical stems remain readable on small phones without permanently consuming the viewport.
- Moving Previous / Next / Go-to-question resets the question scroll to the top and hides the compact pane for the new question.

### Branch separation
- A subtle `outlineVariant` divider is inserted between branch answer rows.
- Existing answer controls and scoring behavior are not redesigned in this slice.
- The goal is clearer A–E visual grouping without turning every branch into a heavy card.

## Validation result
- Agent Fast CI run `34621565519`: **success** (`flutter analyze` only).
- Build Debug APK run `34621565611` (#19): **success**.
- Artifact `mcq-quizzer-debug-arm64-19`, id `10273356276`.
- Uploaded artifact archive size: 60,103,325 bytes.
- Extracted APK size: 95,848,949 bytes.

## Validation policy

This project is APK-first for meaningful UI slices. `Agent Fast CI` is analyze-only; `flutter test` is not a delivery gate. The acceptance loop is:

`implement -> flutter analyze -> arm64 debug APK -> Owner phone test -> targeted bug fix`

Automated tests may be added later only when they clearly protect a real bug/regression and do not slow feature delivery.

## Phone test checklist
1. Quiz Generation opens on AI Generation; Manual Upload is second.
2. Quiz Library opens on AI Generated; Uploaded is second.
3. Generate a quiz and tap View in Library; the new quiz is visible immediately in AI Generated.
4. Start a quiz with a long stem; scroll until the full stem leaves view and verify the compact stem pane appears.
5. Tap the compact pane and verify the full stem opens in a readable scrollable overlay.
6. Confirm branch rows are visually separated by thin dividers.
7. Move Previous / Next / Go-to-question and verify the new question returns to the top of its stem.
8. Smoke-check answer selection, Show Correct Answers, save/exit, and result navigation.
