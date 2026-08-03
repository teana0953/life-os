# split-ui Specification

## Purpose
TBD - created by archiving change add-split-ui. Update Purpose after archive.
## Requirements
### Requirement: The split tab leads with who owes whom

The finance shell SHALL offer a 分帳 tab whose first content is the balance
with each other person, split into what they owe the caller and what the
caller owes them, listed per currency and never summed across currencies.
The direction of a debt SHALL be conveyed in words, not by colour alone.
While loading, a progress indicator is shown; on failure, an error with a
retry action; on `401`, the app's existing re-authentication exit.

#### Scenario: Balances are grouped by direction

- **WHEN** the caller is owed by one person and owes another
- **THEN** the two appear under separate headings for owed-to-me and
  owed-by-me, each naming the person and the amount

#### Scenario: Two currencies stay apart

- **WHEN** the caller's balance with someone spans two currencies
- **THEN** each currency is listed on its own line and no combined figure
  appears

#### Scenario: Direction does not depend on colour

- **WHEN** a balance is shown
- **THEN** wording states who owes whom, so the direction is readable
  without perceiving colour

#### Scenario: Nothing yet

- **WHEN** the caller has no split expenses at all
- **THEN** an empty-state guide explaining how to start is shown together
  with **both** first moves — recording a split expense and creating a
  group — not a blank tab, and not only one of the two

#### Scenario: A caller with no friends yet is pointed at the prerequisite

- **WHEN** the caller has nothing to split *and* no friends, so every route
  out of the empty state leads to a form whose participant list holds only
  them
- **THEN** the empty state states that a friend is the first step and offers
  a way to the friends page, and the record sheet — whose submit is blocked
  for the same reason — states it and offers the same way out, rather than
  asking for a second person the caller cannot produce

#### Scenario: Settled up is stated, not left blank

- **WHEN** nothing is owed in either direction (on the split tab, or in a
  group whose members are all square)
- **THEN** a line says everyone is settled, so the user can tell "settled"
  from "this failed to load"

### Requirement: Every person on screen has a name

A user rendered anywhere in the split UI SHALL be shown by display name,
taken from the name the server returns alongside each share, each group
member, each balance, and the expense's payer — the payer's name comes with
the expense because a payer who fronted the money holds no share to carry
it. When a name is genuinely absent, a neutral placeholder SHALL be
shown — never a raw identifier and never blank.

#### Scenario: An expense says who paid it

- **WHEN** an expense is listed
- **THEN** the row names the payer — the one fact a plain participant
  cannot reach any other way, since editing is offered only to the
  creator or payer

#### Scenario: A participant can read their own share

- **WHEN** the viewer holds a share in a listed expense
- **THEN** that share's amount is shown on the row

#### Scenario: A co-participant the viewer does not know is named

- **WHEN** an expense is shown whose participants include someone who is
  neither the viewer's friend nor a member of any group they share
- **THEN** that participant is shown by name

#### Scenario: An unresolvable user degrades to a placeholder

- **WHEN** a participant's name cannot be resolved from either source
- **THEN** a neutral placeholder is shown, and no raw identifier appears
  anywhere on screen

### Requirement: Recording a split expense

The split tab SHALL offer recording an expense with a group (optional), a
payer, an amount and currency, a description, a day, participants, and a
split mode of equal or exact. The stored amounts SHALL be in the currency's
minor units. While submitting, the action SHALL be disabled.

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

### Requirement: The form offers only choices the server would accept

Candidate payers and participants SHALL be limited to the members of the
selected group, or — with no group selected — to the caller's friends and
the caller. A split whose caller holds no stake SHALL be refused before
submission, with an explanation, rather than sent and rejected.

#### Scenario: A group narrows the candidates

- **WHEN** a group is selected
- **THEN** only that group's members can be chosen as payer or participant

#### Scenario: No group means friends

- **WHEN** no group is selected
- **THEN** the caller and the caller's friends are the available candidates

#### Scenario: The caller must have a stake

- **WHEN** the caller is neither the payer nor a participant with a share
  above zero
- **THEN** submission is refused locally with an explanation, and no request
  is sent

#### Scenario: A split of one person is refused locally

- **WHEN** the payer and the participants are the same single person — the
  form's own default state, which the server refuses outright
- **THEN** submission is refused locally with an explanation, and no request
  is sent

#### Scenario: An equal split below its participant count is refused locally

- **WHEN** an equal split's amount is smaller than the number of
  participants, which the server refuses outright
- **THEN** submission is refused locally with an explanation, and no request
  is sent

#### Scenario: Every reason submission is refused is stated

- **WHEN** the submit action is disabled for any reason — nobody to split
  with at all, a missing amount, a blank description, no payer, no
  participants, no stake, too few people, an amount below the participant
  count, or exact shares that do not sum
- **THEN** that reason is readable on screen; the action is never greyed out
  with nothing explaining it

#### Scenario: The stated reason is the actual blocker

- **WHEN** more than one condition would block submission at once — e.g. the
  payer has been switched to someone else while the amount is still blank,
  which makes every previewed share zero
- **THEN** exactly one reason is shown and it is the first unmet one in the
  form's own order (here, the missing amount), never a different condition
  that the pending one merely caused

### Requirement: The split arithmetic is visible while typing

An equal split SHALL show what each participant will owe, including where
the remainder falls. An exact split SHALL show how far the entered shares
are from the amount, so the user is not relying on a server error to learn
they are short.

#### Scenario: Equal shares are previewed

- **WHEN** an amount is split equally between three participants
- **THEN** each participant's resulting share is displayed before submitting

#### Scenario: The preview matches what gets stored

