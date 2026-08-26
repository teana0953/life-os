## ADDED Requirements

### Requirement: Today's care shows the dose quantity with the dose, for medication only

Wherever the Today care checklist (its pending queue row, its focus card, and its completed
group) or the health-overview today-care summary presents a medication slot's dose, it SHALL
present the dose quantity together with the free-text dose rather than the free-text dose
alone: the quantity as a unit-less multiplier (`×N`), followed by the free-text dose when the
slot has one. A whole-number quantity SHALL render without a trailing decimal, and no invented
unit word SHALL be added, because the stored quantity carries no unit. A medication slot with
no free-text dose SHALL still show its quantity, so the dose line is no longer omitted for
slots that only have a quantity. A non-medication slot SHALL show no dose line at all, in every
one of these presentations, because its quantity field is not user-editable and only ever
carries the backend's default value.

#### Scenario: A checklist slot shows quantity and dose together
- **WHEN** a Today slot is medication with a dose quantity of 2 and a free-text dose of `5mg`
- **THEN** the slot's dose line reads `×2 · 5mg`, in its pending-queue row, its focus card, and
  its completed-group row alike

#### Scenario: The overview summary shows quantity and dose together
- **WHEN** the overview today-care summary presents a medication slot with a dose quantity and
  a free-text dose
- **THEN** its dose line shows the quantity and the free-text dose together, in the same form
  as the checklist

#### Scenario: A medication slot with only a quantity still shows a dose line
- **WHEN** a presented medication slot has a dose quantity but no free-text dose
- **THEN** its dose line shows the quantity alone (for example `×2`), rather than being hidden

#### Scenario: A non-medication slot shows no dose line
- **WHEN** a presented slot's category is not medication
- **THEN** no dose line is shown for it, in the checklist or the overview summary, regardless
  of its stored quantity
