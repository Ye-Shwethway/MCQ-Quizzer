# DEDAL Status

State: ACTIVE IMPLEMENTATION. Roadmap architecture challenge is closed. Owner accepted APK #32 Results overflow repair and approved continued DEDAL-only implementation while Codex is unavailable.
Branch: `dedal/history-repair-v1`
Stable main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Accepted phone checkpoints:
- Home responsive repair accepted after APK #30.
- Results narrow-phone overflow repair accepted after APK #32.
- P1Q compact-stem overlay is accepted on phone: no bounce feeling.
- Manual Upload narrow-phone overflow repair is accepted on phone.
- P1G true streaming core is accepted on phone after APK #47: confirmed stems now advance incrementally in real time.

Current bounded Library behavior:
- Library exposes AI Generated / Uploaded / Removed tabs.
- `Remove from Library` is reversible through `Restore to Library`.
- completed history is preserved.
- notes are preserved.
- incomplete saved progress is retired and is not resurrected on restore.
- removed sets remain exportable.
- permanent deletion is approved as a separate future action but remains gated behind P2a durable-history/FK-safe work.
- transitional markers remain `archived_ai_generated` / `archived_uploaded`; do not add more variants.

Small UI fixes accumulated in the current branch:
- Remove snackbar auto-dismisses after a short duration and is hidden immediately before route navigation.
- Manual Upload quiz-type selector is narrow-phone safe; selected labels are concise and explanatory text is shown separately.
- newly uploaded quizzes refresh into Library immediately on back navigation.

P1Q seamless compact-stem overlay:
- compact stem no longer inserts/removes layout height above the question viewport.
- it is a Stack overlay over the scroll viewport using opacity/slide animation.
- small hysteresis separates show/hide thresholds to reduce boundary chatter.
- Previous / Next / Go-to-question still reset scroll and compact-stem state.

P1G adaptive generation status:
- capability-aware model metadata resolver is wired.
- adaptive stems/request and output-token budget are wired.
- normalized recovery policy is wired for rate-limit, timeout, output/context pressure and malformed/truncated output.
- true provider streaming is implemented for profile adapters with non-streaming fallback.
- boundary-aware parser emits progress only after a complete valid question object is assembled.
- Owner phone test confirmed real-time `1/N -> 2/N -> ...` streaming progress.
- bounded concurrency is now capability-gated: unknown/small endpoints remain serial; suitable known-capability profiles may use at most 2 parallel requests.
- concurrent lanes preserve deterministic reassembly order, use local dedupe, refill only missing questions, and downgrade failed parallel work to serial recovery.
- NanoGPT subscription route remains conservative at concurrency 1.

Current phone checkpoint:
- this status commit intentionally carries `[apk]` to build the bounded-concurrency P1G checkpoint.
- compare generation time with APK #47 using the same provider/model/topic when possible.
- verify real-time streaming remains smooth while parallel work is active.
- verify final question count stays exact and no obvious duplicate surge appears.
- if a provider rate-limits or rejects the parallel path, generation should recover serially rather than fail the whole quiz.

Next after bounded-concurrency phone acceptance:
- finish any small P1G progress-label cleanup if needed, then close P1G.
- Owner chooses the next roadmap slice; do not start P2a automatically.

Do not merge to main until explicit Owner approval.
