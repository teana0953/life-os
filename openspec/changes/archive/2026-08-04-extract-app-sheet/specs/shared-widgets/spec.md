## ADDED Requirements

### Requirement: One shared way to open a modal sheet

Opening a modal bottom sheet SHALL go through a single shared entry point
that fixes the options every form sheet in this app needs, so that the
reasoning behind them lives in one place rather than being restated at each
call site, and so a new sheet is correct without its author having to know or
copy them.

That entry point SHALL make the sheet scroll-controlled (an uncontrolled
sheet is capped at 9/16 of the screen, which has clipped a submit button off
the bottom), apply the safe area, and show a drag handle (without one, a tall
sheet fills the viewport, the scrim disappears, and the drag is swallowed by
the content's own scrolling — leaving the browser back button as the only
exit, which on the PWA unwinds the router stack to the home screen).

A sheet that deliberately differs SHALL say so where it opens, so that
differing is distinguishable from forgetting.

#### Scenario: A shared sheet carries the drag affordance

- **WHEN** a sheet is opened through the shared entry point
- **THEN** it shows a drag handle, so it can be dismissed without relying on
  the scrim or a system gesture

#### Scenario: A tall sheet is not clipped

- **WHEN** a sheet's content is taller than 9/16 of the screen
- **THEN** its full height is available rather than being capped, so the
  content at the bottom stays reachable

#### Scenario: Differing is explicit

- **WHEN** a sheet opts out of the shared entry point
- **THEN** the reason is stated at that call site, so it reads as a decision
  rather than an omission
