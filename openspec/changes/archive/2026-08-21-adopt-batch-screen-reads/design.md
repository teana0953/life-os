## Context

life-os-backend PR #117 (issue #114) shipped two batch read endpoints and nothing consumes them. The contract is fixed and authoritative — `openspec/specs/screen-batch-reads/spec.md` in that repo, with the handlers in `src/adapters/http/routes/health-overview.ts` and `home-summary.ts`:

| endpoint | required | optional | default | sections |
| --- | --- | --- | --- | --- |
| `GET /api/health-overview` | `day=YYYY-MM-DD` | `trend_days`, `care_days` | 30, 30 (each `1..366`) | 14 |
| `GET /api/home-summary` | `day=YYYY-MM-DD` | `trend_days` | 366 (`1..366`) | 7 |

Every section is `{ ok: true, data }` or `{ ok: false, error: "unavailable" }`; the response is `200` whenever the caller is authenticated and the parameters valid, **even when every section failed**; every section key is always present; each section's `data` is the same JSON the granular endpoint returns; each section is bounded server-side by an 8s fuse. `day` has **no** server-UTC fallback — absent or malformed is `400`.

On the client side:

- `HealthScaffold._load` awaits a `Future.wait` of thirteen controller loads producing fifteen requests, and carries three pieces of hard-won behaviour that this change must not disturb: reload coalescing (`_loading`/`_reloadPending`/`_refreshCompleter`), the `/health/diet` stand-down from issue #171 with its `_coverStandDown` follow-up, and `_lastOverviewLoadAt` advancing only when a controller genuinely reached `loaded`.
- `HomeDashboardController._load` fans out to seven `_runArm` calls under **Invariant W** (per-arm ticket + generation decide every write) and **Invariant P** (only a full round writes `status`/`lastLoadedAt`). `ArmSlot` exists because an incident showed a failed arm painting as "no data".

Two repo-specific hazards shape the design more than anything else:

1. **Shared controller vs. screen day.** This client has repeatedly shipped code that displays day A while holding day B — enough times that the fix pattern (day-keyed predicates, generation tickets, dropping the outgoing month/day synchronously) is present in `TodayController`, `DailyTargetController`, `HealthCalendarController` and `CareHistoryController` already. A batch request makes this hazard *wider*: one wrong `day` is now wrong for the whole screen at once.
2. **Route/tab state lives in the URL** (`go_router`, nested routes, `?tab=`), so neither screen gets a fresh instance per load. The health scaffold is long-mounted and reloads on `DataRevision` bumps; `HomeDashboardController` is app-scoped across sign-ins. Nothing here may assume "one screen, one load".

## Goals / Non-Goals

**Goals:**

- One request per whole-screen load on both screens, with the fan-out landing each controller in exactly the state its own granular load would have produced.
- A section's `ok: false` reaching precisely the per-card failure state that card already has — one empty card, never a whole-screen error.
- `day` always sent, always equal to the day the screen displays, and never applied to a screen that has moved on.
- Zero change to what any card renders, to any write path, and to any per-card retry.

**Non-Goals:**

- Any backend change. The endpoints are deployed; this is the client half only.
- Batching the finance screen (5 requests) — the backend deliberately did not ship an endpoint for it.
- Caching, ETags, or persisting a batch response between rounds.
- Reworking the controllers' internal models, statuses, or error taxonomies.
- Fixing `TodayStatus.error`'s undiscoverable dead end (a pre-existing gap tracked separately).

## Decisions

### D1 — The batch adapter is one cross-context module, not thirteen per-context pieces

A new `lib/shared/screen_batch/` module holds: the HTTP repository (`ScreenBatchRepository`) that issues the two requests, the envelope/section decoding, and the two typed response objects (`HealthOverviewBatch`, `HomeSummaryBatch`) whose fields are already-decoded domain values wrapped in a per-section outcome.

*Alternative considered: a `getHealthOverview` method on each context's repository, each decoding its own slice.* Rejected — every one of them would have to parse the same envelope and share one HTTP call, so they would need a common owner anyway; thirteen partial owners is the worst version of that.

