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
Once authenticated, the app SHALL fetch the current user's profile from the backend `GET /api/me` using the Firebase ID token as a bearer credential, and SHALL display the returned identity (email and id).

#### Scenario: Profile loads
- **WHEN** the user is authenticated and the backend returns their profile
- **THEN** the home view displays the profile's email and id

#### Scenario: Profile request fails
- **WHEN** the backend returns a non-success response for `/api/me`
- **THEN** the home view shows an error state (not a crash) and offers sign-out

### Requirement: Sign-out
The app SHALL let an authenticated user sign out and return to the login screen.

#### Scenario: Sign-out
- **WHEN** an authenticated user chooses sign-out
- **THEN** the auth session ends and the app shows the login screen

### Requirement: Auth-state routing
The app SHALL show the login screen when there is no authenticated user and the authenticated view when there is, driven by the auth service's state, without manual navigation on startup.

#### Scenario: Start unauthenticated
- **WHEN** the app starts with no authenticated user
- **THEN** the login screen is shown

#### Scenario: Start authenticated
- **WHEN** the app starts with an existing authenticated session
- **THEN** the authenticated view is shown

