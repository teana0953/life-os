## Why

The backend now serves a body profile and a weight-goal overview
(`/api/body-profile`, `/api/weight-goal`; life-os-backend PR #22). This is the
first step of the goals/dashboard layer (feature C) and the start of the
information-architecture shift from the UX analysis: the health module should
**land on a 總覽 (Overview) dashboard** — a stack of glanceable cards — rather
than dropping the user straight into the diet tab.

This change stands up that dashboard as the health module's landing screen and
adds its first card: a **goal card** showing target weight, current weight,
remaining, an achievement ring, and BMI, with an edit flow to set height and
target weight. The existing tab shell (今日 / 目標 / 飲水 / 更多) is unchanged and is
reached from the dashboard — the bottom-nav restructure into full 總覽/記錄/趨勢/更多
modes is deferred until the trend/adherence cards (C2/C3) exist, so no empty tab
ships now.

## What Changes

- **New `body_profile` context** (`lib/contexts/body_profile/`):
  `WeightGoal {heightCm?, targetWeightKg?, currentWeightKg?, remainingKg?,
  achievementRate?, bmi?}` and `BodyProfile {heightCm?, targetWeightKg?}` +
  `BodyProfileRepository` port + typed exceptions (reauth/fetch); `GetWeightGoal`,
  `GetBodyProfile`, `SetBodyProfile` use cases; `HttpBodyProfileRepository`
  (GET `/api/weight-goal`, GET/PUT `/api/body-profile`; bearer; 401→reauth;
  snake_case; PUT partial); a `WeightGoalController` (immediate: saving reloads).
- **New `DashboardScreen` (總覽)** — the health module's landing (what the home
  screen's 健康 space now opens). A scrollable card stack. For this change it holds
  the goal card plus an entry that opens the existing tab shell (`DietShellScreen`)
  for daily logging. The home 健康 space opens the dashboard; the dashboard opens
  the shell.
- **Goal card**: when a profile is set, shows target / current / remaining (kg),
  an achievement ring (the `achievement_rate`, or an empty ring when null), and
  BMI; when height and target are both unset, shows a "set your goal" prompt
  instead of a wall of "—". Tapping the card opens an **edit bottom sheet**
  (height + target weight number inputs; a bottom sheet, not an AlertDialog, so
  the keyboard doesn't cover the fields on mobile) → PUT `/api/body-profile` →
  reload. Reuses `LedgeCard`, `AsyncStateScaffold`.
- **DI** threaded `main.dart` → `App` → `_AuthenticatedHome` → `HomeScreen`
  (a new `weightGoalController`, and the diet-shell construction moves into the
  dashboard's "open log" callback). New i18n keys (en + zh-Hant + zh);
  l10n regenerated.

Frontend-only; consumes the existing backend API. The diet/water/… trackers are
unchanged — only the health module's landing changes from the tab shell to the
dashboard, with the shell one tap away.

## Capabilities

### Added Capabilities

- `dashboard-goal-card`: a 總覽 dashboard as the health module's landing, showing a
  goal card (target / current / remaining weight, an achievement ring, and BMI)
  with an edit flow to set height and target weight, and an entry into the daily-log
  tab shell. The first card of the dashboard; further cards (trends, adherence,
  cycle, vitals) and the bottom-nav restructure follow in later changes.
