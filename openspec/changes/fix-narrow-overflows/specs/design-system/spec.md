## ADDED Requirements

### Requirement: No layout overflow on narrow phones

Screens SHALL lay out without RenderFlex overflow at the phone widths the app
targets (320dp and 360dp), in every supported locale, and at accessibility
text scales up to 2.0. Where a row of items cannot fit, it SHALL reflow or
shrink rather than overflow, keeping content readable rather than clipped.

#### Scenario: Narrow width in either locale

- **WHEN** the period tracker, net worth tab, record calendar card, diet
  calendar, or a category progress bar is rendered at 320dp or 360dp in
  English or Traditional Chinese
- **THEN** no layout overflow occurs

#### Scenario: Enlarged text

- **WHEN** those screens are rendered at a text scale of 2.0
- **THEN** no layout overflow occurs

#### Scenario: Landscape

- **WHEN** the diet calendar dialog is shown in landscape
- **THEN** its content fits or scrolls rather than overflowing vertically

### Requirement: Overflow guards assert rather than swallow

The narrow-width layout tests covering the screens named in this change SHALL
assert that no layout error occurred, rather than draining errors with
`takeException()`. Because the test binding retains only the first error,
draining hides every subsequent one; these guards SHALL collect all reported
errors so a newly introduced overflow fails the suite. This applies to the
guards this change touches, not to every existing `takeException()` assertion
in the suite.

#### Scenario: A new overflow is caught

- **WHEN** a change introduces an overflow on a screen covered by these guards
- **THEN** the guard test fails, rather than passing because an existing
  overflow was drained first
