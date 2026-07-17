# CLAUDE.md — life-os

Architecture conventions for this repo. Read before adding or modifying any
frontend code (human or AI agent). Mirrors `life-os-backend/CLAUDE.md`.

## Architecture: Clean Architecture + DDD (hexagonal naming, context-first structure)

```
LoginScreen/HomeScreen (presentation, driving) ──▶ use cases (application, inbound port)
                                                       └─ AuthRepository / ProfileRepository port
                                                            ◀─ FirebaseAuthRepository / HttpProfileRepository
                                                               (driven adapters) ──▶ Firebase Auth / backend API
```

### Dependency rule

- `domain` imports nothing from outer layers. It defines entities and
  **ports** (interfaces) that outer layers implement or call.
- `application` depends only on `domain` and ports. It contains use cases
  (inbound ports) that orchestrate domain logic via injected repository
  ports.
- `infrastructure` implements ports (**driven adapters**, e.g.
  `FirebaseAuthRepository`, `HttpProfileRepository`).
- `presentation` (screens + `ChangeNotifier` controllers) drives the
  application from the outside (**driving adapter**) by calling use cases.
- Dependencies always point inward:
  `presentation → application → domain ← infrastructure`. Nothing in
  `domain` or `application` may import from `infrastructure` or
  `presentation`.
- `main.dart` is the only place that wires concrete adapters into use cases
  and controllers via manual dependency injection — no DI framework.

### Bounded contexts (context-first structure)

The codebase is organized **by context first, by layer second**:

```
lib/
  contexts/
    <context>/
      domain/            # entities, repository ports (interfaces)
      application/       # use cases (inbound ports), depend only on domain
      infrastructure/    # driven adapters implementing domain ports
      presentation/       # screens + ChangeNotifier controllers (driving adapter)
  shared/
    config.dart           # cross-context technical config (API_BASE_URL, ...)
  app.dart                 # MaterialApp + auth-state routing
  main.dart                # composition root (manual DI) + runApp
```

Each product area (auth, user, and future ones) becomes its own context
under `lib/contexts/`, copying the `contexts/user/` layout. Keep the
tactical pattern set lightweight: entity + repository port + thin use case
is enough until a context needs more — don't add value objects/domain
events speculatively (YAGNI).

### Naming conventions

- Driven adapters are named **`<TechnologyPrefix><PortName>`** (e.g.
  `FirebaseAuthRepository` implements the `AuthRepository` port,
  `HttpProfileRepository` implements the `ProfileRepository` port). Do not
  use an `~Adapter` suffix.
- Ports (interfaces) live in `domain/` and are named after the capability
  they expose (e.g. `AuthRepository`, not `IAuthRepository`).

### Adding a new context

1. Copy the `lib/contexts/user/` folder layout (`domain/`, `application/`,
   `infrastructure/`, `presentation/`) for the new context name.
2. Define entities and repository ports in `domain/`.
3. Define use cases in `application/`, depending only on `domain`.
4. Implement ports in `infrastructure/` (e.g. a `Http<X>Repository`).
5. Add screens/controllers under `presentation/` and wire them from
   `main.dart`.

## Testing strategy

- **domain / application layers**: plain Dart unit tests (`flutter test`).
  Use cases are tested with a fake repository implementing the port — no
  Firebase/network involved.
- **infrastructure layer**: unit tests inject a mock `http.Client` /ports;
  never hit real Firebase or the real backend.
- **presentation layer**: widget tests inject fake repositories via the
  controllers/use cases — never call `Firebase.initializeApp` or perform
  real HTTP calls.
- Run everything with `flutter test`. Lint/type-check with `flutter
  analyze`.

## Error handling

- Sign-in rejected by the auth service → `LoginScreen` shows a user-facing
  error message without exposing internal error detail.
- `/api/me` returns non-200 → `HomeScreen` shows an error state (not a
  crash); `401` specifically surfaces a "sign in again" exit rather than a
  dead end.
- Network exceptions are caught and surfaced the same way — never crash the
  UI.

## Firebase configuration

- `lib/firebase_options.dart` is committed (not gitignored). Firebase web
  config (`apiKey`, `appId`, ...) is a public client identifier, not a
  secret. Run `flutterfire configure` to overwrite the placeholder values
  checked in here with your project's real values.
- `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist` remain gitignored (web-first;
  add them only when Android/iOS builds are needed).

## Design system

A Chiikawa-inspired cute pastel design language, applied via a single
Material 3 theme (light + dark, following `ThemeMode.system`). See
`openspec/changes/add-design-system/design.md` for the full token
rationale.

- **Tokens**: `lib/shared/theme/app_colors.dart` — raw color constants
  (Hachiware blue primary, blush pink / Usagi yellow accents, cream
  ground, soft-brown ink/outline, sage/honey/error semantic colors).
  Never reference these hex values directly from a screen; go through
  the theme.
- **Theme**: `lib/shared/theme/app_theme.dart` — `lightTheme` and
  `darkTheme` (`ThemeData`, `useMaterial3: true`) with an explicit
  `ColorScheme` and component themes (`CardThemeData`,
  `InputDecorationTheme`, `FilledButtonThemeData`,
  `OutlinedButtonThemeData`, `TextTheme`). Use the `*ThemeData` types,
  not the deprecated non-`Data` aliases (e.g. `CardTheme`) — Flutter
  3.35's `ThemeData` constructor expects `*Data` and the old aliases
  trip `flutter analyze`.
- **Toy-ledge shadow**: the soft, downward-offset "step" shadow under
  cards/buttons is *not* `elevation` (which is symmetric). Use
  `ledgeShadow(outlineColor)` from `app_theme.dart` inside a
  `BoxDecoration.boxShadow` on a wrapping `Container`.
- **Mascot**: `lib/shared/widgets/mascot.dart` — an original
  `CustomPaint` round face (not a reproduction of any existing
  character), themed from `Theme.of(context).colorScheme`. Sized via
  the `size` constructor parameter.
- **Font**: Quicksand (SIL OFL 1.1), bundled offline at
  `assets/fonts/Quicksand-VariableFont_wght.ttf` and registered as the
  `Quicksand` family in `pubspec.yaml` (license: `assets/fonts/OFL.txt`).
  Bundled rather than fetched at runtime so it works offline and in
  tests. Applied via `ThemeData.fontFamily`, not per-widget.
- **Screens**: derive all colors, shapes, and text styles from
  `Theme.of(context)` — never hard-code a `Color(...)` or use
  `Colors.*` in presentation code.
- **Responsive breakpoints**: phone `< 600`, tablet `600–899`, desktop
  `>= 900` (logical pixels, via `LayoutBuilder`/`MediaQuery`). Sign-in
  centers its card with a `maxWidth` of ~420 that shrinks on narrower
  viewports instead of stretching edge-to-edge. Home centers its
  content in a `maxWidth` of 960 and the "Your spaces" grid uses
  `SliverGridDelegateWithFixedCrossAxisCount` with 2 columns on phone,
  3 on tablet, 4 on desktop.
- **New screens**: use `TextField` (not `TextFormField`) for consistency
  with existing widget tests that assert on `TextField.enabled`; wrap
  primary content in a themed `Container`/`Card` with the standard
  20–22px corner radius and 2px outline border; use `FilledButton` for
  primary actions (pill shape + ledge shadow come from the theme) and
  `OutlinedButton` for secondary actions. Test responsive layout with
  `tester.binding.setSurfaceSize(...)`, and always
  `addTearDown(() => tester.binding.setSurfaceSize(null))` to avoid
  leaking the size into later tests.
