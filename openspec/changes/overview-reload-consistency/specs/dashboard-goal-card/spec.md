## ADDED Requirements

### Requirement: An overview card that cannot refresh keeps its content and says so

Every card on the health overview SHALL distinguish two failures that are not the same thing.
Having never loaded, it has nothing to show and SHALL show the failure and a retry in place of
content. Having already loaded, it SHALL keep the content it has, say that it could not be
refreshed, and offer a retry for itself — because the reload is automatic (an import, a return
to the overview), so taking away what the user was reading is a bigger harm than the content
being a few minutes stale. Silence is not an option either: content that failed to refresh
SHALL NOT look identical to content that just refreshed.

#### Scenario: A failed refresh keeps the content and marks it
- **WHEN** a card that is already showing content fails to reload
- **THEN** it keeps showing that content, marked as not refreshed, with a retry — the overview
  does not collapse and nothing the user was reading is taken away

#### Scenario: A first load that fails shows the failure instead of content
- **WHEN** a card that has never loaded fails to load
- **THEN** it shows the failure and a retry, because it has no content to keep

#### Scenario: Retry reloads only its own card
- **WHEN** the user retries from one card
- **THEN** only that card's data is reloaded — cards each have their own source, so one
  failing says nothing about the others

#### Scenario: A refresh in flight is not a failure
- **WHEN** a card that is already showing content is reloading
- **THEN** it keeps showing that content with no failure marking

#### Scenario: A successful retry clears the marking
- **WHEN** a retry succeeds
- **THEN** the card shows the fresh content with no failure marking

#### Scenario: A 401 is not handled by the card
- **WHEN** a card's load fails with an authentication failure
- **THEN** the card does not present its own error; the overview's re-authentication exit takes
  over, as it already does
