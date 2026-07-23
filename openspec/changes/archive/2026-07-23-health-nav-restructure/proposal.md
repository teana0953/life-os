## Why

Recording was buried. The health module landed on a 總覽 dashboard, and to record
anything you tapped a "今日記錄" row into a diet shell whose bottom nav (今日 / 目標 /
飲水 / 更多) hid four trackers (數值 / 運動 / 排便 / 生理期) behind a nested 更多 menu —
up to four taps deep. And "回總覽" only existed on the diet Today tab, so from any
other tracker you couldn't get back. This restructures the module to a persistent
bottom nav (option A) so recording and the overview are always one tap away.

## What Changes

- **`HealthScaffold`** (new): the health module's home — a persistent bottom nav
  with **總覽 / 記錄 / 趨勢 / 更多** over an `IndexedStack`. Owns the auth-token load and
  pre-loads today's day-keyed trackers (as the shell did). Home now pushes this
  instead of "dashboard → push shell".
  - **總覽**: the goal + this-month record cards.
  - **記錄**: a flat hub — one tile per tracker (飲食 / 飲水 / 數值 / 運動 / 排便 / 生理期);
    each pushes its screen for today. No nested 更多.
  - **趨勢**: the trend chart.
  - **更多**: opens app settings (theme / language / sign-out).
- **`DietDayScreen`** (was `DietShellScreen`): reduced to the diet day flow — the
  day-nav + Today log + food search + calendar — with the **每日份量目標** moved to an
  app-bar action. Its water / 更多 tabs and bottom nav are gone (those trackers are
  now hub tiles). Each tracker manages its own day (opens at today); the former
  cross-tracker shared day is dropped.
- **Removed**: `DashboardScreen` (replaced by the 總覽 tab) and the shell's nested
  更多 menu. New i18n (記錄 / 飲食 hub labels), en + zh-Hant + zh.

Frontend-only. The individual tracker screens are unchanged; they're just launched
from the flat hub rather than the shell's tabs/更多.

## Capabilities

### Added Capabilities

- `health-navigation`: the health module uses a persistent bottom nav (overview /
  record / trends / more); every tracker is one tap from the record hub, and the
  overview is always reachable.
