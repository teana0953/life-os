# Design — Email/password sign-up

## Context

Auth is Firebase email/password. `AuthRepository` (domain) exposes
`signIn/signOut/idToken/authStateChanges` — no `signUp`. Sign-in failures flow
as a typed `AuthFailure(AuthFailureCode)`: `FirebaseAuthRepository` catches
`FirebaseAuthException` and maps its `code` via `authFailureCodeFor`; the
`LoginController` re-maps to a `LoginError` enum; `LoginScreen` maps that to
localized copy in `build()`. App routing is driven by `authStateChanges`, so a
successful `createUserWithEmailAndPassword` (which auto-signs-in) flips the app
to home with no manual navigation. Follow the frontend CLAUDE.md (Clean
Arch/DDD, typed errors in controllers, i18n, Chiikawa theme, TextField, fakes).

## Decisions

### D1 — Extend the typed-error vocabulary, don't fork it

Add `emailAlreadyInUse` and `weakPassword` to `AuthFailureCode` (`invalidEmail`
already exists, reused). Extend `authFailureCodeFor`: `email-already-in-use` →
`emailAlreadyInUse`, `weak-password` → `weakPassword`. Keeping one
`AuthFailureCode` vocabulary (not a separate sign-up enum in domain/infra) avoids
duplicating the Firebase mapping.

**Exhaustive-switch fallout (must handle):** `LoginController._mapError` is a
`switch` **expression** over `AuthFailureCode` with no `default`/`_`, so it is
exhaustive — adding two enum values makes it non-exhaustive and `flutter analyze`
/ compilation fails. So this change MUST add the two new cases to
`LoginController._mapError`, both mapping to `LoginError.unknown` (the sign-in
flow never produces email-already-in-use / weak-password, but the switch must
still cover them). This is a required edit, not optional.

### D2 — signUp down the same seam

- `AuthRepository.signUp(String email, String password): Future<void>`.
- `FirebaseAuthRepository.signUp` → `createUserWithEmailAndPassword`, `catch
  (FirebaseAuthException e)` → `throw AuthFailure(authFailureCodeFor(e.code))`
  (same shape as `signIn`).
- `SignUp` use case mirrors `SignIn` (thin call-through).

### D3 — Confirm-password is a presentation concern

`RegisterController` (mirrors `LoginController`) holds `isLoading`, a
`RegisterError?` enum (`emailAlreadyInUse`, `weakPassword`, `invalidEmail`,
`passwordMismatch`, `unknown`), **and a `bool succeeded` success signal** (see
D4 — the screen needs to know sign-up worked so it can pop itself).
`submit(email, password, confirmPassword)`:

1. If `password != confirmPassword` → set `RegisterError.passwordMismatch` and
   **return without calling `SignUp`** (a purely client-side check; Firebase
   never sees a mismatch).
2. Else call `SignUp`; on success set `succeeded = true` and notify; on
   `AuthFailure`, `_mapError` maps `AuthFailureCode` → `RegisterError`
   (emailAlreadyInUse/weakPassword/invalidEmail/unknown).

The controller holds the enum/flag, never localized text; `RegisterScreen` maps
the error in `build()`.

### D4 — Two screens, plain push/pop navigation

`RegisterScreen` mirrors `LoginScreen`'s layout (centered card, `maxWidth ~420`,
Mascot, theme — no hard-coded colors; `TextField`, not `TextFormField`): email,
password, confirm-password fields, a register `FilledButton` (loading state),
and a localized error area. It also carries the pre-auth `LanguageSwitcher` like
the login screen. `LoginScreen` gains a bottom `TextButton` "No account?
Register" → `Navigator.push(MaterialPageRoute(builder: (_) => RegisterScreen(...)))`;
`RegisterScreen` gets "Have an account? Sign in" → `Navigator.pop`.

**Success must pop the pushed register screen (required, not cosmetic).** Unlike
`LoginScreen` (which is the `MaterialApp` `home:` bottom route), `RegisterScreen`
is pushed on top of the root navigator. When sign-up succeeds, `authStateChanges`
flips `home:` from `LoginScreen` to the authenticated shell, but that only swaps
the bottom route — the pushed `RegisterScreen` would persist over the
authenticated home (the exact settings sign-out pitfall CLAUDE.md documents).
So `RegisterScreen` listens to the controller and, when `succeeded` becomes true,
`Navigator.pop`s itself (guarded by `Navigator.canPop`). This is why
`RegisterController` carries the `succeeded` flag (D3).

DI: `main.dart` builds `SignUp(authRepository)` and threads it (and/or a
`RegisterController`) to `LoginScreen` so it can construct `RegisterScreen`,
parallel to how `SignIn`/`LoginController` are already wired. `RegisterController`
is owned/disposed by `RegisterScreen`'s `State` (created in `initState`, disposed
in `dispose`) so a fresh push starts clean.

### D5 — i18n

New ARB keys (en template + zh-Hant + zh): register title/subtitle, register
button, confirm-password label, and error copy for password-mismatch,
email-already-in-use, weak-password (reuse existing `errorInvalidEmail` /
`errorSomethingWentWrong` where they fit), plus the two switch-link labels. No
hard-coded strings; regenerate `lib/l10n/generated`.

## Testing

- Domain/infra: `authFailureCodeFor` maps the two new codes; a fake/mock
  `FirebaseAuth` (or the existing pattern) verifies `signUp` throws the mapped
  `AuthFailure`.
- Controller: `RegisterController.submit` — mismatch → `passwordMismatch` and
  `SignUp` NOT called (assert the fake use case saw no call); success →
  no error; each `AuthFailureCode` → the right `RegisterError`; loading toggles.
- Widget: `RegisterScreen` with a fake `SignUp` — renders fields; mismatch shows
  the localized mismatch error without calling sign-up; a mapped failure shows
  the right localized copy; the login→register and register→login links
  navigate. Use `l10nTestApp`, inject fakes, never touch real Firebase.
