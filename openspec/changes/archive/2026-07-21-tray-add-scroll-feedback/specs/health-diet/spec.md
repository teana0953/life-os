## ADDED Requirements

### Requirement: Adding a food to the tray gives immediate visible feedback

Adding a food to the current-meal tray in the full-screen food search (by tapping a search result or via manual entry) SHALL give immediate visible feedback that the item was added: the tray SHALL scroll to reveal the newly added item (so a newly added item is never left below the fold unseen), and SHALL briefly highlight the newly added item's row with a soft background that fades out. Removing an item or changing an item's amount SHALL NOT scroll the tray to the newly added position nor trigger the highlight.

#### Scenario: A newly added item is scrolled into view
- **WHEN** the tray already holds enough items to overflow its visible height and the user adds another food
- **THEN** the tray scrolls to reveal the newly added item

#### Scenario: The newly added row is briefly highlighted
- **WHEN** the user adds a food to the tray
- **THEN** that item's row shows a soft highlight background that fades out shortly after, and no other row is highlighted

#### Scenario: Removing or adjusting an item does not trigger add feedback
- **WHEN** the user removes a tray item or changes a tray item's amount
- **THEN** the tray neither scrolls to the end nor shows the add highlight
