## ADDED Requirements

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
