# web-navigation-history Specification

## Purpose
TBD - created by archiving change go-router-navigation. Update Purpose after archive.
## Requirements
### Requirement: Each pushed screen is a distinct browser-history entry

On the web, navigating from one full-screen to another SHALL create a distinct
browser-history entry, so the browser/system back button returns through the pushed
screens in reverse order and only leaves the app from the base route.

#### Scenario: Back returns through pushed screens before leaving the app
- **WHEN** the user navigates grid → health module → a tracker (two pushes)
- **THEN** one back returns to the health module, a second back returns to the grid, and only a third back leaves the app

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

