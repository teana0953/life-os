# life-os

Flutter frontend for Life OS. Minimal login skeleton: Firebase email/password
sign-in → fetch the user's profile from the backend `GET /api/me` → display
it. See `CLAUDE.md` for architecture conventions.

Targets Flutter Web (Chrome) first; the code stays cross-platform.

## Prerequisites (do this before running the app)

1. **Register a Firebase Web app and generate config**: in your Firebase
   project, add a Web app, then run `flutterfire configure` in this
   directory. It overwrites `lib/firebase_options.dart` with your project's
   real values (this file is committed — Firebase web config is a public
   client identifier, not a secret).
2. **Enable Email/Password sign-in**: Firebase Console → Authentication →
   Sign-in method → enable Email/Password.
3. **Create a test user**: Firebase Console → Authentication → Users → add
   an email/password account to sign in with.

## Running

```
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://life-os-backend.playground-92f.workers.dev
```

`API_BASE_URL` defaults to the URL above if omitted; pass a different value
(e.g. a local backend) to override it.

## Testing

```
flutter analyze
flutter test
```

Tests inject fake `AuthRepository`/`ProfileRepository` implementations and
never call `Firebase.initializeApp` or perform real network requests.
