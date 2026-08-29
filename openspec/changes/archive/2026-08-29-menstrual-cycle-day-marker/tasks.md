## 1. Copy (ARB first, per the i18n rule)

- [x] 1.1 Add a second placeholder (the cycle day) to `menstrualDaySemanticPeriod` in `lib/l10n/app_en.arb` with a `description`, and translate it in `lib/l10n/app_zh_Hant.arb`; verify `flutter gen-l10n` regenerates `lib/l10n/generated/` with the two-argument signature and the diff is committed
- [x] 1.2 Add the legend key `menstrualLegendCycleDay` ("small number = day of period") to both ARB files with a `description`; verify it appears in the generated localizations

## 2. Derivation

- [x] 2.1 Add `menstrualCycleDay(DateTime day, List<MenstrualPeriod> periods, DateTime today) -> int?` to `menstrual_calendar.dart`, returning the 1-based day of the covering period with the largest `startDate`, uncapped, and `null` when no period covers the day; verify with unit tests for a closed period's first/middle/last day, an open period bounded by today, a day after today inside an open period's month, and a day outside every period
- [x] 2.2 Cover the overlap tie-break with a unit test: a day covered by periods starting 2026-05-01 and 2026-05-03 resolves to day 1, not day 3
- [x] 2.3 Add a unit test asserting the calendar's number for today equals `computeNextPeriodStatus(overview, today).days` for an ongoing period, pinning the "the two never disagree" spec scenario
- [x] 2.4 Replace `isMenstrualPeriodDay` at its call site in `MenstrualCalendar.build` with `menstrualCycleDay(...) != null`, removing the duplicate range scan; verify the existing menstrual calendar tests still pass and no unused symbol remains (`flutter analyze` clean)

## 3. Day cell rendering

- [x] 3.1 Change `_MenstrualDayCell` to take a nullable `cycleDay` in place of `isPeriod`, and render a two-line `Column` (day-of-month in `bodySmall`, cycle-day digits in `labelSmall` at reduced opacity of `onPrimary`) inside the unchanged 32×32 circle when `cycleDay != null`; verify a widget test finds both numbers inside `Key('menstrual-day-marker-<date>')` for a period day
- [x] 3.2 Verify by widget test that a non-period day, the predicted-next day and today each render only the day-of-month number and no second line
- [x] 3.3 Clamp the marker's `textScaler` to a 1.3 maximum and leave the legend and statistics unclamped; verify a widget test at `textScaleFactor: 2.0` still renders the marker without a layout overflow

## 4. Semantics and legend

- [x] 4.1 Pass the cycle day into `menstrualDaySemanticPeriod` when building the cell's semantic label; verify a widget test asserts the announced label against `lookupAppLocalizations(locale).menstrualDaySemanticPeriod(dateLabel, 3)` for the 3rd day of a period
- [x] 4.2 Add the third legend entry to the `Key('menstrual-legend')` `Wrap`; verify a widget test finds all three entries and that the `Wrap` still lays out without overflow at 320dp width and at `textScaleFactor: 2.0`

## 5. Real-font and full verification

- [x] 5.1 Extend `test/shared/theme/real_font_metrics_test.dart` with a case that loads the bundled `.ttf` and asserts the two-line marker content fits within the 32×32 circle at scale 1.0 and at the 1.3 clamp — the ordinary widget tests cannot see the font and would pass vacuously
- [x] 5.2 Run `flutter analyze` and `flutter test` and verify both are clean before the ship gate
