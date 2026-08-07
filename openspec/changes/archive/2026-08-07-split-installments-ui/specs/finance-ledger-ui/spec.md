# finance-ledger-ui Specification

## ADDED Requirements

### Requirement: A split repayment period is marked as one

A transaction the server wrote as one period of a **split** repayment
schedule SHALL say which period it is, in both the list and the sheet. Twelve
identical rows of 500 with nothing distinguishing them is the state this rule
exists to end.

Being a period SHALL be read from the period number itself, not from the
presence of an instalment plan. A split repayment has no plan — it is the
holder repaying a person, not a bank — so a rule keyed on the plan marks none
of them. Plan-level offers (going to the plan, settling it) SHALL stay keyed
on the plan, which is what they actually need.

The total period count SHALL NOT be claimed where it is not known: a split
period carries its own position and nothing about the schedule it belongs to,
and "of 12" invented from an unrelated source would be a number the server
never said.

#### Scenario: A split repayment period in the list

- **WHEN** the month contains the third period of a friend's repayment
- **THEN** the row shows both that it came from a split and that it is period
  3

#### Scenario: No plan, no plan actions

- **WHEN** the user opens a split repayment period
- **THEN** the sheet says which period it is and offers no way to a plan,
  because there is none — while its category and note stay editable like any
  other mirrored row

#### Scenario: An instalment plan period is unaffected

- **WHEN** the user opens the third period of their own twelve-period plan
- **THEN** it still says period 3 of 12 and still offers the way to the plan
