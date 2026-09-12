# Accessibility

Accessibility is part of UI correctness, not a later polish pass.

## Touch
- Android interactive targets should be at least 48x48dp. The visible icon may be smaller; expand the hit area.
- Keep neighboring targets separated enough to avoid accidental taps.
- Do not make swipe/gesture the only way to perform an important action.

## Semantics
- Prefer semantic Material buttons, fields, switches, radios, menus, and dialogs.
- Standalone icon buttons need meaningful `tooltip`/semantic labels.
- Decorative icons next to equivalent visible text should not create noisy duplicate announcements.
- Expose selected/active/verified/expanded state through visible text/iconography and semantics where applicable.
- Color alone must not carry critical state.

## Text scaling
- Support system text scaling; do not assume fixed text height.
- Avoid layouts that require one-line labels for critical controls.
- Verify important screens with large accessibility font settings.
- Use modern Flutter text scaling APIs when manual measurement/scaling is necessary; do not build new code around deprecated fixed scale-factor assumptions.

## Contrast
- Normal text should target at least 4.5:1 contrast against its surface.
- Meaningful non-text controls/icons should remain distinguishable against adjacent colors.
- Check selected, disabled, error, modal, and dark-mode states independently.

## Forms and errors
- Fields need persistent labels, not placeholder-only identification.
- Put validation/error messages near the affected field.
- Keep entered values after a failed submission unless clearing is required for security/correctness.
- Focus order should follow visual/task order.

## Dynamic state
- Loading, successful verification, failure, deletion, and unavailable/stale model states should be understandable without relying on transient snackbars alone.
- When a settings mutation removes an option used by another screen, the dependent screen must update to a safe, understandable state immediately.

## Manual checkpoint checks
For test-worthy UI checkpoints, verify TalkBack-relevant labels, large text, narrow width, light/dark mode, and destructive confirmation behavior on at least the primary changed flow.