- **WHEN** an amount that does not divide evenly is split equally
- **THEN** the previewed shares — including which participants carry the
  extra minor unit — are exactly the shares the server stores, so no figure
  changes between preview and save

#### Scenario: An exact split shows the shortfall

- **WHEN** the entered shares do not add up to the amount
- **THEN** the difference is displayed while typing — including while
  editing an existing expense's pre-filled shares

#### Scenario: Over-assigning is not reported as a shortfall

- **WHEN** the entered shares add up to more than the amount
- **THEN** the excess is stated as an excess, never as a negative
  shortfall, and submission is refused until the shares sum to the amount

### Requirement: Groups

The split UI SHALL let the caller create a group, add a friend to it, view
its members, its per-currency balances and its expenses, and — if they
created it — archive it. Archiving SHALL be offered only to the group's
creator, and SHALL require a confirmation naming the group. An archived group
SHALL be readable and SHALL hide the actions for adding expenses and
members, while still allowing an existing expense to be edited or deleted by
its creator or payer.

#### Scenario: A group is created and populated

- **WHEN** the caller creates a group and adds a friend
- **THEN** both appear as members of it

#### Scenario: Archiving is confirmed by name

- **WHEN** the group's creator archives it
- **THEN** a confirmation naming that group is shown, and nothing is sent
  until it is confirmed

#### Scenario: A member who did not create the group cannot archive it

- **WHEN** a member other than the creator views the group
- **THEN** no archive action is offered — the server refuses them, so the
  action would only ever fail

#### Scenario: An archived group is not offered for a new expense

- **WHEN** the record sheet's group selector is shown
- **THEN** archived groups are not among the choices, and a caller whose only
  group is archived is treated as having nowhere to split — they are pointed
  at adding a friend rather than left with a form the server will reject

#### Scenario: An archived group stays correctable

- **WHEN** a group is archived
- **THEN** its expenses remain readable and one of them can still be edited
  by its creator or payer, while the add-expense and add-member actions are
  not offered

### Requirement: Permission gates read the signed-in user

Every gate that depends on who the caller is — archiving (creator only),
editing or deleting an expense (creator or payer), the caller's own stake in
a split — SHALL be decided by the user id resolved from the signed-in
profile. A caller-supplied value, in particular anything carried in a URL,
SHALL NOT decide it.

#### Scenario: A group opened by URL still gates on the signed-in user

- **WHEN** a group screen is reached by a shared, bookmarked or hand-edited
  link
- **THEN** the actions offered are exactly those the signed-in user can
  perform, whatever the link says

### Requirement: Only the creator or payer is offered editing

The edit and delete actions for an expense SHALL be offered only to its
creator or its payer. Another participant SHALL not be shown an action that
would fail.

#### Scenario: A mere participant sees no edit action

- **WHEN** a participant who is neither creator nor payer views an expense
- **THEN** no edit or delete action is offered

### Requirement: Destructive actions are confirmed by name

Deleting an expense and archiving a group SHALL each require a confirmation
that names what is being acted on. Adding a member SHALL NOT require one.

#### Scenario: Deleting an expense is confirmed

- **WHEN** the caller deletes an expense
- **THEN** a confirmation naming that expense is shown first

#### Scenario: Adding a member is not confirmed

- **WHEN** the caller adds a friend to a group
- **THEN** the member is added without a confirmation step

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

### Requirement: Split UI is localized and lays out on small screens

All split copy SHALL come from the app's localizations in English and
Traditional Chinese — no hard-coded user-facing strings. The split tab, the
group detail screen, the record sheet, and the finance bottom navigation
with its fourth destination SHALL lay out without layout errors at 320dp and
360dp wide, on a phone-height viewport, in each supported locale, at text
scales 1.0 and 2.0.

#### Scenario: Narrow screens stay clean

- **WHEN** any split screen is rendered at 320dp or 360dp on a phone-height
  viewport, in any supported locale, at text scale 1.0 or 2.0
- **THEN** no layout error is raised and no content overflows

#### Scenario: The fourth navigation destination fits

- **WHEN** the finance bottom navigation is rendered at 320dp at text scale
  2.0 in each supported locale
- **THEN** all four destinations lay out without error, and each label's
  painted rectangle lies fully inside its own destination's slot —
  horizontally *and vertically*. A label too large for its slot wraps and
  paints past the bar's own bottom edge, clipped, raising no layout error at
  all, so measuring the painted rectangle is the only way this catches the
  regression. (An ellipsis check cannot: the bar's labels carry no
  `maxLines`, so they never ellipsize.)

#### Scenario: A long name does not push the amount out

- **WHEN** a participant's display name is longer than its row can fit
- **THEN** the name wraps or shrinks and the amount stays fully visible

### Requirement: Expense days are calendar dates, not instants

An expense's `day` is a plain `YYYY-MM-DD` calendar date and SHALL be
rendered as such, without instant parsing or timezone conversion, which
would shift it by a day. Genuine instants elsewhere SHALL go through the
app's shared helpers with an injectable local-time conversion.

#### Scenario: A day is shown as recorded, not shifted

- **WHEN** an expense recorded on a given day is rendered under a fixed
  non-UTC offset
- **THEN** that same day is shown — the day is a plain calendar date, so no
  timezone conversion is applied to it and it never shifts by one

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

#### Scenario: A refused amount states its reason in full

- **WHEN** an amount is refused locally at any of those widths, locales and
  text scales
- **THEN** the reason is laid out in full rather than clipped — "no layout
  error was raised" is not enough, because a sentence squeezed into a
  fixed-width field is silently truncated without raising one

