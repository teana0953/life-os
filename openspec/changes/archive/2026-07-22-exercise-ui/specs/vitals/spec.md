## MODIFIED Requirements

### Requirement: Vitals tab in the daily-log shell

The daily-log shell SHALL offer the vitals tracker via its More overflow menu (not a dedicated bottom-navigation tab), and selecting it SHALL show the vitals screen for the shell's currently viewed day. The vitals screen SHALL follow the shell's day navigation, so changing the viewed day updates the vitals screen too.

#### Scenario: The vitals tracker is reachable from the daily-log shell
- **WHEN** the user opens the daily-log shell, taps the More destination in the bottom navigation, and selects the vitals tracker
- **THEN** the vitals screen is shown for the shell's currently viewed day, and the Today, Target, and Water tabs remain reachable in the bottom navigation
