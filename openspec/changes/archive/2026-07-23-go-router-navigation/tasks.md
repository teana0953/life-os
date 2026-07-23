# Tasks

## 1. Dependency
- [x] Add `go_router` to `pubspec.yaml`; `flutter pub get`.

## 2. Auth router notifier
- [x] `AuthRouterNotifier` (ChangeNotifier over `authStateChanges`, exposing
      loading/error/signedIn + retry). Unit test its state transitions.

## 3. Router + App
- [x] Build `GoRouter` in `_AppState` (routes per design; redirect + refreshListenable).
- [x] `MaterialApp` → `MaterialApp.router`; remove the `StreamBuilder` home.
- [x] Splash + auth-error as routes (reuse existing spinner / retry UI).

## 4. Convert transitions
- [x] home: `_openSettings` / `_openHealth` → `context.push`.
- [x] `HealthScaffold._push` (trackers) → `context.push`.
- [x] diet → food-search (value-returning) + diet → daily-target → `context.push` / `context.pop(result)`.
- [x] login → register → `context.push`.
- [x] Leave `showDialog` + `Navigator.pop` flows untouched.

## 5. Tests / gates
- [x] Rewrite `app_test.dart` for the router (redirect + a two-push/two-pop
      back-to-base regression).
- [x] Fix `food_search` / `daily_target` / `register` / `home` / `settings` tests
      (minimal GoRouter wrapper where they assert navigation).
- [x] `flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh` green.
