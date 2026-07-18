# Design: align-diet-log-target-ui

## Context

Presentation-only alignment of the logging and target screens to the reviewed
mockup (screens ② and ③), following the Today alignment already shipped. Same
conventions: Chiikawa theme, `DietCategoryColors`, `ledgeShadow`, gen_l10n. No
controller/use-case/repository/backend change — the data each screen has is
enough. Reuses widgets built earlier: `PortionPills`, `PortionStepper`,
`CategoryProgressBar`.

## Goals / Non-Goals

**Goals**: dictionary rows with portion pills + heart + an All/Favorites tab; a
quantity card with basis + segmented unit toggle + stepper + preview math; a
carded target screen with category icons, a bonus note, and remaining bars.

**Non-Goals**: any behavior/data change (search results, favorites, quantity and
gram conversion, preview numbers, target save, remaining math stay identical);
new screens or data.

## Decisions

### D1 — Dictionary rows: pills + heart + explicit tab

Each dictionary row renders the food name plus `PortionPills(entry-equivalent
portions)` and a heart (♥/♡) favorite toggle (was a star `IconButton`). The
implicit "empty query → favorites" switch becomes an explicit segmented control
("All / Favorites ♥") above the search field; selecting Favorites shows the
favorites list, All shows search results. The
controller's `query`/`results`/`favorites` state is untouched — the tab only
chooses which existing list to show. The default landing tab is **Favorites** (as
today, so the initial screen isn't empty); the All tab shows search results and,
before any query, a search prompt — never a silently empty list.

### D2 — Quantity card: basis, segmented unit, stepper, preview math

- **Basis line**: derive "<unit> ＝ <portions>" from the selected item — take the
  **unit segment after `/` in the name** (e.g. `飯/1碗` → "1碗", `蛋/1個` → "1個"),
  never a hardcoded "碗", plus its non-zero portions (skip when it has none). Pure
  display.
- **Unit toggle**: replace the `use-grams` `Switch` with a segmented "碗 | 克"
  (`SegmentedButton`), the gram segment shown only when the item has base grams —
  same `useGrams` state, same mutual-exclusion.
- **Amount**: replace the quantity `TextField` with a stepper whose **value is
  itself editable** — the −/+ buttons adjust by 0.5, and tapping the number opens
  numeric entry — so any decimal (e.g. 1.25) stays reachable even for items with
  no base grams (no precision loss). Bound to the same quantity state. The
  **grams** field stays a numeric `TextField` (grams is an exact measured value).
- **Preview**: render the previewed portions as pills plus the "dictPortions ×
  quantity" math label (e.g. "4 × 1.5"), from the existing `controller.preview`.

### D3 — Target screen: cards, category icons, bonus note, remaining bars

Wrap the screen in two themed cards (rounded + 2px outline + `ledgeShadow`): a
"daily target" card holding the four category steppers, and a "today / remaining"
card. Each stepper gains a small category-color icon (rounded chip with 主/肉/果/菜)
— extend `PortionStepper` with an optional leading icon rather than duplicating
it. Add a non-editable, muted bonus note ("✳️ 運動後可加成份數（之後串運動模組）").
Replace the plain remaining rows with a per-category **remaining bar**: the bar
fills to `logged / effective` (like Today's `CategoryProgressBar`) but the row
still shows the **remaining** number (e.g. "3 剩"), not a "used of target" string.
Extend/wrap `CategoryProgressBar` to take a trailing remaining label instead of
its used/target text, so the "3 remaining" behavior and its test are preserved.

## Risks / Trade-offs

- **Tab vs current implicit switch** → keep the controller's list state as-is;
  the tab is a presentation selector, so search/favorite behavior can't regress.
- **Stepper for quantity vs free decimal** → the stepper's value is itself
  editable (tap to type a number); −/+ handle the common 0.5 steps, and typing
  reaches any decimal (1.25) even for items without base grams, so no precision
  is lost.
- **Extending `PortionStepper` with an icon** → optional param, default null, so
  the target-screen use adds an icon without changing existing call sites/tests.

## Open Questions

- None — all four alignments have a concrete mockup reference and reuse existing
  widgets.
