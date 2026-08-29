# menstrual-ui Specification

## Purpose
TBD - created by archiving change menstrual-ui. Update Purpose after archive.

## Requirements

### Requirement: Menstrual tracker reached via More

The daily-log shell SHALL offer a menstrual tracker via its More overflow menu, and selecting it SHALL show the menstrual screen with an app bar back control. The menstrual screen SHALL NOT be tied to the shell's viewed day — it shows the user's whole period history and cycle statistics regardless of which day the shell is viewing.

#### Scenario: The menstrual tracker is reachable from More
- **WHEN** the user opens the More menu and selects the menstrual tracker
- **THEN** the menstrual screen is shown with a back control that returns to the More menu

### Requirement: Mini-calendar of periods

The menstrual screen SHALL show a month calendar (Sunday-first) that marks the days belonging to each recorded period (from its start date through its end date inclusive; an open period marks from its start through today) and marks the predicted next start date with a distinct marker. The user SHALL be able to move to the previous and next month.

Each marked period day SHALL also show which day of that period it is — the period's start date is day 1 — so the length of a period can be read off the calendar without counting cells. The number SHALL be shown together with, not instead of, the day-of-month number. Days that belong to no period — including the predicted next start — SHALL NOT carry a day-of-period number. Where more than one recorded period covers the same day, the number SHALL come from the period with the latest start date among those covering it, matching how the overview card resolves the same overlap, so the two never disagree about a day. The count SHALL NOT be capped: an open period left unclosed showing a large number is the signal that it was never closed. The day cell's accessible label for a period day SHALL name the day of the period as well as the date.

#### Scenario: A recorded period is marked across its range
- **WHEN** a period runs 2026-05-01 to 2026-05-05 and the user views May 2026
- **THEN** each day from the 1st through the 5th is marked as a period day

#### Scenario: A period day shows which day of the period it is
- **WHEN** a period runs 2026-05-01 to 2026-05-05 and the user views May 2026
- **THEN** the 1st shows day 1, the 3rd shows day 3 and the 5th shows day 5, each alongside its day-of-month number

#### Scenario: An open period counts through today
- **WHEN** a period started 2026-05-01 with no end date and today is 2026-05-04
- **THEN** the 4th shows day 4, and no day after today carries a number

#### Scenario: A day belonging to no period carries no number
- **WHEN** the user views a month containing days outside every recorded period, including the predicted next start
- **THEN** those days show only their day-of-month number

#### Scenario: Overlapping periods resolve to the later start
- **WHEN** 2026-05-03 is covered both by a period starting 2026-05-01 and by one starting 2026-05-03
- **THEN** the 3rd shows day 1, from the later-starting period, and not day 3

#### Scenario: A long-unclosed period is not capped
- **WHEN** a period started 40 days ago and was never given an end date
- **THEN** today shows day 41 rather than a truncated or capped number

#### Scenario: A period day is announced with its day of the period
- **WHEN** a screen reader focuses a day that is the 3rd day of a recorded period
- **THEN** the announcement names the date and that it is day 3 of the period

#### Scenario: The predicted next start is marked
- **WHEN** the overview predicts the next start on 2026-07-24 and the user views July 2026
- **THEN** the 24th carries the predicted-next marker, distinct from a recorded period day

#### Scenario: Month navigation
- **WHEN** the user taps the next-month control
- **THEN** the calendar advances to the following month

### Requirement: Add, edit, and delete a period

The menstrual screen SHALL let the user add a period (a start date and an optional end date), edit an existing period (change its dates, or clear its end date to reopen a completed period), and delete a period. Each action SHALL take effect immediately — persisted to the backend and the overview re-read — rather than being staged behind a save control. An end date earlier than the start date SHALL be prevented.

#### Scenario: Adding a period shows it on the calendar
- **WHEN** the user adds a period starting 2026-06-01 with no end date
- **THEN** the overview is re-read and the 1st of June onward is marked as an open period

#### Scenario: Setting an end date
- **WHEN** the user edits an open period to set an end date
- **THEN** the period is now marked through that end date

#### Scenario: Reopening a completed period
- **WHEN** the user clears the end date of a completed period
- **THEN** the period becomes open again (marked from its start through today)

#### Scenario: Deleting a period
- **WHEN** the user deletes a period
- **THEN** it is removed from the calendar after the overview is re-read

### Requirement: Cycle statistics

The menstrual screen SHALL show the derived cycle statistics from the overview — the average cycle length, the average period length, and the predicted next start — and the most recent period. Each statistic SHALL display a placeholder (e.g. "—") when it is null (not enough data).

#### Scenario: Statistics are shown when available
- **WHEN** the overview reports an average cycle of 28 days and a predicted next start of 2026-07-24
- **THEN** the screen shows those values

#### Scenario: Missing statistics show a placeholder
- **WHEN** the overview reports null statistics (not enough data)
- **THEN** the screen shows a placeholder rather than a number

