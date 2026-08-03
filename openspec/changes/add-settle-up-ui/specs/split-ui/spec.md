## MODIFIED Requirements

### Requirement: Split failures are explained and actionable

Each failure the server distinguishes SHALL be explained in terms the user
can act on, never as a status code: not friends, not a group member, group
archived, shares not summing, split too small, duplicate participant,
already a member, cannot settle with yourself, and an invalid link or unknown
record SHALL each produce their own message.

#### Scenario: Not friends

- **WHEN** the server answers `not_friends`
- **THEN** the message says the person is not yet a friend and points at
  adding them first

#### Scenario: Archived group

- **WHEN** the server answers `group_archived`
- **THEN** the message says the group is archived and no expense can be
  added to it

#### Scenario: Shares do not add up

- **WHEN** the server answers `shares_do_not_sum_to_amount`
- **THEN** the message states the discrepancy rather than a status code

#### Scenario: A failed write is never silent

- **WHEN** creating a group, adding a member, or archiving a group fails
- **THEN** the failure is shown to the user, rather than the dialog closing
  on nothing

#### Scenario: A pass-through message still reads in the user's language

- **WHEN** the server answers `invalid_split_input` or `bad_request`, whose
  explanation text the server writes itself
- **THEN** that text is wrapped in localized framing — the two failures
  read differently from each other, and the user always gets at least one
  sentence in their own language

## ADDED Requirements

### Requirement: Settling up starts from the balance that shows the debt

Each **person-to-person** balance line SHALL offer settling it — group
figures, which state a member's net against the whole group rather than a
debt to a named person, SHALL NOT, since there is no payer and payee to
derive. Choosing it SHALL open a form
pre-filled with that line's currency and its full outstanding amount, and
with the direction already decided from the sign of the balance — the user
SHALL NOT be asked which way the money goes. A balance spanning two
currencies SHALL offer one settle action per currency, each pre-filled with
its own amount; there is no cross-currency repayment.

#### Scenario: Being owed pre-fills a repayment coming in

- **WHEN** the user is owed 450 TWD by someone and settles that line
- **THEN** the form is pre-filled with 450 TWD and records that person paying
  the user

#### Scenario: Owing pre-fills a repayment going out

- **WHEN** the user owes 450 TWD and settles that line
- **THEN** the form is pre-filled with 450 TWD and records the user paying
  that person — the two directions are not interchangeable and are never
  chosen by the user

#### Scenario: Each currency settles on its own

- **WHEN** a balance with one person spans TWD and USD
- **THEN** each currency line offers its own settle action, pre-filled with
  that currency's amount

#### Scenario: A group figure offers no settle action

- **WHEN** a group's per-member net figures are shown
- **THEN** none of them offers settling, because it names no counterpart to
  pay

#### Scenario: A group figure says it excludes repayments

- **WHEN** a group's per-member net figures are shown
- **THEN** they are labelled as excluding repayments — because a repayment
  recorded person-to-person never moves them, so without the label the group
  screen would keep showing a debt the split tab shows as settled, silently
  and permanently

#### Scenario: Settling is reachable from a group's members

- **WHEN** the user opens a group
- **THEN** their person-to-person balance with each member is shown as well,
  labelled as spanning all their shared history rather than only that group,
  and each such line offers settling

#### Scenario: A group member who is not a friend can still be settled with

- **WHEN** a group member the user is not friends with appears in the
  person-to-person section
- **THEN** settling is offered for them like any other member — sharing a
  group is enough, so a debt that arose through the group is never stranded

#### Scenario: A settled balance disappears

- **WHEN** the full amount is settled
- **THEN** that currency no longer appears in the balance with that person

### Requirement: Partial and excess repayments are both allowed

The pre-filled amount SHALL be editable. Paying less SHALL leave the
remainder owing. Paying more SHALL be allowed — it is a real situation, not
an error — but the user SHALL be warned before submitting, in terms that name
the consequence.

#### Scenario: Paying part leaves the rest

- **WHEN** the user owes 450 and settles 300
- **THEN** they still owe 150

#### Scenario: Overpaying warns but proceeds

- **WHEN** the user owes 450 and enters 600
- **THEN** a warning states that the other person will end up owing them 150,
  and submitting is still permitted

#### Scenario: The warning names the direction that actually applies

- **WHEN** the user is owed 450 and records the other person paying 600
- **THEN** the warning states that **the user** will end up owing 150 — the
  form is reachable from both directions and one fixed sentence would be
  wrong half the time

#### Scenario: An empty or non-positive amount is refused before sending

- **WHEN** the amount is cleared, zero, or not a whole number
- **THEN** submission is refused locally with a reason, rather than sent and
  rejected by the server

### Requirement: A repayment reads as a repayment, not as another expense

Repayments SHALL be listed alongside expenses but SHALL be visually and
textually distinguishable from them, so settling a debt is never misread as
spending more money.

#### Scenario: A repayment is labelled as one

- **WHEN** a repayment appears in the list
- **THEN** it is marked as a repayment in words, not only by an icon or a
  colour, and cannot be mistaken for an expense row

### Requirement: Only the creator or the payer is offered deleting a repayment

Because a repayment cannot be edited, correcting one means deleting it. That
action SHALL be offered only to the user who recorded it or the one who paid;
anyone else SHALL not see an action the server would refuse. Deleting SHALL
require a confirmation naming the other person and the amount.

#### Scenario: A payee sees no delete action

- **WHEN** the payee, who did not record the repayment, views it
- **THEN** no delete action is offered

#### Scenario: Deleting is confirmed by name and amount

- **WHEN** the creator deletes a repayment
- **THEN** a confirmation naming the other person and the amount is shown
  first, and the balance returns to what it was once confirmed

### Requirement: Settle-up copy states direction and consequence

Every figure and action SHALL say who owes whom in words rather than relying
on colour, and the settle form SHALL name the other person and the direction
so the user need not go back to check which line they tapped.

#### Scenario: The form names the direction

- **WHEN** the settle form opens for a debt the user owes
- **THEN** its heading names the other person and makes clear the user is
  paying them

### Requirement: Settle-up lays out on small screens

The settle form, the repayment rows and the delete confirmation SHALL lay out
without layout errors at 320dp and 360dp wide, on a phone-height viewport, in
each supported locale, at text scales 1.0 and 2.0, including with an amount
wide enough to be realistic rather than a token fixture.

#### Scenario: Narrow screens stay clean

- **WHEN** any settle-up surface is rendered at 320dp or 360dp on a
  phone-height viewport in any supported locale at text scale 1.0 or 2.0,
  with a seven-figure amount
- **THEN** no layout error is raised and the confirm and cancel actions are
  on screen and tappable
