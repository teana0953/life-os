# i18n Specification

## Purpose
TBD - created by archiving change add-i18n. Update Purpose after archive.
## Requirements
### Requirement: Localized UI in English and Traditional Chinese
All user-facing text (labels, buttons, headings, and error messages) SHALL be provided from localized resources for English and Traditional Chinese, with no user-facing string hard-coded in the presentation code.

#### Scenario: Traditional Chinese
- **WHEN** the active locale is Traditional Chinese
- **THEN** the sign-in and home screens, and any error message shown, render in Traditional Chinese

#### Scenario: English
- **WHEN** the active locale is English
- **THEN** the same surfaces render in English

### Requirement: Locale follows the system with English fallback
The app SHALL use the operating-system locale by default, and SHALL fall back to English when the system locale is not a supported language.

#### Scenario: Supported system locale
- **WHEN** the OS locale is Traditional Chinese and the user has not chosen a language
- **THEN** the app displays Traditional Chinese

#### Scenario: Unsupported system locale
- **WHEN** the OS locale is neither English nor Traditional Chinese and the user has not chosen a language
- **THEN** the app displays English

### Requirement: In-app language switch is remembered
The app SHALL let the user switch language within the app, apply it immediately, and remember the choice across app restarts (overriding the system locale until changed).

#### Scenario: Switch language
- **WHEN** the user selects a different language from the in-app switcher
- **THEN** the UI updates to that language immediately

#### Scenario: Choice persists
- **WHEN** the user has chosen a language and reopens the app
- **THEN** the app starts in the chosen language regardless of the system locale

### Requirement: Localized error messages
Errors surfaced to the user (sign-in failures, profile-load failures, re-authentication needed) SHALL be shown in the active language, driven by error type rather than copy embedded in infrastructure code.

#### Scenario: Error in active language
- **WHEN** an error is shown while the active locale is Traditional Chinese
- **THEN** the message text is in Traditional Chinese

