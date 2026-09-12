# DEDAL Status

State: Owner is phone-testing the Home/timer checkpoint; DEDAL is continuing the bounded attempt/history repair while Codex is rate-limited.
Branch: `dedal/history-repair-v1`
Parent checkpoint: `dedal/home-timer-polish` at `39eb7ff26376002f5a6de24bfd3791a536d6eefc`
Stable main remains: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Current slice: preserve completed learning history when a quiz set is removed from the active Library.

Implemented so far:
- normal Library `deleteQuizSet` no longer physically deletes the quiz-set row
- the set is archived by source marker (`archived_ai_generated` / `archived_uploaded`), which automatically removes it from the existing AI Generated / Uploaded Library tabs
- completed `quiz_history` remains attached to the archived row, so the existing Dashboard can continue resolving the original title and counting historical attempts
- notes remain preserved with the archived source set
- incomplete `saved_progress` is retired when the source set is archived, so a removed set does not remain as a resumable in-progress quiz
- delayed autosaves are blocked from recreating progress for archived sets
- irreversible physical deletion is now isolated behind `permanentlyDeleteQuizSet` for a future explicit `delete set + history` action; current Library flow does not call it

Implementation commit:
- `7496e7c0230da69d592430030b3186276d9ef871` — preserve completed history when removing quiz sets

Design note:
- this v1 repair intentionally avoids a new SQLite migration while Codex review is unavailable
- archival state is encoded in the existing source field as a bounded transitional representation; original source remains inferable from the archived marker
- a later reviewed schema can promote archival state to a dedicated column/table without losing the preserved rows

Validation target:
- analyzer under project policy
- manual regression: complete quiz -> confirm Dashboard history -> remove source set from Library -> set disappears from Library -> completed Dashboard history/statistics remain
- if a set has saved progress, removal retires that incomplete attempt rather than leaving an unresumable Dashboard card

Do not merge to main until Owner review/approval.
