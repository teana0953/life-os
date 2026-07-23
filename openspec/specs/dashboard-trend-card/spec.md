# dashboard-trend-card Specification

## Purpose
TBD - created by archiving change dashboard-trend-card. Update Purpose after archive.
## Requirements
### Requirement: Trend card on the dashboard

The dashboard SHALL show a trend card (its second card, below the goal card) with a line chart of one vitals metric over a date range, a metric picker, and a range selector. The metric picker SHALL offer weight, body fat, systolic, diastolic, pulse, glucose, and blood oxygen; the range selector SHALL offer 7, 30, and 90 days. Changing the range SHALL reload the data for that span (ending today); changing the metric SHALL re-plot the selected metric's series.

#### Scenario: The trend card is shown with a picker and range selector
- **WHEN** the user opens the dashboard
- **THEN** the trend card is shown below the goal card with a metric picker, a 7/30/90-day range selector, and a chart

#### Scenario: Switching metric re-plots
- **WHEN** the user selects a different metric
- **THEN** the chart shows that metric's series over the current range

#### Scenario: Switching range reloads
- **WHEN** the user selects a different range (e.g. 90 days)
- **THEN** the data is reloaded for that span and the chart updates

### Requirement: Plot the selected metric's series

The trend card SHALL plot the selected metric's daily points (day on the x-axis, value on the y-axis) over the selected range. When the selected metric has no points in the range, the card SHALL show a "no data yet" message in the chart area rather than an empty or misleading plot.

#### Scenario: A metric with data is plotted
- **WHEN** the selected metric has recorded points in the range
- **THEN** the chart plots those points as a line over the range

#### Scenario: A metric with no data shows a message
- **WHEN** the selected metric has no points in the range
- **THEN** the chart area shows a "no data yet" message instead of a plot

### Requirement: Trend range data over the API

The system SHALL fetch the trend data from `GET /api/vitals/range?from=&to=` with the bearer token, mapping the response to the per-metric series. A load failure SHALL surface as an error state (with a retry), and a 401 SHALL surface a re-authentication exit consistent with the rest of the dashboard.

#### Scenario: A load failure shows an error state
- **WHEN** loading the trend range fails
- **THEN** the trend card shows an error state rather than crashing

