# finance-ledger-ui Specification

## Purpose
TBD - created by archiving change add-finance-ledger-ui. Update Purpose after archive.
## Requirements
### Requirement: Finance entry and shell

The home hub SHALL show a 財務 tile alongside the health tile that opens
`/finance`, a finance shell with its own bottom navigation of four
destinations (總覽, 明細, 淨值, 分帳). The shell SHALL default to the current
month, and 總覽 and 明細 SHALL reflect the same selected month. Adding the
分帳 destination SHALL not change the behaviour or the test keys of the
existing three.

#### Scenario: Entering finance from home

- **WHEN** an authenticated user taps the 財務 tile on the home hub
- **THEN** the finance shell opens on the 總覽 tab showing the current month

#### Scenario: Month selection is shared

- **WHEN** the user switches to the previous month on 總覽 and then opens 明細
- **THEN** 明細 lists that same previous month's transactions

#### Scenario: The split destination is reachable

- **WHEN** the finance shell is shown
- **THEN** a 分帳 destination is available in its bottom navigation alongside
  the existing three

### Requirement: Recording a transaction

Both tabs SHALL show a FAB that opens a record sheet as a modal bottom sheet
padded above the soft keyboard. The sheet SHALL offer: an amount field using
a numeric keyboard following the repo's empty-plus-hint zero convention, an
expense/income toggle that swaps the category grid accordingly, a category
grid from the user's categories, a date defaulting to today, a currency
selector from the supported whitelist defaulting to TWD, and an optional
note. The save button SHALL be disabled while the amount is empty or zero or
no category is chosen. On success the sheet closes and the visible month's
data refreshes; the new transaction appears without a manual reload. On
failure the sheet stays open with everything the user entered still present
and an actionable error message is shown.

#### Scenario: Fast default path

- **WHEN** the user opens the record sheet, types an amount, and picks a
  category without touching type, date, or currency
- **THEN** saving records a TWD expense dated today and the sheet closes
- **AND** the 總覽 totals and 明細 list include it immediately

#### Scenario: Save is gated on valid input

- **WHEN** the amount field is empty or 0, or no category is selected
- **THEN** the save button is disabled and no request is sent

#### Scenario: Failure keeps input

- **WHEN** saving fails (network or server error)
- **THEN** the sheet stays open, the entered amount/category/note remain, and
  an error message tells the user to retry

#### Scenario: Saving into another month jumps the view there

- **WHEN** the user is viewing July, opens the record sheet, sets the date to
  an August day, and saves
- **THEN** the view switches to August and the saved transaction is visible

#### Scenario: Expired session leads to re-auth, not a dead end

- **WHEN** any finance request returns 401
- **THEN** the finance screens show the sign-in-again exit (existing reauth
  convention), not a generic error page

### Requirement: Monthly overview

The 總覽 tab SHALL show, for the selected month: expense/income/net cards
listed per currency (one row per currency present, no conversion), a
category breakdown chart of expenses, and the five most recent
transactions. Amounts SHALL be formatted per currency minor-unit rules
(TWD/JPY/KRW no decimals; others two decimals). A month with no data SHALL
show an empty-state guide with a call-to-action that opens the record sheet
— never a blank page. While loading, a progress indicator is shown; on load
failure, an error state with a retry action.

#### Scenario: Overview reflects mixed currencies

- **WHEN** the selected month holds TWD and USD transactions
- **THEN** the totals show one TWD row and one USD row, each formatted with
  its own decimal rules, never summed together

#### Scenario: Empty month guides the user

- **WHEN** the selected month has no transactions
- **THEN** an empty-state message with a record call-to-action appears, and
  tapping it opens the record sheet

The month switcher within the 總覽 tab SHALL be rendered by the shared
`MonthNavHeader` widget (keyPrefix `finance-month`), preserving the existing
behavior and test keys.

#### Scenario: Month switcher uses the shared header

- **WHEN** the 總覽 tab renders its month switcher
- **THEN** it is the shared MonthNavHeader and its existing month-change
  behavior is unchanged

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

### Requirement: Month switching is race-safe

Month navigation (previous/next arrows) SHALL always render data belonging
to the displayed month: a slow response for a previously selected month
SHALL never overwrite the currently selected month's view. This applies to
every figure the month drives, including the split-spending line, which is
fetched separately from the month's transactions.

#### Scenario: Rapid month switching

- **WHEN** the user switches months twice quickly and the first month's
  response arrives after the second's
- **THEN** the view shows the second (current) month's data, not the stale
  first response

#### Scenario: The split-spending figure follows the same rule

- **WHEN** the month is switched while a split-spending request for the
  previous month is in flight
- **THEN** the late answer is discarded rather than shown against the new
  month

### Requirement: Finance modal sheets are always dismissible

Every modal bottom sheet opened from the finance shell (record transaction,
account management, snapshot entry, budget settings) SHALL remain dismissible
regardless of how tall its content grows. The guarantee SHALL come from a
drag handle: a grab area outside the sheet's scrollable content, so the
pull-down gesture is never swallowed by the content's own scrolling. A user
SHALL never be forced to use the device or browser back control to leave a
finance sheet — on the PWA that control unwinds the router stack and leaves
the finance section entirely.

#### Scenario: A long sheet can still be closed without the back control

- **WHEN** a finance sheet's content is taller than the viewport
- **THEN** the sheet shows a drag handle that closes it when dragged down,
  returning to the finance screen underneath

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

#### Scenario: The budget card shows the server's figure, never a local sum

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

#### Scenario: Each group says what it is counted in, where its own amount is

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

### Requirement: The overview lays out on small screens

The whole overview — the per-currency expense/income/net totals, the category
breakdown, the split-spending line and the recent-transaction rows — SHALL lay
out without layout errors at 320dp and 360dp wide, on a phone-height viewport,
in each supported locale, at text scales 1.0 and 2.0, with amounts and category
names wide enough to be realistic rather than token fixtures.

#### Scenario: A wide amount does not push a row off the edge

- **WHEN** the overview is rendered at 320dp or 360dp on a phone-height
  viewport in any supported locale at text scale 1.0 or 2.0, with recorded
  transactions in more than one currency, several expense categories and
  seven-figure amounts
- **THEN** no layout error is raised: in every label-plus-amount row the
  amount keeps its own width and the label is the half that wraps, rather
  than the amount overflowing to the right or consuming the row

#### Scenario: A long category name does not squeeze the amount out

- **WHEN** an expense category's name is long enough to fill the row on its
  own at those widths and text scales
- **THEN** the name wraps and the amount stays fully on screen — the amount
  is never the half that is squeezed

#### Scenario: A recent-transaction amount is not broken across lines

- **WHEN** the overview is rendered at 360dp or 375dp — the ordinary phone
  widths — at text scale 1.0, with a seven-figure transaction amount
- **THEN** that amount paints on a single line: a wrapped amount breaks
  mid-digit-group (`+1,234,5` / `67`), reads as two numbers, and raises no
  layout error at all, so "no layout error" is not a sufficient criterion here

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

