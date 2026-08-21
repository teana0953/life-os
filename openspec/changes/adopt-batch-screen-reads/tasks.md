## 1. Shared decoders (D7) — extract, do not rewrite

- [x] 1.1 NOT extracted, deliberately: `VitalsDay` already has a public `fromJson`, which design D7 lists under "nothing is extracted". A wrapper calling it adds a name, not a shared definition, so the batch decoder calls `VitalsDay.fromJson` directly.
- [x] 1.2 Same conclusion as 1.1 — `BowelDay.fromJson` is public and is named in D7's "nothing is extracted" list.
- [x] 1.3 Make `HttpCareTodayRepository._parseSlot` and the `/api/care/today` envelope decode public in `lib/contexts/notifications/infrastructure/http_care_today_repository.dart`
- [x] 1.4 Make `HttpCareHistoryRepository._parseDay` (and its slot decode) public in `lib/contexts/notifications/infrastructure/http_care_history_repository.dart`
- [x] 1.5 Extract the list-shaped decodes into public functions: exercise activities (`lib/contexts/exercise/infrastructure/http_exercise_repository.dart`), favorites (`lib/contexts/health/infrastructure/http_food_dictionary_repository.dart`), budgets (`lib/contexts/finance/infrastructure/http_finance_repository.dart`), balances (`lib/contexts/split/infrastructure/http_split_repository.dart`)
- [x] 1.6 Verify no behaviour moved with the code: existing repository tests under `test/contexts/**` pass unchanged, with no test edited in this section

## 2. The batch module (D1, D2)

- [x] 2.1 Add `lib/shared/screen_batch/section_outcome.dart`: sealed `SectionOutcome<T>` with `ok(T)` / `unavailable` / `reauth`
- [x] 2.2 Add `lib/shared/screen_batch/screen_batch_exceptions.dart`: `ScreenBatchReauthRequired` (401 only) and `ScreenBatchFetchFailure` (everything else)
- [x] 2.3 Add `lib/shared/screen_batch/health_overview_batch.dart`: a typed object with one `SectionOutcome<T>` field per the fourteen section keys, decoded with the D7 functions; `{ok:false}` and an undecodable `data` both become `unavailable`
- [x] 2.4 Add `lib/shared/screen_batch/home_summary_batch.dart`: the same for the seven home section keys, including the null-category budget reduction. The blood-pressure reduction stayed in `HomeDashboardController` instead — `BloodPressureSnapshot` is a presentation type, and importing it here would make `shared/` and that screen import each other.
- [x] 2.5 Add `lib/shared/screen_batch/screen_batch_repository.dart`: `getHealthOverview(idToken, day, trendDays, careDays)` and `getHomeSummary(idToken, day, trendDays)`, building the exact query strings, clamping windows to `1..366`, mapping 401 → `ScreenBatchReauthRequired` and all other non-200/transport/decode faults → `ScreenBatchFetchFailure`
- [x] 2.6 Add `test/shared/screen_batch/screen_batch_repository_test.dart`: parameter strings sent verbatim (`day`, `trend_days`, `care_days`), a missing section key, an all-`ok:false` body, a 401, a 500, a transport throw, an undecodable body
- [x] 2.7 Add `test/shared/screen_batch/health_overview_batch_test.dart` and `home_summary_batch_test.dart`: each section decodes to the same value the granular repository produces from the identical payload

## 3. Per-controller `applyBatchSection` (D2) — one method, one test, each proven equal to `load()`

- [x] 3.1 `lib/contexts/body_profile/presentation/weight_goal_controller.dart`
- [x] 3.2 `lib/contexts/vitals/presentation/trend_controller.dart` — takes the window it was requested for and ignores a section whose window is no longer `spanDays` (D6)
- [x] 3.3 `lib/contexts/health_calendar/presentation/health_calendar_controller.dart` — takes the month it was requested for and ignores a section whose month is no longer `selectedMonth` (D6)
- [x] 3.4 `lib/contexts/health/presentation/today_controller.dart` — day-keyed; also consumes the `daily_target` section (removing the second fetch)
- [x] 3.5 `lib/contexts/health/presentation/daily_target_controller.dart` — day-keyed; consumes the same `daily_target` section instance
- [x] 3.6 `lib/contexts/health/presentation/dictionary_controller.dart` (favorites)
- [x] 3.7 `lib/contexts/hydration/presentation/water_controller.dart` — day-keyed
- [x] 3.8 `lib/contexts/bowel/presentation/bowel_controller.dart` — day-keyed
- [x] 3.9 `lib/contexts/vitals/presentation/vitals_controller.dart` — day-keyed
- [x] 3.10 `lib/contexts/exercise/presentation/exercise_controller.dart` — day-keyed; consumes both `exercise` and `exercise_activities`
- [x] 3.11 `lib/contexts/menstrual/presentation/menstrual_controller.dart`
- [x] 3.12 `lib/contexts/notifications/presentation/care_today_controller.dart`
- [x] 3.13 `lib/contexts/notifications/presentation/care_history_controller.dart` — window-keyed against `spanDays`, and ignores the section entirely when `period.spanDays` is `null` (custom range)
- [x] 3.14 For each controller above, a test in its existing `test/contexts/**` suite asserting `applyBatchSection(ok(payload))` leaves the controller in the identical state as `load()` of the same payload — value, status enum, `error`, and `lastLoadedAt`
- [x] 3.15 For each controller above, a test that `unavailable` reaches that controller's own fetch-failed state (not empty, not reauth) and `reauth` reaches its re-auth state