### Requirement: Menstrual API errors are surfaced without crashing

The menstrual screen SHALL surface a load or save failure as an error state rather than crashing, and an authentication failure (401) SHALL surface a re-authentication exit consistent with the other trackers.

#### Scenario: A load failure shows an error state
- **WHEN** loading the overview fails
- **THEN** the screen shows an error state rather than crashing

### Requirement: The overview shows when the next period is due

The health overview SHALL show the predicted next period and how it relates to today, so
the user does not have to open the tracker to find out. The card SHALL be present whether
or not a prediction exists, because it is also the way into the tracker.

#### Scenario: A future prediction shows the date and the wait
- **WHEN** the predicted next start is later than today
- **THEN** the overview shows that date together with how many days away it is

#### Scenario: A prediction for today says so
- **WHEN** the predicted next start is today
- **THEN** the overview says it is expected today rather than showing a zero-day countdown

#### Scenario: Having recorded nothing is stated plainly
- **WHEN** no period has been recorded at all
- **THEN** the overview says so, rather than showing a placeholder or omitting the card

#### Scenario: One recorded period says what would make a prediction possible
- **WHEN** exactly one period has been recorded, so a cycle length cannot be derived
- **THEN** the overview says recording one more would make a prediction possible — a
  promise it SHALL NOT make to someone who has recorded nothing, for whom one more
  recording still yields no prediction

### Requirement: A prediction that has passed is reported as overdue

The overview SHALL say when the expected date has passed and by how much, rather than
presenting a past date as if it were upcoming, and SHALL NOT roll the prediction forward to
manufacture a future one. The prediction is the last recorded start plus the average cycle
and is not clamped to the future, so it falls into the past whenever recording has lapsed.

#### Scenario: An expected date in the past is called out
- **WHEN** the predicted next start is earlier than today
- **THEN** the overview shows that it is overdue, and by how many days

#### Scenario: The prediction is not advanced to the next cycle
- **WHEN** the predicted next start is well in the past
- **THEN** the date shown is still the predicted one, not one silently advanced by whole
  cycles to land in the future

### Requirement: An ongoing period takes precedence over the prediction

The overview SHALL report an ongoing period ahead of the next prediction when today falls
inside any recorded period — including one with no recorded end — and SHALL say which day
of it today is, while still showing the predicted next start when that prediction is
still ahead. The day count SHALL NOT be capped: a period left open long ago showing a large day count is the signal that it was
never closed.

#### Scenario: Today inside a period reports the day of it
- **WHEN** today falls within a recorded period
- **THEN** the overview says a period is ongoing and which day of it today is, ahead of the
  next prediction

#### Scenario: An ongoing period does not hide a prediction still ahead
- **WHEN** a period is ongoing and the predicted next start is still in the future
- **THEN** the predicted date is still shown, so someone who records starts but not ends
  is not left without the thing this card exists to show

#### Scenario: An ongoing period drops a prediction that has arrived or passed
- **WHEN** a period has been left open until its predicted next start is today or earlier
- **THEN** no predicted date is shown — labelling today's date "next expected", or a past
  one, is the same contradiction the overdue wording exists to avoid, arriving through the
  ongoing state instead. This is the resolution where the two requirements meet.

#### Scenario: An ongoing period with nothing to predict from still reads correctly
- **WHEN** the only recorded period is the ongoing one, so no next start can be predicted
- **THEN** the card reports the ongoing period alone, with no predicted date and no
  placeholder standing in for one — the state of someone recording for the first time

#### Scenario: A period that covers today wins over a later-starting one
- **WHEN** a period covering today was recorded alongside a later-starting one that does
  not cover today
- **THEN** today is reported as ongoing, so the overview and the tracker's calendar do not
  disagree about the same day

#### Scenario: A period with no end date counts as ongoing
- **WHEN** a recorded period has no end date and started on or before today
- **THEN** it is treated as ongoing

### Requirement: The overview card opens the menstrual tracker

Tapping the card SHALL open the menstrual tracker, in every state including when there is
no prediction — the state in which the user is most likely to want to go and record
something.

#### Scenario: Tapping the card opens the tracker
- **WHEN** the user taps the card
- **THEN** the menstrual tracker opens, reached through the application's own routing so a
  back control returns to the overview

#### Scenario: The shortcut works with no data
- **WHEN** no period has been recorded yet
- **THEN** the card is still shown and still opens the tracker

### Requirement: Period calendar jumps to a distant month

The menstrual mini-calendar SHALL let the user reach any month in one step by
tapping its month title to open the month picker, in addition to the existing
previous/next month arrows.

#### Scenario: Jumping back a year in the period calendar

- **WHEN** the user taps the period calendar's month title and picks a month a
  year earlier
- **THEN** the calendar shows that month

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
