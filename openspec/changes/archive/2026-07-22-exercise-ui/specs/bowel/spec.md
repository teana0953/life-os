## MODIFIED Requirements

### Requirement: Bowel tab in the daily-log shell

The daily-log shell SHALL offer the bowel tracker via its More overflow menu (not a dedicated bottom-navigation tab), and selecting it SHALL show the bowel screen for the shell's currently viewed day. The bowel screen SHALL follow the shell's day navigation, so changing the viewed day updates the bowel screen too.

#### Scenario: The bowel tracker is reachable from the daily-log shell
- **WHEN** the user opens the daily-log shell, taps the More destination in the bottom navigation, and selects the bowel tracker
- **THEN** the bowel screen is shown for the shell's currently viewed day, and the Today, Target, and Water tabs remain reachable in the bottom navigation
