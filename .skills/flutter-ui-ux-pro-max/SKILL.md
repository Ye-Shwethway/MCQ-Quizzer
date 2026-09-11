---
name: flutter-ui-ux-pro-max
description: Project-local Flutter/mobile UI quality guidance for MCQ Quizzer. Apply when designing, implementing, reviewing, or polishing screens, widgets, navigation, forms, dialogs, selectors, accessibility, responsive layout, theming, interaction states, and perceived UI quality. Skip for backend-only, data-only, or infrastructure work.
---

# Flutter UI/UX Pro Max — MCQ Quizzer

This is the project-local Flutter/mobile adaptation of Next Level Builder's UI/UX Pro Max guidance. It intentionally keeps the Flutter and native-mobile parts that matter to MCQ Quizzer instead of vendoring the full web-oriented dataset.

## When to use
Apply before and during any change that affects how the app looks, feels, moves, or is interacted with. Examples: Quiz Generation controls, AI-provider model selectors, settings cards, dialogs, lists, forms, navigation, dark/light mode, empty/loading/error states, accessibility, or responsive behavior.

Do not use it to justify unrelated refactors, new packages, or architecture churn. Existing repository decisions and Owner instructions win.

## Priority order
1. Accessibility and readable semantics.
2. Touch target, feedback, and safe interaction.
3. Correct state behavior: loading, error, selected, active, disabled, empty.
4. Mobile layout and responsive constraints.
5. Visual hierarchy, spacing, typography, and theme consistency.
6. Flutter implementation quality and rebuild scope.
7. Animation only when it clarifies state or spatial continuity.

## MCQ Quizzer defaults
- Phone-first Material 3 UI; tablets/landscape must remain usable.
- Prefer `ThemeData`, `ColorScheme`, and existing typography over screen-local hardcoded styling.
- Use a 4/8dp spacing rhythm. Typical page gutters 16dp; section gaps 12–24dp depending on hierarchy.
- Android tap targets should be at least 48x48dp even when the visible icon is smaller.
- Use Material/vector icons, not emoji as structural controls.
- Surface selected/active/verified/error state with more than color alone where practical.
- Avoid horizontal overflow and clipped labels at large system text sizes.
- Preserve safe areas and leave scroll clearance for bottom navigation/gesture areas and fixed CTAs.
- Prefer progressive disclosure: keep primary action clear; advanced detail should not dominate the first scan.
- A catalog/discovery list and a saved/active selection list are different UX concepts; do not visually conflate them.

## Flutter implementation rules
Read `flutter-components.md` for widget/state/list/theming rules, `mobile-layout.md` for layout and phone ergonomics, `accessibility.md` for semantics and text scaling, and `interaction-patterns.md` for selectors/dialogs/feedback.

Key rules:
- Keep widgets small and compositional; extract repeated or complex UI from large `build` methods.
- Use `const` where practical.
- Keep business/shared state in the existing provider/state layer; local `setState` is for local transient UI state.
- Use `context.watch`, `Consumer`, or `Selector` only around the subtree that needs live shared-state updates.
- Long/dynamic lists use lazy builders and stable keys where state can move.
- Dispose controllers/subscriptions.
- Never call `setState` during build.
- Every async path needs visible loading/error/success or disabled feedback appropriate to the action.

## UI change workflow
Before coding:
1. Identify the primary user task on this screen.
2. Identify source-of-truth state and which parts must update live.
3. Decide primary/secondary/destructive actions and their hierarchy.
4. Check small-phone width, large text, light/dark mode, and delete/error/empty states.

While coding:
1. Reuse existing design language unless there is a clear usability problem.
2. Make state transitions explicit and predictable.
3. Keep interactive regions >=48dp on Android.
4. Avoid nesting scrollables unless the behavior is deliberate.
5. Prefer semantic Material controls over custom gesture-only surfaces.

Before a test-worthy checkpoint:
- no overflow on a narrow phone;
- touch targets and tooltips/semantic labels are sensible;
- large text does not lose critical actions;
- light/dark states remain distinguishable;
- loading/error/empty/disabled/selected/active states are represented;
- no stale UI after shared state changes;
- `flutter analyze` and targeted/widget tests are green before `[apk]`.

## Upstream attribution
Adapted from `nextlevelbuilder/ui-ux-pro-max-skill`, particularly its Flutter stack guidance and native/mobile professional rules. Upstream is MIT licensed. See `UPSTREAM_LICENSE.md`.
