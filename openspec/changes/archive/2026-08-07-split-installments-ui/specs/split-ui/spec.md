# split-ui Specification

## ADDED Requirements

### Requirement: A share can be put on a repayment schedule

The expense form SHALL let the payer put a single participant's share on a
monthly repayment schedule by naming a period count, and SHALL derive the
per-period amount rather than asking for it — the server accepts a schedule
only when the periods multiply back to exactly the share, so two free numbers
would be two chances to be rejected.

A schedule SHALL be offered on **exact** splits only, and the form SHALL say
so rather than letting the control fall silently out of effect when the mode
changes. A schedule already entered SHALL NOT survive a switch back to an
equal split unannounced.

The form SHALL show what an existing schedule already is when editing, and
SHALL send it back unchanged when the user did not touch it. A schedule the
form cannot see is a schedule the next save deletes, and deleting it charges
the holder for the whole amount again on top of the periods already in their
ledger.

#### Scenario: Putting a share on a schedule

- **WHEN** the payer sets a participant's share to 6,000 over 12 periods
- **THEN** the form shows 500 per period, and the saved expense carries that
  schedule

#### Scenario: An existing schedule survives an unrelated edit

- **WHEN** the user opens a scheduled expense, changes only its description,
  and saves
- **THEN** the schedule is sent back as it was, and the holder's ledger still
  holds the same periods

#### Scenario: Equal mode has no schedules

- **WHEN** the split mode is equal
- **THEN** the form states that schedules need an exact split rather than
  showing a control whose value would be dropped

### Requirement: An indivisible share is adjusted in the open

Where the chosen period count does not divide the share exactly, the form
SHALL adjust that share down to the nearest divisible amount and move the
difference to another participant, and SHALL show both the old and the new
figure. A number silently different from what the user typed is the failure
this rule exists to prevent.

The participant who absorbs the difference SHALL be chosen in a defined
order: the payer's own share first, then any participant not themselves on a
schedule. Where neither exists, the form SHALL block the save and offer the
period counts that would divide exactly, rather than adjusting a scheduled
share and silently invalidating that person's own schedule.

#### Scenario: The payer absorbs the rounding

- **WHEN** a 6,100 share is put on 12 periods and the payer holds a share of
  their own
- **THEN** the scheduled share becomes 6,096 with the change shown, the
  payer's share rises by 4, and the save is allowed

#### Scenario: Nobody can absorb it

- **WHEN** a 6,100 share is put on 12 periods and it is the only share
- **THEN** the save is blocked and the form names period counts that divide
  6,100 exactly

### Requirement: The balance says where each schedule has got to

A balance row SHALL show every repayment schedule behind it, one line each,
naming which period is next, of how many, and what that period is worth. Two
things split with the same person in the same currency are two schedules, and
a single combined line would belong to neither.

A balance SHALL still read as the whole of what is owed. A schedule says when
the money moves, not whether the debt exists, and the row's amount SHALL NOT
be reduced to the periods already due.

#### Scenario: Two schedules with one person

- **WHEN** a counterpart is repaying two split expenses in the same currency
- **THEN** the balance row shows both schedules, each with its own period
  count and per-period amount

#### Scenario: No schedule

- **WHEN** a counterpart owes an ordinary lump balance
- **THEN** the row shows no schedule line at all, rather than a zeroed one
