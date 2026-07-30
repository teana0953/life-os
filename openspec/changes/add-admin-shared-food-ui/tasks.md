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

## 2. Profile loads once per session, not once per home visit

- [ ] 2.1 Test first — a widget test that enters a health route directly (the way
      `test/` already drives go_router deep links; the PWA-shortcut tests are the
      closest existing example) asserts the profile is loaded even though
      `HomeScreen` was never shown.
- [ ] 2.2 Move the `homeController.load(idToken)` call out of
      `_AuthenticatedHome.initState` (lib/app.dart:964-974) to where the app knows it
      is authenticated, regardless of route. Guard it so a single authentication does
      not trigger two loads (`_AuthenticatedHome` should only trigger a load if one
      has not happened for this session) — verify with a fake `GetProfile` counting
      calls: exactly one load for one authentication, and the home screen still shows
      its loaded/error/needsReauth states as before.
- [ ] 2.3 Confirm no regression in the existing home-screen tests (loading → loaded,
      error, needsReauth, sign-out) — they are the safety net for this move.

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

- [ ] 4.1 Add the ARB copy first — `lib/l10n/app_en.arb` (with `description` for each
      key) and `lib/l10n/app_zh_Hant.arb`: sheet titles (create/edit), field labels
      (name, the four portions, the six nutrients, measure amount, measure unit),
      submit/cancel, the two validation messages (pair rule, positive amount),
      success messages, the forbidden message, the generic retryable failure, and
      the tooltips for the two entry points. Regenerate with `flutter gen-l10n` and
      commit the generated files.
- [ ] 4.2 Test first — widget tests for a new
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
      - a failed submission keeps the sheet open with values intact and shows a
        retryable message; a forbidden failure shows the permission message.
- [ ] 4.3 Implement the sheet with `showModalBottomSheet(isScrollControlled: true)` —
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
      add a required `isAdmin` parameter (the screen must not know how admin status
      is obtained); render the per-row `⋮` menu only for `isAdmin && item.ownerUserId
      == null`; add the app-bar create action only for `isAdmin`. Both carry tooltips.
      Keep the existing row shape, favorite control, and `onTap` behavior untouched.
- [ ] 5.3 Wire it in `lib/app.dart`: the `food-search` and `dictionary` routes pass
      `isAdmin` from `homeController.profile?.isAdmin ?? false`, rebuilding when the
      controller notifies (`AnimatedBuilder`/`ListenableBuilder`) so the entry points
      appear once the profile lands. Wire the two new use cases from `lib/main.dart`
      the way the existing dictionary use cases are wired.

## 6. Verify

- [ ] 6.1 `flutter analyze` clean.
- [ ] 6.2 `flutter test` — must print `All tests passed!`. A run that hangs is NOT a
      pass (this project has hit an infinite `notifyListeners` re-entrancy before);
      if it hangs, treat it as a failure and find the cause.
- [ ] 6.3 `npx openspec validate add-admin-shared-food-ui --strict` passes.
- [ ] 6.4 Confirm the non-admin path is untouched: existing food-search tests still
      green without modification (if one needed editing, say why in the report).
