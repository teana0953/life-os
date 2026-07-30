## Why

The backend half of [life-os#87](https://github.com/teana0953/life-os/issues/87) is
live: `GET /api/me` reports `is_admin`, and an administrator can create and edit
shared dictionary items over `/api/admin/food-items`. Nothing in the app reaches any
of it — `UserProfile` doesn't carry the flag, and the food search screen has no path
to create or edit a dictionary item at all (its "manual entry" dialog only drops a
one-off item into the meal tray; `POST /api/food-items` has never been called from
this app). Seeded nutrients are approximations that were always meant to be corrected
per item, so today those corrections are impossible from the app.

## What Changes

- **`UserProfile.isAdmin`**, parsed from `/api/me`'s `is_admin` with a `?? false`
  fallback so a response missing the key degrades to "not an admin" instead of
  failing the whole profile load.
- **Profile loads once per authenticated session, not once per home-screen visit** —
  today `HomeController.load` only runs from `_AuthenticatedHome.initState`, so a
  deep link straight to `/health/dictionary` (exactly what the PWA shortcut does)
  never has a profile, and therefore could never know the user is an administrator.
- **Edit entry point on the search results**: for an administrator, a shared item's
  row (`owner_user_id == null`) gains a `⋮` menu next to the favorite button with a
  single "Edit" action. Non-administrators, and every custom item, keep exactly
  today's row. Tapping the row still adds the food to the tray.
- **Create entry point**: an administrator sees a `+` action in the search/dictionary
  app bar. Nobody else does.
- **One bottom sheet for both**, prefilled when editing and empty when creating —
  name, the four portions, the six nutrients, and the measure basis. A bottom sheet
  rather than a dialog because this project has already been bitten by
  `AlertDialog` + soft keyboard on mobile. Editing sends only the fields the
  administrator actually changed, matching the backend's "absent key = leave alone".
- **The measure-basis pairing rule is enforced before submitting** (`base_amount` and
  `measure_unit` both set or both empty, amount positive), with the error shown next
  to the field and the entered values kept, instead of surfacing a bare backend 400.
- **`FoodDictionaryRepository` grows `createSharedItem` / `updateSharedItem`**, with
  two use cases and a distinct "forbidden" error type so a 403 reads as "you don't
  have permission" rather than "try again".
- **Not changed**: no delete, no editing another user's custom item, no admin
  management screen, no separate admin page — the entry points live inside the
  existing dictionary surface.

## Capabilities

### Modified Capabilities

- `health-diet`: the food dictionary becomes editable in place for an administrator —
  shared items can be corrected and new shared items created from the search screen,
  while every non-administrator sees the screen exactly as before.
