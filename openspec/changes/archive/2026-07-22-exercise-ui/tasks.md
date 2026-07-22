# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` (+ `bash scripts/lint-actions.sh`) before finishing. Widget tests
inject fakes via `l10nTestApp`. Colors from `Theme.of(context)` — no hard-coded
hex. Every user-facing string via an ARB key (add to `app_en.arb` with a
description + `app_zh_Hant.arb` + `app_zh.arb`, run `flutter gen-l10n`, commit the
regenerated `lib/l10n/generated/*.dart`). The `vitals-ui` code is the closest
template for the context/DI shape; the `water` controller is the template for the
**immediate add/delete** (not draft-then-save) semantics. **Reuse the shared
widgets** (`lib/shared/widgets/{ledge_card,async_state_scaffold,tracker_day_header,
numeric_amount_field}.dart`).

## 1. Domain + application (exercise context)

- [x] 1.1 `lib/contexts/exercise/domain/exercise_day.dart` —
      `ExerciseActivity {id, name, category, intensity}` (category: String,
      'aerobic'|'anaerobic'), `ExerciseEntry {id, activityId, activityName?,
      category?, durationMinutes, note, createdAt}`, `ExerciseDay {day, entries,
      totalMinutes}`. snake_case fromJson (activity_id, activity_name,
      duration_minutes, created_at, total_minutes). `exercise_repository.dart` —
      `ExerciseRepository` port: `listActivities(idToken)`, `getDay(idToken, day)`,
      `addEntry(idToken, {day, activityId, durationMinutes, note})`,
      `deleteEntry(idToken, entryId)`. `exercise_exceptions.dart` —
      `ExerciseReauthenticationRequired`, `ExerciseFetchFailure` (typed, no message).
- [x] 1.2 Test first (fake repo) then implement `ListExerciseActivities`,
      `GetExerciseDay`, `AddExerciseEntry`, `DeleteExerciseEntry` in
      `lib/contexts/exercise/application/` — thin, delegate to the port.

## 2. Infrastructure: HttpExerciseRepository

- [x] 2.1 Test first with a mock `http.Client`: `HttpExerciseRepository`
      (`lib/contexts/exercise/infrastructure/`) maps `GET /api/exercise/activities`
      → `List<ExerciseActivity>` (unwrapping the `{activities:[...]}` envelope),
      `GET /api/exercise?day=` → `ExerciseDay`, `POST /api/exercise` (body
      `{day, activity_id, duration_minutes, note}`) → the created entry, and
      `DELETE /api/exercise/:id`. Sends the bearer `idToken`; typed error on
      non-200 (401 distinguishable for reauth). Entry enrich fields round-trip.

## 3. ExerciseController (immediate add/delete)

- [x] 3.1 Test first (fake `ExerciseRepository`): `ExerciseController`
      (ChangeNotifier) — `load(idToken, day)` loads the day's entries (+ activities
      for the picker); `addEntry(...)` POSTs then RE-READS the day (total reflects
      the new entry); `deleteEntry(...)` DELETEs then re-reads (total drops);
      status `loading|loaded|saving|error|needsReauth`; a 401 → needsReauth; a
      fetch failure → error. Mirror `WaterController._apply` (re-read, don't
      compute locally). Implement `lib/contexts/exercise/presentation/exercise_controller.dart`.

## 4. ExerciseScreen

- [x] 4.1 Test first (widget, `l10nTestApp` + fake controller/repo):
      `ExerciseScreen` shows a `TrackerDayHeader`, the day's total minutes, and the
      day's entries (each with a remove control); an unrecorded day shows no
      entries and a zero total; an add affordance opens an activity picker (library
      grouped aerobic/anaerobic) + a positive-integer duration field
      (empty-zero convention via `NumericAmountField`) + an optional note →
      appends (entry appears, total grows); a non-positive/empty duration cannot be
      submitted; removing an entry drops it and reduces the total; a load failure
      shows an error state. Implement
      `lib/contexts/exercise/presentation/exercise_screen.dart` — colors from
      `Theme.of(context)`, all copy via ARB, reuse the shared widgets.

## 5. Navigation restructure (更多 overflow) + shell wiring + DI + i18n

- [x] 5.1 Add ARB keys (en + zh-Hant + zh base) + `flutter gen-l10n`: the 更多 tab
      label, the More-menu tile labels (reuse existing bowel/vitals tab-label keys
      or add), the exercise screen copy (title, total-minutes label, add button,
      activity/duration/note fields, aerobic/anaerobic category labels, remove,
      error messages). Activity NAMES are backend data (not localized); localize
      only the aerobic/anaerobic category via the `category` value.
- [x] 5.2 Test first (`test/contexts/health/presentation/diet_shell_screen_test.dart`):
      the bottom `NavigationBar` shows exactly four destinations (今日/目標/飲水/更多);
      tapping 更多 shows a menu listing the Bowel, Vitals, and Exercise trackers;
      selecting Exercise shows the exercise screen for the shell's viewed day;
      Bowel and Vitals remain reachable via 更多; Today/Target/Water remain in the
      bottom bar. Update the existing shell tests that assumed 5 bottom tabs
      (bowel/vitals were bottom destinations) to reach them via 更多.
- [x] 5.3 Implement in `diet_shell_screen.dart`: add `required ExerciseController
      exerciseController`; call `exerciseController.load(token, _day)` in `_load()`
      and `_reloadCurrentDay()`; change the `screens` list to four entries
      (Today, Target, Water, More-menu) and the `NavigationBar` to four
      destinations (更多 icon e.g. `Icons.more_horiz`); add a `_MoreMenuScreen`
      widget listing 排便/數值/運動 tiles that `Navigator.push` the respective
      screen (`BowelScreen`/`VitalsScreen`/`ExerciseScreen`) with `idToken`, the
      shell's `_day`, the controller, and `clock`.
- [x] 5.4 DI: build `HttpExerciseRepository` + the four use cases +
      `ExerciseController` in `main.dart`, and thread `exerciseController` through
      `App` → `_AuthenticatedHome` → `HomeScreen` → `DietShellScreen` — mirror
      EVERY place `vitalsController` is passed (grep `vitalsController` to find all
      call sites, incl. any widget tests constructing `DietShellScreen`/`HomeScreen`
      that now need an exercise controller/fake).

## 6. Gate

- [x] 6.1 `flutter analyze` clean + `flutter test` green +
      `bash scripts/lint-actions.sh` pass. Regenerated l10n committed. No behavior
      change to the Today/Target/Water screens or the Bowel/Vitals screens
      themselves — only the Bowel/Vitals entry point moves into 更多.
