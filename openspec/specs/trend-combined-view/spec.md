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

