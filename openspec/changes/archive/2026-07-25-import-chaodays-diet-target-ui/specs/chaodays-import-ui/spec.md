## ADDED Requirements

### Requirement: Chaodays import screen offers a diet-target import

The chaodays import screen SHALL present a "diet target" import type in addition to
weight, diet, water, and bowel, and importing SHALL include it in the same sequence
against the entered credentials and date range. Its per-type row SHALL show the same
not-attempted / importing / success / failed states as the others, and on success
SHALL show the imported/skipped counts for the daily portion targets and the water
target. The row SHALL reuse the existing import flow, credentials handling, and
error display (auth failure / unavailable) without a new screen or dialog.

#### Scenario: The diet-target row is present and imports
- **WHEN** the user opens the chaodays import screen and runs an import with valid credentials and a date range
- **THEN** a "diet target" row is shown alongside the other types and, on success, displays its imported/skipped counts (portion targets, and the water target)

#### Scenario: Diet-target failure surfaces like the others
- **WHEN** the diet-target import fails with wrong credentials or an unavailable upstream
- **THEN** its row shows the same failure state/message as the other import types