*Alternative considered: a `screens` context with its own domain.* Rejected for the same reason the backend rejected it (its D1): "what the health screen renders" is a presentation grouping, not a domain fact. `app.dart` is already the single place holding every repository, so it is where this composition belongs.

The module depends on the contexts, never the reverse.

### D2 — Fan-out is an explicit `applyBatchSection` on each controller, never a hidden prefetch cache

Each controller gains exactly one new entry point that takes a section outcome and writes the controller's own state — the same fields, statuses and `lastLoadedAt` its `load()` writes.

*Alternative considered: seeding a cache inside each HTTP repository so the existing `load()` calls resolve from memory.* Rejected, and it is the tempting one. It makes `load()` mean two different things depending on invisible state, it needs an invalidation rule nobody will maintain, and this repo has already shipped the failure mode it invites — data flowing through a path the reader cannot see (the split-installments "field the client cannot read is the field the next save deletes" incident). An explicit method makes the batch path greppable and mutation-testable.

The outcome type is deliberately three-valued rather than nullable:

```dart
sealed class SectionOutcome<T> { }   // ok(T) | unavailable | reauth
```

`unavailable` covers both `{ ok: false }` and a `data` that fails to decode — the card cannot act differently on them. `reauth` is produced only by a request-level `401` (D5). Each controller maps the three onto **its own** enum, so the mapping lives beside the enum it targets, and no new status value is introduced anywhere.

### D3 — One clock read per round; `day` is threaded, never recomputed

Each round computes its day string once and passes that same value into the request, into every day-keyed apply-guard, and into whatever the screen labels. Recomputing `_todayString(widget.clock())` at apply time is forbidden: a round that straddles midnight would then request one day and gate on another, which is the exact shape of this repo's most-repeated bug.

