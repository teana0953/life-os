## MODIFIED Requirements

### Requirement: Recording a split expense

The split tab SHALL offer recording an expense with a group (optional), a
payer, an amount and currency, a description, a day, participants, a split
mode of equal or exact, and an optional finance category. The stored amounts
SHALL be in the currency's minor units. While submitting, the action SHALL be
disabled.

The category SHALL be chosen from the recorder's own finance categories and
sent as a name, because each participant's mirrored transaction resolves that
name against their own category list — an identifier would mean nothing to
them. Leaving it unset SHALL be allowed, and SHALL land every participant's
mirror in their fallback category, which is what happens today.

Because editing an expense replaces it wholesale, the form SHALL resend the
category it is editing: omitting it clears the expense's category and moves
every mirror nobody has hand-picked back to the fallback.

#### Scenario: An equal split is recorded

- **WHEN** the caller records an expense split equally between themselves
  and two others
- **THEN** the expense is created and the balances reflect it

#### Scenario: Submission cannot be double-fired

- **WHEN** a submission is in flight
- **THEN** the submit action is disabled

#### Scenario: A failed submission keeps what was typed

- **WHEN** submitting fails
- **THEN** an explanation is shown and every field the user filled in is
  still there

#### Scenario: A category is offered from the recorder's own list

- **WHEN** the user opens the expense form
- **THEN** they can pick one of their own expense categories, and leaving it
  unset is allowed

#### Scenario: Editing keeps the category it opened with

- **WHEN** the user edits an expense that has a category and changes only its
  amount
- **THEN** the expense still has the category it had before
