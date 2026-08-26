## MODIFIED Requirements

### Requirement: List care reminders grouped by category with an empty state

The screen SHALL list the user's care reminders grouped by category (medication, rehab,
radiotherapy care, custom), each showing its title, a schedule summary, and — for medication —
its stock; when there are none it SHALL show an empty-state guide, not a blank page. Each
schedule's summary SHALL include its start date regardless of the schedule's every-N-weeks
interval, so a start date the user set in the form is visible in the list they set it from.
For a medication reminder's schedule, the summary SHALL also include the dose quantity that
schedule takes per firing, expressed as a multiplier (`×N`) because the stored quantity carries
no unit; a whole-number quantity SHALL render without a trailing decimal. A non-medication
reminder's schedule summary SHALL NOT include a quantity, because its quantity field is not
user-editable and only ever carries the backend's default value. For a medication reminder that
has a free-text dose, that dose SHALL be shown on its own line under the schedules, so it is not
mistaken for belonging to a single schedule.

#### Scenario: Reminders are listed by category
- **WHEN** the user has care reminders in more than one category
- **THEN** each appears under its category heading with its title and schedule summary

#### Scenario: No reminders shows guidance
- **WHEN** the user has no care reminders
- **THEN** an empty-state guide (with a way to add one) is shown

#### Scenario: The summary shows the start date on a plain daily or weekly schedule
- **WHEN** a listed reminder has a schedule whose every-N-weeks interval is 1
- **THEN** that schedule's summary includes its start date, and still omits the
  every-N-weeks suffix

#### Scenario: The summary shows each medication schedule's dose quantity
- **WHEN** a listed medication reminder has a schedule whose dose quantity is 2
- **THEN** that schedule's summary shows the quantity as `×2`, with no invented unit word

#### Scenario: A whole-number quantity has no trailing decimal
- **WHEN** a listed medication schedule's dose quantity is a whole number
- **THEN** it is shown as an integer (for example `×2`, never `×2.0`)

#### Scenario: A medication's free-text dose is its own line
- **WHEN** a listed medication reminder has a free-text dose
- **THEN** that dose is shown on a separate line from the schedule summaries

#### Scenario: A non-medication reminder shows no dose at all
- **WHEN** a listed reminder is not a medication
- **THEN** no free-text dose line is shown for it, and its schedule summaries show no dose
  quantity either
