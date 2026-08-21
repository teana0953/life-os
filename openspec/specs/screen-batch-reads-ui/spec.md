# screen-batch-reads-ui Specification

## Purpose
TBD - created by archiving change adopt-batch-screen-reads. Update Purpose after archive.
## Requirements
### Requirement: The health screen loads itself in one request

A whole-screen load of the health scaffold (`HealthScaffold._load`) SHALL issue exactly **one** backend read request: `GET /api/health-overview` with `day`, `trend_days` and `care_days`. It SHALL NOT issue the thirteen controller loads that produced fifteen requests.

The fourteen sections of the response — `weight_goal`, `vitals_trend`, `health_calendar`, `meals`, `daily_target`, `favorite_food_items`, `water`, `bowel`, `vitals`, `exercise_activities`, `exercise`, `menstrual`, `care_today`, `care_range` — SHALL be fanned out to the controllers that already own them, leaving each controller's public state (its status enum, its data field, its `lastLoadedAt`) indistinguishable from the state its own granular load would have produced from the same payload.

The batch response's section `data` is byte-for-byte the granular endpoint's body, so each section SHALL be decoded by the same decoder the granular repository uses. A section SHALL NOT get a second, parallel decoder.

#### Scenario: One request replaces fifteen

- **WHEN** the health scaffold runs a whole-screen load against a fake HTTP client that records every request
- **THEN** exactly one request was recorded, its path is `/api/health-overview`, and no request was made to `/api/weight-goal`, `/api/vitals/range`, `/api/health-calendar`, `/api/meals`, `/api/daily-target`, `/api/food-items/favorites`, `/api/water`, `/api/bowel`, `/api/vitals`, `/api/exercise/activities`, `/api/exercise`, `/api/menstrual`, `/api/care/today` or `/api/care/range`

#### Scenario: Every card ends in the state its own load would have produced

- **WHEN** the health scaffold loads from a batch response in which every section is `{ ok: true, data: … }`
- **THEN** each of the thirteen controllers holds the same value and the same `loaded` status it holds after its own granular load of the identical payload

#### Scenario: The duplicate daily-target fetch is gone

- **WHEN** the health scaffold runs a whole-screen load
- **THEN** the `daily_target` section is applied to **both** `TodayController` and `DailyTargetController`, and the load makes no second request for the day's target

### Requirement: The home dashboard loads itself in one request

A full round of `HomeDashboardController.load` SHALL issue exactly **one** backend read request: `GET /api/home-summary` with `day` and `trend_days`. It SHALL NOT fan out to seven independent arm fetches.

The seven sections — `weight_goal`, `vitals_trend`, `menstrual`, `budgets`, `net_worth`, `split_balances`, `daily_target` — SHALL be reduced to the same arm values the corresponding arm fetch produces today, including the derived ones: the `vitals_trend` section reduces to the most recent blood-pressure reading in the series, and the `budgets` section reduces to the single budget whose category is null.

The controller's page-level contract SHALL be unchanged: `status` becomes `loaded` when at least one arm produced a value and `error` only when **all seven** failed, `lastLoadedAt` advances only on a round that landed at least one arm, and `data` returns to `null` only when every arm failed with nothing carried over.

#### Scenario: One request replaces seven

- **WHEN** a full home-dashboard round runs against a fake HTTP client that records every request
- **THEN** exactly one request was recorded and its path is `/api/home-summary`

#### Scenario: Derived arms are computed from their sections

- **WHEN** a round loads a batch response whose `vitals_trend` series contains several readings and whose `budgets` list contains one category budget and one overall budget
- **THEN** the blood-pressure arm holds the most recent systolic/diastolic pair and the budget arm holds the overall (null-category) budget, exactly as the granular arms did

#### Scenario: Page status still distinguishes partial from total failure

- **WHEN** a round loads a batch response in which one section is `ok: false` and six are `ok: true`
- **THEN** `status` is `loaded`, `lastLoadedAt` advances, and only the failing arm's slot is marked failed

