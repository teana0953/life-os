## ADDED Requirements

### Requirement: Shared async-state scaffold

The system SHALL provide a shared async-state scaffold that renders a
loading indicator while loading, a re-authentication state while
re-authentication is required, and the caller's content otherwise. Loading
SHALL take precedence over re-authentication.

The re-authentication state SHALL present both the caller-supplied message
and a control that starts re-authentication, so the user is never shown a
problem without a way to act on it. The control SHALL be a required
constructor parameter, so that a screen cannot silently render a
re-authentication state with no way out.

#### Scenario: The re-authentication state offers a way out

- **WHEN** the scaffold is in the re-authentication state
- **THEN** the caller's message and an enabled sign-in-again control are both
  visible, and tapping the control invokes the caller's callback

#### Scenario: Loading still wins over re-authentication

- **WHEN** both loading and re-authentication are signalled at once
- **THEN** the loading indicator is shown and no sign-in-again control appears

#### Scenario: The re-authentication state is reachable without an app bar

- **WHEN** the scaffold is in the re-authentication state and the caller
  supplied no app bar
- **THEN** the sign-in-again control is still present and hittable, so a
  screen with no back affordance is not a dead end

#### Scenario: The control's callback is the caller's, not the widget's

- **WHEN** the sign-in-again control is tapped
- **THEN** the scaffold invokes exactly the callback it was given and performs
  no navigation of its own — what happens to the route stack afterwards is
  the caller's obligation and is not specified here
