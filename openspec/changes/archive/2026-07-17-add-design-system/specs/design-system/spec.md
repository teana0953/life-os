# design-system — Delta Spec

## ADDED Requirements

### Requirement: Themed Material 3 design language
The app SHALL apply a single Material 3 theme with an explicit color scheme (a pale-blue primary with blush-pink and yellow accents on a warm cream ground, and soft-brown text rather than pure black) and consistent component styling (rounded buttons, inputs, and cards). Screens SHALL derive colors from the theme, not hard-code them.

#### Scenario: Theme applied
- **WHEN** the app builds its root `MaterialApp`
- **THEN** it uses a Material 3 theme whose color scheme primary is the design's pale-blue accent, and its screens render with the themed components

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
