# DEDAL Status

State: Owner found a real small-phone Home RenderFlex overflow during phone validation; DEDAL corrected the Home layout and is keeping the bounded attempt/history repair on the same test branch while Codex is rate-limited.
Branch: `dedal/history-repair-v1`
Parent checkpoint: `dedal/home-timer-polish` at `39eb7ff26376002f5a6de24bfd3791a536d6eefc`
Stable main remains: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Current bounded work:
1. responsive Home repair
2. preserve completed learning history when a quiz set is removed from the active Library

Responsive Home repair:
- the failed phone design forced two narrow columns at only 360 logical px and also imposed a fixed tile height; long title/subtitle content then exceeded the available vertical flex space
- phone layouts now use full-width compact horizontal feature cards rather than forcing two narrow cards side-by-side
- two-column Home layout is reserved for wide layouts (>= 600 logical px)
- fixed grid `mainAxisExtent` was removed; cards now size naturally to their text with only a compact minimum height
- removed the vertical `Spacer`/bottom-arrow structure that caused the fixed-height `Column` to overflow
- title, subtitle, icon, and trailing navigation affordance remain readable without text-size reduction or overflow suppression

Home repair commit:
- `1c35ccd22db416583b92d337feb5fd8a233a03c9` — constraint-safe responsive Home cards

Home repair validation:
- Agent Fast CI run `34683926372`: success
- phone checkpoint requested because Owner is actively testing on a narrow device

Attempt/history repair implemented so far:
- normal Library `deleteQuizSet` no longer physically deletes the quiz-set row
- the set is archived by source marker (`archived_ai_generated` / `archived_uploaded`), which removes it from the existing AI Generated / Uploaded Library tabs
- completed `quiz_history` remains attached to the archived row, so the Dashboard can continue resolving the original title and counting historical attempts
- notes remain preserved with the archived source set
- incomplete `saved_progress` is retired when the source set is archived
- delayed autosaves are blocked from recreating progress for archived sets
- irreversible physical deletion is isolated behind `permanentlyDeleteQuizSet`; current Library flow does not call it

Attempt/history implementation commit:
- `7496e7c0230da69d592430030b3186276d9ef871`

Design note:
- archive state currently uses the existing source field as a bounded transitional representation to avoid an unreviewed schema migration while Codex is unavailable
- Codex should later review promotion to dedicated `is_archived` / `archived_at` schema

Manual phone validation target:
- Home: no yellow/red RenderFlex overflow; two compact full-width cards fit comfortably on the phone screen; text remains readable
- Timer: 3h/4h/5h presets remain available
- History: complete quiz -> confirm Dashboard history -> remove source set -> set disappears from Library -> completed Dashboard history/statistics remain

Do not merge to main until Owner review/approval.
