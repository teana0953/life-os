# login-flow — Delta Spec

## MODIFIED Requirements

### Requirement: Sign-out
The app SHALL let an authenticated user sign out and return to the login screen. Sign-out SHALL be available from the settings page, and SHALL also remain directly available on the home screen's error and re-authentication states as a recovery exit (so a failed profile load or an expired session is never a dead end).

#### Scenario: Sign-out from settings
- **WHEN** an authenticated user chooses sign-out in settings
- **THEN** the auth session ends and the app shows the login screen

#### Scenario: Sign-out as recovery on home error
- **WHEN** the home screen is in its profile-load error or re-authentication-needed state and the user chooses the sign-out / sign-in-again exit there
- **THEN** the auth session ends and the app shows the login screen
