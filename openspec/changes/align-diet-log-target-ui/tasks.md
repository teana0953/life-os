# Tasks: align-diet-log-target-ui

## 1. Dictionary rows (widget tests)

- [x] 1.1 In `dictionary_screen.dart`, render each row's portions via `PortionPills` and change the favorite toggle from a star `IconButton` to a heart (♥/♡); keep `onSelectItem`/`toggleFavorite` behavior. Widget test: a row for `飯/1碗` (4 staple) shows a "staple 4" pill; heart toggles favorite
- [x] 1.2 Add an explicit segmented "All / Favorites" tab above the search field selecting which existing list to show (search results vs favorites), replacing the implicit empty-query switch; controller list state unchanged. Default landing tab is Favorites (initial screen not empty); the All tab, before any query, shows a search prompt (not a silently empty list). Widget tests: selecting Favorites shows the favorites list; All with no query shows the prompt

## 2. Quantity card (widget tests)

- [x] 2.1 Show a dictionary-basis line ("<unit> ＝ <portions>") — take the unit segment after `/` in the item's name (e.g. `飯/1碗` → "1碗", never a hardcoded "碗") + its non-zero portions; skip the basis line when it has no portions or the name has no `/` unit segment
- [x] 2.2 Replace the `use-grams` `Switch` with a segmented "碗 | 克" toggle (`SegmentedButton`); the gram segment appears only when the item has base grams; same `useGrams` state + mutual exclusion. Widget test: no-base-grams item shows unit only
- [x] 2.3 Replace the quantity `TextField` with a stepper whose value is editable — −/+ adjust by 0.5 AND tapping the number opens numeric entry, so a non-0.5 decimal (e.g. 1.25) is still reachable for no-base-grams items (no precision loss); bound to the same quantity state; keep the grams numeric field. Widget tests: stepping changes the quantity and the preview; a typed 1.25 is accepted
- [x] 2.4 Render the portion preview as pills plus the "dictPortions × quantity" math label (e.g. "4 × 1.5"); from the existing `controller.preview`. Widget test: `飯/1碗` × 1.5 → "主食 6" pill + "4 × 1.5"

## 3. Target screen (widget tests)

- [x] 3.1 Extend `PortionStepper` with an optional leading category-color icon (rounded chip, 主/肉/果/菜); default null so existing call sites are unchanged
- [x] 3.2 Wrap `daily_target_screen.dart` in two themed cards (rounded + 2px outline + `ledgeShadow`): a target card (four steppers with icons) + a today/remaining card; add a muted, non-editable bonus note ("✳️ 運動後可加成份數（之後串運動模組）")
- [x] 3.3 Replace the plain `_RemainingRow`s with a per-category remaining bar: bar fills to `logged/effective` but the row shows the REMAINING number (e.g. "3 剩"), not "used of target" — extend/wrap `CategoryProgressBar` to take a trailing remaining label. Widget test: target 12 / logged 9 → staple bar ~3/4 AND "3 remaining" still reads correctly

## 4. i18n

- [x] 4.1 Add any new ARB keys (en + zh-Hant) — basis phrasing, bonus note, tab labels, preview math label if needed; run `flutter gen-l10n` and commit. No hard-coded UI strings; no hard-coded `Color`

## 5. Verify

- [x] 5.1 Run `flutter analyze` and `flutter test`; both green
