# assistant-entry-context Specification

## Purpose
Governs what the assistant is told about the screen the user came from: which
modules offer an entry point, what the assistant's address carries about that
view, how an impossible or malformed address is reduced to only what a screen
could really have shown, and how the entered context shapes the assistant's
empty-state example prompts.

## Requirements

### Requirement: The entered view travels in the assistant's address

When the user opens the assistant from a module's screen, the view they were
looking at SHALL be carried in the assistant's address (its query string), not
in in-memory navigation state, so that reloading the page in a browser
reconstructs the same context. The address SHALL name the module, the module's
active tab, and the period that tab was showing — a month for finance, a
calendar day for health.

#### Scenario: Reload reconstructs the context
- **WHEN** the assistant has been opened from a module screen and the browser is
  reloaded at that address
- **THEN** the assistant shows the same entered-view line it showed before the
  reload

#### Scenario: Entering twice with different views
- **WHEN** the user opens the assistant from one view, leaves, and opens it again
  from a different view
- **THEN** the second entry shows the second view, not the first

### Requirement: The entered view is stated exactly once

The entered view SHALL be turned into text in exactly one place, and that one
text SHALL be both what the user sees above the transcript and what is prepended
to the first message sent to the model. No screen SHALL compose its own wording
for the entered view.

#### Scenario: What the user reads is what the model reads
- **WHEN** the assistant is entered with a context and the user sends the first
  message
- **THEN** the entered-view text shown above the transcript appears verbatim at
  the head of that first message's content

### Requirement: Health is a recognized entry context

An address naming health as the entry module SHALL produce an entered view
describing the health module, its active tab (overview, record, trends, or
more), and — for the tabs that show one — the viewed calendar day. An address
naming no module, or a module that is not recognized, SHALL produce no entered
view at all: no line above the transcript and no prefix on the first message.

#### Scenario: Entering from the health overview tab
- **WHEN** the assistant is opened with the health module, the overview tab, and
  a well-formed day
- **THEN** the entered view names the health module, the overview tab, and that
  day

#### Scenario: An unrecognized module
- **WHEN** the assistant is opened with a module name that is neither finance nor
  health
- **THEN** no entered view is shown and the first message carries no prefix

### Requirement: A malformed address is reduced field by field

A tab that is not one of the entering module's own tabs, and a period that is not
a well-formed calendar month (finance) or calendar day (health), SHALL each be
dropped on their own, leaving the rest of the entered view intact. A dropped
field SHALL NOT be echoed back to the user or to the model in any form. A day
SHALL be well-formed only if it is a real calendar date in `YYYY-MM-DD` form; a
string that merely looks like a date but names no real day SHALL be dropped.

#### Scenario: A hand-edited day is dropped, the tab survives
- **WHEN** the assistant is opened with the health module, the overview tab, and
  a day of `banana`
- **THEN** the entered view names the health module and the overview tab, and
  mentions no day, and the text `banana` appears nowhere

#### Scenario: A day that is not a real date is dropped
- **WHEN** the assistant is opened with the health module, the overview tab, and
  a day of `2026-02-31`
- **THEN** the entered view mentions no day

#### Scenario: An unknown tab is dropped, the module survives
- **WHEN** the assistant is opened with the health module and a tab that is not one
  of the health tabs
- **THEN** the entered view names the health module alone and mentions no tab

### Requirement: A tab is not given a period it never shows

A period SHALL be dropped when the entering tab has no such period on screen,
even when that period is itself well-formed, so that the entered view can never
claim a view no screen has ever shown. For finance this is the split tab, which
has no month. For health this is the record, trends and more tabs — the record
tab's body is a hub of buttons that paints no date, and neither trends nor more
is day-keyed. The health overview tab is the only health tab that carries a day.

#### Scenario: A hand-typed day on the health record tab
- **WHEN** the assistant is opened with the health module, the record tab, and a
  well-formed day
- **THEN** the entered view names the health module and the record tab, and
  mentions no day

#### Scenario: A hand-typed day on the health trends tab
- **WHEN** the assistant is opened with the health module, the trends tab, and a
  well-formed day
- **THEN** the entered view names the health module and the trends tab, and
  mentions no day

#### Scenario: A hand-typed day on the health more tab
- **WHEN** the assistant is opened with the health module, the more tab, and a
  well-formed day
- **THEN** the entered view mentions no day

