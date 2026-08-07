## MODIFIED Requirements

### Requirement: The overview shows split spending as its own line

The monthly overview SHALL show what the user personally owed on split
expenses that month, per currency, as a line of its own beside the recorded
expense totals.

Each currency SHALL be presented according to whether the server reports it
as already counted in the user's transactions. A counted currency's share is
already inside the expense total and inside the budget, because the server
mirrors it into the ledger when the split is recorded; an uncounted one is in
neither, because a transaction cannot hold that currency. The line SHALL NOT
describe both with one sentence: whichever half a reader belongs to, the
other half's sentence is false for them.

A month with no split activity SHALL omit the line rather than show a zero.

#### Scenario: Split spending sits beside recorded expenses

- **WHEN** the user has recorded expenses and split shares in the month
- **THEN** the overview shows both figures separately, and a counted
  currency's share is included in the expense total exactly once

#### Scenario: Budgets are unaffected

This scenario is kept under its former name so the inversion is explicit: a
counted currency's share now DOES consume the budget.

- **WHEN** the user has TWD split shares in the month
- **THEN** the budget card shows exactly the figure the server reported, with
  nothing added locally — the shares are already inside it, and adding them
  again is the double-count the old wording existed to prevent

#### Scenario: A month without splits omits the line

- **WHEN** the user has no split shares in the month
- **THEN** no split-spending line is shown, rather than a zero

#### Scenario: A month with splits but no transactions still shows the line

- **WHEN** the user has split shares but recorded no transactions that month
- **THEN** the split-spending line is still shown, rather than being replaced
  by the empty-month call to action

#### Scenario: The line says what it is not counted in

This scenario is kept under its former name so the inversion is explicit.

- **WHEN** the month has both a counted and an uncounted currency
- **THEN** the counted one is shown as already included in the expense total
  and the budget, and the uncounted one as included in neither, each stated
  where its own amount is — not as one sentence covering both

#### Scenario: A month with only counted currencies says so

- **WHEN** every currency in the month is counted
- **THEN** no claim is made about uncounted currencies, rather than showing
  an empty group or a sentence about money that is not there

#### Scenario: A second account never sees the first one's figure

- **WHEN** one account has loaded a month's split spending and a different
  account then loads the same calendar month
- **THEN** the first account's figure is never shown — neither while the
  second account's own request is still in flight, nor after signing out

#### Scenario: A failure in one figure does not take down the other

- **WHEN** loading split spending fails but the month's transactions load
- **THEN** the overview still shows the recorded totals, and the
  split-spending line reports its own failure

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
