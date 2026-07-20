## MODIFIED Requirements

### Requirement: Diet surfaces fit narrow (mobile) screens

The diet surfaces SHALL remain usable at narrow phone widths without clipping
content or overflowing their layout. Specifically: the Today day-navigation
header SHALL show the date and calendar affordance without a layout overflow at
narrow widths (ellipsizing the date text as needed); the add-food logging bar's
meal controls (including the snack name and rename control) SHALL not overflow
at narrow widths; and the add-food dictionary sheet SHALL keep its search
results reachable above the on-screen keyboard when the search field is focused,
including on platforms where the keyboard is reported via the browser visual
viewport rather than the layout viewport.

#### Scenario: Day header does not overflow on a narrow screen
- **WHEN** the diet shell is shown at a narrow phone width and the date label is long
- **THEN** the header shows the (possibly ellipsized) date and the calendar affordance with no layout overflow

#### Scenario: Logging bar fits a narrow screen
- **WHEN** the logging bar is shown with a snack selected at a narrow phone width
- **THEN** the current snack name and the rename control are shown together without a layout overflow

#### Scenario: Search results stay reachable above the keyboard
- **WHEN** the user focuses the dictionary sheet's search field and the on-screen keyboard covers the lower part of the sheet
- **THEN** the results list reserves space for the keyboard so the lower results can be scrolled up into view above it, while the search field stays pinned at the top

#### Scenario: No keyboard leaves the list unchanged
- **WHEN** no on-screen keyboard is shown (the keyboard inset is zero)
- **THEN** the results list keeps its normal padding (the keyboard handling adds nothing)
