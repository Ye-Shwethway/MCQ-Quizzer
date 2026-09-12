# Quiz UX Refinement — AI-first tabs and smart question stem

Updated: 2026-09-12
Current branch: `dedal/history-repair-v1`
Stable baseline: `main` at `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
Current app version: `1.0.0+4`

## Owner-accepted behavior so far

The Owner manually accepted the current quiz-session refinements and, on APK #32, confirmed that the previously observed Quiz Results narrow-phone overflow is gone.

Accepted quiz-session behavior includes:
- AI Generation first / Manual Upload second in generation navigation
- AI Generated first / Uploaded second in Library navigation
- compact question stem appears only after the original full stem leaves the viewport
- compact stem can be tapped to open the full stem
- branch separators appear only between branches
- question navigation resets scroll/compact state
- narrow-phone result/answer summaries wrap rather than overflow
- APK #32 Results layout has no observed RenderFlex overflow on the Owner's real phone

## Smart question-stem pane — current implementation

Current code keeps the full stem in normal scroll content and inserts/removes a compact Material card above the scroll viewport through an `AnimatedSwitcher` when the original stem crosses the viewport boundary.

The trigger itself is semantically correct: it observes the actual rendered stem and viewport instead of using a guessed fixed scroll offset.

However, real-phone testing exposed a remaining polish defect:

> When the compact card appears or disappears, the scroll content has a subtle backward/forward bounce instead of feeling seamless.

### Root cause

The compact card currently participates in the parent `Column` layout. Showing it consumes vertical height and therefore changes the height/top position of the `Expanded` scroll viewport while the `ScrollController` offset remains the same. Hiding it reverses that geometry change.

This produces a visible content jump even though the user's finger/scroll offset did not intentionally move backward.

The problem is therefore **layout geometry**, not ordinary scroll physics.

## Approved seamless-overlay refinement

The next implementation should keep the scroll viewport geometry stable.

Preferred structure:
- keep the question scroll view at a constant layout size
- wrap the scroll region in a `Stack`
- render the compact stem as a pinned `Positioned`/overlay layer above the scroll content rather than inserting/removing it from the main `Column`
- use a lightweight `AnimatedOpacity` plus very small `SlideTransition` (or equivalent transform that does not consume layout space)
- preserve the existing tap-to-expand full-stem behavior

The overlay animation must not move or resize the underlying scroll viewport.

### Threshold hysteresis

Avoid rapid show/hide chatter exactly at the boundary.

Use a small hysteresis band, approximately 4–8 logical pixels:
- show only after the original stem has clearly passed above the viewport threshold
- hide only after it has clearly re-entered past the opposite threshold

This should prevent flicker when a slow finger drag, overscroll, or fractional layout rounding hovers at the transition point.

## Interaction requirements

- the compact overlay must not steal scrolling gestures from the underlying content except for its intentional tap target
- tap target remains accessible and large enough for normal touch use
- text remains a short two-line preview
- large text scale must not cause clipping/overflow; the overlay may grow within a bounded readable design if necessary
- screen-reader semantics should not expose the same stem twice in a confusing way while both full and compact versions are technically present
- reduced-motion settings should avoid unnecessary movement; opacity-only fallback is acceptable

## Acceptance checklist for the seamless refinement

1. Scroll slowly downward through the stem boundary: compact pane appears without any backward content jump.
2. Reverse direction slowly: compact pane disappears without a forward/backward snap.
3. Hover/drag around the threshold: no rapid flicker.
4. Fling through the boundary: no visible scroll-offset correction or bounce introduced by the compact pane.
5. Tap compact pane: full-stem overlay still opens correctly.
6. Previous / Next / Go-to-question: scroll resets to top and compact state is cleared for the new question.
7. Short and long clinical stems both behave correctly.
8. Large text scale does not create a new overflow.
9. Existing answer selection, timer, notes, Show Correct Answers, save/exit, and result navigation remain unchanged.

## Validation policy

Normal loop remains:

`DEDAL implementation -> analyzer -> Codex local build when available OR meaningful APK -> Owner real-phone test -> targeted fix`

Do not restore a broad historical test suite as a delivery gate. Add a focused regression check only if it directly protects this observed geometry bug without slowing normal delivery.
