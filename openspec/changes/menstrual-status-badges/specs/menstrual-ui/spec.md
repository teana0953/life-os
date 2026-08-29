## ADDED Requirements

### Requirement: The next-period card leads with a status badge

The health overview's next-period card SHALL lead its content with a circular
status badge that carries the state's number and unit as text, so the state is
readable at a glance and the card shares one visual vocabulary with the
tracker's calendar. The badge SHALL reuse exactly the calendar's two marker
forms and no third one: a **filled** badge for a period day that is actually
happening, and an **outlined** badge for a prediction. An ongoing period SHALL
use the filled form in the period colour; a prediction still ahead SHALL use
the outlined form in the same colour; a prediction due today SHALL use the
filled form in a neutral colour, matching how the calendar already marks today;
and a prediction that has passed SHALL use the outlined form in the warning
colour, because it is still a prediction — one that has not yet been confirmed.

A state with nothing to predict — no records at all, or only one record —
SHALL NOT render a badge at all, not even an empty one, because an empty circle
reads as a count of zero.

The badge's text SHALL NOT be the only thing a screen reader hears: the badge
SHALL be excluded from the semantics tree and the card SHALL announce one whole
sentence naming the state, the number and the date, so nothing is announced as
a bare number. The badge's own text SHALL remain inside its circle when the
user enlarges system text, by clamping the scale applied inside the badge; the
surrounding date and explanation text SHALL NOT be clamped.

#### Scenario: An ongoing period shows a filled badge

- **WHEN** today is the 4th day of an ongoing period
- **THEN** the card shows a filled badge in the period colour reading 4 days, a
  main line saying a period is ongoing, and — when a prediction is still ahead
  — the predicted date below it

#### Scenario: A prediction still ahead shows an outlined badge

- **WHEN** the predicted next start is 6 days away
- **THEN** the card shows an outlined badge in the period colour reading 6
  days, a main line saying how many days remain, and the predicted date below
  it

#### Scenario: A prediction due today shows a neutral filled badge

- **WHEN** the predicted next start is today
- **THEN** the card shows a filled badge in the neutral outline colour reading
  "today", a main line saying it is expected today, and no date sub-line,
  because the main line already says which day it is

#### Scenario: A passed prediction shows a warning outlined badge and says how late it is

- **WHEN** the predicted next start was 3 days ago
- **THEN** the card shows an outlined badge in the warning colour reading 3
  days late, a main line saying it is overdue, the predicted date, and a
  further line stating in words that the predicted date has been passed by 3
  days

#### Scenario: The overdue state does not rely on colour alone

- **WHEN** the card is in the overdue state
- **THEN** the number of days overdue is present as text in the badge and
  restated in the explanation line, so the warning colour only reinforces
  information that is already written

#### Scenario: States with nothing to predict carry no badge

- **WHEN** no period has been recorded, or exactly one has been recorded
- **THEN** the card shows its existing wording with no badge and no date, so
  nothing reads as a zero-day count

#### Scenario: The badge is announced as part of a whole sentence

- **WHEN** a screen reader focuses the card in any badged state
- **THEN** it announces one sentence naming the state, the number of days and
  the relevant date, and never announces the badge's text on its own

#### Scenario: The badge text stays inside the badge at large text sizes

- **WHEN** the user has enlarged system text well beyond the default
- **THEN** the badge's text is clamped so it still fits inside the circle
  without overflow, while the card's date and explanation lines still grow with
  the user's setting
