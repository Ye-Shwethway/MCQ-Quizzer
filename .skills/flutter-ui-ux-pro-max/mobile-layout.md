# Mobile Layout & Visual Hierarchy

## Phone-first layout
- Design for narrow Android phone widths first; verify larger phones, tablet widths, and landscape after the primary flow works.
- Prefer constraint-aware layouts (`Expanded`, `Flexible`, `Wrap`, `LayoutBuilder`) over fixed widths.
- Do not introduce horizontal scrolling for ordinary settings/forms.
- Respect SafeArea/system insets and keep tappable content clear of gesture/navigation regions.

## Spacing rhythm
Use a consistent 4/8dp rhythm rather than arbitrary gaps.
- 4–8dp: tight internal relationships.
- 12–16dp: normal control/card spacing.
- 20–24dp: section separation.
- 32dp+: major page hierarchy only.
Typical phone page horizontal gutter: 16dp unless the existing screen establishes another coherent token.

## Hierarchy
- Screen title → primary task/status → primary controls → secondary/advanced controls.
- The most frequent action should be easiest to find and reach.
- Do not give destructive or advanced actions equal visual weight to the primary action.
- Use cards/containers to group concepts, not every individual row.
- Keep saved/favorite/active items visually distinct from huge searchable catalogs.

## Text and truncation
- Allow important model/provider names to wrap when space permits rather than silently hiding identity behind ellipsis.
- Secondary IDs may truncate if the human-readable title remains clear and detail can be opened.
- Avoid relying on a one-line row if large system text makes the action unreachable.
- Keep helper copy concise; progressive disclosure is preferred for long explanations.

## Responsive controls
- Rows containing label + selector/action should be able to stack vertically on narrow widths or large text.
- Prefer `Wrap` for sets of status chips/actions that may overflow.
- For full-width primary mobile actions, give adequate height and spacing; avoid tiny side-by-side buttons when labels become cramped.
- Dialog content must remain readable and actions reachable at large text scale.

## Light/dark surfaces
- Preserve clear separation among background, card, selected state, and modal surfaces in both themes.
- Dividers/borders should not disappear in dark mode.
- Selection highlight must not reduce text/icon contrast.
