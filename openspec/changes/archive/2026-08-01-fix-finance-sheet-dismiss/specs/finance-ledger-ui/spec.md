## ADDED Requirements

### Requirement: Finance modal sheets are always dismissible

Every modal bottom sheet opened from the finance shell (record transaction,
account management, snapshot entry, budget settings) SHALL remain dismissible
regardless of how tall its content grows. The guarantee SHALL come from a
drag handle: a grab area outside the sheet's scrollable content, so the
pull-down gesture is never swallowed by the content's own scrolling. A user
SHALL never be forced to use the device or browser back control to leave a
finance sheet — on the PWA that control unwinds the router stack and leaves
the finance section entirely.

#### Scenario: A long sheet can still be closed without the back control

- **WHEN** a finance sheet's content is taller than the viewport
- **THEN** the sheet shows a drag handle that closes it when dragged down,
  returning to the finance screen underneath
