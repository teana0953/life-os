# Proposal: add-design-system

## Why

The app currently uses Flutter's default Material styling — no visual identity. Life OS is a personal health & life-management app; it should feel warm, calm, and friendly. The user chose a **Chiikawa-inspired cute pastel** direction (aligned via a visual mockup). This change establishes a reusable design system and applies it to the existing screens, so every future module inherits a consistent look.

## What Changes

- Add a Flutter Material 3 theme (`lib/shared/theme/`): light + dark `ThemeData` with an explicit `ColorScheme` (Hachiware blue primary, blush pink & Usagi yellow accents, cream ground, soft-brown ink) and component themes (filled/outlined buttons as pills with soft-brown outlines and a toy-ledge shadow, rounded outlined inputs, rounded cards, a rounded type scale).
- Bundle a rounded OFL font (e.g. Baloo 2 / Quicksand) as a pubspec asset for offline + test reliability.
- Add an original cute mascot widget (not a copyrighted character).
- Restyle `LoginScreen` and `HomeScreen` to the themed components and design tokens — no behavior change.
- Make both screens **responsive** (phone → desktop): centered max-width sign-in card; responsive "spaces" grid on home.
- `MaterialApp` uses `theme` / `darkTheme` / `themeMode: system`.
- Document the design-system conventions in the repo `CLAUDE.md`.

## Capabilities

### New Capabilities

- `design-system`: the app's visual identity and responsive behavior — a themed Material 3 design language (color, type, shape, component styles, light/dark) applied consistently, and layouts that adapt across phone and desktop widths.

### Modified Capabilities

(none — `login-flow` behavior is unchanged; only presentation is restyled.)

## Impact

- **New**: `lib/shared/theme/` (`app_theme.dart`, `app_colors.dart`), `lib/shared/widgets/` (mascot), `assets/fonts/` (rounded font), theme/responsive tests.
- **Modified**: `lib/app.dart` (theme wiring), `lib/contexts/auth/presentation/login_screen.dart`, `lib/contexts/user/presentation/home_screen.dart` (restyle), `pubspec.yaml` (font asset), `README`/`CLAUDE.md`.
- **Not affected**: auth/api logic, backend, CI/CD. Future modules (Health, Finance, …) are out of scope — the home "spaces" grid preview is illustrative only.