Day-scoped sections (`meals`, `daily_target`, `water`, `bowel`, `vitals`, `exercise`, plus home's `daily_target`) are applied only if the controller is still on the requested day — reusing the day-keyed predicates already there (`holdsDay`, `isLoadingDay`, the `ArmSlot` tickets), not a new mechanism.

### D4 — Only a whole-screen round uses the batch

The batch is used by `HealthScaffold._load` and by `HomeDashboardController.load` — and by nothing else. Writes and their reloads, per-tile `retryArm`, `setSpan`, `setPeriod`, `loadMonth`, and every other screen keep their granular endpoints, which the backend guarantees are unchanged.

**This is the one place the issue's wording needs interpretation and it is recorded rather than silently resolved.** Issue #114 calls the batch "a first-paint optimisation only… granular for writes, single-card retries, and refreshes". Taken literally, a `DataRevision`-driven reload or a pull-to-refresh — both of which are *whole-screen* rounds — would go back to fifteen requests. We interpret "refreshes" as *card-level* refreshes: every whole-screen round batches, nothing narrower ever does.

*Alternative considered: batch only the first round of a screen's lifetime.* Rejected on two counts. It leaves the 15-request cost on the reload path that runs after every chaodays import and every care edit, which is exactly when the user is watching; and it leaves two load paths in one screen, one of them rarely exercised — the arrangement in which this repo's guards have repeatedly turned out to be testing the path that was not broken.

### D5 — Request-level failure is applied to every card; only `401` is a re-auth

`ScreenBatchRepository` throws two typed failures: `ScreenBatchReauthRequired` for `401`, `ScreenBatchFetchFailure` for everything else (transport, timeout, `400`, `4xx`, `5xx`, undecodable body). The screen converts the throw into a `reauth`/`unavailable` outcome **for every section**, then runs the same fan-out it runs on success. There is one apply path, not a success path and a separate failure path.

`400` is deliberately not its own user-visible mode: it can only mean the client sent a bad `day` or an out-of-range window, i.e. a client bug, and "unavailable" is the honest thing to tell a user about a client bug. It is prevented at source instead — `day` is always formatted, and both window values are clamped to `1..366` before they are sent (D6).

### D6 — Every parameter is sent explicitly; a card whose window does not match falls back alone

`trend_days` comes from `TrendController.spanDays` (7/30/90) on health and is sent as `366` on home; `care_days` comes from the trend tab's `CareHistoryController.spanDays`. Nothing relies on a server default even where the default happens to match — a default changed on either side would move a window silently, and the two defaults differ between the endpoints on purpose (30 vs 366), which is precisely the kind of asymmetry a silent default gets wrong.

Verified, not assumed: home's existing arm computes `from = today − 365 days`, an inclusive 366-day window; `trend_days=366` yields `[day − 365, day]`. They agree.

Two windows cannot always be expressed:

- `CareHistoryPeriod.spanDays` is `int?` — `null` for a custom date range.
- A span outside `1..366` would be a `400`.

In either case `care_days` (resp. `trend_days`) cannot describe the card, so the batch is issued **without applying that section**: that one card loads from its granular endpoint and the other twelve are applied normally. The same rule covers a window changed while the request was in flight — the response is checked against the card's current window at apply time, not at request time. `health_calendar` gets the identical treatment against the calendar card's `selectedMonth`.

Cost accepted: a user on a custom care period pays 1 + 1 requests instead of 1. That is still thirteen fewer than today.

### D7 — Decoders become shared functions, so batch and granular cannot drift

The batch section `data` is the granular body, so the correct decoder already exists — but several repositories decode inline in a private method (`HttpCareTodayRepository._parseSlot`, `HttpCareHistoryRepository._parseDay`, `HttpVitalsRepository._parse`, `HttpBowelRepository._parse`, the activities/favorites/budgets/balances list-shaped decodes). Each becomes a public top-level function in its context's infrastructure, called by both the granular repository and the batch decoder — one definition rather than two that agree today. This mirrors the backend's own D7 for the same reason.

Where a domain type already has a public `fromJson` (`WeightGoal`, `VitalsRange`, `VitalsDay`, `HealthCalendar`, `DayMealsLog`, `DailyTargetWithRemaining`, `WaterDay`, `BowelDay`, `ExerciseDay`, `MenstrualOverview`, `FoodItem`, `FinanceBudget`, `MonthlyNetWorth`, `Balance`), the batch decoder calls it directly and nothing is extracted.

### D8 — The `/health/diet` stand-down becomes an apply-gate

Today the stand-down decides whether to *issue* the meals/target requests. With one batch request that carries thirteen other sections, the request goes out regardless, so the stand-down moves to the apply step: under the existing conditions (`isLoadingDay(day)`, or `holdsDay(day) && status == loaded`) the `meals` / `daily_target` sections are simply not written onto those two controllers.

`_coverStandDown` is kept verbatim in intent: a stand-down is still a bet that the deferred-to claim lands, and if it does not, the scaffold still issues that controller's own granular load. It cannot instead apply the held section — by the time the claim settles the section is of unknown age, and the whole point of the cover is to get the day fetched, not to get it filled.

### D9 — Home's Invariant W is extended to a batch round, not bypassed

A batch round takes **one ticket per arm at its start**, exactly as if it had started seven fetches, and each section is written only if `_mayWrite(arm, generation, ticket)` still holds. Consequences preserved verbatim: a per-tile retry started after the round wins its arm whatever the arrival order, the other six arms still land, `reset()` still stops an outgoing user's in-flight round, and `retryArm` still writes neither `status` nor `lastLoadedAt` (Invariant P).

`_runArm`/`_fetchArm` stay — they are what `retryArm` uses. The batch adds a parallel write path under the same invariant, it does not replace the granular one.

### D10 — The batch goes through the ordinary 15s client, and the whole screen now rides one deadline

`ScreenBatchRepository` is constructed with the same `TimeoutClient(httpRequestTimeout)` (15s) every other repository uses, not the 120s long-running one. The backend's per-section fuse is 8s and sections measure ~8ms, so a healthy batch response is an order of magnitude inside the deadline, and a pathological one is bounded server-side before the client deadline can fire.

Accepted trade-off, stated plainly: previously a hung request emptied one card while fourteen others painted; now a hung request empties the screen for up to 15s. The backend's 8s fuse is what makes that acceptable, and it is a backend guarantee this client is relying on — if it were removed, this change would need its own client-side per-screen fallback.

### D11 — Test hazards specific to this change

Recorded because each one produces a guard that passes whether or not the feature works — the failure mode this repo has hit most often:

- **"One request" must be asserted from a recorded request list**, not from "the batch repository was called". A stub batch repository plus a forgotten controller `load()` passes the second and fails the first.
- **A zero-delay fake closes the observation window before the first `pump`.** Any test about in-flight ordering (span changed mid-flight, retry vs round, `reset()` mid-flight) needs a fake whose completion the test controls.
- **The day guard needs a clock whose local date differs from its UTC date** (e.g. 2026-08-20 07:00 at UTC+8). A fixture where the two agree passes with the bug present. This suite must be run both ways: `flutter test` (local UTC+8) and `TZ=UTC flutter test`.
- **The "failed section is not an empty card" guards must assert the rendered distinction**, not just the controller enum, for the cards where empty is legitimate.
- **Every guard added here gets mutated**: delete the apply-gate, flip `ok:false` to a whole-screen error, drop `day` from the query, swap `trend_days` for a constant — each must turn something red.

## Risks / Trade-offs

- **One request means one point of failure for a whole screen** → mitigated by D5's fan-out of a request-level failure onto every card's existing failure state (so nothing hangs on `loading`), and by the backend's 8s per-section fuse bounding the wait.
- **A section applied to the wrong day/window/month is a silent data lie** — this repo's most-repeated bug class, now with a wider blast radius → mitigated by D3 (one clock read, threaded day) and D6 (apply-time window/month check, granular fallback), and by reusing the existing day-keyed predicates rather than inventing a second mechanism.
- **Thirteen new `applyBatchSection` methods are thirteen new chances for a controller to end in a state its own `load()` never produces** → mitigated by specifying the equality directly ("indistinguishable from its granular load of the same payload") and testing each controller's method against its `load()` on the same payload.
- **Decoder extraction touches working granular code** → the extracted function is the same code moved, called by the same repository; the existing repository tests are the regression guard, and no behaviour is added during the move.
- **The stand-down interaction is subtle and was already expensive to get right (#171)** → D8 keeps both halves (gate + cover) and the change is confined to gating the *write* instead of the *request*; its existing tests (`app_diet_day_duplicate_fetch_test.dart`, `app_tracker_load_test.dart`) stay as they are and must keep passing.
- **Partial adoption looks finished but is not**: a controller left calling its own `load()` inside `_load` keeps a request alive and the "one request" claim is then false → the recorded-request-list assertion is the guard that catches it.
- **A screen whose card windows are unusual (custom care period) pays extra requests** → accepted; still 2 instead of 15.

## Migration Plan

Client-only and shippable in one PR; the backend endpoints are already live, so there is no ordering constraint and nothing to deploy on the server side.

Order that keeps the tree green at every step: (1) shared decoders extracted; (2) `screen_batch` module + repository + its tests; (3) `applyBatchSection` on each controller, each with its own test, while `_load` still calls `load()` — nothing is wired yet; (4) health scaffold switched over; (5) home dashboard switched over; (6) the guards that assert the request count.

Rollback is reverting the two call sites (steps 4–5): every granular path is still present and still tested, so the previous behaviour is one revert away without touching the controllers or the backend.

Verification is a measurement, not an assertion: run the real app against the deployed backend with the network panel open and confirm one request per screen load; confirm a forced section failure paints one empty card; confirm a UTC+8 morning load sends the local day.

## Open Questions

- **Should `favorite_food_items` be applied to `DictionaryController` at all?** It is not day-scoped and feeds the food picker rather than a card — the backend's own design flags it as the one section a reviewer might cut. Applying it costs nothing here (it is already in the response), so we do; if it is ever dropped backend-side, `DictionaryController.load()` is the fallback.
- **`care_today` is computed from the server's `new Date()`, not from `day`.** That matches the granular `/api/care/today` exactly, so nothing changes — but it means the care card's "today" and the screen's `day` can disagree for a UTC+8 user near midnight, identically to how they can today. Out of scope here; noted so the next reader does not mistake it for something this change introduced.
- **Whether the OPTIONS preflight also collapses** to one per screen is unmeasured (the backend ships `Access-Control-Max-Age: 7200`, but the OPTIONS:GET ratio was never re-measured). The request-count win is claimed for GETs only.
