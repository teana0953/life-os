# Proposal: add-login-skeleton

## Why

The Life OS backend skeleton is deployed and verified, but nothing yet exercises the real authentication path from a client, and the backend's "valid Firebase token → user JSON" flow remains unverified end-to-end. A minimal Flutter login page establishes the frontend foundation and closes that gap: sign in with Firebase, call the backend, and show the returned profile.

## What Changes

- Scaffold the Flutter app in `life-os` (web-first, cross-platform), adding `firebase_core`, `firebase_auth`, `http`.
- Add an `AuthService` port (Firebase email/password sign-in, sign-out, ID token, auth-state stream) with a Firebase implementation and a fake for tests.
- Add an `ApiClient` port that calls `GET /api/me` with a bearer token and parses a `UserProfile`, with an HTTP implementation and a fake; backend base URL injected via `--dart-define=API_BASE_URL`.
- Add `LoginScreen` (email/password + error), `HomeScreen` (profile + sign out), and auth-state routing.
- Wire Firebase init + dependency injection in `main.dart` (composition root).

## Capabilities

### New Capabilities

- `login-flow`: email/password authentication via Firebase, retrieval of the authenticated user's profile from the backend, profile display, sign-out, and user-facing error handling — the frontend UI, auth port, and API-client port that make it work.

### Modified Capabilities

(none — first change in this repo.)

## Impact

- **New**: Flutter project in `life-os` (`lib/`, `test/`, `pubspec.yaml`, platform folders), gitignored Firebase config.
- **Dependencies**: `firebase_core`, `firebase_auth`, `http`; dev: `flutter_test`.
- **External (user)**: register a Firebase Web app (`flutterfire configure` → `lib/firebase_options.dart`), enable Email/Password sign-in, create a test user.
- **Backend**: CORS for localhost web origins — already shipped as a prerequisite (`feat/cors`, deployed).
- **Not affected**: backend code, `life-os-infra`. Android/iOS packaging and Cloudflare Pages deployment are deferred.
