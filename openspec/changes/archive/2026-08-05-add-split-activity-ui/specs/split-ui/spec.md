## ADDED Requirements

### Requirement: Split change log

The split section SHALL offer a change log listing what has happened to the
user's shared expenses, groups and repayments, newest first, separately from
the list of expenses that currently exist.

An entry SHALL name who made the change, using the second person when that
person is the reader.

An entry about a deleted record SHALL still show what was deleted, and SHALL
not offer to open or edit it.

An entry about an amount being changed SHALL show what the amount was as well
as what it became. Every kind of recorded change SHALL have its own wording,
including changes to groups.

An entry SHALL never show a raw account identifier in place of a person's
name.

#### Scenario: A deletion is readable afterwards

- **WHEN** the change log contains an entry for a deleted expense
- **THEN** it shows that expense's amount and description, and the entry
  cannot be tapped

#### Scenario: An edit says what the amount became

- **WHEN** the change log contains an entry for an expense whose amount was
  changed
- **THEN** it shows both the previous and the new amount

#### Scenario: A missing display name does not become an identifier

- **WHEN** a person involved in an entry has no display name
- **THEN** the entry shows a placeholder for them, not their account id

#### Scenario: The reader is named in the second person

- **WHEN** an entry records a change the reader made
- **THEN** the entry refers to them as "you" rather than by name

### Requirement: Repayment direction in the change log

A change-log entry about a repayment SHALL state who paid whom, correctly for
the reader whether they paid, were paid, or were neither.

#### Scenario: The payer reads their own repayment

- **WHEN** the reader recorded a repayment they made
- **THEN** the entry says they paid the other person

#### Scenario: The recipient reads a repayment made to them

- **WHEN** the reader is the person a repayment was made to
- **THEN** the entry says the other person paid them

#### Scenario: A third party reads a repayment between two others

- **WHEN** the reader is a group member who is neither party to a repayment
- **THEN** the entry names both people and which of them paid

### Requirement: Change log paging

The change log SHALL load further entries as the reader reaches the end of the
list, and SHALL stop requesting once the server reports no further page.

#### Scenario: Reaching the end loads more

- **WHEN** the reader scrolls to the end of the loaded entries and the server
  has reported a further page
- **THEN** the next page is requested and its entries are appended

#### Scenario: Reaching the end stops the requests

- **WHEN** the reader scrolls to the end and the server has reported no
  further page
- **THEN** no further request is made

#### Scenario: An empty final page is not an empty list

- **WHEN** a further page is requested and comes back with no entries
- **THEN** the entries already loaded remain shown, and this is not treated as
  an error or as an empty change log
