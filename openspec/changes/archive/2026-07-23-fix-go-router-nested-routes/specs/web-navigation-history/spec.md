## MODIFIED Requirements

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
