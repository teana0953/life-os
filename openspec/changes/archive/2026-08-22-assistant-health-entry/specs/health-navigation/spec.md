## ADDED Requirements

### Requirement: The health shell offers a labelled assistant entry point

The health shell's app bar SHALL offer an action that opens the AI assistant,
and that action SHALL carry a visible text label, not an icon alone: the app is
used on a phone and as an installed web app, where a tooltip needs a hover or a
long-press and so never appears. The label SHALL be constrained and ellipsized
rather than allowed to push the shell's title out, so that a long translation at
a large text scale cannot consume the tab name.

The action SHALL open the assistant carrying the health module, the tab
currently on screen, and — only from the overview tab, the one health tab whose
content is anchored to a date — the day the shell is showing.

#### Scenario: The button reads as the assistant on every tab
- **WHEN** the health shell is on any of its four tabs
- **THEN** an app-bar action with visible assistant text is present and enabled

#### Scenario: Opening from the overview tab
- **WHEN** the user activates the assistant action while the overview tab is
  selected
- **THEN** the assistant is opened with the health module, the overview tab, and
  the day the shell is showing

#### Scenario: Opening from the record tab
- **WHEN** the user activates the assistant action while the record tab is selected
- **THEN** the assistant is opened with the health module and the record tab, and
  no day — the record tab shows no date anywhere on screen

#### Scenario: Opening from the trends tab
- **WHEN** the user activates the assistant action while the trends tab is selected
- **THEN** the assistant is opened with the health module and the trends tab

### Requirement: Returning from the assistant refreshes the health screen

The assistant can record food and health entries on the user's behalf, so the
health shell SHALL reload its data when the user returns from the assistant,
rather than leaving the screen showing the state from before the conversation.

#### Scenario: A record made in the assistant is visible on return
- **WHEN** the user opens the assistant from the health shell and then returns
- **THEN** the health shell reloads its data before the user reads it again

#### Scenario: A disposed shell does not reload
- **WHEN** the user opens the assistant from the health shell and the shell is
  disposed before the return
- **THEN** no reload is attempted
