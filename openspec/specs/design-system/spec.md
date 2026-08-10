# design-system Specification

## Purpose
TBD - created by archiving change add-design-system. Update Purpose after archive.
## Requirements
### Requirement: Themed Material 3 design language
The app SHALL apply a single Material 3 theme with an explicit color scheme (a pale-blue primary with blush-pink and yellow accents on a warm cream ground, and soft-brown text rather than pure black) and consistent component styling (rounded buttons, inputs, and cards). Screens SHALL derive colors from the theme, not hard-code them.

#### Scenario: Theme applied
- **WHEN** the app builds its root `MaterialApp`
- **THEN** it uses a Material 3 theme whose color scheme primary is the design's pale-blue accent, and its screens render with the themed components

### Requirement: Home uses primary bottom navigation

The authenticated home screen SHALL replace the four-space grid with a Material 3 NavigationBar containing health, finance, tasks, journal, and settings in that order. Existing health, finance, and settings destinations SHALL remain navigable. Destinations without product functionality SHALL communicate that they are coming soon instead of navigating to a false or empty feature.

#### Scenario: Primary destinations are visible

- **WHEN** an authenticated profile has loaded
- **THEN** the bottom navigation shows health, finance, tasks, journal, and settings with health selected

#### Scenario: Existing destinations navigate

- **WHEN** the user selects health, finance, or settings
- **THEN** the corresponding existing route opens

#### Scenario: Planned destinations do not imply finished functionality

- **WHEN** the user selects tasks or journal
- **THEN** the app remains on the home screen and shows the localized coming-soon message

### Requirement: Light and dark themes follow the system
The app SHALL define both light and dark themes and select between them by the operating-system preference.

#### Scenario: System light
- **WHEN** the OS is in light mode
- **THEN** the app renders the light theme

#### Scenario: System dark
- **WHEN** the OS is in dark mode
- **THEN** the app renders the dark theme (a warm dark ground, not a naive inversion), keeping text legible

### Requirement: Accessible contrast
Text and interactive elements SHALL meet WCAG AA contrast against their background in both themes, despite the pastel palette (e.g. pastel buttons carry dark-ink labels).

#### Scenario: Readable controls
- **WHEN** any button, label, or body text is shown in either theme
- **THEN** its contrast against its background is at least AA (4.5:1 for body text, 3:1 for large text)

### Requirement: Responsive layout
The sign-in and home screens SHALL adapt to viewport width: a phone shows a single-column layout; wider screens use additional columns and a centered, max-width content area. No layout SHALL overflow horizontally at any supported width.

#### Scenario: Phone width
- **WHEN** the viewport is narrow (phone)
- **THEN** the sign-in card and home content fill a single column without horizontal overflow

#### Scenario: Desktop width
- **WHEN** the viewport is wide (desktop)
- **THEN** the sign-in card is centered with a bounded max width, and the home "spaces" grid shows multiple columns

### Requirement: No layout overflow on narrow phones

Screens SHALL lay out without **any layout error** — overflow or otherwise —
at the phone widths the app targets (320dp and 360dp), in every supported
locale, and at accessibility text scales up to 2.0. Not every such failure is
a RenderFlex overflow: a list tile whose trailing content cannot be laid out
raises a different error and must equally not occur. Where content cannot
fit, it SHALL reflow or shrink rather than overflow, keeping content readable
rather than clipped.

#### Scenario: Narrow width in either locale

- **WHEN** the period tracker, net worth tab, record calendar card, diet
  calendar, or a category progress bar is rendered at 320dp or 360dp in
  English or Traditional Chinese
- **THEN** no layout overflow occurs

#### Scenario: Enlarged text

- **WHEN** those screens are rendered at a text scale of 2.0, at either phone
  width and in either locale
- **THEN** no layout error occurs — including the calendar's day cells, whose
  height must follow the text size, and list tiles whose trailing content must
  stay layout-able

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
