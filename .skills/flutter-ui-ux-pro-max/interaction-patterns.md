# Interaction Patterns

## Selection vs activation
Do not collapse discovery, selection, saving, and activation into one ambiguous tap.
- Available catalog = discovery.
- Saved model = curated reusable choice.
- Selected model = current UI focus/draft choice.
- Active model = persisted model used for generation.
Make active state obvious. Do not silently choose a new active model after deletion.

## Quick selectors
For frequently changed options such as the AI model:
- show current provider + human-readable model name in the collapsed control;
- list only relevant saved/verified choices, not the full provider catalog;
- group by provider when more than one provider contributes choices;
- update live from shared source-of-truth state;
- if the chosen model disappears, switch to an explicit `Choose a model`/not-ready state;
- disable/guard the dependent primary action until a valid choice exists;
- keep a clear path to Manage/Add models without mixing the huge catalog into the quick selector.

## Destructive actions
- Use confirmation when deleting/removing an active or consequential item.
- State the consequence plainly.
- Cancel is safe/default; destructive action is visually distinct.
- Non-active saved-model removal may be lightweight if reversible/re-addable and consequence is obvious.
- Do not delete provider credentials/catalog just because a model binding is removed.

## Feedback
- Give immediate pressed feedback using Material interactions.
- Busy actions should disable duplicate submission and show progress.
- Success/failure messages should describe the result, not just `Success`/`Error`.
- Persistent state changes should also be visible in the resulting UI; do not rely only on a snackbar.

## Dialogs and menus
- Keep titles short and action-oriented.
- Place the most important explanatory consequence before secondary detail.
- Avoid long model catalogs in generic dropdowns when search/grouping is needed; use a bottom sheet/dialog/menu suited to the list size.
- Menus/selectors must remain navigable with large text and narrow width.

## Animation
- Use motion to clarify state/continuity, not decoration.
- Prefer implicit Flutter animations for simple state changes.
- Keep press/state feedback responsive and layout-stable.
- Avoid animation that moves surrounding controls or creates accidental taps.
- Respect reduced-motion preferences where meaningful motion is introduced.

## MCQ generation model-selector acceptance criteria
- Displays current provider and active/screen-selected saved model.
- Uses saved + verified models only.
- Reacts immediately to model/provider removal and activation changes.
- No silent fallback after active model removal.
- Generation is blocked with a helpful state when no valid model exists.
- Manage-model route remains accessible nearby but visually secondary.
- Works in light/dark mode, narrow width, and large text without hiding identity/actions.
