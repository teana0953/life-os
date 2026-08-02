# settings Specification

## Purpose
TBD - created by archiving change add-settings. Update Purpose after archive.
## Requirements
### Requirement: Dedicated settings page reachable from home

The app SHALL provide a settings page, reachable from the home screen, that
groups user preferences (theme, language), the friends entry, and sign-out.

#### Scenario: Open settings

- **WHEN** an authenticated user activates the settings entry on the home screen
- **THEN** the settings page is shown

#### Scenario: Friends entry opens the friends page

- **WHEN** the user activates the friends entry on the settings page
- **THEN** the friends page is shown

### Requirement: Theme selection
The settings page SHALL let the user choose the app theme among **System**, **Light**, and **Dark**, apply it immediately, and remember it across app restarts (overriding the system setting until changed back to System).

#### Scenario: Choose dark
- **WHEN** the user selects Dark in settings
- **THEN** the app switches to the dark theme immediately

#### Scenario: Theme persists
- **WHEN** the user has chosen a theme and reopens the app
- **THEN** the app starts in the chosen theme

#### Scenario: Back to system
- **WHEN** the user selects System
- **THEN** the app follows the operating-system light/dark setting again

### Requirement: Language selection in settings
The settings page SHALL let the user choose the language (System / English / Traditional Chinese), applying immediately, consistent with the existing locale behavior.

#### Scenario: Change language in settings
- **WHEN** the user selects a language in settings
- **THEN** the UI updates to that language immediately

### Requirement: Sign out from settings
The settings page SHALL let the user sign out, ending the session and returning to the login screen.

#### Scenario: Sign out
- **WHEN** the user chooses sign out in settings
- **THEN** the session ends and the login screen is shown

### Requirement: Localized settings UI
All settings-page text SHALL be localized (English and Traditional Chinese), with no hard-coded strings.

#### Scenario: Settings in Traditional Chinese
- **WHEN** the active locale is Traditional Chinese
- **THEN** the settings page labels and options render in Traditional Chinese

