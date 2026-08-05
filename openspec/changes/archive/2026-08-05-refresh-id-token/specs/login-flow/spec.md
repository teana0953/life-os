## ADDED Requirements

### Requirement: ID token freshness

Screens SHALL resolve the ID token at the moment they make an authenticated
request, rather than holding a value captured when they were built, so that a
session left open past the token's lifetime keeps sending a valid token.

The app SHALL NOT hold a long-lived token snapshot on the object that drives
auth routing; that object's job is the signed-in/loading/error state only.

#### Scenario: A request made later uses a later token

- **WHEN** a screen makes an authenticated request some time after it was built
- **THEN** it sends the token resolved at request time, not the one that was
  current when it was built

#### Scenario: Each request resolves the token again

- **WHEN** a screen makes two authenticated requests and the token changed
  between them
- **THEN** the second request carries the second token

#### Scenario: Auth routing is unaffected

- **WHEN** the user signs in or signs out
- **THEN** routing between the login screen and the authenticated view behaves
  as before
