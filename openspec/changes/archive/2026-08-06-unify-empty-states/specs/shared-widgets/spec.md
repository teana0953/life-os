## ADDED Requirements

### Requirement: Empty-state presentation

Where a screen or tab has nothing to show, or a card or section within a
populated screen has an empty region, the app SHALL present that emptiness in
one of two shapes, chosen by whether anything that is part of the content —
a card header, a section heading, a summary above it — still names that region
once it is empty. Chrome does not count: an app bar title, a tab label, a
navigation bar or a date switcher says which page the reader is on, not what
the empty region was.

- A **full guide** for a screen or tab that has nothing to show: an icon, a
  title, optionally a body, and optionally an action.
- An **inline note** for an empty region inside a card or section: one line of
  muted, centred text.

Both shapes SHALL take their colours and text styles from the theme, and each
SHALL accept an identifying key from the screen that uses it, so a screen that
had one keeps it.

A full guide SHALL remain usable at the narrowest supported width and the
largest supported text scale — its actions reachable and its text not clipped.

A full guide SHALL be able to offer any number of actions — the app's empty
states offer none, one, two and three — so its actions are a **list**, not a
primary/secondary pair. Where a guide offers more than one, exactly one SHALL
carry the primary emphasis and the rest secondary emphasis, so that a guide
never presents two equally-weighted first moves.

This requirement does not reach a control that is shown when a region is empty
but whose purpose is to be acted on rather than to explain the emptiness — a
tappable prompt is not an empty state.

#### Scenario: A screen with nothing to show guides the user

- **WHEN** a screen or tab has no content
- **THEN** it shows an icon, a title, and where one exists an action, rather
  than a bare line of text

#### Scenario: An empty region inside a card stays small

- **WHEN** a card or section within a populated screen has an empty region
- **THEN** it shows one line of muted text, not a full-page guide

#### Scenario: The guide survives a narrow screen at a large text scale

- **WHEN** a full guide is shown at the narrowest supported width and the
  largest supported text scale
- **THEN** its text is not clipped and its action is still reachable

#### Scenario: A guide with several actions still has one first move

- **WHEN** a full guide offers more than one action
- **THEN** exactly one of them carries the primary emphasis, and the action a
  user cannot yet complete is not the one that carries it

#### Scenario: A screen that had a key keeps it

- **WHEN** an empty state that carried an identifying key is replaced by a
  shared one
- **AND** the shared shape still has a node of its own to carry that key
- **THEN** that key still resolves to the same part of the tree

The exception, recorded because it happened: a key on a node the shared shape
does not have — `split_tab`'s `split-empty-needs-friends`, whose line became
the guide's `body`, a `String` with no node to hang a key on — is dropped
rather than preserved by widening the shared widget. Its copy stays asserted
by text, and the guide as a whole keeps its own key.
