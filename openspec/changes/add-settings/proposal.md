# Proposal: add-settings

## Why

The app has no settings page — language switching is a chip on the login/home screens, and the theme is locked to `ThemeMode.system` with no user control. Users want to pick their theme (light/dark/system) and manage preferences in one place. A dedicated settings page consolidates language + theme + sign-out and gives future preferences a home.

## What Changes

- Add a `ThemeController` (mirroring `LocaleController`): holds `ThemeMode` (system/light/dark), persisted with `shared_preferences`; `MaterialApp.themeMode` follows it.
- Add a localized `SettingsScreen` with three sections: **Theme** (system/light/dark), **Language** (system/English/繁體中文, reusing `LocaleController`), and **Sign out**.
- Add a settings entry point (gear icon) to the home header that navigates to the settings page; move the home language chip and sign-out into settings. Keep the language chip on the login screen (pre-auth language choice).
- Add ARB strings for the settings UI (English + Traditional Chinese).

## Capabilities

### New Capabilities

- `settings`: a dedicated, localized settings page for user preferences — theme selection (light/dark/system, remembered), language selection, and sign-out — reached from the home screen.

### Modified Capabilities

- `login-flow`: the standard (loaded-state) sign-out moves into the settings page, while the home screen's error / re-authentication states keep their direct sign-out / sign-in-again recovery exits (delta clarifies sign-out placement). `i18n` and `design-system` behaviors are unchanged; the loaded-state language switch relocates into settings, the login language chip stays.

## Impact

- **New**: `lib/shared/theme/theme_controller.dart`, `lib/contexts/settings/presentation/settings_screen.dart`, settings ARB strings, tests.
- **Modified**: `lib/app.dart` (themeMode from controller), `lib/main.dart` (ThemeController wiring + prefs), `lib/contexts/user/presentation/home_screen.dart` (settings entry; move language chip + sign-out out), existing home tests, `CLAUDE.md`.
- **Not affected**: auth/api logic, backend, CI/CD. Other settings (account, notifications) and custom theme colors are out of scope.
