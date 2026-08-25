## MODIFIED Requirements

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
