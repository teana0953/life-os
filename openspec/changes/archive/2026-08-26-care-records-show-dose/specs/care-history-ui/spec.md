## ADDED Requirements

### Requirement: History slots show the dose taken, for medication only

Each medication care slot listed in the history SHALL show its dose alongside its time and
status: the dose quantity as a unit-less multiplier (`×N`) and, when the slot has a free-text
dose, that text after it. A whole-number quantity SHALL render without a trailing decimal. The
quantity SHALL NOT be dressed in an invented unit word, because the stored quantity carries no
unit. A non-medication slot SHALL show no dose line at all, because its quantity field is not
user-editable and only ever carries the backend's default value.

#### Scenario: A medication slot with quantity and free-text dose
- **WHEN** a listed history slot is medication with a dose quantity of 2 and a free-text dose
  of `5mg`
- **THEN** its row shows both, as `×2 · 5mg`, next to its time and status

#### Scenario: A medication slot with no free-text dose
- **WHEN** a listed history slot is medication with a dose quantity of 1 and no free-text dose
- **THEN** its row shows `×1` and no separator or empty dose text

#### Scenario: A fractional quantity keeps its decimal
- **WHEN** a listed history slot is medication and its dose quantity is 0.5
- **THEN** its row shows `×0.5`, while a whole-number quantity shows as an integer

#### Scenario: A non-medication slot shows no dose line
- **WHEN** a listed history slot's category is not medication
- **THEN** its row shows no dose line, regardless of its stored quantity
