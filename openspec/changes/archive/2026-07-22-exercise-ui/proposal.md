## Why

The backend now persists per-day exercise entries (`/api/exercise`, life-os-backend
PR #20). Users need a UI to log the activities they did and for how long. This is
the daily-log shell's next tracker — but the bottom `NavigationBar` is already at
Material's 5-destination max (今日 / 目標 / 飲水 / 排便 / 數值). Rather than crowd a
6th tab (and hit the wall again for the coming period + dashboard surfaces), this
change also restructures the bottom navigation into **4 primary tabs + a 更多
(More) overflow**: the two lower-frequency trackers already there (排便, 數值) move
into 更多, and exercise joins them. Frequency now maps to hierarchy — high-frequency
trackers stay one tap away, lower-frequency ones live one tap deeper — and future
surfaces (period, dashboard) add to 更多 without another restructure.

## What Changes

- **New `exercise` context** (`lib/contexts/exercise/`): `ExerciseActivity {id,
  name, category, intensity}`, `ExerciseEntry {id, activityId, activityName?,
  category?, durationMinutes, note, createdAt}`, `ExerciseDay {day, entries,
  totalMinutes}` + `ExerciseRepository` port; `ListExerciseActivities`,
  `GetExerciseDay`, `AddExerciseEntry`, `DeleteExerciseEntry` use cases;
  `HttpExerciseRepository` (GET `/activities`, GET `?day=`, POST, DELETE `/:id`;
  snake_case; bearer token; 401→reauth); `ExerciseController` + `ExerciseScreen`.
- **Cumulative, immediate-write tracker** (unlike the draft-then-save bowel/vitals
  screens): appending an entry POSTs and reloads the day; deleting an entry DELETEs
  and reloads — mirroring the `WaterController._apply` pattern, not a Save button.
- **`ExerciseScreen` UI**: a date + today/history header (`TrackerDayHeader`), the
  day's total minutes, the day's entries as a list (each removable), and an add
  affordance opening an activity picker (the static library, grouped aerobic/
  anaerobic) + a positive-integer duration (minutes, empty-zero convention) + an
  optional note → appends. Reuses `LedgeCard`, `AsyncStateScaffold`,
  `TrackerDayHeader`, `NumericAmountField`.
- **Bottom navigation restructure (方案 A)**: `DietShellScreen`'s `NavigationBar`
  becomes 4 destinations — 今日 / 目標 / 飲水 / **更多**. Selecting 更多 shows a
  **More menu** screen listing the overflow trackers (排便, 數值, 運動) as tiles;
  tapping a tile opens that tracker's screen for the shell's viewed day. The shell
  still owns loading (`<controller>.load(token, _day)` in `_load()` /
  `_reloadCurrentDay()`), now including `exerciseController`.
- **DI** threaded `main.dart` → `App` → `_AuthenticatedHome` → `HomeScreen` →
  `DietShellScreen` (mirroring `vitalsController`). New i18n keys (en + zh-Hant +
  zh base) for the 更多 tab, the More menu, and the exercise screen; l10n
  regenerated. Activity names/categories are backend data (the library is
  Chinese-labeled, like the food dictionary); only UI chrome is localized.

Frontend-only; consumes the existing backend API. No behavior change to the 今日 /
目標 / 飲水 tabs; 排便 and 數值 keep their screens unchanged — only their entry
point moves from the bottom bar into 更多.

## Capabilities

### Added Capabilities

- `exercise-ui`: log the day's exercise — pick an activity from the library, enter
  a duration, optionally a note; see the day's entries and total minutes; remove an
  entry — from a 運動 screen reached via the daily-log shell's 更多 overflow, saved
  to the backend, viewable per day.

### Changed Capabilities

- `daily-log navigation`: the shell's bottom bar changes from five tab destinations
  to four (今日 / 目標 / 飲水 / 更多), with 排便 / 數值 / 運動 reached through the 更多
  overflow menu instead of dedicated bottom-bar tabs.
