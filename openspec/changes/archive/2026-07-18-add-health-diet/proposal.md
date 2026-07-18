# Proposal: add-health-diet

## Why

The backend diet module is live (food dictionary, per-meal logging with quantity
and gram entry, per-day targets, eaten-at ordering). The Flutter app has no UI
for it yet — the home "健康" space is just a placeholder tile. This change builds
the diet-tracking front end, whose UX/UI was reviewed and settled: three screens
(Today, Log an entry, Daily target) in the existing Chiikawa pastel system, with
a quantity card that converts a dictionary pick into portions.

## What Changes

- Add a `health` context (`lib/contexts/health/{domain,application,infrastructure,presentation}`)
  following the `contexts/user` template.
- **Domain**: `FoodItem`, `FoodEntry`, `DayDietLog`, `DailyTarget` entities; ports
  `FoodDictionaryRepository`, `DietLogRepository`, `DailyTargetRepository`; and a
  pure portion-preview helper (portions/nutrients × quantity, `grams ÷ base_grams`)
  so the quantity card can show the result before saving.
- **Application**: use cases for searching the dictionary, listing/toggling
  favorites, logging from a dictionary item (quantity or grams, eaten-at),
  logging a manual entry, fetching a day's log, deleting an entry, and
  getting/setting the daily target.
- **Infrastructure**: `Http*Repository` adapters over the backend endpoints
  (`/api/food-items*`, `/api/diet-entries*`, `/api/daily-target`), Bearer-token
  authed like `HttpProfileRepository`.
- **Presentation**: a bottom-nav diet shell (Today · Dictionary · Target ·
  Settings) reached from the home "健康" tile, with three screens — Today
  (per-category portion progress + meals/snacks in eaten order, add via FAB),
  Log-an-entry (meal chips, dictionary search + favorites, a quantity card with
  unit/gram toggle + eaten-at time, add-snack), and Daily target (per-category
  steppers + remaining). Food groups use four category colors
  (staple/meat/fruit/veg). `ChangeNotifier` controllers per screen.
- Add ARB strings (English + Traditional Chinese) for all diet copy.
- Remove the internal user id row from the home profile card (show only
  meaningful info).

## Capabilities

### New Capabilities

- `health-diet`: the diet-tracking front end — a day's food log by meal in eaten
  order with per-category portion progress; logging a food from the dictionary
  by a decimal quantity or a gram amount (converted via the item's base grams)
  with a settable eaten-at time; snacks in addition to the three standard meals;
  favorites; and a user-set daily portion target with a remaining view. Reached
  from the home "健康" space.

### Modified Capabilities

- `login-flow`: the home screen gains a working "健康" entry point into the diet
  shell and no longer displays the internal user id on its profile card (delta
  clarifies the home content; sign-in/auth behavior is unchanged).

## Impact

- **New**: `lib/contexts/health/**` (domain/application/infrastructure/presentation),
  diet ARB strings, unit/widget tests.
- **Modified**: `lib/contexts/user/presentation/home_screen.dart` (健康 tile
  navigates to the diet shell; remove the user-id row), `lib/main.dart`
  (compose + inject the new repositories/use cases/controllers), `CLAUDE.md`.
- **Backend**: consumes the existing API only — no backend change.
- **Out of scope**: manual free-portion entry (the "手動輸入份數" fallback —
  dictionary logging is the primary path here, manual entry is a follow-up),
  photo-based logging, water/bowel/exercise/period modules, and auto-computed
  targets (targets stay user-set). Offline caching is not addressed; screens
  fetch on load like the profile does.
