# login-flow Specification

## Purpose
TBD - created by archiving change add-login-skeleton. Update Purpose after archive.
## Requirements
### Requirement: Email/password sign-in
The app SHALL let an unauthenticated user sign in with an email and password via Firebase Authentication, and on success SHALL transition to the authenticated view.

#### Scenario: Successful sign-in
- **WHEN** a user enters valid credentials and submits the login form
- **THEN** the app authenticates via the auth service and shows the authenticated (home) view

#### Scenario: Rejected credentials
- **WHEN** a user submits credentials the auth service rejects
- **THEN** the app stays on the login screen and shows a user-facing error message without exposing internal error detail

### Requirement: Authenticated profile retrieval and display
Once authenticated, the app SHALL fetch the current user's profile from the backend `GET /api/me` using the Firebase ID token as a bearer credential, and SHALL display the returned email. It SHALL NOT display the internal user id.

#### Scenario: Profile loads
- **WHEN** the user is authenticated and the backend returns their profile
- **THEN** the home view displays the profile's email and does not show the internal user id

#### Scenario: Profile request fails
- **WHEN** the backend returns a non-success response for `/api/me`
- **THEN** the home view shows an error state (not a crash) and offers sign-out

### Requirement: Sign-out
The app SHALL let an authenticated user sign out and return to the login screen. Sign-out SHALL be available from the settings page, and SHALL also remain directly available on the home screen's error and re-authentication states as a recovery exit (so a failed profile load or an expired session is never a dead end).

#### Scenario: Sign-out from settings
- **WHEN** an authenticated user chooses sign-out in settings
- **THEN** the auth session ends and the app shows the login screen

#### Scenario: Sign-out as recovery on home error
- **WHEN** the home screen is in its profile-load error or re-authentication-needed state and the user chooses the sign-out / sign-in-again exit there
- **THEN** the auth session ends and the app shows the login screen

### Requirement: Auth-state routing
The app SHALL show the login screen when there is no authenticated user and the authenticated view when there is, driven by the auth service's state, without manual navigation on startup.

#### Scenario: Start unauthenticated
- **WHEN** the app starts with no authenticated user
- **THEN** the login screen is shown

#### Scenario: Start authenticated
- **WHEN** the app starts with an existing authenticated session
- **THEN** the authenticated view is shown

### Requirement: Email/password sign-up

The app SHALL let a new user create an account with an email and password. The
register form SHALL require the password to be entered twice and MUST reject a
mismatch with a localized error without attempting to create the account. On a
successful creation the user SHALL become signed in and be routed to the
authenticated app by the existing auth-state routing, with no manual navigation.
A creation failure SHALL surface a localized message for the known cases
(email already in use, weak password, invalid email) without leaking internal
error detail. The sign-in and sign-up screens SHALL each offer a link to switch
to the other.

#### Scenario: Successful registration signs the user in
- **WHEN** a new user submits a valid email and matching passwords
- **THEN** the account is created and the app routes to the authenticated home via auth-state changes

#### Scenario: Password confirmation must match
- **WHEN** the user submits a password and a confirmation that differ
- **THEN** the app shows a localized "passwords do not match" error and does not attempt to create the account

#### Scenario: Email already in use
- **WHEN** the user tries to register with an email that already has an account
- **THEN** the app shows a localized "email already in use" error and stays on the register screen

#### Scenario: Weak password rejected
- **WHEN** the user submits a password the auth service considers too weak
- **THEN** the app shows a localized "password too weak" error and stays on the register screen

#### Scenario: Invalid email rejected
- **WHEN** the user submits a malformed email address
- **THEN** the app shows a localized "invalid email" error and stays on the register screen

#### Scenario: Switch between sign-in and sign-up
- **WHEN** the user taps the register link on the sign-in screen
- **THEN** the register screen is shown, and it offers a link back to sign-in

