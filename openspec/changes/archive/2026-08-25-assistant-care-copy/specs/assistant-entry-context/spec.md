## MODIFIED Requirements

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
