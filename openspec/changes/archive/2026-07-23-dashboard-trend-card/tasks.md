# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` (+ `bash scripts/lint-actions.sh`) before finishing. Widget tests
inject fakes via `l10nTestApp`. Colors from `Theme.of(context)` — no hard-coded
hex. Every user-facing string via an ARB key (en + zh-Hant + zh, run
`flutter gen-l10n`, commit generated). Extends the existing `vitals` context; the
`body_profile` goal card + its `WeightGoalController` are the closest templates for
the card/controller/DI shape.

## 0. Dependency

- [x] 0.1 Add **`fl_chart`** to `pubspec.yaml` (`flutter pub add fl_chart`) and
      `flutter pub get`. Commit the pubspec + lockfile changes.

## 1. Domain + application (vitals context)

- [x] 1.1 `lib/contexts/vitals/domain/vitals_series.dart`:
      `SeriesPoint {DateTime day, double value}`,
      `VitalsSeries {weight, bodyFat, systolic, diastolic, pulse, glucose, spo2}`
      (each `List<SeriesPoint>`), `VitalsRange {DateTime from, DateTime to,
      VitalsSeries series}` with snake_case fromJson (each series a list of
      `{day, value}`; day parsed date-only; the snake_case keys are exactly
      `weight, body_fat, systolic, diastolic, pulse, glucose, spo2` — note
      `body_fat`/`spo2`), an `enum VitalsMetric {...}`, and
      `seriesFor(VitalsSeries, VitalsMetric)`. Add `getRange(idToken, from, to)` to
      `VitalsRepository`. **Adding this abstract method breaks EVERY existing
      `implements VitalsRepository` test fake — grep `implements VitalsRepository`
      across `test/` and add a `getRange` stub to each** so `flutter analyze` /
      `flutter test` still compile (the 7 implementers: `vitals_use_cases_test`,
      `vitals_controller_test`, `vitals_screen_test`, `app_test`, `home_screen_test`,
      `home_screen_responsive_test`, `diet_shell_screen_test`).
- [x] 1.2 Test first (fake repo) then implement `GetVitalsTrends` in
      `lib/contexts/vitals/application/get_vitals_trends.dart` — thin.

## 2. Infrastructure: getRange

- [x] 2.1 Test first with a mock `http.Client`: `HttpVitalsRepository.getRange`
      requests `GET /api/vitals/range?from=YYYY-MM-DD&to=YYYY-MM-DD` with the bearer
      token, maps the response to `VitalsRange` (each series' points); typed error on
      non-200 (401 distinguishable).

## 3. TrendController

- [x] 3.1 Test first (fake repo): `TrendController` (ChangeNotifier) — `load(idToken)`
      computes `from = today − (spanDays − 1)`, `to = today` from an injectable clock
      and fetches the range; `setSpan(idToken, days)` updates spanDays (7/30/90) and
      reloads; status `loading|loaded|error|needsReauth`; 401 → needsReauth; fetch
      failure → error. Assert the computed from/to for a given clock + span. Implement
      `lib/contexts/vitals/presentation/trend_controller.dart`.

## 4. Trend card

- [x] 4.1 Test first (widget, `l10nTestApp` + fake): `TrendCard` shows a metric
      picker (the 7 metrics), a 7/30/90-day range selector, and — with data for the
      selected metric — an `fl_chart` `LineChart` (`find.byType(LineChart)`);
      switching metric re-plots (selected metric's series); switching range calls
      `setSpan` (the fake receives the new from/to); a metric with no points shows a
      `trend-empty` message and no chart; a load failure shows an error state with a
      retry. Implement `lib/contexts/vitals/presentation/trend_card.dart` — colors
      from `Theme.of(context)`, all copy via ARB, reuse `LedgeCard`; the selected
      metric is card-local state, the range span drives the controller reload. The
      x-axis day offset (a point's day vs `range.from`) MUST use UTC/date-component
      arithmetic (`DateTime.utc(...)` diff), not `a.difference(b).inDays` on local
      DateTimes, to avoid a DST off-by-one.

## 5. Dashboard wiring + DI + i18n

- [x] 5.1 Add ARB keys (en + zh-Hant + zh) + `flutter gen-l10n`: trend card title,
      the 7 metric labels (+ optional units), the range labels (7/30/90 天), the
      empty "no data yet" message, and error/retry messages.
- [x] 5.2 Test first (`dashboard_screen_test.dart`): the dashboard shows the trend
      card below the goal card; returning from the record entry reloads the trend
      (getRange called again); a trend `needsReauth` surfaces the sign-in-again exit.
- [x] 5.3 Implement in `dashboard_screen.dart`: add `required TrendController
      trendController`; `trendController.load(token)` in `_load()` (so the record-
      return reload covers it too); insert `TrendCard(controller: trendController,
      idToken: idToken)` after the `GoalCard`; include the trend controller in the
      needsReauth check.
- [x] 5.4 DI: build `TrendController` (with the vitals `getRange` via
      `GetVitalsTrends`) in `main.dart`, and thread `trendController` through
      `App` → `_AuthenticatedHome` → `HomeScreen` → `DashboardScreen` — mirror EVERY
      place `weightGoalController` is passed (grep `weightGoalController`: `main.dart`,
      `app.dart`, `home_screen.dart`, and the test construction sites `app_test.dart`,
      `home_screen_test.dart`, `home_screen_responsive_test.dart`,
      `dashboard_screen_test.dart`).

## 6. Gate

- [x] 6.1 `flutter analyze` clean + `flutter test` green + `bash scripts/lint-actions.sh`
      pass. Regenerated l10n committed; `fl_chart` in pubspec + lockfile. No behavior
      change to the goal card, trackers, or tab shell — only a second dashboard card.
