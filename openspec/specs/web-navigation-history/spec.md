# web-navigation-history Specification

## Purpose
TBD - created by archiving change go-router-navigation. Update Purpose after archive.

## Requirements

### Requirement: Each pushed screen is a distinct browser-history entry

On the web, navigating from one full-screen to another SHALL create a distinct
browser-history entry **as a nested route whose screen is built from injected
dependencies** (not carried per-navigation), so that a URL-driven stack rebuild
(browser back, forward, or refresh) reconstructs the full ancestor chain and the
back button returns through the pushed screens in reverse order, only leaving the
app from the base route.

#### Scenario: Back returns through pushed screens before leaving the app
- **WHEN** the user navigates grid → health module → a tracker (two pushes)
- **THEN** one back returns to the health module, a second back returns to the grid, and only a third back leaves the app

#### Scenario: A URL-driven rebuild recreates the whole stack
- **WHEN** a deep route (e.g. the diet daily-target) is reached by a URL-driven navigation that rebuilds the stack from the URL
- **THEN** the health module and diet screen are rebuilt beneath it, so a back returns to the diet screen rather than collapsing to the grid

#### Scenario: Depth does not shorten the intercepted back count
- **WHEN** the user pushes an additional screen (e.g. food search from the diet screen)
- **THEN** the number of backs needed to return to the grid grows by one accordingly, rather than the app leaving earlier

### Requirement: Auth state drives routing via redirect

Routing SHALL be gated by authentication state: signed-out users are redirected to
the sign-in screen, signed-in users away from the sign-in/splash screens, with a
splash shown while the auth state is still unknown and a retry screen on auth
error.

#### Scenario: Signed-out user is redirected to sign-in
- **WHEN** there is no authenticated user
- **THEN** any route redirects to the sign-in screen

#### Scenario: Signed-in user leaves the sign-in screen
- **WHEN** the user becomes authenticated while on the sign-in screen
- **THEN** routing redirects to the home grid

### Requirement: Modal dialogs and tab switches are not history entries

Modal dialogs (day picker, amount entry, confirmations) and bottom-navigation tab switches SHALL be excluded from browser history (they create no history entry), so the back button dismisses a modal or is a no-op for tabs rather than being consumed as a screen.

#### Scenario: A tab switch is not a back target
- **WHEN** the user switches health bottom-nav tabs and presses back
- **THEN** the back does not merely undo the tab switch as if it were a pushed screen

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
