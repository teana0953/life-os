# home-dashboard-ui Specification

## Purpose
TBD - created by archiving change menstrual-status-badges. Update Purpose after archive.

## Requirements

### Requirement: The home menstrual tile names a date whenever it has one

The home dashboard's menstrual-prediction tile SHALL show an explicit calendar
date in every loaded state for which a date exists, rather than only a relative
count. A tile that says "day 4" without saying which day the period started, or
"3 days late" without saying late for which date, forces the user to open the
tracker to recover a date the app already holds — which is the one thing a
dashboard tile exists to avoid.

Specifically: an ongoing period SHALL name the date the period started, derived
from today and the reported day of the period; a prediction still ahead, a
prediction due today, and a prediction that has passed SHALL each name the
predicted next start date. The tile SHALL carry the same status badge
vocabulary as the health overview's next-period card, so the two do not depict
the same state differently. A tile whose state has no date to show — no records
at all, or only one record — SHALL keep its existing wording and show no date
and no badge.

The date line SHALL NOT change the tile's height between states: every state of
the tile, including the ones with no date, SHALL occupy the same height as its
neighbouring tiles, because tiles that grow and shrink between states move
their neighbours' tap targets under the user's finger.

The tile SHALL keep its existing loading and failure behaviour: while the value
is still loading, or when it failed with no previously loaded value, the tile
SHALL show its status line instead of a badge and a date — a failure SHALL NOT
be drawn as a no-data state, and SHALL NOT be drawn with a stale badge.

#### Scenario: An ongoing period names its start date

- **WHEN** today is the 4th day of an ongoing period
- **THEN** the tile shows the day count with a filled badge and a second line
  naming the date the period started, which is three days before today

#### Scenario: A passed prediction names the predicted date

- **WHEN** the predicted next start was 3 days ago
- **THEN** the tile shows how many days overdue with an outlined warning badge,
  a second line naming the predicted date, and its outline in the warning
  colour

#### Scenario: A prediction due today names that date

- **WHEN** the predicted next start is today
- **THEN** the tile says it is expected today and its second line names that
  date plainly, with no redundant "= today" suffix

#### Scenario: A prediction still ahead keeps its date

- **WHEN** the predicted next start is 6 days away
- **THEN** the tile shows the day count with an outlined badge and keeps naming
  the predicted date as it already did

#### Scenario: A state with no date shows none

- **WHEN** no period has been recorded, or exactly one has been recorded
- **THEN** the tile shows its existing wording with no badge and no date line

#### Scenario: Every state of the tile is the same height

- **WHEN** the tile is rendered in each of its loaded states in turn, including
  the ones with no date line
- **THEN** the tile's height is identical across all of them and equal to the
  other tiles in its row, so no neighbouring tile's tap target moves

#### Scenario: A failure is not drawn as data

- **WHEN** the menstrual arm failed to load and no previously loaded value
  exists
- **THEN** the tile shows its retryable failure status line, with neither a
  badge nor a date

#### Scenario: A stale value keeps its badge and date

- **WHEN** the menstrual arm failed to reload but a previously loaded value
  exists
- **THEN** the tile keeps showing that value's badge and date and marks it as
  stale and retryable, rather than discarding it
