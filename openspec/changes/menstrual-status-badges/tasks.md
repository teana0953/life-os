## 1. Copy (ARB first, per the i18n rule)

- [ ] 1.1 Add the four badge label keys to `lib/l10n/app_en.arb` with a `description` each — ongoing/upcoming "{n}天", overdue "逾{n}天", today "今天" — and translate them in `lib/l10n/app_zh_Hant.arb`; verify `flutter gen-l10n` regenerates `lib/l10n/generated/` and the diff is committed
- [ ] 1.2 Add the four full-sentence accessibility keys (one per badged state), each taking the day count and the relevant date as placeholders with `description`s naming what each placeholder is; verify a widget test asserts the announced label against `lookupAppLocalizations(locale).<key>(...)` rather than a literal
- [ ] 1.3 Split the card's `nextPeriodUpcoming` copy into a main line ("還有 N 天") and keep the existing predicted-date sub-line key; verify no ARB key is left unreferenced (`flutter analyze` clean and a grep for the old key returns no call site)
- [ ] 1.4 Add the overdue explanation key ("已超過預測日 {n} 天") and the ongoing tile date key ("{date} 開始") to both ARB files with `description`s; verify both render in a widget test under `zh_Hant` and under `en`
- [ ] 1.5 Confirm the date formatting used by the new lines is the same formatter the card already uses for the predicted date; verify a widget test asserts the tile's date string and the card's date string are byte-identical for the same status

## 2. Ongoing start-date derivation (presentation only)

- [ ] 2.1 Add a helper deriving the ongoing period's start date from a `NextPeriodStatus` as `today - (days - 1)`, placed next to the state→badge mapping so the tile and the card cannot compute it differently; verify with unit tests for `days == 1` (yields today, not yesterday), `days == 4` (yields today minus 3) and a large uncapped `days == 41`
- [ ] 2.2 Verify by unit test that the helper returns null for every non-`ongoing` state, so no caller can render a start date for a state that has none
- [ ] 2.3 Verify `lib/contexts/menstrual/domain/` and `application/` are untouched by this task (`git diff --stat` shows no file under those directories)

## 3. `CycleBadge` shared widget

- [ ] 3.1 Add `lib/shared/widgets/cycle_badge.dart` — a 32dp circular badge taking `filled`, a colour, a text colour and a label, with `border.width` (2dp) for the outlined form and `textTheme.labelSmall` for the label; verify golden-free widget tests assert the filled form paints a `BoxDecoration` with a fill and no border, and the outlined form the reverse
- [ ] 3.2 Add the `NextPeriodState` → badge-appearance mapping at the menstrual presentation layer (not inside `shared/widgets/`), covering the four badged states and returning null for `needsOneMore` / `noRecords`; verify a unit test asserts each of the six states maps to the colours in `design.md` decision 1 and that the two no-data states map to null
- [ ] 3.3 Wrap the badge's content in `ExcludeSemantics` and clamp its `textScaler` to `maxScaleFactor: 1.3`; verify a widget test at `textScaleFactor: 2.0` renders the badge with no layout overflow, and a semantics test finds no standalone node announcing the bare label
- [ ] 3.4 Verify the badge derives every colour from `Theme.of(context)` / `financeBudgetWarningColor(scheme)` and hard-codes no `Color(...)` or `Colors.*` (grep the new file, plus `flutter analyze` clean)

## 4. Home tile second line and equal-height contract

- [ ] 4.1 Extend `_SnapshotTile` in `home_screen.dart` with an optional leading badge, an optional second line (`bodyMedium` / `color.ink-muted`, at 4dp below the value) and an optional warning outline colour; verify the seven non-menstrual tiles render byte-identically to before (their existing widget tests pass untouched)
- [ ] 4.2 Wire the menstrual tile's builder to render the badge plus the state's date line — `ongoing` → "{derived start} 開始", `upcoming`/`overdue` → "預計 {predicted}", `today` → the predicted date with no suffix, `needsOneMore`/`noRecords` → no badge and no date; verify a widget test covers all six states and asserts the exact strings from the ARB lookups
- [ ] 4.3 Switch the tile's 1dp outline to `color.warning` in the `overdue` state only, leaving the width at 1dp; verify a widget test reads the tile's `BoxDecoration.border` colour in `overdue` and in `upcoming` and finds them different, and that no other tile's outline changed
- [ ] 4.4 Raise the tile's `minHeight` so all six menstrual states and the seven other tiles share one height, with the no-date states reserving the second line's space; verify by widget test that the rendered height of the menstrual tile is identical across all six states and equal to a neighbouring tile
- [ ] 4.5 Update the R3 equal-height guards in `test/contexts/user/presentation/home_screen_responsive_test.dart` to the new height and extend them to iterate the six menstrual states; verify the updated guards fail if the `minHeight` is reverted to the old value (run them once against the old value to confirm they are not vacuous)
- [ ] 4.6 Verify the loading and cold-failure states still render the status line with neither badge nor date, and that the stale-value failure state keeps the badge and date plus the error marker; widget tests for all three
- [ ] 4.7 Verify at a 320dp surface size that the `overdue` state — the widest CJK value plus badge plus padding — renders without a RenderFlex overflow, with `addTearDown(() => tester.binding.setSurfaceSize(null))`

## 5. `NextPeriodCard` badge and overdue explanation

- [ ] 5.1 Add the badge column to the left of the card's text column at `space.stack-md` (16dp), rendering it only for the four badged states; verify a widget test finds the badge for each badged state and finds none for `needsOneMore` / `noRecords`
- [ ] 5.2 Change the `upcoming` main line to the split copy and keep the predicted date as the sub-line; verify the widget test asserts main and sub lines separately against their ARB lookups
- [ ] 5.3 Add the `overdue` explanation line ("已超過預測日 N 天") below the date at 4dp, in `bodyMedium` / `color.ink-muted`; verify a widget test finds it in `overdue` and finds it absent in the other five states
- [ ] 5.4 Give the card one `Semantics` label per badged state using the new full-sentence keys, with the badge excluded; verify a semantics test asserts the whole sentence and that no bare number is announced
- [ ] 5.5 Verify the card's existing loading (`next-period-loading`), cold-error (`next-period-retry`), `StaleNotice` and tap-to-open-tracker behaviour are unchanged — the existing tests for them pass untouched

## 6. Real-font and full verification

- [ ] 6.1 Extend `test/shared/theme/real_font_metrics_test.dart` with cases loading the bundled `.ttf` and asserting the longest **English** badge label ("3d late") fits inside the 32dp circle at scale 1.0 and at the 1.3 clamp — the ordinary widget tests cannot see the font and would pass vacuously; do **not** assert on the zh-Hant labels there, the bundled subset has no CJK glyphs (see `design.md` risks) — instead verify the CJK fit manually in a browser and note the result on the PR
- [ ] 6.2 Settle the tile `minHeight` against that real-font test rather than shipping the ~132dp estimate from `design.md`, and update the R3 guards to the measured value; verify the test asserts no overflow for the tallest of the six states
- [ ] 6.3 Run `flutter analyze` and verify it is clean
- [ ] 6.4 Run `flutter test` and verify the whole suite is green, including the updated `home_screen_responsive_test.dart`
- [ ] 6.5 Verify `git diff --stat` shows no file under `lib/contexts/*/domain/`, `lib/contexts/*/application/` or `lib/contexts/*/infrastructure/`, confirming the change is presentation-only as the proposal states
