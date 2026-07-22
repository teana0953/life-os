# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` before finishing. Widget tests inject fakes via `l10nTestApp`.
Colors from `Theme.of(context)` — no hard-coded hex. Every user-facing string via
an ARB key (add to `app_en.arb` with description + `app_zh_Hant.arb` + `app_zh.arb`,
run `flutter gen-l10n`, commit regenerated `lib/l10n/generated/*.dart`). The
`bowel-ui` code is the closest template. **Reuse the shared widgets**
(`lib/shared/widgets/{ledge_card,async_state_scaffold,tracker_day_header,
numeric_amount_field}.dart`).

## 1. Domain + application (vitals context)

- [x] 1.1 `lib/contexts/vitals/domain/vitals_day.dart` — `BpReading {systolic,
      diastolic, pulse (int?)}`, `GlucoseReading {label, value}`, `Spo2Reading
      {spo2, pulse (int?)}`, `VitalsDay { day, weightKg (num?), bodyFatPct (num?),
      bpReadings, glucoseReadings, spo2Readings }` (snake_case fromJson: weight_kg,
      body_fat_pct, bp_readings, glucose_readings, spo2_readings, and each reading's
      fields). `vitals_repository.dart` — `VitalsRepository` port: `getDay(day)`,
      `save(day, VitalsDay-ish payload)`.
- [x] 1.2 Test first (fake repo) then implement `GetVitalsDay`, `SaveVitalsDay` in
      `lib/contexts/vitals/application/` — thin, delegate to the port.

## 2. Infrastructure: HttpVitalsRepository

- [x] 2.1 Test first with a mock `http.Client`: `HttpVitalsRepository`
      (`lib/contexts/vitals/infrastructure/`) maps `GET /api/vitals?day=` →
      `VitalsDay` and `PUT /api/vitals` (the full snake_case body incl. the three
      arrays) → the saved `VitalsDay`; sends the bearer `idToken`; typed error on
      non-200 (401 distinguishable for reauth); the three reading arrays
      round-trip (incl. a null pulse).

## 3. VitalsController

- [x] 3.1 Test first (fake `VitalsRepository`): `VitalsController` (ChangeNotifier)
      loads a day into an editable draft — weightKg, bodyFatPct, and three MUTABLE
      lists. Mutations (`setWeight`, `setBodyFat`; and per list: add / update a
      field of a row / remove a row) update the draft without saving; `save()`
      upserts via the port then reflects the saved state; loading a different day
      resets the draft; a save ERROR keeps the draft (only a day change resets);
      exposes loading / loaded / saving / error / needsReauth and
      `hasUnsavedChanges` (draft vs loaded). 401 → needsReauth.
      **CRITICAL — hasUnsavedChanges over the lists**: the draft lists are separate
      instances from the loaded `day`'s lists, so a bowel-style `bpReadings !=
      day.bpReadings` is IDENTITY comparison and is always true (Save would be
      permanently enabled, failing the "Save is gated on unsaved edits" scenario).
      Give `BpReading`/`GlucoseReading`/`Spo2Reading` VALUE equality (`==`/`hashCode`
      or Equatable) AND compare the lists ELEMENT-WISE with `listEquals`
      (`package:flutter/foundation.dart`). Include a test: a freshly loaded day has
      `hasUnsavedChanges == false`; it flips true after adding/editing/removing a
      row; and returns to false after a successful save.

## 4. VitalsScreen

- [x] 4.1 Test first (widget, `l10nTestApp`, fake controller): `VitalsScreen`
      (`lib/contexts/vitals/presentation/`) shows `TrackerDayHeader` (今日數值 /
      數值紀錄 + date); weight + body-fat fields drive `setWeight`/`setBodyFat`;
      three list sections (blood pressure / glucose / blood oxygen) each render
      their rows, an "add" control appends a row, a remove control drops a row, and
      editing a row's field updates the draft; a **Save** button calls `save()`,
      is disabled unless `hasUnsavedChanges`, disabled while saving, and shows a
      SnackBar on save failure. Loading/error/reauth via `AsyncStateScaffold`. All
      copy via ARB keys.
- [x] 4.2 Implement the three list sections with ONE screen-local generic widget
      (e.g. `_ReadingListSection<T>` taking a title, the rows, a row builder, an
      add callback, and a remove callback) so blood pressure / glucose / blood
      oxygen don't duplicate layout. Glucose row's label offers 餐前/餐後 quick
      picks + free text; colors from Theme.
      **Nullable scalars — empty→null, NOT empty→0**: weight and body-fat are
      nullable ("未記錄"). Do NOT use `NumericAmountField` (its `hintText:'0'` +
      empty-zero would persist 0 for an unrecorded metric) for these two — use a
      plain `TextField` that maps empty-string → null. The REQUIRED per-reading
      numeric fields (systolic/diastolic/value/spo2) may keep empty-zero; the
      optional pulse maps empty → null.
      **Row TextEditingController lifecycle**: unlike bowel's single note
      controller, each list row's editable fields need controllers created when a
      row is added, disposed when the row is removed, and re-synced on reload —
      OR (simpler, recommended) use raw `TextField`s seeded from the draft each
      build with `onChanged` writing back to the controller (no per-row
      TextEditingController to manage), so there are no leaks or stale text.

## 5. Wire the 數值 tab into the diet shell

- [x] 5.1 Test first (extend `diet_shell_screen_test.dart`): the bottom
      `NavigationBar` has a fifth **數值** destination; selecting it shows
      `VitalsScreen` for the viewed day; the existing 今日/目標/飲水/排便 tabs and
      day navigation still work.
- [x] 5.2 Implement in `diet_shell_screen.dart`: add `VitalsScreen` to the
      `IndexedStack` + a `NavigationDestination` (`Icons.monitor_heart`,
      `loc.dietTabVitals`), passing `_day` + `idToken`. Thread a required
      `vitalsController` param through `DietShellScreen`, and call
      `vitalsController.load(token, _day)` in BOTH `_load()` and
      `_reloadCurrentDay()` (mirroring bowel). No day switcher on the vitals tab.

## 6. DI wiring + regression

- [x] 6.1 `main.dart`: construct `HttpVitalsRepository(baseUrl: apiBaseUrl)` + the
      two use cases + a `VitalsController`, threaded main.dart → `App` →
      `_AuthenticatedHome` → `HomeScreen` → `DietShellScreen` (add a
      `vitalsController` field/param to `App` + `_AuthenticatedHome` in
      `lib/app.dart`, pass in main.dart's `App(...)`, add to `HomeScreen`'s
      constructor, forward in `_openHealth`).
- [x] 6.2 Update ALL existing construction call sites for the new required param
      so the suite compiles: `lib/app.dart`'s `_AuthenticatedHome` build;
      `test/contexts/user/presentation/home_screen_test.dart` +
      `home_screen_responsive_test.dart` (inject a fake `VitalsController`); AND
      **`test/app_test.dart`**, which builds the root `App(...)` directly and has a
      local health-controllers fixture (mirror how it builds `bowel:
      BowelController(...)` — add a `vitals: VitalsController(GetVitalsDay(fake),
      SaveVitalsDay(fake))` field with a `_FakeVitalsRepository` and pass
      `vitalsController: health.vitals` in the `App(...)` call). Missing this fails
      `flutter test` at compile.
- [x] 6.3 `flutter analyze` clean + `flutter test` green — existing tabs/shell/home
      tests still pass; regenerate and commit `lib/l10n/generated/*.dart`.
