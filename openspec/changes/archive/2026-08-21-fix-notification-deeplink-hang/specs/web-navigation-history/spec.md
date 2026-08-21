## ADDED Requirements

### Requirement: An unmatched location lands on a localized screen with a way out

A location the app cannot match — a stale bookmark, a hand-picked URL, a destination written by
a different app version — SHALL land on a localized screen that names what happened and offers
a control returning the user to the home screen. It SHALL NOT fall through to the framework's
untranslated default, and it SHALL NOT leave the user on a screen whose only controls are
inoperative.

#### Scenario: A URL that matches no screen is explained in the user's language
- **WHEN** the app is asked to show a location that matches no screen
- **THEN** the screen shown is in the user's selected language and offers a control that
  returns to the home screen

#### Scenario: The way out actually leaves
- **WHEN** the user activates that control
- **THEN** the app is on the home screen and the unmatched location is no longer in the stack
  the back affordance walks
