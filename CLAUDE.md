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
