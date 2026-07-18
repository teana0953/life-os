## MODIFIED Requirements

### Requirement: Authenticated profile retrieval and display
Once authenticated, the app SHALL fetch the current user's profile from the backend `GET /api/me` using the Firebase ID token as a bearer credential, and SHALL display the returned email. It SHALL NOT display the internal user id.

#### Scenario: Profile loads
- **WHEN** the user is authenticated and the backend returns their profile
- **THEN** the home view displays the profile's email and does not show the internal user id

#### Scenario: Profile request fails
- **WHEN** the backend returns a non-success response for `/api/me`
- **THEN** the home view shows an error state (not a crash) and offers sign-out
