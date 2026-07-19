# Tasks — Diet history + edit

## 1. Domain + infrastructure (repository)
- [x] 1.1 Add `updateEntry(idToken, entryId, {name,meal,eatenAt,portions})` and
      `loggedDays(idToken, month)` to the `DietLogRepository` port.
- [x] 1.2 Implement both on `HttpDietLogRepository`: `updateEntry` → partial
      `PATCH /api/diet-entries/:id` (only non-null fields, `eaten_at` as UTC ISO,
      `portions` map), 200 → `FoodEntry`, 401 → reauth, else `DietFetchFailure`;
      `loggedDays` → `GET .../logged-days?month=`, 200 → `List<String>`.
- [x] 1.3 Infra tests (mock `http.Client`): partial PATCH body, 200 parse, 401 →
      reauth; `loggedDays` parses `{days}` and passes month through.

## 2. Use cases
- [x] 2.1 `UpdateFoodEntry` and `GetLoggedDays` thin use cases (mirror existing).

## 3. Edit controller + bottom sheet (TDD)
- [x] 3.1 `EditEntryController`: `start(entry)` seeds name/portions/meal/
      snackLabel (custom meal → snackMealValue + snackLabel)/eatenAt; `eatenAt`
      dirty-tracked (flag set only by `setEatenAt`). `save(idToken)` →
      UpdateFoodEntry with `eatenAt` sent ONLY when changed (else null), name via
      `isEmpty?null:name`, status + typed error; `delete(idToken)` → DeleteEntry.
      Unit tests: seed (incl. snack round-trip), save patch shape, delete, errors,
      and **a portions-only edit (time untouched) omits eaten_at** so the entry's
      day is not moved.
- [x] 3.2 Extract shared `PortionFormFields` (name + 4 portion inputs + meal
      selector + time picker) from `ManualEntryScreen`; reuse in both screens.
      Confirm manual-entry behavior/tests unchanged.
- [x] 3.3 `EditEntryScreen` (bottom-sheet body): shared form + save + delete
      (with confirm), maps typed errors to localized copy. Widget tests: prefilled
      from entry, save calls update + pops, delete removes + pops.

## 4. Day navigation + calendar
- [x] 4.1 Make `DietShellScreen._day` mutable state; add `_DayNavBar`
      (prev/next + calendar), next disabled on today; changing day reloads today +
      target controllers. Widget tests: prev reloads prior day; next disabled today.
- [x] 4.2 `_DietCalendar` dialog: month grid, future dates (after today, by the
      injected clock) non-selectable/dimmed, dots on days from `GetLoggedDays`;
      picking a day reloads. Failure → unmarked calendar, navigation still works.
      Widget test with fake `loggedDays`.
- [x] 4.3 Make `TodayScreen` entries tappable via `onEditEntry(FoodEntry)`; wire
      the shell to open the edit sheet and refresh the day on save/delete.

## 5. i18n + wiring
- [x] 5.1 Add ARB keys (en + zh-Hant + zh): edit title, save/delete, delete
      confirm, 今日/昨天 labels, calendar title/close. Regenerate l10n.
- [x] 5.2 Wire new controllers/use cases in `main.dart` (manual DI).

## 6. Verify
- [x] 6.1 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` all green.
