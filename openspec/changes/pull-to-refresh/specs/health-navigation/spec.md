## ADDED Requirements

### Requirement: Data-bearing screens can be pull-to-refreshed and show when they last loaded

The health module's data-bearing screens SHALL support pull-to-refresh and SHALL show when the
data on that screen was last successfully loaded, so a user whose screen loaded stale content
(most often because the network was down) can force a fresh load without restarting the app and
can tell how old what they are looking at is.

This SHALL apply to the overview and trends tabs (which share a single batched load) and to each
day-keyed tracker screen that loads its own data (water, vitals, bowel, exercise). It SHALL NOT
apply to the record tab, which is a navigation hub that loads no data of its own.

Pulling to refresh SHALL reuse each screen's existing load path — the overview/trends batched
reload for those two tabs, and the tracker's own per-day reload for a tracker screen — including
its existing coalescing, so a pull that arrives while a load is already running does not run a
second load concurrently. The refresh gesture SHALL settle (stop showing its spinner) only when
the load it triggered has finished.

The last-loaded time SHALL be per load source, not a single global value: the overview and
trends share one time because they load together, while each tracker screen shows the time of
its own last load. The time SHALL be updated only on a successful load and SHALL be left
unchanged when a load fails, so it always reflects the data currently shown rather than the
moment of a failed attempt. It SHALL be shown as a readable clock time, not a machine timestamp.

#### Scenario: Pulling down on the overview reloads its cards
- **WHEN** the user pulls to refresh on the overview
- **THEN** the overview's batched load runs and the refresh spinner settles when that load finishes

#### Scenario: Pulling down on a tracker reloads that tracker's day
- **WHEN** the user pulls to refresh on a day-keyed tracker screen (water, vitals, bowel, or exercise)
- **THEN** that tracker reloads the day it is viewing and the refresh spinner settles when the reload finishes

#### Scenario: A refresh arriving mid-load does not run twice concurrently
- **WHEN** a pull-to-refresh happens while a load is already in flight
- **THEN** no second concurrent load starts, and the gesture settles once the coalesced load has completed

#### Scenario: The record tab has no pull-to-refresh
- **WHEN** the user is on the record tab
- **THEN** no pull-to-refresh is offered, because it loads no data of its own

#### Scenario: A screen shows when it last loaded
- **WHEN** a data-bearing screen has successfully loaded its data
- **THEN** it shows the clock time of that load

#### Scenario: A failed reload keeps the previous last-loaded time
- **WHEN** a reload fails after an earlier successful load
- **THEN** the screen keeps showing the earlier successful load's time, not the failed attempt's

#### Scenario: An overview reload where every card fails does not advance the time
- **WHEN** the overview reloads and every card fails to load (for example the network is down)
- **THEN** the last-loaded time is left unchanged, so it never claims a just-now load that produced no fresh data

#### Scenario: Refreshing a tracker with unsaved edits confirms before discarding
- **WHEN** the user pulls to refresh on a tracker screen that holds unsaved edits
- **THEN** it asks the user to confirm before reloading, and reloads only if the user confirms; if the user cancels, the edits and the current data are kept
