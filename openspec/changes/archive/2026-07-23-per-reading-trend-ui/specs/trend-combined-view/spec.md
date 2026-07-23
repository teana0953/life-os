## ADDED Requirements

### Requirement: The trend chart plots every reading on a time axis

The trend chart SHALL plot one point per reading at a position combining the point's day and its time-of-day, so multiple readings on the same day are spread across that day rather than stacked. A point with no time SHALL sit at the start of its day.

#### Scenario: Same-day readings are spread by time
- **WHEN** a metric has two readings on the same day at 08:00 and 20:00
- **THEN** the two points appear at different horizontal positions within that day's slot

### Requirement: The glucose view splits by meal context and keeps a band

The glucose trend view SHALL split its glucose series by meal context into up to four lines — fasting, pre-meal, post-meal, and unspecified (points with no context) — each a distinct colour with a legend naming the contexts that have data, and SHALL show a general glucose normal band (70–140) behind them.

#### Scenario: Glucose splits into per-context lines over a band
- **WHEN** the user views the glucose trend with fasting, post-meal, and untagged readings
- **THEN** the chart shows a line per context that has data, a legend naming those contexts, and a shaded glucose normal band with its legend

#### Scenario: A context with no data is omitted from the legend
- **WHEN** the glucose trend has no pre-meal readings
- **THEN** the pre-meal context is absent from the legend

### Requirement: Glucose readings are recorded with a structured meal context

The daily-log glucose row SHALL let the user pick a reading's meal context from 空腹 / 餐前 / 餐後; picking a context sets it and tapping the selected one clears it. The chosen context SHALL be saved with the reading.

#### Scenario: Picking a context sets it on the reading
- **WHEN** the user taps the 空腹 chip on a glucose reading and saves
- **THEN** the saved reading carries the fasting meal context

#### Scenario: Tapping the selected context clears it
- **WHEN** a glucose reading's 空腹 chip is selected and the user taps it again
- **THEN** the reading's meal context is cleared
