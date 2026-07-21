# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` before finishing. Widget tests inject fakes via `l10nTestApp`.
Derive all colors from `Theme.of(context)` — no hard-coded hex. Every
user-facing string comes from an ARB key (add to `app_en.arb` with a
description, `app_zh_Hant.arb`, and `app_zh.arb`, then run `flutter gen-l10n`
and commit the regenerated `lib/l10n/generated/*.dart`). Mirror the diet
`daily-target` code as the closest template.

## 1. Domain + application (hydration context)

- [x] 1.1 `lib/contexts/hydration/domain/water_day.dart` — `WaterDay { day,
      totalMl, targetMl, remainingMl }`. `lib/contexts/hydration/domain/
      water_repository.dart` — `WaterRepository` port: `getDay(day)`,
      `addWater(day, addMl)`, `setTarget(day, targetMl)`, each returning the
      updated state as needed.
- [x] 1.2 Test first (fake repo) then implement use cases in
      `lib/contexts/hydration/application/`: `GetWaterDay`, `AddWater`,
      `SetWaterTarget` — thin, delegate to the port.

## 2. Infrastructure: HttpWaterRepository

- [x] 2.1 Test first with a mock `http.Client`: `HttpWaterRepository`
      (`lib/contexts/hydration/infrastructure/`) maps
      `GET /api/water?day=` → `WaterDay` (fields `day`, `total_ml`, `target_ml`,
      `remaining_ml`), `POST /api/water {day, add_ml}` → updated total,
      `PUT /api/water/target {day, target_ml}` → set target; sends the bearer
      `idToken`; surfaces a typed error on non-200 (401 distinguishable for
      reauth), never crashes.

## 3. WaterController

- [x] 3.1 Test first (fake `WaterRepository`): `WaterController` (ChangeNotifier,
      `lib/contexts/hydration/presentation/`) loads a day; `addWater(ml)` and
      `correct(-ml)` update total + remaining and reload/patch state; `setTarget`
      updates the target; exposes loading / loaded / error / needsReauth states
      (mirror `DailyTargetController`/`HomeController` patterns). A 401 surfaces
      a needsReauth state, not a crash. **Contract note**: the backend
      `POST /api/water` returns only `{ day, total_ml }` (already clamped ≥0), not
      the target/remaining — take the displayed total from the POST response (or
      re-GET the day) rather than local arithmetic, so the "never below zero" and
      over-target readouts stay consistent with the backend.

## 4. WaterScreen

- [x] 4.1 Test first (widget, `l10nTestApp`, inject fake controller/use cases):
      `WaterScreen` (`lib/contexts/hydration/presentation/`) shows the
      total-over-target readout + a progress bar; the quick-add buttons ＋250ml
      / ＋500ml call `addWater`; the custom-amount dialog (empty-zero numeric)
      adds an arbitrary amount; the −250ml control calls `correct`; a target
      control sets the target. Over-target: the progress bar fill **clamps at
      100%** (goal met — never a negative or overflowing bar). Loading/error/
      reauth render without crashing. All copy
      via ARB keys; assert against `lookupAppLocalizations(locale).<key>`.

## 5. Wire the water tab into the diet shell

- [x] 5.1 Test first (extend `diet_shell_screen_test.dart`): the shell's
      bottom `NavigationBar` has a third **飲水** destination; selecting it shows
      `WaterScreen` for the shell's viewed day. Existing 今日 / 目標 tabs and the
      day navigation still work.
- [x] 5.2 Implement in `diet_shell_screen.dart`: add the `WaterScreen` to the
      `IndexedStack` and a `NavigationDestination` (water-drop icon,
      `loc.dietTabWater`), passing the shell's `_day` + `idToken`. Thread a
      required `waterController` param through `DietShellScreen`.
      **The shell owns loading** — `DailyTargetScreen`/`TodayScreen` do NOT
      self-load; the shell calls `dailyTargetController.load(token, _day)` /
      `todayController.load(token, _day)` in `_load()` (initState) and
      `_reloadCurrentDay()` (on day change). So ALSO call
      `waterController.load(token, _day)` in BOTH `_load()` and
      `_reloadCurrentDay()`, otherwise the water tab never loads and does not
      follow day navigation (required by spec: "changing the viewed day updates
      the water screen too"). Note: the `_DayNavBar` day switcher lives only in
      the Today tab's header; the water tab shares the shell's `_day` but has no
      switcher of its own (acceptable — spec doesn't require one on the water tab).

## 6. DI wiring + regression

- [x] 6.1 `main.dart`: construct `HttpWaterRepository(baseUrl: apiBaseUrl)` + the
      three use cases + a `WaterController`. Thread it exactly like
      `healthDailyTargetController` — the real path is
      **main.dart → `App(...)` → `_AuthenticatedHome` → `HomeScreen` →
      `DietShellScreen`**, so add a `waterController` field + constructor param to
      BOTH `App` and `_AuthenticatedHome` in `lib/app.dart` (forwarding it), pass
      it in main.dart's `App(...)` call, add it to `HomeScreen`'s constructor, and
      forward it in HomeScreen's `_openHealth` push of `DietShellScreen`.
- [x] 6.2 Update the existing `HomeScreen(...)` construction call sites for the
      new required param: `lib/app.dart`'s `_AuthenticatedHome` build, and
      `test/contexts/user/presentation/home_screen_test.dart` +
      `home_screen_responsive_test.dart` (inject a fake `WaterController`), so
      analyze/tests still compile.
- [x] 6.3 `flutter analyze` clean + `flutter test` green — existing diet/shell
      tests still pass; regenerate and commit `lib/l10n/generated/*.dart`.