## 4. Health screen switch-over (D3, D4, D6, D8)

- [x] 4.1 In `lib/contexts/health/presentation/health_scaffold.dart`, take the new `ScreenBatchRepository` as a constructor dependency
- [x] 4.2 Rewrite `_load` to compute `day` once, read `trendController.spanDays` and `careAdherenceController.spanDays` once, and issue a single `getHealthOverview`
- [x] 4.3 Fan out the fourteen sections through the `applyBatchSection` methods, replacing the thirteen `load()` calls in the `Future.wait`
- [x] 4.4 Convert a `ScreenBatchReauthRequired` / `ScreenBatchFetchFailure` throw into `reauth` / `unavailable` for every section and run the same fan-out (one apply path, D5)
- [x] 4.5 Turn the `/health/diet` stand-down into an apply-gate for `meals` and `daily_target`, keeping `_coverStandDown` as the granular follow-up (D8)
- [x] 4.6 Fall back to a granular load for the one card whose window/month the batch could not describe (custom care period, non-current calendar month), leaving the other sections applied
- [x] 4.7 Keep `_lastOverviewLoadAt` keyed on a controller reaching `loaded`, never on the request returning 200
- [x] 4.8 Update `lib/app.dart`'s `HealthScaffold(` construction to pass the repository
- [x] 4.9 Construct the repository once in `lib/main.dart` beside the other repositories, using the shared 15s `TimeoutClient` (D10)

## 5. Home dashboard switch-over (D4, D9)

- [x] 5.1 In `lib/contexts/user/presentation/home_dashboard_controller.dart`, take the `ScreenBatchRepository` as a dependency and update `lib/main.dart`'s construction
- [x] 5.2 Replace `_load`'s seven-`_runArm` fan-out with one `getHomeSummary(day: dayString(now), trendDays: 366)`
- [x] 5.3 Take one ticket per arm at the start of the round and write each arm only under `_mayWrite(arm, generation, ticket)` (Invariant W preserved)
- [x] 5.4 Preserve Invariant P and the page-level rules: `loaded` on any arm landing, `error` only when all seven failed, `data = null` only when nothing carried over, `lastLoadedAt` only on a round that landed something
- [x] 5.5 Leave `_runArm`/`_fetchArm` in place for `retryArm`, which stays granular

## 6. Guards for the spec's scenarios

- [x] 6.1 `test/contexts/health/presentation/health_scaffold_batch_test.dart`: assert from a **recorded request list** that a whole-screen load makes exactly one request, to `/api/health-overview`, and that none of the fourteen granular paths was requested
- [x] 6.2 Same shape for the home dashboard round in `test/contexts/user/` — exactly one request, to `/api/home-summary`
- [x] 6.3 One `ok:false` section → that card failed, the rest loaded, no whole-screen error and no re-auth exit
- [x] 6.4 All sections `ok:false` on a 200 → every card failed, still no whole-screen error, stamp unchanged
- [x] 6.5 Request-level failures: transport throw and 500 → every card failed, none left on `loading`, no re-auth; 401 → re-auth exit on both screens
- [x] 6.6 Home total failure on a first-ever round → `status == error`, `data == null`, whole-dashboard card with its retry
- [x] 6.7 Day guard with a clock whose local date differs from its UTC date (e.g. 2026-08-20 07:00 at UTC+8) → the request's `day` is the local day; run the suite under both `flutter test` and `TZ=UTC flutter test`
- [x] 6.8 A response for day D landing after the screen moved to D+1 → no day-scoped controller written (fake whose completion the test controls, not a zero-delay fake)
- [x] 6.9 Window guards: `trend_days`/`care_days` carry the cards' current spans; a span switched in flight is not overwritten; a custom care period ignores `care_range` and loads granularly while the rest applies
- [x] 6.10 Calendar guard: card paged to another month is not overwritten by the section
- [x] 6.11 Granular-only paths: a per-tile `retryArm`, a water write's reload, and a `setSpan` each hit their granular endpoint and make no batch request
- [x] 6.12 Repeat-round guards: a `DataRevision` bump issues a second batch request with a freshly computed day; a retry started mid-round wins its arm while the other six land; `reset()` mid-round discards the response
- [x] 6.13 Stand-down guards: `app_diet_day_duplicate_fetch_test.dart` and `app_tracker_load_test.dart` pass unchanged, plus a new guard that the stand-down does not write `meals` while the diet day's own load is in flight, and that a failed claim is still covered
- [x] 6.14 Duplicate-fetch guard: a health load applies `daily_target` to both controllers and issues no second target request

## 7. Verification

- [x] 7.1 `flutter analyze` clean and `flutter test` green; then `TZ=UTC flutter test` green (both timezones, per the repo's two opposite failure modes)
- [x] 7.2 Mutation-check the new guards: delete the apply-gate, map `ok:false` to a whole-screen error, drop `day` from the query string, replace `trend_days` with a constant, delete the day check — each must turn a named test red; record which test caught which mutant
- [ ] 7.3 Run the app against the deployed backend and confirm in the network panel: one request per health load, one per home load, `day` equal to the local day, and a forced section failure painting exactly one empty card
