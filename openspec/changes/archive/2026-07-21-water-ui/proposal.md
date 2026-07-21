## Why

The backend now persists water intake and a daily water target (`/api/water`,
life-os-backend). Users need a UI to log water and see progress against their
goal. This is the frontend half. Water is a daily intake like food, so it lives
as a new tab in the existing daily-log shell rather than a separate destination.

## What Changes

- **New `hydration` context** (`lib/contexts/hydration/`) mirroring the diet
  layout: `WaterDay { day, totalMl, targetMl, remainingMl }` + `WaterRepository`
  port; `GetWaterDay` / `AddWater` / `SetWaterTarget` use cases;
  `HttpWaterRepository` (calls `GET`/`POST /api/water`, `PUT /api/water/target`,
  snake_case contract matching the backend); `WaterScreen` + `WaterController`.
- **A third tab in the diet shell**: `DietShellScreen`'s bottom `NavigationBar`
  gains a **飲水 (Water)** destination alongside 今日 / 目標, showing `WaterScreen`
  for the shell's currently viewed day (`_day`) and `idToken`. (The shell is now
  a health daily-log shell; a future 排便 tab will join the same way.)
- **WaterScreen UI** (design-system consistent): a progress readout「總量 / 目標
  ml」with a progress bar (reusing the portion-progress style; over-target shows
  a negative remaining); quick-add buttons **＋250ml / ＋500ml / 自訂** (custom
  amount via a numeric dialog following the empty-zero convention); a **−250ml /
  修正** control (sends a negative `add_ml`, backend clamps ≥0); and a **settable
  daily target** control mirroring the diet daily-target UI. Loading / error /
  reauth(401) states handled like the diet screens.
- **DI** in `main.dart`: an `HttpWaterRepository` + the three use cases + a
  `WaterController`, threaded main.dart → HomeScreen → DietShellScreen (mirroring
  `dailyTargetController`).
- New i18n keys in `app_en.arb` + `app_zh_Hant.arb` (+ `app_zh.arb` base) for all
  new copy; regenerate `lib/l10n/generated`.

Frontend-only; consumes the existing backend API. No change to diet behavior
beyond adding the water tab to the shell.

## Capabilities

### Added Capabilities

- `hydration`: log the day's water intake in millilitres against a settable daily
  target, from a water tab in the daily-log shell — quick-add and correct the
  amount, see progress toward the goal (including over-target), set the target,
  and view any day.
