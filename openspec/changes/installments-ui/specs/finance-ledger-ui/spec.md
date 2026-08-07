## MODIFIED Requirements

### Requirement: Transaction list and editing

The 明細 tab SHALL group the selected month's transactions by day, newest
day first, each row showing category, note (if any), and signed formatted
amount. Tapping a row SHALL open the same sheet pre-filled for editing,
including a delete action with confirmation. Edits and deletes SHALL refresh
the month's data on success.

A transaction the server mirrored from a split expense SHALL be marked as
such in the list, and its sheet SHALL offer only what the server accepts: its
category and note SHALL be editable, and its amount, date, currency and type
SHALL be shown as facts rather than as inputs the user cannot use. The type
control SHALL be among them: switching type clears the category, so leaving
it live costs the user the one field they came to change and then fails the
save anyway. The delete
action SHALL be absent, not disabled, and the sheet SHALL both say where the locked
parts are changed and offer a way to get there — a sentence pointing at a
place the user then has to find alone is a dead end. A disabled control still invites the press
that a mirrored row cannot honour.

When the server reports that the split changed between the sheet opening and
the save, the user SHALL be told the record moved on and offered the current
values, not told the save failed: retrying the same values would fail again.
What they had typed and not yet saved SHALL survive that reload — the server
applied none of the write, so nothing of theirs was consumed by it. When the
split is gone entirely rather than changed, they SHALL be told that instead,
and SHALL NOT be left editing a record that no longer exists.

A transaction the server wrote as one period of an instalment plan SHALL show
which period it is, of how many, and SHALL offer a way to the plan it belongs
to. Its amount stays editable — the bank amending a past charge is the reason
that door exists — but the sheet SHALL make clear that editing one period does
not re-spread the rest.

**A transaction can be both a split mirror and an instalment period.** The two
markers are independent nullable columns with nothing forbidding their
coexistence, and a split paid in instalments is exactly that case. The sheet
SHALL therefore resolve them by a stated precedence rather than assuming one
excludes the other, and the plan-level actions (managing the plan, settling
it) SHALL be offered on the basis of whether the plan is the viewer's own —
not on the basis of the row being an instalment. A share holder looking at a
period of somebody else's plan can change their own category and note and
nothing more.

#### Scenario: Editing an existing transaction

- **WHEN** the user taps a transaction, changes its amount, and saves
- **THEN** the list and 總覽 totals show the updated amount

#### Scenario: Deleting a transaction

- **WHEN** the user taps a transaction, chooses delete, and confirms
- **THEN** the transaction disappears from 明細 and the totals update

#### Scenario: A mirrored row is recognisable before it is opened

- **WHEN** the month contains a mirrored transaction and one the user
  recorded
- **THEN** the list distinguishes them

#### Scenario: A mirrored transaction offers no delete

- **WHEN** the user opens a mirrored transaction
- **THEN** there is no delete control at all, and the sheet says where the
  expense is deleted instead

#### Scenario: A mirrored transaction's facts are not inputs

- **WHEN** the user opens a mirrored transaction
- **THEN** its amount, date, currency and type are shown as text, and the only
  fields that accept input are its category and note — the type control above
  all, since switching type clears the category, which is the one field the
  user opened the sheet to change

#### Scenario: Recategorising a mirrored transaction works

- **WHEN** the user changes a mirrored transaction's category and saves
- **THEN** it succeeds, and the category budget it moved to reflects it

#### Scenario: A split edited underneath is a reload, not a failure

- **WHEN** the payer edits the split while the user has the mirrored
  transaction open, and the user then saves
- **THEN** the user is told the record changed **and the sheet shows the
  split's current amount and date**, rather than a save-failed message that a
  retry would repeat while the stale figures stay on screen

#### Scenario: A mirrored transaction offers a way to the split

- **WHEN** the user opens a mirrored transaction and takes the offered exit
- **THEN** they arrive at the split records, without having to close the
  sheet and find them

#### Scenario: The split behind a mirrored transaction can vanish

- **WHEN** the payer deletes the split while the user has its mirrored
  transaction open, and the user then saves
- **THEN** the user is told the expense is gone and the sheet closes, rather
  than leaving them editing a record that no longer exists, and the row it
  came from is gone from the list

#### Scenario: A reload that lands in another month is not a crash

- **WHEN** the payer moves the split's date into a different month and the
  user then saves
- **THEN** the user is told the record is no longer in this month and the
  sheet closes — the same treatment as a deleted one, rather than an error
  from looking for a row that is not there

#### Scenario: A refused save keeps what the user was typing

- **WHEN** the save is refused because the split moved on, and the user had
  changed the category
- **THEN** their category choice is still selected and the note they typed is
  still there after the reload — the server applied none of the write, so
  nothing they typed is lost to it

#### Scenario: An instalment period says which one it is

- **WHEN** the user opens the third period of a twelve-period plan
- **THEN** the sheet says it is period 3 of 12 and offers a way to the plan

#### Scenario: A row that is both a mirror and an instalment period

- **WHEN** a transaction carries both a split expense and an instalment plan
- **THEN** the sheet resolves them by the stated precedence rather than
  showing one and silently dropping the other, and the user can still edit
  their own category and note

#### Scenario: Plan actions follow whose plan it is

- **WHEN** the plan a period belongs to is not the viewer's own
- **THEN** managing and settling it are not offered, while the category and
  note stay editable

