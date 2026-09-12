# DEDAL Status

State: ACTIVE IMPLEMENTATION. Roadmap architecture challenge is closed. Owner accepted APK #32 Results overflow repair and approved continued DEDAL-only implementation while Codex is unavailable.
Branch: `dedal/history-repair-v1`
Stable main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Accepted phone checkpoints:
- Home responsive repair accepted after APK #30.
- Results narrow-phone overflow repair accepted after APK #32.

Current bounded Library behavior:
- Library now exposes AI Generated / Uploaded / Removed tabs.
- `Remove from Library` is reversible through `Restore to Library`.
- completed history is preserved.
- notes are preserved.
- incomplete saved progress is retired and is not resurrected on restore.
- removed sets remain exportable.
- permanent deletion is approved as a separate future action but remains gated behind P2a durable-history/FK-safe work.
- transitional markers remain `archived_ai_generated` / `archived_uploaded`; do not add more variants.

Small UI fixes accumulated after APK #33:
- Remove snackbar now auto-dismisses after a short duration and is hidden immediately before route navigation.
- Manual Upload quiz-type selector is narrow-phone safe; selected labels are concise and explanatory text is shown separately.

P1Q seamless compact-stem overlay:
- implemented at commit `ce064d98e7045234514ab68d951ace5b318e6085`.
- compact stem no longer inserts/removes layout height above the question viewport.
- it is now a Stack overlay over the scroll viewport using opacity/slide animation.
- small hysteresis separates show/hide thresholds to reduce boundary chatter.
- Previous / Next / Go-to-question still reset scroll and compact-stem state.
- Agent Fast CI #27 succeeded.

Current worthy checkpoint:
- this docs commit intentionally carries `[apk]` to build a phone-test artifact containing:
  1. reversible Remove / Restore Library UX,
  2. short-lived/navigation-safe Restore snackbar,
  3. Manual Upload quiz-type overflow fix,
  4. P1Q seamless compact-stem overlay.

Phone acceptance targets:
- Remove -> Removed -> Restore works; completed Dashboard history remains.
- snackbar disappears automatically and never follows navigation.
- Manual Upload quiz-type field has no right overflow on the Owner's phone.
- compact stem appears only after the original stem leaves the viewport, does not cause backward/forward scroll bounce, hides smoothly when scrolling back, remains tappable for full stem, and resets correctly on question navigation.

Next planned slice after this checkpoint is accepted:
- P1G adaptive + streaming AI generation performance.
- capability-aware batch sizing instead of fixed 20-stem assumptions.
- bounded concurrency with automatic backoff on 429/limit errors.
- confirmed-question streaming progress (`Generating 1 / N...`) only after a complete question object parses/validates.
- preserve conservative fallback for unknown/free/small endpoints.

Do not start P2a automatically.
Do not merge to main until explicit Owner approval.
