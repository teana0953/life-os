# Tasks

TDD throughout: a failing test first, then implementation. Follow the repo's
CLAUDE.md — clean-architecture layering, typed errors (never localized strings) in
domain/infrastructure, all user-facing copy from ARB via `AppLocalizations`, all
styling from `Theme.of(context)`. Run `flutter analyze` + `flutter test` before
finishing.

Scope: administrator create + edit of **shared** dictionary items, inline in the
existing food search surface. No delete, no editing another user's custom item, no
admin management screen.

Timezone note: this change touches no dates, so `TZ=UTC flutter test` is not required.

## 1. The admin flag reaches the app

- [ ] 1.1 Test first — `UserProfile.fromJson` maps `is_admin: true` to
      `isAdmin == true`, `is_admin: false` to false, and a response **missing** the
      key to false without throwing (deliberate: a missing key must degrade to
      "not an admin", not fail the whole profile load).
- [ ] 1.2 Add `final bool isAdmin` to `lib/contexts/user/domain/user_profile.dart`
      and parse it as `json['is_admin'] as bool? ?? false`. Fix every existing
      `UserProfile(...)` construction in `lib/` and `test/` that the new required
      field breaks (grep `UserProfile(`).

## 2. The profile is available on a deep link, without touching the auth/home flow

Do NOT move the existing `homeController.load` out of `_AuthenticatedHome.initState`
(lib/app.dart:964-974). It stays: it is also the only retry after a failed profile
load (leave `/` and come back → remount → reload), and moving it would put the whole
auth/home flow at risk for a secondary feature.

- [ ] 2.1 Test first — `HomeController.ensureLoaded(idToken)` calls `GetProfile`
      exactly once when invoked repeatedly (already-loaded and in-flight both no-op);
      after a **failed** load it DOES fetch again (the judgment is `profile != null`,
      not "was ever called" — a failed first attempt must be retryable, and this is
      the only retry a deep-linked screen gets); and `reset()` clears the profile so a
      later `ensureLoaded` fetches again. Use a fake `GetProfile` that counts calls.
