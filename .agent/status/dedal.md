# DEDAL Status

State: NEW-CHAT HANDOFF READY. Owner is downloading/testing APK #29. Current work remains bounded to the responsive Home repair plus attempt/history preservation; Codex is rate-limited.
Branch: `dedal/history-repair-v1`
Stable main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Latest phone-test checkpoint:
- commit `7bc46c5641dd55c87f62533c7c295f69c774c707`
- Build Debug APK run `34684036798` (#29): success
- artifact `mcq-quizzer-debug-arm64-29`, id `10294314335`

Current bounded work:
1. Responsive Home repair after real-phone RenderFlex overflow.
2. Preserve completed learning history when a quiz set is removed from the active Library.
3. Timer preset extension up to 5 hours remains part of the current phone checkpoint.

Responsive Home repair:
- rejected first design forced two narrow phone columns plus fixed height and overflowed
- phone layouts now use full-width compact horizontal feature cards
- two-column layout only on wide/tablet layouts >= 600 logical px
- card height is content-driven with compact minimum height
- fixed grid `mainAxisExtent` and vertical `Spacer` were removed
- text is not shrunk or clipped to hide layout errors
- Agent Fast CI run `34683926372`: success

Attempt/history repair:
- normal Library removal archives rather than physically deleting a set
- transitional markers: `archived_ai_generated` / `archived_uploaded`
- completed `quiz_history` and notes survive
- incomplete `saved_progress` is retired
- delayed autosave cannot resurrect progress for archived sets
- destructive physical deletion is isolated behind `permanentlyDeleteQuizSet`
- implementation commit `7496e7c0230da69d592430030b3186276d9ef871`

Important constraint:
The archive-marker approach is a bounded migration-free bridge while Codex is unavailable. Do not expand it into a new SQLite migration without Owner approval / pending Codex architecture review.

Continuity docs refreshed for the chat transition:
- `docs/continuity/CURRENT_CHECKPOINT.md`
- `docs/continuity/NEW_CHAT_BOOTSTRAP.md`

New-chat first action:
- confirm branch head from GitHub
- read the two continuity docs above
- ask Owner for APK #29 phone-test feedback before further implementation

If APK #29 Home is accepted, next minor refinement candidate is Library wording: replace destructive-looking `Delete` wording with `Remove from Library` and explicitly state completed history is preserved, then manually validate the history survival path.

Do not merge to main until explicit Owner approval.
