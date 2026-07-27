## MODIFIED Requirements

### Requirement: A care adherence card on the health trends tab

The health module's trends tab SHALL show a care adherence card alongside the vitals trend chart.
The card SHALL summarize a selectable period (e.g. 7 / 30 / 90 days, defaulting to a month-scale
period) with a headline (adherence rate, days with care done, missed count), a per-day heatmap,
and a legend. It SHALL derive everything from the same per-slot care records the history list
reads — no separate aggregate endpoint.

#### Scenario: The trends tab shows the care adherence card below the vitals chart
- **WHEN** the user opens the health module's trends tab
- **THEN** the vitals trend chart and the care adherence card are both shown, with the care card **after** the vitals chart (vitals are the primary axis; care is the secondary one)

#### Scenario: The card summarizes adherence
- **WHEN** the card has loaded records
- **THEN** a headline (adherence rate, days with care done, missed count), a per-day heatmap, and a legend are shown

#### Scenario: The heatmap colors each day by state
- **WHEN** the heatmap is shown
- **THEN** each day of the period is a cell colored by its state: full (every due slot done), partial (some due slots done), missed (at least one due slot and none done), upcoming (nothing due yet — which keeps today's cell from reading as missed before anything is due), or no-schedule (nothing scheduled)

#### Scenario: The heatmap lays out seven days per row
- **WHEN** the heatmap is shown
- **THEN** it lays out exactly seven cells per row — so every column is the same weekday — rather than a column count derived from the available width, and a weekday header names those columns

#### Scenario: Heatmap cells stay a readable size on a wide screen
- **WHEN** the heatmap is shown on a screen wide enough that seven cells could stretch
- **THEN** each cell is capped at a small fixed size and the grid aligns to the leading edge, rather than stretching into large blocks that dominate the tab

#### Scenario: The heatmap says which dates it covers
- **WHEN** the heatmap is shown
- **THEN** the period's first and last dates are readable as text beneath it, and today's cell is distinguished from the others — so a touch user can locate a cell without long-pressing it

#### Scenario: A heatmap cell exposes its state as text to assistive technology and pointer users
- **WHEN** a heatmap cell is rendered
- **THEN** its date and its state are both available as text — an accessibility label for screen readers and a tooltip for pointer/hover users — rather than color alone, and each cell is announced **once**, not twice

#### Scenario: A screen reader hears the summary before the cells
- **WHEN** a screen reader reaches the heatmap
- **THEN** it first encounters a one-line summary of the period (its per-state day counts), so the whole picture is available without traversing the day cells — each of which keeps its own label

#### Scenario: Each state's size is readable without interaction
- **WHEN** the legend is shown
- **THEN** each legend entry carries the number of days in that state, so a sighted user on a touch device can read how much of the period each state covers without long-pressing individual cells

#### Scenario: Each day state is distinguishable without color vision
- **WHEN** the heatmap and its legend are shown, in either theme
- **THEN** every state's fill is distinguishable from the card surface **and** from every other state's fill by luminance alone, so the states don't collapse into one another for a greyscale or fully color-blind reader in a cell that small

#### Scenario: The card links to the records it summarizes
- **WHEN** the card is shown, including when its load failed
- **THEN** it offers an entry to the care history record list, so a user who sees a missed or partial day on the heatmap can go correct that record from where the number is

#### Scenario: Switching the card's period reloads without blanking
- **WHEN** the user changes the card's period
- **THEN** the card reloads records for the corresponding date range (ending today, inclusive), keeping the current content visible with a progress indicator rather than blanking the card

#### Scenario: The card's own empty, loading, error, and auth states
- **WHEN** the period has nothing scheduled, or the first load is in flight, or the load fails, or the request needs re-auth
- **THEN** the card shows an empty state, a loading state, or a retryable error inside the card respectively — and a re-auth need surfaces through the trends tab's existing re-authenticate exit

#### Scenario: The empty card offers the next step
- **WHEN** the card's period has nothing scheduled
- **THEN** its empty state offers going to care management, rather than being a dead end — the period selector cannot help a user who has no care items at all

#### Scenario: A failed load says which period failed
- **WHEN** the card's load fails
- **THEN** the error names the period that failed, so the retained period selector reads as a way out rather than an unrelated control

#### Scenario: Correcting a record on the history screen refreshes the card
- **WHEN** the user successfully corrects a care record on the care history screen
- **THEN** the health module is signalled that its data is stale, and the card reflects the corrected record on its next load — while keeping its own selected period (period independence above is about the *period*, not about staying stale)

#### Scenario: The card's period is independent of the history screen's
- **WHEN** the user picks a period on the card and a different period on the care history screen
- **THEN** each keeps its own period and records; changing one does not overwrite the other
