## Why

Every care slot and schedule carries a `doseQuantity` (how much is taken per firing) that the
app never shows. Today only the free-text `dose` string appears, and only on the Today
checklist / overview summary — so a schedule set to "take 2" is indistinguishable from "take 1"
anywhere in the UI, and the history list shows no dose information at all. A user checking what
they actually took cannot tell how many.

## What Changes

- Add a shared presentation formatter `careDoseLabel(loc, doseQuantity, dose)` in the
  notifications context that renders `×2 · 5mg` (quantity + free-text dose), `×2` when there
  is no `dose`, and drops a trailing `.0` from a whole-number quantity — the same integer
  formatting `care_items_screen`'s existing `_formatStock` already does.
- Care history list: each slot row's subtitle gains the dose label alongside its time and
  status.
- Care reminders list: each schedule's summary line gains its `×N` quantity; a medication
  item's free-text `dose` moves to its own row under the schedules (it was not shown before).
- Today care screen and the health-overview today-care summary card: the current
  `dose`-only line becomes the merged label, so the quantity shows next to the dose text.
- i18n: new `careDoseQuantityValue` key (`×{quantity}`) in `app_en.arb` and
  `app_zh_Hant.arb`, with regenerated `lib/l10n/generated/` committed.
- `doseQuantity` carries no unit from the backend, so the label is deliberately `×N` rather
  than an invented unit word such as 「顆」.
- Non-goals: no backend contract change, no domain-model change, and the existing rule that
  free-text `dose` is medication-only is untouched.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `care-history-ui`: the day-grouped slot list must show each slot's dose in addition to its
  time, title, and status.
- `care-reminders-ui`: the grouped reminders list must show each schedule's dose quantity and,
  for medication, the item's free-text dose.
- `care-today-ui`: the Today checklist and the overview today-care summary must show the dose
  quantity together with the free-text dose, instead of the free-text dose alone.

## Impact

- New: `lib/contexts/notifications/presentation/care_dose_label.dart` plus its unit test.
- Modified presentation files: `care_history_screen.dart`, `care_items_screen.dart`,
  `care_today_screen.dart`, `care_today_summary_card.dart`, and their widget tests.
- Modified i18n: `lib/l10n/app_en.arb`, `lib/l10n/app_zh_Hant.arb`, regenerated
  `lib/l10n/generated/`.
- No changes to `domain/`, `application/`, `infrastructure/`, or the backend.