- [ ] 2.2 Implement `ensureLoaded` and `reset` on
      `lib/contexts/user/presentation/home_controller.dart`. `load` keeps its current
      always-reload behavior (the home screen's retry depends on it).
- [ ] 2.3 Test first — entering the dictionary deep link with no profile loaded
      results in the profile being fetched, and the admin entry points appear once it
      resolves (drive it the way the existing PWA-shortcut/go_router tests do).
- [ ] 2.4 Trigger `ensureLoaded` **once from `FoodSearchScreen.initState`**, inside
      `WidgetsBinding.instance.addPostFrameCallback`. Put it in the screen, not in the
      route builders: there are THREE construction sites (lib/app.dart — the
      `food-search` route, the `extra`-carrying `dictionary` route, and
      `_UrlDictionaryScreen` at lib/app.dart:939, which is the one the PWA shortcut
      takes), and a single trigger inside the screen covers all three without
      repeating it. Post-frame is required because `HomeController.load`
      synchronously `notifyListeners()` before its first await
      (home_controller.dart:27-30) and lib/app.dart already documents this
      notify-during-build hazard twice.
      This means `FoodSearchScreen` needs a way to request the load without knowing
      about `HomeController` — pass a `VoidCallback? onNeedProfile` (or equivalent)
      from the wiring in app.dart, keeping the screen ignorant of where admin status
      comes from (same rule as `isAdmin` being a plain bool).
- [ ] 2.5 Call `homeController.reset()` when the session ends, from app.dart's
      existing auth listener (`_authNotifier.addListener(...)`, lib/app.dart:304).
      **Detect sign-out, not "a different user"**: `AuthRouterNotifier`
      (lib/shared/routing/auth_router_notifier.dart:16-34) exposes only
      loading/error/signedIn/idToken and its source stream is `Stream<bool>` (:41) —
      there is no uid to compare, and adding one is well outside this change. Reset on
      `signedIn` going true → false; signing in as somebody else necessarily passes
      through that transition, so the round-1 hazard (a new user inheriting the
      previous user's `isAdmin`) is still closed. Test it: sign out → sign in as a
      non-admin → no admin entry points.

## 3. Repository + use cases

- [ ] 3.1 Test first (fake `http.Client`) for
      `lib/contexts/health/infrastructure/http_food_dictionary_repository.dart`:
      - `createSharedItem` POSTs to `/api/admin/food-items` with snake_case fields and
        returns the created `FoodItem`;
      - `updateSharedItem` PATCHes `/api/admin/food-items/:id` with **only the keys
        supplied** (a field the caller did not change must not appear in the body at
        all — the backend treats an absent key as "leave alone");
      - an explicit null for `base_amount`/`measure_unit` IS sent (clearing), and is
        distinguishable from "not supplied";
      - 401 throws the existing reauth error, 403 throws a NEW distinct
        forbidden error, other non-2xx throw the existing failure type.
- [ ] 3.2 Add the two methods to the `FoodDictionaryRepository` port
      (`lib/contexts/health/domain/food_dictionary_repository.dart`) with an input
      type for create and a patch type for update that can express
      "absent vs explicitly null" for the measure basis. Add the forbidden error to
      `lib/contexts/health/domain/diet_exceptions.dart`.
- [ ] 3.3 Implement in `HttpFoodDictionaryRepository`, reusing the existing `_send`
      helper so 401 handling stays in one place.
- [ ] 3.4 Test first, then add the two use cases in
      `lib/contexts/health/application/` (`create_shared_food_item.dart`,
      `update_shared_food_item.dart`), thin wrappers over the port like the existing
      ones (`favorite_food.dart` is the shape to copy).
- [ ] 3.5 Update every fake/stub implementing `FoodDictionaryRepository` in `test/`
      so it satisfies the widened port.

## 4. The form (bottom sheet, create + edit)

- [ ] 4.1 Add the ARB copy first to **all three** ARB files — `lib/l10n/app_en.arb`
      (with a `description` for each key), `lib/l10n/app_zh_Hant.arb`, and
      `lib/l10n/app_zh.arb` (this repo keeps `app_zh.arb` as a full translation, byte-
      identical to `app_zh_Hant.arb` apart from `@@locale`; skipping it makes
      `flutter gen-l10n` warn about missing keys and drops `zh` back to English): sheet titles (create/edit), field labels
      (name, the four portions, the six nutrients, measure amount, measure unit),
      submit/cancel, the two validation messages (pair rule, positive amount),
      success messages, the forbidden message, the generic retryable failure, and
      the tooltips for the two entry points. Regenerate with `flutter gen-l10n` and
      commit the generated files.
- [ ] 4.2 Add `lib/contexts/health/presentation/shared_food_item_controller.dart` —
      a `ChangeNotifier` holding the submit state (idle / submitting / typed error)
      and the two use cases, built in `lib/main.dart` and passed down through the
      routes to `FoodSearchScreen` and from there to the sheet. The sheet must not
      hold use cases directly (this project's layering is screen → controller → use
      case). Test it first with fake use cases: success, generic failure, forbidden,
      and that a second submit while one is in flight does not fire twice.
- [ ] 4.3 Test first — widget tests for a new
      `lib/contexts/health/presentation/shared_food_item_sheet.dart` driven through
      `l10nTestApp` (test/support/l10n_test_app.dart):
      - create mode opens empty; edit mode opens prefilled from the given `FoodItem`;
      - a numeric field whose value is 0 shows an empty string with a `'0'` hint (the
        project-wide convention — see CLAUDE.md);
      - submitting in edit mode after changing two fields calls the update use case
        with only those two fields;
      - measure amount without unit → error next to the field, nothing submitted,
        input preserved; unit without amount → same; amount `0` or negative → error;
      - both cleared together → submits explicit nulls;
      - while submitting, the submit control is disabled/busy and the entered values
        are still visible;
      - in edit mode with nothing changed, the submit control is unavailable (the
        backend rejects an empty patch with 400, so this path must not be reachable);
      - a failed submission keeps the sheet open with values intact and shows a
        retryable message; a forbidden failure keeps the sheet open and shows the
        permission message (NOT closing the sheet or hiding the entry point).
- [ ] 4.4 Implement the sheet with `showModalBottomSheet(isScrollControlled: true)`
      **and bottom padding of `MediaQuery.of(context).viewInsets.bottom`** —
      `isScrollControlled` alone does not lift content above the soft keyboard, which
      is the entire reason for choosing a sheet over a dialog; every existing sheet in
      this repo pads by `viewInsets` —
      **not** `AlertDialog`: on mobile this project has already hit the dialog +
      soft-keyboard problem, so every text-input form is a bottom sheet. Numeric
      fields follow the empty-zero convention (`value == 0 ? '' : …` with
      `hintText: '0'`), styling comes from the theme, copy comes from
      `AppLocalizations`.

## 5. Entry points in the search screen

- [ ] 5.1 Test first — `test/` widget tests for `FoodSearchScreen` with
      `isAdmin: true` / `false`:
      - admin + shared item (`ownerUserId == null`) → the row shows the edit action;
      - admin + custom item (`ownerUserId != null`) → no edit action on that row;
      - non-admin → no row action anywhere and no create action in the app bar;
      - tapping the row still adds the item to the tray in every case (the primary
        action must not be shadowed by the new one);
      - admin taps the row's edit action → the sheet opens prefilled;
      - admin taps the app bar create action → the sheet opens empty;
      - after a successful create or edit the screen re-runs the current search (or
        reloads favorites when the query is empty) and shows a success message.
- [ ] 5.2 Implement in `lib/contexts/health/presentation/food_search_screen.dart`:
      add an `isAdmin` parameter **defaulting to `false`** (the screen must not know
      how admin status is obtained, and a default keeps the eight existing
      constructions in `test/` compiling — "unknown" must mean "not an admin"); render the per-row `⋮` menu only for `isAdmin && item.ownerUserId
      == null`; add the app-bar create action only for `isAdmin`. Both carry tooltips.
      Keep the existing row shape, favorite control, and `onTap` behavior untouched.
- [ ] 5.3 Wire **all three** construction sites in `lib/app.dart` — the `food-search`
      route, the `dictionary` route that receives `extra`, and `_UrlDictionaryScreen`
      (lib/app.dart:939), which builds `FoodSearchScreen` itself and is the path the
      PWA launcher shortcut takes (`web/manifest.json` points at
      `/#/health/diet/dictionary`). Each passes `isAdmin` from
      `homeController.profile?.isAdmin ?? false` and rebuilds when the controller
      notifies (`ListenableBuilder`) so the entry points appear once the profile
      lands. Wire the new controller and use cases from `lib/main.dart` the way the
      existing dictionary ones are wired.
- [ ] 5.4 After a successful **create**, set the search field to the new item's name
      and run that search — with an empty query the screen shows favorites
      (food_search_screen.dart:299-300), which a brand-new shared item can never be
      in, so a plain "reload" would look like the create silently failed.
      **This needs a prerequisite**: the search field is currently a bare `TextField`
      with no controller (food_search_screen.dart:322-326, only
      `onChanged: dictionary.search`), so nothing can set its text — the
      `TextEditingController`s at :725-729 all belong to `_ManualEntryDialog`. Give
      the search field its own `TextEditingController` (disposed in `dispose`), then
      on success set `controller.text` AND call `dictionary.search(newName)`.
      Note `DictionaryController.search` is debounced by 300 ms
      (dictionary_controller.dart:76-106) and returns a `Future` that completes after
      the debounce fires — the test must await it (or pump past the debounce) rather
      than asserting immediately.
      After a successful **edit**, re-run the current search (or reload favorites when
      the query is empty).
- [ ] 5.5 Items already in the tray keep the values they were added with — an edit
      must not rewrite `TrayItem`'s snapshot (create_meal_controller.dart:26-31).
      Add a test that pins this.

## 6. Verify

- [ ] 6.1 `flutter analyze` clean.
- [ ] 6.2 `flutter test` — must print `All tests passed!`. A run that hangs is NOT a
      pass (this project has hit an infinite `notifyListeners` re-entrancy before);
      if it hangs, treat it as a failure and find the cause.
- [ ] 6.3 `npx openspec validate add-admin-shared-food-ui --strict` passes.
- [ ] 6.4 Confirm the non-admin path is untouched: existing food-search tests still
      green without modification (if one needed editing, say why in the report).
