# Tasks: refine-diet-logging

## 1. Domain + application (TDD)

- [x] 1.1 Add `logManualEntry(idToken, {name, portions{staple,meat,fruit,veg}, meal, eatenAt})` to the `DietLogRepository` port
- [x] 1.2 Add a `LogManualEntry` use case + unit tests (with a fake repo): passes name/portions/meal/eatenAt through; guards an all-zero-portions entry

## 2. Infrastructure (TDD with a mock http.Client)

- [x] 2.1 Implement `HttpDietLogRepository.logManualEntry` — `POST /api/diet-entries` with `{ day, meal, name?, portions:{staple,meat,fruit,veg}, eaten_at }` and NO `food_item_id`; decode the returned entry; typed errors + 401→reauth like the other methods. Tests pin the exact request body.

## 3. Manual-entry UI (widget tests with fake repos)

- [x] 3.1 A `ManualEntryController` (`ChangeNotifier`) holding the draft (name, four portion values, meal, eatenAt default now) + typed error/status; `setName`/`setPortion`/`setMeal`/`setEatenAt`/`save`
- [x] 3.2 A manual-entry screen: name field + four portion inputs + meal chips + eaten-at picker (defaults now, editable) + save; on successful save invokes an `onSaved` callback; widget tests (save posts name+portions+meal+eatenAt; all-zero portions blocked; eaten-at editable)

## 4. Today portion pills (widget tests)

- [x] 4.1 A `PortionPills` widget: one pill per non-zero group among {staple,meat,fruit,veg}, colored via `DietCategoryColors`, labeled category + value; omits zero groups; `Wrap` so it never overflows. Widget test: 蛋 (0 staple, 1 meat) → a single "meat 1" pill, no "0"
- [x] 4.2 Use `PortionPills` in `TodayScreen`'s entry row in place of `Text(entry.staple.toString())`; when an entry has no name (a portions-only manual entry), show a localized fallback label (e.g. "手動記錄") instead of a blank title; update Today widget tests

## 5. Entry point + refresh

- [x] 5.1 Add a "找不到? 手動輸入" affordance at the bottom of `DictionaryScreen` that opens the manual-entry screen
- [x] 5.2 Wire the manual-entry `onSaved` to reload Today (shell passes `() => todayController.load(idToken, day)`, mirroring dictionary/target logging)

## 6. i18n

- [x] 6.1 Add manual-entry + portion-pill ARB keys to `app_en.arb` (with descriptions) and `app_zh_Hant.arb`; run `flutter gen-l10n` and commit generated output

## 7. Composition

- [x] 7.1 Wire the `LogManualEntry` use case + `ManualEntryController` from `main.dart` (manual DI) and thread them into the diet shell / dictionary flow

## 8. Verify

- [x] 8.1 Run `flutter analyze` and `flutter test`; both green
