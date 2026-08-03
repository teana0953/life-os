## MODIFIED Requirements

### Requirement: Finance entry and shell

The home hub SHALL show a 財務 tile alongside the health tile that opens
`/finance`, a finance shell with its own bottom navigation of four
destinations (總覽, 明細, 淨值, 分帳). The shell SHALL default to the current
month, and 總覽 and 明細 SHALL reflect the same selected month. Adding the
分帳 destination SHALL not change the behaviour or the test keys of the
existing three.

#### Scenario: Entering finance from home

- **WHEN** an authenticated user taps the 財務 tile on the home hub
- **THEN** the finance shell opens on the 總覽 tab showing the current month

#### Scenario: Month selection is shared

- **WHEN** the user switches to the previous month on 總覽 and then opens 明細
- **THEN** 明細 lists that same previous month's transactions

#### Scenario: The split destination is reachable

- **WHEN** the finance shell is shown
- **THEN** a 分帳 destination is available in its bottom navigation alongside
  the existing three
