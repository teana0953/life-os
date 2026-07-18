# Proposal: add-i18n

## Why

All UI text is hard-coded in English. The user (Traditional Chinese speaker) needs the app in their language. Internationalizing now — while the surface is small (sign-in + home) — establishes the pattern so every future module ships localized from the start.

## What Changes

- Add Flutter i18n via the official `gen_l10n` toolchain: `flutter_localizations` + `intl`, `l10n.yaml`, and ARB files for **English** (template) and **Traditional Chinese** (`zh-Hant`).
- Add a `LocaleController` that follows the system locale by default and supports in-app language switching, persisted with `shared_preferences`.
- Wire `MaterialApp` with the localization delegates, `supportedLocales`, and an English fallback; add a language switcher on the sign-in and home screens.
- Move all hard-coded UI copy into ARB resources — including error messages: infrastructure/application throw typed errors (e.g. `ReauthenticationRequired`, `ProfileFetchFailure`, coded auth failures) and the presentation layer maps them to localized strings, so no UI copy lives in `infrastructure`.
- Migrate existing widget tests (which assert on English literals) to a fixed test locale, and add i18n tests.

## Capabilities

### New Capabilities

- `i18n`: multi-language UI — English and Traditional Chinese, selected by system locale with an in-app switcher and a remembered choice, English fallback, and all user-facing copy (including errors) sourced from localized resources rather than hard-coded.

### Modified Capabilities

(none at the spec-behavior level — `login-flow` and `design-system` behaviors are unchanged; only the text is now localized.)

## Impact

- **New**: `lib/l10n/` (ARB files), `l10n.yaml`, `lib/shared/i18n/locale_controller.dart`, i18n tests.
- **Modified**: `pubspec.yaml` (deps + `generate: true`), `lib/app.dart` (delegates, supportedLocales, locale), `lib/main.dart` (LocaleController wiring + prefs), the sign-in/home screens and error-message code (copy → ARB; typed errors), existing tests, `CLAUDE.md`.
- **Not affected**: auth/api business logic, backend, CI/CD. Japanese / Simplified Chinese and future-module strings are out of scope (adding a locale later is just another ARB file).
