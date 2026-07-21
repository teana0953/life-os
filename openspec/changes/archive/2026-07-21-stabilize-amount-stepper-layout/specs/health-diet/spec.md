## MODIFIED Requirements

### Requirement: Diet surfaces fit narrow (mobile) screens

The diet surfaces SHALL remain usable at narrow phone widths without clipping
content or overflowing their layout. Specifically: the Today day-navigation header
SHALL show the date and calendar affordance without a layout overflow at narrow
widths (ellipsizing the date text as needed); and the full-screen food search
SHALL keep its search results reachable above the on-screen keyboard when the
search field is focused, without any visual-viewport keyboard-inset workaround —
being a full-screen page, its scaffold resizes for the keyboard so the pinned
search field stays at the top and the results list shrinks to remain scrollable
above it. The amount control (the −/field/+ stepper with its unit label and
portion/measure toggle, in both the food-search tray and Today's in-place item
editor) SHALL have a layout that is stable across a portion/measure mode toggle —
the mode toggle keeps a fixed position and the number of lines does not change
when the mode is switched — and SHALL NOT overflow at narrow phone widths
(320dp/360dp) in either supported locale, ellipsizing the after-field unit label
as needed rather than overflowing.

#### Scenario: Day header does not overflow on a narrow screen
- **WHEN** the diet shell is shown at a narrow phone width and the date label is long
- **THEN** the header shows the (possibly ellipsized) date and the calendar affordance with no layout overflow

#### Scenario: Search results stay reachable above the keyboard
- **WHEN** the user focuses the food search's search field at a narrow phone width and the on-screen keyboard is shown
- **THEN** the results list shrinks so its lower rows can be scrolled up into view above the keyboard, while the search field stays pinned at the top, with no viewport-inset workaround

#### Scenario: The amount control does not reflow when the mode is toggled
- **WHEN** the user toggles a tray or in-place amount control between portion (份量) and measure (顆/公克/毫升) mode
- **THEN** the portion/measure toggle stays in the same position and the control keeps the same number of lines, only the after-field unit label changing with the mode

#### Scenario: The amount control does not overflow on a narrow screen in either locale
- **WHEN** a gram or household amount control is shown at 320dp or 360dp width, in English or Traditional Chinese, in either portion or measure mode
- **THEN** the control renders with no layout overflow, the after-field unit label ellipsizing if there is not enough room
