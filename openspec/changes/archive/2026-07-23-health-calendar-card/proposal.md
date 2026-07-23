## Why

Feature C3's dashboard card. The backend now exposes a monthly health summary
(`GET /api/health-calendar`); this adds the card that shows it — a record
calendar and three adherence rings — so the dashboard answers "how consistent
was I this month?" at a glance.

## What Changes

- **New `health_calendar` context** (domain / application / infrastructure /
  presentation), mirroring `body_profile`: a `HealthCalendar` model, a repository
  port + `HttpHealthCalendarRepository` calling `GET /api/health-calendar?month=&
  today=`, a `GetHealthCalendar` use case, and a `HealthCalendarController` that
  loads the **current local month** (passing the user's local `today` so
  days-elapsed is judged against their calendar day).
- **`HealthCalendarCard`** on the dashboard (between the trend card and the record
  entry): a Sunday-first month grid with a dot on every day that has any tracker
  entry, plus three rings — **記錄率** (logging rate) and **飲食達標** (diet-adherence
  rate) from the endpoint, and **體重達成** (weight-goal achievement) reused from the
  existing goal controller. Loading / error (with retry) render in the card; a 401
  joins the dashboard's re-auth exit. A null rate shows an empty ring and no
  number.
- Wired through `main → App → HomeScreen → DashboardScreen`. New i18n keys (en +
  zh-Hant + zh). Frontend-only.

## Capabilities

### Added Capabilities

- `health-calendar-card`: the dashboard shows the current month's record calendar
  (dots on logged days) and three adherence rings (logging, diet, weight).
