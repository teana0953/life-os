# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` before finishing. Widget tests inject fakes via `l10nTestApp`.
Colors from `Theme.of(context)` — no hard-coded hex. Every user-facing string via
an ARB key (add to `app_en.arb` with description + `app_zh_Hant.arb` + `app_zh.arb`,
run `flutter gen-l10n`, commit regenerated `lib/l10n/generated/*.dart`). The
`water-ui` code is the closest template. **Reuse the shared widgets** in
`lib/shared/widgets/` (ledge_card, async_state_scaffold, numeric_amount_field)
and `lib/shared/date/day_format.dart`.

## 0. Extract shared TrackerDayHeader (do first — genuine dedup, behavior-preserving)

- [x] 0.1 Extract the "viewed date + today-vs-history title" header currently in
      `water_screen.dart` into `lib/shared/widgets/tracker_day_header.dart`
      (`TrackerDayHeader({required day, required clock, required todayTitle,
      required historyTitle})`, using `daysBetween`/`fullDateLabel`). Migrate
      `water_screen.dart` to use it. This is behavior/pixel-preserving — existing
      water tests must stay GREEN with assertions UNCHANGED. `bowel_screen` will
      reuse it. `flutter test` green before moving on.

## 1. Domain + application (bowel context)

- [x] 1.1 `lib/contexts/bowel/domain/bowel_day.dart` — `BowelDay { day, count,
      isNormal (bool?), note }` (snake_case fromJson: `count`, `is_normal`, `note`).
      `bowel_repository.dart` — `BowelRepository` port: `getDay(day)`,
      `save(day, {count, isNormal, note})`.
- [x] 1.2 Test first (fake repo) then implement `GetBowelDay`, `SaveBowelDay` in
      `lib/contexts/bowel/application/` — thin, delegate to the port.

## 2. Infrastructure: HttpBowelRepository

- [x] 2.1 Test first with a mock `http.Client`: `HttpBowelRepository`
      (`lib/contexts/bowel/infrastructure/`) maps `GET /api/bowel?day=` → `BowelDay`
      (`day`, `count`, `is_normal` nullable, `note`) and `PUT /api/bowel
      {day, count, is_normal, note}` → the saved `BowelDay`; sends the bearer
      `idToken`; surfaces a typed error on non-200 (401 distinguishable for
      reauth), never crashes.

## 3. BowelController

- [x] 3.1 Test first (fake `BowelRepository`): `BowelController` (ChangeNotifier)
      loads a day and populates an editable draft (count/isNormal/note); mutating
      the draft (`setCount`, `setIsNormal`, `setNote`) updates it without saving;
      `save()` upserts via the port then reflects the saved state; loading a
      different day resets the draft; exposes loading / loaded / saving / error /
      needsReauth. A 401 (load or save) surfaces needsReauth, not a crash; a save
      failure surfaces an error state (for the screen's SnackBar).

## 4. BowelScreen

- [x] 4.1 Test first (widget, `l10nTestApp`, fake controller): `BowelScreen`
      (`lib/contexts/bowel/presentation/`) shows `TrackerDayHeader` (今日排便 /
      排便紀錄 + date); a count stepper (−/＋, floor 0) drives `setCount`; a
      normal/abnormal `SegmentedButton` (nullable — nothing selected when isNormal
      is null) drives `setIsNormal`; a multiline note field drives `setNote`; a
      **Save** button calls `save()`, is disabled while saving, and shows a
      SnackBar on save failure. Loading/error/reauth render via `AsyncStateScaffold`
      without crashing. All copy via ARB keys; assert against
      `lookupAppLocalizations(locale).<key>`.

## 5. Wire the 排便 tab into the diet shell

- [x] 5.1 Test first (extend `diet_shell_screen_test.dart`): the bottom
      `NavigationBar` has a fourth **排便** destination; selecting it shows
      `BowelScreen` for the viewed day; the existing 今日/目標/飲水 tabs and day
      navigation still work.
- [x] 5.2 Implement in `diet_shell_screen.dart`: add `BowelScreen` to the
      `IndexedStack` + a `NavigationDestination` (e.g. `Icons.wc`,
      `loc.dietTabBowel`), passing `_day` + `idToken`. Thread a required
      `bowelController` param through `DietShellScreen`, and call
      `bowelController.load(token, _day)` in BOTH `_load()` and
      `_reloadCurrentDay()` (mirroring water). No day switcher on the bowel tab
      (shares the shell's `_day`).

## 6. DI wiring + regression

- [x] 6.1 `main.dart`: construct `HttpBowelRepository(baseUrl: apiBaseUrl)` + the
      two use cases + a `BowelController`, threaded main.dart → `App` →
      `_AuthenticatedHome` → `HomeScreen` → `DietShellScreen` (add a
      `bowelController` field/param to `App` + `_AuthenticatedHome` in
      `lib/app.dart`, pass it in main.dart's `App(...)`, add to `HomeScreen`'s
      constructor, forward in `_openHealth`).
- [x] 6.2 Update the existing `HomeScreen(...)` construction call sites for the
      new required param: `lib/app.dart`'s `_AuthenticatedHome` build, and
      `test/contexts/user/presentation/home_screen_test.dart` +
      `home_screen_responsive_test.dart` (inject a fake `BowelController`).
- [x] 6.3 `flutter analyze` clean + `flutter test` green — existing diet/water/
      shell/home tests still pass; regenerate and commit `lib/l10n/generated/*.dart`.
