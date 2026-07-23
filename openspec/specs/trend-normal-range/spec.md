# trend-normal-range Specification

## Purpose
TBD - created by archiving change trend-normal-range. Update Purpose after archive.
## Requirements
### Requirement: Normal reference range per metric

The system SHALL provide, for each trend metric, its normal reference range or an indication that there is none. Blood pressure (systolic 90–120, diastolic 60–80), pulse (60–100), glucose (70–140), and blood oxygen (95–100) SHALL use fixed clinical ranges. Weight SHALL use a range derived from a healthy BMI of 18.5 to 24.9 and the user's height (`min = 18.5 × (height/100)²`, `max = 24.9 × (height/100)²`), and SHALL have no range when the height is unset. Body fat SHALL have no range.

#### Scenario: A clinical metric has its fixed range
- **WHEN** the normal range for systolic blood pressure is requested
- **THEN** it is 90 to 120

#### Scenario: Weight's range comes from healthy BMI and height
- **WHEN** the normal range for weight is requested for a height of 165 cm
- **THEN** it is about 50.4 to 67.8 kg (18.5 and 24.9 × 1.65²)

#### Scenario: Weight has no range without a height
- **WHEN** the normal range for weight is requested with no height set
- **THEN** there is no range

#### Scenario: Body fat has no range
- **WHEN** the normal range for body fat is requested
- **THEN** there is no range

### Requirement: Trend chart shows the normal-range band

When the selected metric has a normal reference range, the trend chart SHALL show a shaded horizontal band spanning that range, keep the band visible by including it in the chart's value axis extent, and show a legend identifying the band as the normal range. When the selected metric has no range, no band and no legend SHALL be shown.

#### Scenario: A band is shown for a metric with a range
- **WHEN** the user views the trend for a clinical metric (e.g. blood oxygen)
- **THEN** the chart shows a shaded band over its normal range with a "normal range" legend

#### Scenario: The weight band appears once a height is set
- **WHEN** the user has set their height and views the weight trend
- **THEN** the chart shows the healthy-weight band; with no height set, no band is shown

#### Scenario: No band for body fat
- **WHEN** the user views the body-fat trend
- **THEN** no normal-range band or legend is shown

