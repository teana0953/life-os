# Email/password sign-up

## Why

The app can only sign in existing accounts — there is no way to create one from
the UI. Add open email/password registration so a new user can make an account
and land signed-in. The backend needs no change: its user store is
get-or-create by `firebase_uid`, so the row is created on the new user's first
authenticated request.

## What Changes

- `AuthRepository` gains `signUp(email, password)`; `FirebaseAuthRepository`
  implements it via `createUserWithEmailAndPassword`, mapping Firebase errors
  (`email-already-in-use`, `weak-password`, `invalid-email`) to typed failures.
- New `SignUp` use case and `RegisterController` + `RegisterScreen`, mirroring
  the sign-in shape. The register form has email, password, and **confirm
  password** (client-side match check → a typed error, never hitting Firebase).
- On success, Firebase auto-signs-in and the existing auth-state routing sends
  the user to home — no manual navigation.
- The login screen gets a "no account? register" link to the register screen,
  and the register screen a "have an account? sign in" link back.
- New localized copy (en + zh-Hant + zh) for the register screen and its errors.

## Impact

- Affected spec: `login-flow` — a new "Email/password sign-up" requirement.
- Affected code: `auth` context front-end only (domain typed errors,
  infrastructure mapping + repo, a use case, two presentation files, the login
  screen link, ARB copy). No backend change.
