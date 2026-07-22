# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` (+ `bash scripts/lint-actions.sh`) before finishing. Widget tests
inject fakes via `l10nTestApp`. Colors from `Theme.of(context)` — no hard-coded
hex. Every user-facing string via an ARB key (add to `app_en.arb` with a
description + `app_zh_Hant.arb` + `app_zh.arb`, run `flutter gen-l10n`, commit the
regenerated `lib/l10n/generated/*.dart`). The `exercise`/`menstrual` contexts are
the closest template; the `water` controller is the template for immediate
save-then-reload. **The edit form MUST be a `showModalBottomSheet(isScrollControlled:
true)` with a `MediaQuery.viewInsetsOf` bottom padding — NOT an AlertDialog** (see
the exercise add-form keyboard fix, PR #54).

## 1. Domain + application (body_profile context)

- [x] 1.1 `lib/contexts/body_profile/domain/weight_goal.dart` —
      `BodyProfile {heightCm (double?), targetWeightKg (double?)}` and
      `WeightGoal {heightCm?, targetWeightKg?, currentWeightKg?, remainingKg?,
      achievementRate (int?), bmi (double?)}`. snake_case fromJson (all nullable:
      height_cm, target_weight_kg, current_weight_kg, remaining_kg,
      achievement_rate, bmi). `body_profile_repository.dart` —
      `BodyProfileRepository` port: `getWeightGoal(idToken)`, `getBodyProfile(idToken)`,
      `setBodyProfile(idToken, {double? heightCm, double? targetWeightKg})` (partial).
      `body_profile_exceptions.dart` — typed `BodyProfileReauthenticationRequired`,
      `BodyProfileFetchFailure`.
- [x] 1.2 Test first (fake repo) then implement `GetWeightGoal`, `GetBodyProfile`,
      `SetBodyProfile` in `lib/contexts/body_profile/application/` — thin.

## 2. Infrastructure: HttpBodyProfileRepository

- [x] 2.1 Test first with a mock `http.Client`: `HttpBodyProfileRepository` maps
      `GET /api/weight-goal` → `WeightGoal`, `GET /api/body-profile` → `BodyProfile`,
      `PUT /api/body-profile` → `BodyProfile`. Sends bearer `idToken`; typed error
      on non-200 (401 distinguishable). **PUT sends only the provided fields** —
      assert bodies for height-only, target-only, and both.

## 3. WeightGoalController

- [x] 3.1 Test first (fake repo): `WeightGoalController` (ChangeNotifier) —
      `load(idToken)` loads the weight goal (and body profile for the edit
      pre-fill); `saveProfile(idToken, {heightCm?, targetWeightKg?})` PUTs then
      RE-READS; status `loading|loaded|saving|error|needsReauth`; 401 → needsReauth;
      fetch failure → error. Mirror `WaterController._apply`. Implement
      `lib/contexts/body_profile/presentation/weight_goal_controller.dart`.

## 4. Goal card + edit sheet

- [x] 4.1 Test first (widget, `l10nTestApp` + fake): the goal card — with a set
      profile, shows target / current / remaining, an achievement ring at the rate,
      and BMI (target 51 / current 52 / remaining 1 / ring 75 / bmi 19.1); a null
      achievement/BMI shows an empty/indeterminate ring and a "—" placeholder; an
      unset profile (height & target both null) shows a "set your goal" prompt (not
      a row of "—"); a load failure shows an error state. Implement
      `lib/contexts/body_profile/presentation/goal_card.dart` — colors from
      `Theme.of(context)`, all copy via ARB, reuse `LedgeCard`.
- [x] 4.2 Test first — the edit flow: tapping the card / prompt opens a
      **modal bottom sheet** (assert it is a bottom sheet with a `viewInsets` bottom
      padding, NOT an AlertDialog) with height (cm) and target-weight (kg) number
      fields (empty-zero convention); a non-positive value can't be saved; saving
      calls `saveProfile` with the entered values and the card refreshes. Implement
      the sheet.

## 5. Dashboard screen + landing rewire + DI + i18n

- [x] 5.1 Add ARB keys (en + zh-Hant + zh) + `flutter gen-l10n`: dashboard title,
      goal-card labels (target / current / remaining + kg unit, achievement, BMI,
      the "—" placeholder), the unset "set your goal" prompt + button, the edit sheet
      (height cm / target weight kg / save), the "record" entry, and error messages.
- [x] 5.2 Test first (a new `dashboard_screen_test.dart`): the dashboard shows the
      goal card and a "record" entry; activating the entry shows the daily-log shell.
      Implement `lib/contexts/health/presentation/dashboard_screen.dart` — a Scaffold
      + AppBar + scrollable card list holding `GoalCard(weightGoalController)` and a
      "today / record" entry that calls an `onOpenLog` callback; load
      `weightGoalController.load(token)` on first build.
- [x] 5.3 Rewire the landing in `home_screen.dart`: `_openHealth` now pushes
      `DashboardScreen(weightGoalController: ..., onOpenLog: () =>
      Navigator.push(MaterialPageRoute(builder: (_) => DietShellScreen(...the existing
      controllers...))))` — move the DietShell construction into the `onOpenLog`
      callback (controllers still read from the widget fields). Add a required
      `weightGoalController` field to `HomeScreen`.
- [x] 5.4 DI: build `HttpBodyProfileRepository` + the three use cases +
      `WeightGoalController` in `main.dart`, and thread `weightGoalController` through
      `App` → `_AuthenticatedHome` → `HomeScreen` (mirror an existing controller's
      threading). Update the widget-test construction sites: `app_test.dart`,
      `home_screen_test.dart`, `home_screen_responsive_test.dart` (new controller),
      and the `home_screen_test.dart` assertion that opening health shows the shell →
      now shows the dashboard (and reaching the shell goes via the dashboard's record
      entry). `diet_shell_screen_test.dart` builds the shell directly and is
      unaffected except it no longer needs the home path.

## 6. Gate

- [x] 6.1 `flutter analyze` clean + `flutter test` green + `bash scripts/lint-actions.sh`
      pass. Regenerated l10n committed. No behavior change to the diet/water/… trackers
      or the tab shell itself — only the health module's landing becomes the dashboard,
      with the shell one tap away.
