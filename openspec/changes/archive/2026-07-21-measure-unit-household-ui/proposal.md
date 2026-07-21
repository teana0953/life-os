## Why

The backend now generalizes `measure_unit` to open text, so household-unit foods
(顆/碗/杯/片…) carry a real `base_amount` + `measure_unit` just like g/ml foods
(dev dictionary reseeded: 208 with a base, 63 without). But the frontend still
scrapes the unit word from the food name (`unitLabelForName`) and its measure
label only understands g/ml — so a 顆/碗 food can't be entered by count, its
consumed amount reads as a raw quantity, and portion mode shows a scraped word
the user found confusing. This is the user-facing half of "treat 顆 like g/ml".

## What Changes

- **`measureLabelFor` handles any unit**: `g`→公克, `ml`→毫升, any other
  non-empty string→itself (顆/碗/杯), null→null.
- **Portion mode's unit label is unified to 份**: the amount control no longer
  scrapes the name; portion mode always reads 份, and measure mode reads the
  food's `measure_unit` (公克/毫升/顆/碗/杯) and is directly typable. Household
  foods with a base now get the portion/measure toggle.
- **Consumed amount**: a household item with a base now shows its measure
  ("9 顆"); an item without a base shows "N 份".
- **Remove `unitLabelForName`** (`unit_label.dart`) and its test — its only job
  is now done by `measure_unit` + the 份 label.
- New i18n key `dietPortionUnit` (份 / "portion(s)").

Frontend-only presentation + i18n. No DTO change (`measureUnit` is already
`String?`), no API change. Pairs with backend #14.

## Capabilities

### Modified Capabilities

- `health-diet`: the amount control's portion side is labeled 份 (not a
  name-scraped unit word) and its measure side is labeled by the food's own
  `measure_unit` (any unit, not just 公克/毫升); household-unit foods with a base
  can now be entered by their measure.
