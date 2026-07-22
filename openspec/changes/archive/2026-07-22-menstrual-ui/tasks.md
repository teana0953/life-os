# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` (+ `bash scripts/lint-actions.sh`) before finishing. Widget tests
inject fakes via `l10nTestApp`. Colors from `Theme.of(context)` — no hard-coded
hex. Every user-facing string via an ARB key (add to `app_en.arb` with a
description + `app_zh_Hant.arb` + `app_zh.arb`, run `flutter gen-l10n`, commit the
regenerated `lib/l10n/generated/*.dart`). The `exercise-ui` code is the closest
template for the context/DI/更多-tile shape; the `water` controller is the template
for the **immediate add/edit/delete** (not draft-then-save) semantics. Reuse the
shared widgets (`ledge_card`, `async_state_scaffold` [has an optional `appBar`]).
Menstrual is **NOT day-keyed**.

## 1. Domain + application (menstrual context)

- [x] 1.1 `lib/contexts/menstrual/domain/menstrual_period.dart` —
      `MenstrualPeriod {id, startDate (DateTime, date-only), endDate (DateTime?)}`,
      `MenstrualStats {averageCycleDays (int?), averagePeriodDays (int?),
      predictedNextStart (DateTime?)}`, `MenstrualOverview {periods, stats,
      lastPeriod}`. snake_case fromJson (start_date, end_date, average_cycle_days,
      average_period_days, predicted_next_start, last_period; nullables handled).
      `menstrual_repository.dart` — `MenstrualRepository` port: `getOverview(idToken)`,
      `addPeriod(idToken, {startDate, endDate})`, `updatePeriod(idToken, id,
      {DateTime? startDate, DateTime? endDate, bool clearEndDate = false})` (partial),
      `deletePeriod(idToken, id)`. `menstrual_exceptions.dart` —
      `MenstrualReauthenticationRequired`, `MenstrualFetchFailure` (typed).
- [x] 1.2 Test first (fake repo) then implement `GetMenstrualOverview`, `AddPeriod`,
      `UpdatePeriod`, `DeletePeriod` in `lib/contexts/menstrual/application/` — thin.

## 2. Infrastructure: HttpMenstrualRepository

- [x] 2.1 Test first with a mock `http.Client`: `HttpMenstrualRepository` maps
      `GET /api/menstrual` → `MenstrualOverview`, `POST` (body `{start_date,
      end_date?}`), `PATCH /:id`, `DELETE /:id`. Sends bearer `idToken`; typed error
      on non-200 (401 distinguishable). **PATCH sends only changed fields** — assert
      three bodies: editing only end_date, only start_date, and clearing end_date
      (`end_date: null`); dates serialised as `YYYY-MM-DD`.

## 3. MenstrualController (immediate add/edit/delete)

- [x] 3.1 Test first (fake repo): `MenstrualController` (ChangeNotifier) —
      `load(idToken)` (NO day param) loads the overview; `addPeriod` / `updatePeriod`
      (partial params) / `deletePeriod` each mutate then RE-READ the overview;
      status `loading|loaded|saving|error|needsReauth`; 401 → needsReauth; fetch
      failure → error. Mirror `WaterController._apply`. Implement
      `lib/contexts/menstrual/presentation/menstrual_controller.dart`.

## 4. Mini-calendar + MenstrualScreen

- [x] 4.1 Test first — the month-calendar marking logic (a widget or pure helper,
      Sunday-first month grid mirroring `diet_shell_screen.dart`'s
      `_DietCalendarDialog`/`_DayCell`): a day within any period's [startDate,
      endDate] (open period → [startDate, today]) is marked as a period day; the
      `predictedNextStart` day carries a distinct marker; prev/next month navigation.
      Use an injectable `clock` for "today". Implement the calendar widget in the
      menstrual presentation folder (do NOT modify diet_shell's private calendar).
- [x] 4.2 Test first (widget, `l10nTestApp` + fake): `MenstrualScreen` shows the
      calendar, a statistics card (average cycle / average period / predicted next —
      each "—" when null) and the most recent period; a load failure shows an error
      state; wrapped in `AsyncStateScaffold` with an `appBar` (back affordance).
      Implement `lib/contexts/menstrual/presentation/menstrual_screen.dart` — colors
      from `Theme.of(context)`, all copy via ARB, reuse shared widgets.
- [x] 4.3 Test first — the add/edit/delete flow: a "new period" affordance and
      tapping a calendar day open a dialog (start date required, end date optional;
      end < start prevented); editing an existing period can change dates, clear the
      end date (reopen), or delete it (with an undo SnackBar or a confirm, mirroring
      exercise's delete). Submitting calls the controller (immediate) and the
      overview re-reads. Implement the dialog + wiring.

## 5. 更多 tile + shell wiring + DI + i18n

- [x] 5.1 Add ARB keys (en + zh-Hant + zh) + `flutter gen-l10n`: 生理期 tile/screen
      title, the three stat labels + the null placeholder ("—"), the last-period
      summary, the add/edit dialog copy (start/end date, clear end date, delete,
      open/in-progress), month navigation labels, and error messages
      (load/save failed, reauth).
- [x] 5.2 Test first (`diet_shell_screen_test.dart`): the More menu now lists a
      生理期 tile; selecting it shows `MenstrualScreen` with a back control; the
      other More tiles (排便/數值/運動) remain. The shell loads `menstrualController`
      once in `_load` (day-independent).
- [x] 5.3 Implement in `diet_shell_screen.dart`: add `required MenstrualController
      menstrualController`; call `menstrualController.load(token)` in `_load()` only
      (NOT in `_reloadCurrentDay()`); add a 生理期 tile to `_MoreMenuScreen` that
      `Navigator.push`es `MenstrualScreen(controller: menstrualController,
      idToken: token)`.
- [x] 5.4 DI: build `HttpMenstrualRepository` + the four use cases +
      `MenstrualController` in `main.dart`, and thread `menstrualController` through
      `App` → `_AuthenticatedHome` → `HomeScreen` → `DietShellScreen` — mirror EVERY
      place `exerciseController` is passed (grep `exerciseController`: `main.dart`,
      `app.dart`, `home_screen.dart`, and the widget-test construction sites
      `app_test.dart`, `diet_shell_screen_test.dart`, `home_screen_test.dart`,
      `home_screen_responsive_test.dart`).

## 6. Gate

- [x] 6.1 `flutter analyze` clean + `flutter test` green + `bash scripts/lint-actions.sh`
      pass. Regenerated l10n committed. No behavior change to other tabs/trackers —
      only a new 生理期 tile in 更多 and one extra controller loaded in `_load`.
