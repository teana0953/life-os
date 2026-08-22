## MODIFIED Requirements

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
about their health and diet records, not about spending, budgets and split
balances; a finance entry SHALL be told what it can answer about spending,
budgets and split balances.

When the assistant is entered with **no module at all** — the home entry — the
hint SHALL name both halves of what the assistant can answer: finance (spending,
budgets, split balances, logging a transaction) *and* health and diet records,
so that the home entry stops presenting the assistant as finance-only.

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

#### Scenario: Entering from health
- **WHEN** the assistant is opened from the health module's overview tab with a
  day and no message has been sent
- **THEN** the hint speaks about health and diet records and does not mention
  spending, budgets or split balances

#### Scenario: Entering from a health tab with no day
- **WHEN** the assistant is opened from the health module's record or trends tab
  and no message has been sent
- **THEN** the hint speaks about health and diet records and asks the user to name
  the period they mean

#### Scenario: Entering from finance is unchanged
- **WHEN** the assistant is opened from the finance module with a month
- **THEN** the hint is the finance one, without the ask-for-a-period sentence,
  and it does not mention health or diet records

#### Scenario: Entering with no context mentions both modules
- **WHEN** the assistant is opened without an entry module and no message has
  been sent
- **THEN** the hint mentions both finance matters and health and diet records,
  and asks the user to name the period they mean

#### Scenario: The home hint states the health half outright when access is on
- **WHEN** the assistant is opened without an entry module while health access is
  on
- **THEN** the hint says the assistant can be asked about health and diet
  records, and no control leading to settings is offered

#### Scenario: The home hint makes the health half conditional when access is off
- **WHEN** the assistant is opened without an entry module while health access is
  off
- **THEN** the hint still names finance and health and diet records, but says the
  health half is available once health access is turned on in settings, and a
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
