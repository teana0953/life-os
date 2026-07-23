# trend-combined-view Specification

## Purpose
TBD - created by archiving change bp-pulse-combined-trend. Update Purpose after archive.
## Requirements
### Requirement: Trend views group metrics onto one chart

The trend chart SHALL be selected by a *view* rather than a single raw metric. The
views SHALL be weight, body fat, blood pressure & pulse, glucose, and blood oxygen.
A single-metric view SHALL plot exactly one metric; the blood pressure & pulse view
SHALL plot systolic, diastolic, and pulse together, in that draw order.

#### Scenario: A single-metric view maps to one metric
- **WHEN** the metrics for the weight view are requested
- **THEN** the result is exactly the weight metric

#### Scenario: The blood pressure & pulse view maps to three metrics
- **WHEN** the metrics for the blood pressure & pulse view are requested
- **THEN** the result is systolic, diastolic, and pulse, in that order

### Requirement: The blood pressure & pulse view plots one multi-line chart

When the blood pressure & pulse view is selected, the trend chart SHALL plot
systolic, diastolic, and pulse as three distinct lines on one chart, show a
per-line legend naming each line, and SHALL NOT show a shaded normal-range band.
Single-metric views SHALL keep their single line and their normal-range band.

#### Scenario: Three lines with a per-line legend and no band
- **WHEN** the user views the blood pressure & pulse trend with data
- **THEN** the chart shows three lines, a legend naming systolic, diastolic, and pulse, and no shaded normal-range band

#### Scenario: A single-metric view keeps its band
- **WHEN** the user views the blood-oxygen trend with data
- **THEN** the chart shows one line with its shaded normal-range band

### Requirement: The multi-line view uses a value-less screen-reader summary

The trend chart's screen-reader summary SHALL, for a multi-line view (which has no
single latest value), state the view and range without a value, while a
single-metric view SHALL keep its value-carrying summary.

#### Scenario: Multi-line summary omits a latest value
- **WHEN** a screen reader reads the blood pressure & pulse trend with data
- **THEN** the summary names the view and the range in days without a single latest value

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

