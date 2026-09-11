# Flutter Components & State

Project-local implementation guidance for UI code.

## Widget structure
- Prefer small `StatelessWidget`s for static/pure presentation.
- Use `StatefulWidget` only for real local lifecycle/transient UI state.
- Extract complex rows/cards/selectors rather than allowing one screen `build` method to become the design system.
- Prefer composition over inheritance.
- Use `const` constructors/widgets where values are compile-time constants.
- Avoid deep widget nesting when an extracted semantic component would make intent clearer.

## Shared vs local state
- Shared provider/settings state belongs in the existing state-management layer, not duplicated in screen-local variables.
- Use local `setState` for transient concerns such as search text, expansion, temporary draft selection, busy state, or dialog state.
- When UI must instantly reflect provider/model deletion or activation, observe the shared provider with `context.watch`, `Selector`, or a narrowly scoped `Consumer`.
- Keep rebuild scope minimal: do not watch a large provider high in the widget tree when only a selector row needs the update.
- Never call `setState` from `build`.

## Lists
- Use `ListView.builder`/slivers for large or fetched catalogs.
- Use stable `ValueKey`s for dynamic/stateful rows when identity matters.
- Avoid nested unconstrained `ListView`s. If a list lives inside another scroll view, give it intentional constraints or restructure with slivers.
- Saved items should remain compact; large provider catalogs should be search/discovery surfaces, not permanently expanded settings lists.

## Forms
- Use `Form` + explicit labels + inline validation.
- Keep helper/error text near the field it explains.
- Disable or show busy feedback while a submit/network action is in progress.
- Dispose `TextEditingController`s and other resources.
- Do not clear credentials or user input merely because another independent selection changed unless the underlying endpoint/credential identity truly changed.

## Async UI
Represent all relevant states: initial, loading, success, empty, error, stale/unavailable, and retry where useful. A spinner with no context is not enough for long provider/catalog operations.

## Theming
- Pull colors/text styles from `Theme.of(context)` and `ColorScheme`.
- Avoid hardcoded colors inside screens unless they are true semantic/design tokens and work in both themes.
- Selected, verified, warning, destructive, and disabled states need consistent treatment across screens.
- Prefer standard Material controls first; customize when it materially improves the task, not just for novelty.

## Performance
- Use const/static subtrees when practical.
- Localize consumers/rebuilds.
- Measure before adding exotic optimization.
- Avoid adding packages just to replace simple Flutter/Material behavior.
