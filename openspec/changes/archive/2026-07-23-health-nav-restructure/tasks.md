# Tasks

`flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`. Colors via
Theme; strings via ARB (en+zh_Hant+zh, gen-l10n). Frontend-only.

- [x] 1. `HealthScaffold`: persistent bottom nav (總覽/記錄/趨勢/更多) + IndexedStack;
      owns the token load + pre-loads today's day-keyed trackers; overview/trend
      401 → re-auth exit.
- [x] 2. 總覽 body = goal + record cards; 趨勢 body = trend card; 更多 body = a settings
      entry (pushes SettingsScreen).
- [x] 3. 記錄 hub: a tile per tracker (飲食/飲水/數值/運動/排便/生理期) pushing its screen
      for today.
- [x] 4. Convert `DietShellScreen` → `DietDayScreen` (diet-only: day-nav + Today +
      food + calendar; 目標 as an app-bar action). Remove the water/更多 tabs, bottom
      nav, and the nested 更多 menu.
- [x] 5. Rewire `home` to push `HealthScaffold`; delete `DashboardScreen`. New i18n
      (healthTabRecord / healthRecordDiet), regenerated.
- [x] 6. Tests: home_screen end-to-end (lands on scaffold + 總覽 card, 記錄 shows all 6
      tiles, 更多 → settings, 飲食 tile → diet screen, 目標 action → target screen);
      delete the obsolete shell/dashboard integration tests. Gates green.
