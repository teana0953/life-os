# Tasks — Email/password sign-up

## 1. Domain + infrastructure
- [ ] 1.1 Add `emailAlreadyInUse` + `weakPassword` to `AuthFailureCode`
      (`auth_exceptions.dart`). **Then add both as cases in
      `LoginController._mapError` → `LoginError.unknown`** — its switch over
      `AuthFailureCode` is exhaustive (no default), so new enum values break
      compilation until covered. Keep the existing login test green.
- [ ] 1.2 Extend `authFailureCodeFor` (`firebase_auth_error_messages.dart`):
      `email-already-in-use` → emailAlreadyInUse, `weak-password` → weakPassword.
      Unit test the two new mappings.
- [ ] 1.3 Add `signUp(email, password)` to the `AuthRepository` port; implement
      on `FirebaseAuthRepository` via `createUserWithEmailAndPassword`, catching
      `FirebaseAuthException` → `AuthFailure(authFailureCodeFor(code))`.

## 2. Application
- [ ] 2.1 `SignUp` use case mirroring `SignIn` (thin call-through).

## 3. Presentation (TDD)
- [ ] 3.1 `RegisterController` (mirror `LoginController`): `isLoading`,
      `RegisterError` enum (emailAlreadyInUse/weakPassword/invalidEmail/
      passwordMismatch/unknown), and a `bool succeeded` success flag.
      `submit(email,password,confirm)` → mismatch sets passwordMismatch and does
      NOT call `SignUp`; else calls `SignUp`, on success sets `succeeded=true`+
      notify, on failure maps `AuthFailureCode`. Unit tests: mismatch (no SignUp
      call), success sets succeeded, each mapped error, loading toggle.
- [ ] 3.2 `RegisterScreen` (mirror `LoginScreen`): email/password/confirm fields,
      register button + loading, localized error in build(), LanguageSwitcher,
      theme/Mascot/TextField, no hard-coded colors. Owns/disposes its
      `RegisterController` (initState/dispose). **Listens to the controller and
      `Navigator.pop`s itself (guarded by canPop) when `succeeded` becomes true**
      — the pushed register screen must not linger over the authenticated home
      after auth-state routing swaps the bottom route. Widget tests with fake
      `SignUp`: fields render; mismatch shows localized error + no sign-up call;
      a mapped failure shows the right copy; **success pops the screen**.
- [ ] 3.3 Login↔Register links: LoginScreen bottom "no account? register" →
      push RegisterScreen; RegisterScreen "have an account? sign in" → pop.
      Widget test the navigation both ways.

## 4. i18n + wiring
- [ ] 4.1 Add ARB keys (en + zh-Hant + zh): register title/subtitle, register
      button, confirm-password label, password-mismatch / email-in-use /
      weak-password errors, the two switch links. Regenerate l10n.
- [ ] 4.2 Wire `SignUp` + register flow in `main.dart` (manual DI), parallel to
      `SignIn`/`LoginController`.

## 5. Verify
- [ ] 5.1 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` green.
