## Context

See `proposal.md` — Why. Constraints that shape the approach:

- `CareTodaySlot` (used by Today, the overview summary card, and — via
  `CareHistoryDay.slots` — the history list) already carries both `doseQuantity` (`double`,
  always present) and `dose` (`String?`, medication-only). `CareSchedule` carries
  `doseQuantity`; the free-text `dose` lives on `CareItem`, not on its schedules.
- So no domain, application, infrastructure, or backend change is needed — every value the
  four screens must render is already loaded.
- `doseQuantity` has **no unit anywhere in the contract**. The backend never sends one and the
  form never asks for one.
- The four call sites live in one context (`lib/contexts/notifications/presentation/`), so the
  shared formatter belongs there, not in `lib/shared/`.
- `care_items_screen.dart` already has a private `_formatStock` that renders a `double` as an
  integer when it is whole — the dose quantity needs exactly the same rule.

## Goals / Non-Goals

**Goals:**

- One formatter, four call sites — the dose reads identically on every care screen.
- Keep the change presentation-only and additive: no signature change to any existing widget's
  constructor, no new state.

**Non-Goals:**

- Making the free-text `dose` available on non-medication items (the medication-only rule
  stands).
- Making `doseQuantity` editable anywhere it is not already editable.
- Unifying `_formatStock` and the dose quantity formatting into one exported number helper.

## Decisions

**D1 — `×N`, not a unit word.** The label renders the quantity as `×2`, not 「2 顆」/"2
tablets". A unit word would be fabricated data: the same field backs pills, rehab sessions and
radiotherapy visits, and nothing in the contract says which. `×` is unit-agnostic and reads the
same in both locales. *Alternative rejected:* a per-category unit lookup — it would still be a
guess, and would be wrong the first time a user records a liquid dose.

**D2 — A free function, not a widget.** `careDoseLabel(loc, doseQuantity, dose)` returns a
`String` and lives in a new
`lib/contexts/notifications/presentation/care_dose_label.dart`. A `String` composes into the
existing `Text(...)` subtitles at all four call sites without changing their layout, and is
directly unit-testable without pumping a widget. *Alternative rejected:* a `DoseLabel` widget —
it would have to be threaded into the history subtitle, which is one `Text` with time and
status in the same string.

**D3 — It takes `AppLocalizations`, not `BuildContext`.** The quantity string comes from the
new `careDoseQuantityValue` ARB key, so the function needs `loc`; every call site already has a
`loc` in scope. Taking `loc` keeps the unit test free of a widget pump beyond building a
localizations instance via `lookupAppLocalizations`.

