# assistant-health-consent Specification

## Purpose
Governs whether the AI assistant may read the user's health and diet records: how
that consent is granted and revoked, what the user is told before granting it, and
how it reaches the backend — which exposes the health tools only to a request that
carries the consent, and to no other.

## Requirements

### Requirement: Health access is off until the user turns it on

The assistant SHALL have no access to the user's health or diet records unless the
user has explicitly enabled it. The initial state on a device with no stored
preference SHALL be disabled, and no request SHALL claim consent the user has not
given.

#### Scenario: A device that has never been configured
- **WHEN** the app starts with no stored health-consent preference
- **THEN** health access is reported as disabled and the settings switch is off

#### Scenario: The preference survives a restart
- **WHEN** the user enables health access and the app is restarted
- **THEN** health access is still enabled, without the user re-enabling it

#### Scenario: Turning it back off persists too
- **WHEN** the user disables health access and the app is restarted
- **THEN** health access is disabled

### Requirement: Signing out revokes health consent with the key

Signing out SHALL clear the stored health consent together with the stored Gemini
API key, both in memory and in on-device storage, so that a user signing in
afterwards on the same device starts with health access disabled.

#### Scenario: Sign-out clears both
- **WHEN** the user signs out with a key stored and health access enabled
- **THEN** both the key and the health consent are cleared from memory and from
  on-device storage

#### Scenario: The next session does not inherit consent
- **WHEN** the app is restarted after a sign-out that revoked consent
- **THEN** health access is disabled and no health consent is present in on-device
  storage

### Requirement: The settings control states what is sent and where

The AI assistant section of the settings page SHALL offer a switch for health access
and SHALL, in the user's language, state as standing rules that: enabling it lets the
assistant read the user's health, diet and care records; those records are sent to
Google's Gemini; content sent on the free tier is generally used to improve Google's
models; the records covered include menstrual cycles, blood glucose, vital signs and
care records, named explicitly rather than summarized as "health data"; and signing
out turns the setting back off.

The switch's own label SHALL name the same scope the disclosure does, so that the
control the user toggles does not describe a narrower grant than the paragraph beside
it.

Care records ride this one consent — there is no separate care switch, no second
header, and no additional stored preference. The disclosure SHALL therefore not
suggest that care access is granted or revoked separately from health and diet
access.

The disclosure SHALL NOT claim access to record types the assistant cannot in fact
read under this consent; reminder and push-notification records are outside it and
SHALL NOT be named as covered.

#### Scenario: The switch reflects and changes the stored consent
- **WHEN** the settings page is opened
- **THEN** the switch shows the current consent state, and toggling it stores the new
  state

#### Scenario: The disclosure is present
- **WHEN** the AI assistant section is shown
- **THEN** the destination (Google's Gemini), the free-tier training use, the named
  record types (menstrual cycles, blood glucose, vital signs, care records) and the
  sign-out revocation are all readable on screen, in the selected language

#### Scenario: The switch label covers care too
- **WHEN** the AI assistant section is shown in either supported language
- **THEN** the health-access switch's label names care records alongside health and
  diet records, rather than health and diet records alone

#### Scenario: Care is not presented as a separate opt-in
- **WHEN** the AI assistant section is shown
- **THEN** exactly one health-access switch is offered, and no separate care-access
  control or second consent appears

#### Scenario: The disclosure reads as a standing rule
- **WHEN** the user opens settings without having just signed out or changed anything
- **THEN** the disclosure is phrased as how the feature works, not as a notice that
  something has happened

### Requirement: Consent is settable without a stored key

The health-access switch SHALL be operable whether or not a Gemini API key is stored,
and the section SHALL state that with no key stored the assistant makes no requests
at all.

#### Scenario: No key stored
- **WHEN** the settings page is opened with no Gemini API key stored
- **THEN** the health-access switch is enabled, can be turned on, and the stored
  consent changes accordingly

#### Scenario: The no-key consequence is stated
- **WHEN** no key is stored
- **THEN** the section states that nothing is sent anywhere until a key is added

### Requirement: The consent travels on the request, and only when granted

An assistant request SHALL carry the health-consent header `X-Assistant-Health` with
the exact value `on` when, and only when, the user has enabled health access at the
moment of sending. When health access is disabled the header SHALL be absent from the
request entirely — not sent empty, and not sent with any other value. The value SHALL
be exactly `on` in lower case with no surrounding whitespace, because the backend
compares it exactly and denies access on any other value.

#### Scenario: Enabled
- **WHEN** a message is sent with health access enabled
- **THEN** the request carries `X-Assistant-Health: on` alongside the existing
  authorization and key headers

#### Scenario: Disabled
- **WHEN** a message is sent with health access disabled
- **THEN** the request carries no `X-Assistant-Health` header at all

#### Scenario: A retry carries the consent in force at retry time
- **WHEN** the user retries a failed message after changing the health-access setting
- **THEN** the retried request reflects the current setting, not the one in force when
  the original message was sent
