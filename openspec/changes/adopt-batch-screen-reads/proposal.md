## Why

The health screen issues **15 HTTP requests** on every load (13 controllers, two of which fetch `/api/daily-target` independently) and the home dashboard issues **7**. Backend issue #114 measured what each of those requests costs on the deployed Worker: ~478ms of client→Worker network per request, +0.76–1.08s extra on the first request after idle, and a time-of-day tail where 7.14% of requests exceed 2s. Because each request is an independent draw from that tail, the probability that *at least one* request takes over 2s is **67%** for the health screen and **40%** for home in the bad window. None of this is work the backend does — the Worker's own `wallTime` averages 8ms — it is per-*request* overhead paid 15 and 7 times.

life-os-backend PR #117 shipped the two batch endpoints that collapse those into one request each (`GET /api/health-overview`, `GET /api/home-summary`). They are deployed and nothing consumes them. This change is the client half.

## What Changes

- **`HealthScaffold._load` issues ONE request** — `GET /api/health-overview?day=YYYY-MM-DD&trend_days=&care_days=` — and fans its fourteen sections out to the thirteen existing controllers, instead of calling `load()` on each of them.
- **`HomeDashboardController`'s full round issues ONE request** — `GET /api/home-summary?day=YYYY-MM-DD&trend_days=` — and fans its seven sections onto the seven existing `ArmSlot`s, instead of seven independent arm fetches.
- **A section's `{ ok: false, error: 'unavailable' }` lands on exactly the per-card failure state that card already has**: one empty/"not refreshed" card, never a whole-screen error. This is a hard requirement, not a nicety — both screens already model partial failure (`ArmSlot` exists because a failed arm rendered as "no data" was an incident), and a batch adoption that turned one failed section into a failed screen would be strictly worse than the 15 requests it replaces.
- **`day` is sent explicitly on every batch request and is exactly the day the screen is displaying.** The endpoints have no server-UTC fallback and return `400` without `day`. A wrong day here is wrong for the whole screen at once.
- **The duplicate `/api/daily-target` fetch per health-screen load disappears** — not as separate work, but as a direct consequence: `TodayController` and `DailyTargetController` both read the single `daily_target` section of one batch response, so there is no second fetch left to make.
- **The granular endpoints stay in use, unchanged**, for writes and their post-write reloads, per-card retry buttons, and per-card window changes (trend span, care period, calendar month). The batch is used only for a whole-screen round.
- **Window parameters are sent from the controllers that own them**, not defaulted: `trend_days` from `TrendController.spanDays`, `care_days` from the trend tab's `CareHistoryController.spanDays`. A section whose window does not match what the card is currently showing is ignored and that one card falls back to its granular load.

## Capabilities

### New Capabilities

- `screen-batch-reads-ui`: how the health screen and the home dashboard load themselves in one request each — which parameters go out, which day, how each section is fanned out to an existing controller, how a failed section, a failed request, and a `401` differ, and which loads deliberately stay granular.

### Modified Capabilities

None. Every card's rendered outcome — its loaded, empty, failed and re-auth states — is unchanged, and the existing specs that describe them stay true. What changes is how the data arrives, which is what the new capability states.

## Impact

- **Client code**: `lib/contexts/health/presentation/health_scaffold.dart`, `lib/contexts/user/presentation/home_dashboard_controller.dart`, a new batch repository + section decoding module, and a hydration entry point on each of the ~15 controllers involved (`WeightGoalController`, `TrendController`, `HealthCalendarController`, `TodayController`, `DictionaryController`, `DailyTargetController`, `WaterController`, `BowelController`, `VitalsController`, `ExerciseController`, `MenstrualController`, `CareTodayController`, `CareHistoryController`).
- **Parsing**: several HTTP repositories decode their response inline. Those decoders become public functions shared by the granular repository and the batch decoder, so the two paths cannot drift (mirrors the backend's own D7).
- **Wiring**: `app.dart` constructs the new batch repository and passes it to the two screens.
- **Backend**: none. The endpoints are already deployed; this change adds no backend work and requires no backend deploy.
- **Network**: health-screen first paint 15 requests → 1; home 7 → 1. Worst-case first-paint latency becomes bounded by the backend's 8-second per-section timeout rather than by the slowest of 15 client requests.