### Requirement: A failed section fails one card, never the screen

A section returned as `{ ok: false, error: … }` SHALL be applied to its controller as that controller's **own per-card failure state** — the state that controller already enters when its granular request fails — and SHALL have no effect on any other section's controller.

The response status is `200` in this case, so a failed section SHALL NOT be reported as a request failure, SHALL NOT put the screen into a whole-screen error, and SHALL NOT be rendered as an empty/"no data" card where the controller distinguishes empty from failed.

A section whose `data` is present but cannot be decoded SHALL be treated exactly as `ok: false`: that one card fails and the others are applied normally.

#### Scenario: One failed section, thirteen loaded cards

- **WHEN** the health scaffold loads a batch response whose `bowel` section is `{ ok: false, error: 'unavailable' }` and whose other thirteen sections are `ok: true`
- **THEN** `BowelController` is in its fetch-failed state, every other controller is `loaded` with its section's value, and the screen renders its normal card layout rather than a whole-screen error

#### Scenario: A failed section is not an empty card

- **WHEN** a section for a card that can legitimately be empty (for example `menstrual`, or the home dashboard's blood-pressure arm) returns `ok: false`
- **THEN** that card shows its failed state, distinguishable from "no data recorded"

#### Scenario: An undecodable section fails alone

- **WHEN** a batch response's `water` section is `{ ok: true, data: … }` with a payload that fails to decode
- **THEN** `WaterController` is in its fetch-failed state and the other sections are applied normally

#### Scenario: Every section failed is still not a whole-screen health error

- **WHEN** the health scaffold loads a `200` batch response in which all fourteen sections are `ok: false`
- **THEN** each of the thirteen controllers is in its own fetch-failed state and no re-authentication exit is shown

### Requirement: Request-level failures are distinct from section failures

A batch request that fails as a whole — transport error, timeout, `4xx`, `5xx`, or an undecodable body — SHALL be applied to **every** controller of that screen as the failure that screen's controllers already have for their granular request failing, so no card is left indefinitely on its loading state and no card silently keeps stale data without a marker.

A `401` SHALL be applied as the re-authentication state (`needsReauth` / `reauth`) on every controller of that screen that has one, so the existing "please sign in again" exit appears exactly as it does today. A non-`401` failure SHALL NOT be applied as a re-authentication state.

A `400` (a missing or malformed `day`, or an out-of-range window) is a **client bug**, not a user-visible mode of its own: it SHALL be applied as an ordinary fetch failure, and SHALL be prevented at source by always sending a well-formed `day` and windows within `1..366`.

#### Scenario: Transport failure fails every card

- **WHEN** the batch request throws (network down)
- **THEN** every controller on that screen is in its fetch-failed state and none is left on `loading`

#### Scenario: 401 surfaces the re-authentication exit

- **WHEN** the batch request responds `401`
- **THEN** every controller that models re-authentication is in that state and the screen shows its "sign in again" exit

#### Scenario: A 500 is not a re-authentication prompt

- **WHEN** the batch request responds `500`
- **THEN** every controller is in its fetch-failed state and no re-authentication exit is shown

#### Scenario: Home total failure keeps its whole-dashboard card

- **WHEN** the batch request fails as a whole on a first-ever home round
- **THEN** all seven arms are failed with no carried value, `status` is `error`, `data` is `null`, and the screen shows the single whole-dashboard "couldn't load" card with its one retry

### Requirement: `day` is the day the screen is displaying

Every batch request SHALL send `day` explicitly, formatted `YYYY-MM-DD`, and that value SHALL be the local calendar day the screen is displaying at the moment the request is issued — for the health scaffold, the same `clock()`-derived day string the load already computes; for the home dashboard, the same `now` its round already receives.

`day` SHALL NOT be omitted (the endpoint has no server-UTC fallback and answers `400`), SHALL NOT be derived from a second clock read taken elsewhere in the load, and SHALL NOT be derived from UTC where the screen's day is local.

A response SHALL be applied only to the day it was requested for: a section carrying day-scoped data SHALL be rejected if the screen has since moved to another day, so the screen can never display day A while holding day B's figures.

#### Scenario: The requested day is the displayed day

- **WHEN** the health scaffold loads with its clock pinned to a local time that falls on a different UTC date (for example 2026-08-20 07:00 at UTC+8, which is 2026-08-19 in UTC)
- **THEN** the request's `day` is `2026-08-20`

#### Scenario: A late response for a day the screen has left is dropped

- **WHEN** a batch response for day D arrives after the screen has moved to day D+1
- **THEN** no day-scoped controller is written with D's data, and the day-scoped cards keep describing D+1

#### Scenario: One clock read per round

- **WHEN** a round computes the day it will request and the day it will display
- **THEN** both come from the same value, so a round that straddles midnight cannot request one day and label the cards with another

### Requirement: Window parameters come from the cards that own them

`trend_days` SHALL be sent as the current span of the card that will receive `vitals_trend` — `TrendController.spanDays` on the health screen (7/30/90), and the home dashboard's existing 366-day lookback on home. `care_days` SHALL be sent as the current span of the trend tab's `CareHistoryController`.

A `vitals_trend` or `care_range` section SHALL be applied only if the window it describes is still the window that card is showing when the response lands. If the card's window changed in flight, or if the card's period has no day count expressible as `trend_days`/`care_days` (a custom date range, or a span outside `1..366`), that section SHALL be ignored and that one card SHALL be loaded from its granular endpoint instead. The rest of the batch SHALL still be applied.

#### Scenario: The requested span is the card's span

- **WHEN** the trend card's span is 90 days and the care adherence card's span is 7 days when a health round starts
- **THEN** the request carries `trend_days=90` and `care_days=7`

#### Scenario: A custom care period falls back to granular

- **WHEN** the care adherence card is showing a custom date range (no day count) and a health round runs
- **THEN** the care adherence card is loaded from `/api/care/range` for its own range, the `care_range` section is ignored, and the other twelve sections are still applied

#### Scenario: A span changed in flight is not overwritten

- **WHEN** a round requests `trend_days=30`, the user switches the card to 90 while the request is in flight, and the response then lands
- **THEN** the trend card is not written with the 30-day series, and it ends up showing the 90-day range it was switched to

### Requirement: The calendar section is applied only for the month on screen

`health_calendar` is always computed for `day`'s month. It SHALL be applied only when the health calendar card is showing that month. When the card is showing another month (the user paged it), the section SHALL be ignored and the card SHALL keep or load its own month, without affecting the other sections.

#### Scenario: Card on another month is left alone

- **WHEN** the health calendar card has been paged to the previous month and a health round runs for a day in the current month
- **THEN** the card still shows the previous month's data and is not overwritten by the current month's section

### Requirement: Only whole-screen rounds use the batch

The batch endpoints SHALL be used only where an entire screen loads at once. Every narrower load SHALL keep calling its granular endpoint:

- a write and the reload that follows it (water, bowel, vitals, exercise, meals, target, care log edits, weight goal, menstrual);
- a per-card retry button, including the home dashboard's per-tile `retryArm`;
- a per-card window change (`TrendController.setSpan`, `CareHistoryController.setPeriod`/`setSpan`, `HealthCalendarController.loadMonth`, diet day navigation);
- any screen other than the health scaffold and the home dashboard, including screens that display the same controllers.

#### Scenario: A per-tile retry stays granular

- **WHEN** a home dashboard tile's retry is pressed
- **THEN** that arm's granular endpoint is requested and `/api/home-summary` is not

#### Scenario: A write reloads granularly

- **WHEN** water is logged from the water screen
- **THEN** the reload goes to `/api/water` and `/api/health-overview` is not requested

#### Scenario: Span switch stays granular

- **WHEN** the trend card's span is switched to 7 days
- **THEN** `/api/vitals/range` is requested for the 7-day window and no batch request is made

### Requirement: Repeat rounds on a long-mounted screen

Both screens outlive a single load: the health scaffold is a long-mounted shell whose tab and route state live in the URL, and it reloads on `DataRevision` bumps and pull-to-refresh; the home dashboard's controller is app-scoped across sign-ins. Every whole-screen round SHALL therefore issue a fresh batch request with a freshly resolved id token and a freshly computed `day` — a round SHALL NOT be skipped because a previous round already loaded, and no batch response SHALL be cached or replayed for a later round.

The existing concurrency guards SHALL keep governing which write wins:

- the health scaffold's coalescing (`_loading` / `_reloadPending` / the shared completer) SHALL still ensure a bump arriving mid-round runs exactly one more round afterwards;
- the home dashboard's per-arm ticket and generation rules (Invariant W and Invariant P) SHALL still decide every write, with a batch round taking one ticket per arm at its start, so a per-tile retry started after the round still wins its arm regardless of arrival order, and `reset()` still stops an outgoing user's in-flight batch from landing.

#### Scenario: A data-revision bump reloads through the batch

- **WHEN** a `DataRevision` bump arrives after a completed health round
- **THEN** a second `/api/health-overview` request is issued with a freshly computed `day`

#### Scenario: A retry started after a round wins its arm

- **WHEN** a home round's batch request is in flight, a tile retry for one arm is started and completes first, and the batch response then lands
- **THEN** that arm holds the retry's value and the other six hold the batch's

#### Scenario: Sign-out drops an in-flight batch

- **WHEN** a batch round is in flight and `reset()` runs (sign-out)
- **THEN** the response is discarded and no arm is written with the outgoing user's data

### Requirement: The diet-day stand-down is preserved

When the health scaffold's first round runs with `DietDayScreen` mounted below it in the same navigation (a URL-driven entry to `/health/diet`), the scaffold SHALL still stand down from writing the day's meals and target onto `TodayController` / `DailyTargetController` under exactly the conditions it uses today (that controller is loading that same day, or holds that same day in a `loaded` status).

The stand-down SHALL become a decision about **applying** the `meals` and `daily_target` sections, not about issuing requests: the batch request goes out regardless because thirteen other sections depend on it. The existing cover SHALL be preserved — if the claim the scaffold deferred to does not land successfully, the scaffold SHALL still load that controller's day, so the day cannot end up fetched by nobody.

#### Scenario: Standing down does not overwrite the diet day's fetch

- **WHEN** the first health round runs under `/health/diet` while `TodayController` is already loading that same day
- **THEN** the `meals` section is not written onto `TodayController`, and the other sections are applied normally

#### Scenario: A stand-down whose claim fails is still covered

- **WHEN** the scaffold stands down for a day that the deferred-to load then fails to land
- **THEN** the scaffold loads that controller's day itself, so the day is not left unfetched

#### Scenario: No diet day below means no stand-down

- **WHEN** the health scaffold's first round runs with no `/health/diet` in the route stack
- **THEN** the `meals` and `daily_target` sections are applied normally

### Requirement: The last-loaded stamp reflects data actually fetched

Each screen's "updated HH:mm" stamp SHALL advance only when a round actually landed data: for the health screen when at least one overview/trend controller ended the round in its `loaded` status, and for the home dashboard when at least one arm produced a value. The fact that the batch request returned `200` SHALL NOT by itself advance either stamp — a `200` whose every section is `ok: false` is a round that fetched nothing.

#### Scenario: All-failed sections do not advance the stamp

- **WHEN** a round completes with a `200` response whose sections are all `ok: false`
- **THEN** the screen's last-loaded stamp is unchanged from before the round

#### Scenario: A partially successful round advances the stamp

- **WHEN** a round completes with at least one `ok: true` section that lands on an overview card
- **THEN** the stamp advances to that round's time