**D4 — One new ARB key, `careDoseQuantityValue` (`×{quantity}`), placeholder typed as
`String`.** The Dart side formats the number (dropping a whole number's `.0`) and passes the
result in, rather than letting ICU number formatting decide — this keeps `×2` / `×0.5`
identical in both locales and matches the existing `careStockLabel` pattern, whose `{n}` is
likewise a pre-formatted string. The separator between quantity and free-text dose is the
literal `' · '` written in Dart, consistent with the other care summaries that already build
` · `-joined subtitles in code; it is punctuation, not translatable copy.

**D5 — Keep `_formatStock` where it is.** The new file gets its own private whole-number
formatter rather than exporting one and rewiring the stock label. Touching the stock label is
outside this change, and the duplicated line is a single expression. *Alternative considered:*
export a shared `formatCareQuantity` — worth doing if a third call site appears.

**D6 — Reminders list: `×N` per schedule, item `dose` on its own row.** A `CareItem` has many
schedules that may each take a different quantity, but only one free-text `dose`. Appending
the dose text to every schedule line would imply it varies per schedule; appending only the
quantity to each schedule summary and putting the item's `dose` on a separate row under the
schedules keeps the ownership visible. This is the one call site that does **not** pass both
arguments to `careDoseLabel` from the same object.

**D7 — Reversed after ship-gate review: dose display stays medication-only, everywhere.**
Originally this decision read "Today and the summary card lose the 'hide when dose is empty'
branch" — dropping the empty-dose guard so every slot, including non-medication ones, would
show `×N`. That was reversed during manual ship-gate review: `care_item_form.dart` wraps the
quantity field in `if (_isMedication)`, so a non-medication item's user never gets to set
`doseQuantity` — the value the backend sends for it is only ever the server-side default of 1.
Showing `×1` for a rehab/radiotherapy/custom slot would therefore present data the user never
entered as if they had entered it.

`careDoseLabel` instead takes a `CareCategory` parameter and returns `''` for anything other
than `CareCategory.medication`, before even formatting the quantity. All four call sites
(history slot row, reminders schedule/item lines, Today's slot row/focus card/done group, and
the overview summary card) pass the slot or item's category through, so a non-medication entry
shows no dose line at all — neither quantity nor free-text — while medication entries keep the
full `×N` / `×N · <dose>` behavior described above.

**D8 — Screen-reader label for the `×N` glyph, via a second ARB key.** `×2 · 5mg` read as bare
text by a screen reader collapses the multiplication sign into the following digit — "2 5mg"
with no indication `×` was ever there. A new `careDoseSemanticLabel` key (`Dose: {label}` /
`劑量:{label}`) wraps the rendered dose string for accessibility; each call site pairs
`Semantics(label: loc.careDoseSemanticLabel(doseLabel))` with `ExcludeSemantics` around the
visible `Text`, so the visual `×N` stays but the accessibility tree announces "Dose: ×2" instead
of the raw glyph. `care_items_screen.dart`'s combined schedule-summary-plus-quantity line
composes its own `Semantics(label: '$summary · ${loc.careDoseSemanticLabel(doseLabel)}')` for
the same reason, and the item-level free-text dose row gets the same treatment independently.

## Risks / Trade-offs

- **`×N` is opaque on a rehab or custom reminder** ("×1" next to a physio session says little)
  → accepted: it is honest, and it is what the user typed into the quantity field. Showing a
  guessed unit would be worse than showing none.
- **Today/overview rows that previously had no dose line now always have one, making cards
  taller** → the added line is a short, single-line label in the existing subtitle column; the
  widget tests for both screens cover the layout, and the reminders list already renders a
  variable number of subtitle lines.
- **Widget tests cannot see the real font**, so a green suite does not prove the longer
  subtitle still fits (see repo `CLAUDE.md`) → the label is short and the affected subtitles
  already wrap/ellipsize; no metrics test is added.

## Deviations from the original task list

- **Today screen scope grew beyond the focus card.** The original plan named only the Today
  checklist's focus card. Implementation also updates `_SlotRow` (the pending-queue row) and
  `_DoneGroup` (the completed row) in `care_today_screen.dart`, since both render the same
  per-slot dose information the focus card does and would otherwise be inconsistent with it.
- **`care_items_screen.dart`'s schedule line became a widget, not a string.** `_scheduleSummary`
  (string) is now wrapped by `_scheduleLine`, which returns a `Widget` rather than composing a
  plain string — needed so the semantic label can cover the whole line (summary + quantity)
  while the visible text stays a single `Text`. The item-level free-text `dose` row also gained
  `maxLines: 1` / `TextOverflow.ellipsis`, matching the pattern already used for `item.note`.

## Known, deliberately deferred

Left as-is by explicit decision at ship-gate review, not oversights:

- `_formatQuantity` still uses `.toString()` for a fractional value, so a high-precision decimal
  prints in full rather than being rounded/truncated.
- `careDoseLabel` still returns `×1` for a medication slot whose `doseQuantity` is exactly 1 —
  no special-casing to omit an "obvious" quantity.
- `care_history_screen.dart`'s slot `ListTile` does not set `isThreeLine`, even though the dose
  line can push it past two lines.
- `lib/l10n/app_zh.arb` (the gen_l10n plain-`zh` fallback file, already ~104 keys behind
  `app_zh_Hant.arb` before this change) was not updated with the new keys.
