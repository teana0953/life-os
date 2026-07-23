# Tasks

TDD. `flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`. Colors via
Theme; strings via ARB (en+zh_Hant+zh, gen-l10n). Frontend-only.

- [x] 1. New `health_calendar` context: `HealthCalendar` model (+ fromJson),
      repository port + exceptions, `GetHealthCalendar` use case,
      `HttpHealthCalendarRepository` (GET /api/health-calendar?month=&today=).
- [x] 2. `HealthCalendarController`: loads the current local month, passing the
      user's local `today`; loading/loaded/error/needsReauth; clock-injectable.
- [x] 3. `HealthCalendarCard`: Sunday-first month dot-grid + three rings (logging /
      diet from the summary, weight reused from the goal); null rate → empty ring;
      loading/error(retry) states; listens to its controller so retry self-refreshes.
- [x] 4. Wire through main → App → HomeScreen → DashboardScreen (concurrent loads);
      new i18n keys (en+zh_Hant+zh), regenerated.
- [x] 5. Tests: model fromJson; controller (local month/today, 401, error); card
      (rings + dots + legend, null-rate, retry). Gates green.
