# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` before finishing. Widget tests inject fakes via `l10nTestApp`.

## 1. i18n: 份 unit word

- [x] 1.1 Add `dietPortionUnit` to `app_en.arb` (with description), `app_zh_Hant.arb`,
      `app_zh.arb`: 份 / "portion(s)". Run `flutter gen-l10n` and **commit the
      regenerated `lib/l10n/generated/*.dart`** (CLAUDE.md: generated l10n is
      committed like source).

## 2. measureLabelFor: any unit

- [x] 2.1 Test first — `measureLabelFor('顆', loc)`→顆, `('碗')`→碗, `('g')`→公克,
      `('ml')`→毫升, `(null)`→null, **and `('')`→null** (empty treated as no unit).
- [x] 2.2 Implement in `amount_stepper.dart`: keep g→dietGramsLabel, ml→dietMeasureUnitMl,
      for any other **non-empty** unit return the unit string itself; null **or
      empty string**→null (empty must be null so no blank measure label / "9 "
      consumed ever renders; backend both-or-null makes it unlikely but guard it).

## 3. Portion mode labeled 份; drop name-scraping

> **Scope note**: only the AmountStepper's **after-field unit label** (the `Text`
> at `amount_stepper.dart:137`, driven by the `unitLabel` param) changes to 份.
> The **mode-toggle SegmentedButton's** portion segment (`dietQuantityLabel`
> ="份量", `amount_stepper.dart:143`) is **intentionally unchanged** — 份量 is the
> toggle's name, 份 is the unit after the number. Do NOT touch the segment.

- [x] 3.1 Test first — an AmountStepper for a household food (baseAmount+measureUnit
      set, e.g. 顆) shows a 份量/顆 toggle: the after-field unit label reads 份
      (dietPortionUnit), the measure segment reads 顆; a food with no base measure
      shows the 份 unit label only, no toggle.
- [x] 3.2 Change both AmountStepper call sites — `today_screen.dart` (the inline
      item editor, ~L727) and `food_search_screen.dart` (the tray row, ~L335) — to
      pass `unitLabel: loc.dietPortionUnit` instead of `unitLabelForName(item.name, loc)`.
      `allowMeasure` (`baseAmount != null && measureUnit != null`) is unchanged and
      now true for household foods. Leave the SegmentedButton segment labels alone.

## 4. Consumed amount for household items

- [x] 4.1 Test first — a Today item for `櫻桃/9顆` (quantity 1, base 9, unit 顆)
      shows consumed "9 顆"; an item with no base measure shows "1 份".
- [x] 4.2 `_consumedAmountLabel` (`today_screen.dart`): the base-measure branch is
      unchanged (now yields 顆/碗 via the generalized `measureLabelFor`); change the
      no-base fallback from `quantity + unitLabelForName(name)` to
      `quantity + loc.dietPortionUnit` ("N 份").

## 5. Remove unitLabelForName

- [x] 5.1 Delete `lib/contexts/health/presentation/unit_label.dart` and its test;
      remove all imports. Confirm nothing else references it.
- [x] 5.2 `flutter analyze` clean + `flutter test` green + `flutter build web` compiles.