#### Scenario: The health overview tab keeps its day
- **WHEN** the assistant is opened with the health module, the overview tab, and
  a well-formed day
- **THEN** the entered view names that day

#### Scenario: The existing finance rule is unchanged
- **WHEN** the assistant is opened with the finance module, the split tab, and a
  well-formed month
- **THEN** the entered view mentions no month

### Requirement: The empty state offers examples fitting the entered module

Before the first message, the assistant SHALL offer three tappable example
prompts. When the assistant was entered from health, those three SHALL be health
questions, one of which asks what can still be eaten given the portions
remaining for the day — unless health access is off, in which case the way to
turn it on takes their place (see the health-access requirement below).

When the assistant was entered from finance, those three SHALL be the finance
examples.

When the assistant was entered with no module at all — the home entry, which
belongs to neither — the three SHALL follow the user's health-access consent,
because an example the assistant cannot answer is a dead end:

- With health access **on**, the three SHALL be a mix: at least one finance
  example and at least one health example, and the health one SHALL be the
  question about what can still be eaten given the portions remaining for the
  day.
- With health access **off**, the three SHALL be the finance examples, exactly
  as they are today.

Tapping an example SHALL place its text in the message box and put the keyboard
focus there with the caret at the end, and SHALL NOT send anything. This holds
for every example in every one of the states above.

#### Scenario: Entering from health offers health examples
- **WHEN** the assistant is opened from the health module with health access on
  and no message has been sent
- **THEN** three health example prompts are offered, one of them asking what to
  eat with the remaining portions, and none of the finance examples is shown

#### Scenario: Entering from finance is unchanged
- **WHEN** the assistant is opened from the finance module and no message has been
  sent
- **THEN** the three finance example prompts are offered, and no health example
  is shown

#### Scenario: Entering with no context at all
- **WHEN** the assistant is opened without an entry module and no message has been
  sent
- **THEN** three example prompts are offered, and which three they are follows the
  health-access consent as the two scenarios below state

#### Scenario: Entering with no context while health access is on
- **WHEN** the assistant is opened without an entry module, health access is on,
  and no message has been sent
- **THEN** three examples are offered, of which at least one is a finance example
  and one asks what to eat with today's remaining portions

#### Scenario: Entering with no context while health access is off
- **WHEN** the assistant is opened without an entry module, health access is off,
  and no message has been sent
- **THEN** the three finance example prompts are offered and no health example is
  shown

#### Scenario: Granting the consent while the home empty state is open
- **WHEN** the assistant is opened without an entry module while health access is
  off, and the user then turns health access on and returns
- **THEN** the mixed examples are offered, without the conversation being
  restarted

#### Scenario: Tapping an example does not send it
- **WHEN** the user taps one of the example prompts
- **THEN** its text is in the message box with the caret at its end and the box
  has focus, and no message has been sent

### Requirement: The empty-state hint matches the entered module

The line of guidance shown above the example prompts SHALL match the module the
user entered from: a health entry SHALL be told what the assistant can answer
about their health, diet and care records, not about spending, budgets and split
balances; a finance entry SHALL be told what it can answer about spending,
budgets and split balances.

Care records are read under the same health-access consent as health and diet
records, so wherever the hint names that half of the assistant's reach it SHALL
name care records too — the assistant can answer about them, and a hint that
omits them leaves the capability undiscoverable.

When the assistant is entered with **no module at all** — the home entry — the
hint SHALL name both halves of what the assistant can answer: finance (spending,
budgets, split balances, logging a transaction) *and* health, diet and care
records, so that the home entry stops presenting the assistant as finance-only.

How it names the health half SHALL follow the health-access consent. With the
consent **on**, the health half SHALL be stated outright. With the consent
**off** — the default, since health access is opt-in and sign-out clears it —
the health half SHALL be stated conditionally, as what turning the consent on
would allow, and a low-emphasis control leading to settings SHALL be offered
below the examples, so that the sentence has somewhere to lead. That control
SHALL name what it turns on rather than only where it goes, because it is read
on its own, several examples below the sentence it answers. The home entry
SHALL NOT show the health entry's health-access-off notice, which belongs to a
user who just asked for health and hit a dead end.

The parts of the home empty state that follow the consent SHALL be announced as
a live region, because granting the consent in settings and returning changes
them without the screen being rebuilt from scratch. The announcement SHALL carry
the hint's own wording, since a live region with nothing to say announces
nothing.

