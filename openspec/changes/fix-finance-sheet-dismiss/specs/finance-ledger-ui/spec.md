## ADDED Requirements

### Requirement: Finance modal sheets are always dismissible

Every modal bottom sheet opened from the finance shell (record transaction,
account management, snapshot entry, budget settings) SHALL remain dismissible
regardless of how tall its content grows: it SHALL reserve the device's safe
area so the scrim behind it stays tappable, and SHALL show a drag handle so
it can be pulled down to close. A user SHALL never be forced to use the
device or browser back control to leave a finance sheet — on the PWA that
control unwinds the router stack and leaves the finance section entirely.

#### Scenario: A long sheet can still be closed without the back control

- **WHEN** a finance sheet's content is taller than the viewport
- **THEN** the sheet shows a drag handle and leaves the scrim reachable, so
  it can be closed by dragging down or tapping outside, returning to the
  finance screen underneath