When the assistant is entered with no module, or with a module but no period on
screen, the hint SHALL additionally ask the user to name the period they mean,
because an unanchored question has nothing to attach to.

No hint SHALL offer a capability the assistant does not have. In particular it
SHALL NOT offer to record, change or complete a care entry — care access is
read-only — and SHALL NOT name reminder or push-notification records, which are
outside the consent entirely.

#### Scenario: Entering from health
- **WHEN** the assistant is opened from the health module's overview tab with a
  day and no message has been sent
- **THEN** the hint speaks about health, diet and care records and does not
  mention spending, budgets or split balances

#### Scenario: Entering from a health tab with no day
- **WHEN** the assistant is opened from the health module's record or trends tab
  and no message has been sent
- **THEN** the hint speaks about health, diet and care records and asks the user
  to name the period they mean

#### Scenario: The health hint offers no care write
- **WHEN** the assistant is opened from the health module in either supported
  language
- **THEN** the hint offers only asking about care records, and does not offer to
  log, complete or change one

#### Scenario: Entering from finance is unchanged
- **WHEN** the assistant is opened from the finance module with a month
- **THEN** the hint is the finance one, without the ask-for-a-period sentence,
  and it does not mention health, diet or care records

#### Scenario: Entering with no context mentions both modules
- **WHEN** the assistant is opened without an entry module and no message has
  been sent
- **THEN** the hint mentions both finance matters and health, diet and care
  records, and asks the user to name the period they mean

#### Scenario: The home hint states the health half outright when access is on
- **WHEN** the assistant is opened without an entry module while health access is
  on
- **THEN** the hint says the assistant can be asked about health, diet and care
  records, and no control leading to settings is offered

#### Scenario: The home hint makes the health half conditional when access is off
- **WHEN** the assistant is opened without an entry module while health access is
  off
- **THEN** the hint still names finance and health, diet and care records, but
  says that half is available once health access is turned on in settings, and a
  low-emphasis control leading to settings is offered below the examples

#### Scenario: The consent exit says what it turns on
- **WHEN** the assistant is opened without an entry module while health access is
  off
- **THEN** the control below the examples is labelled with turning health access
  on, not merely with going to settings, and tapping it opens settings

#### Scenario: The home entry never shows the health-access-off notice
- **WHEN** the assistant is opened without an entry module while health access is
  off
- **THEN** the health entry's health-access-off notice and its button are absent

#### Scenario: The consent-dependent part of the home empty state is announced
- **WHEN** the assistant is opened without an entry module while health access is
  off, and the user then turns health access on and returns
- **THEN** the reworded hint and the swapped example are announced as a live
  region carrying the new wording, without the conversation being restarted

### Requirement: A health entry with health access off is told so and given the way out

Reading health, diet and care records requires the user's health-access consent,
which is off until they grant it and is cleared when they sign out. When the
assistant is entered from health while that consent is off, the empty state
SHALL say that the assistant cannot read those records yet — naming care records
alongside health and diet records, so that the refusal covers exactly the ground
the consent covers — and SHALL offer a control that takes the user to the
settings page where the consent lives. The health example prompts SHALL NOT be
offered in that state — every one of them asks for data the assistant cannot see.

This requirement changes nothing about the consent itself: what it means, when
it is asked for, where it is stored, and the settings control that grants it
are all unchanged. The assistant only gains a signpost to it.

#### Scenario: Entering from health with health access off
- **WHEN** the assistant is opened from the health module while health access is
  off and no message has been sent
- **THEN** the empty state says the assistant cannot read the user's health, diet
  or care records yet, offers a control leading to the settings page, and offers
  none of the health example prompts

#### Scenario: The refusal covers the same records the consent does
- **WHEN** the health-access-off notice is shown in either supported language
- **THEN** the record types it names as unreadable match the ones the settings
  disclosure names as covered, care records included

#### Scenario: Entering from health with health access on
- **WHEN** the assistant is opened from the health module while health access is
  on and no message has been sent
- **THEN** no such notice is shown and the three health example prompts are
  offered

#### Scenario: Entering from finance with health access off
- **WHEN** the assistant is opened from the finance module while health access is
  off
- **THEN** no such notice is shown and the finance example prompts are offered

#### Scenario: Granting the consent while the assistant is open
- **WHEN** the user follows that control, turns health access on, and returns to
  the assistant
- **THEN** the notice is gone and the health example prompts are offered, without
  the conversation being restarted
