## Why

`computeNextPeriodStatus` already resolves six states, but the two places that
render its result — the home dashboard's menstrual-prediction tile and the
health overview's next-period card — read as flat sentences with no visual
relationship to the calendar the user lands on after tapping them. Worse, two
of those states show **no date at all**: `ongoing` says "period day 4" without
saying when it started, and `overdue` says "3 days late" without saying late
for *what* date. The user has to open the tracker to recover a date the client
already holds.

Meanwhile the sibling change `menstrual-cycle-day-marker` gives the calendar a
visual vocabulary — **filled circle = a period day that happened, outlined
circle = a prediction** — that the tile and the card do not share. Three
surfaces render the same underlying state in three unrelated shapes.

## What Changes

- A new shared presentation widget, **`CycleBadge`**: a 32dp circular badge
  reusing the calendar's two marker styles (filled / outlined) and no third
  style. It carries a short number-plus-unit label ("4天", "逾3天", "今天").
- The **home menstrual-prediction tile** and the **health overview next-period
  card** both lead with that badge, in four of the six states:

  | state | badge | colour |
  | --- | --- | --- |
  | `ongoing` | filled | `color.primary` |
  | `today` | filled | `color.outline` (neutral) |
  | `upcoming` | outlined | `color.primary` |
  | `overdue` | outlined | `color.warning` |

  `needsOneMore` and `noRecords` get **no badge and no date** — there is
  nothing to date, and an empty circle would read as "0 days".
- The **missing dates are added** to the home tile: `ongoing` gains a
  "{start date} 開始" line (the start date derived in presentation as
  `today - (days - 1)`), `overdue` gains "預計 {predicted date}", and `today`
  gains the plain predicted date. `upcoming` already had its date and keeps it.
- The **overdue tile's outline** turns warning-coloured. Colour is never the
  only signal: the badge already spells out "逾N天" and the date line is there.
- The **next-period card** gains an explanatory line for `overdue`
  ("已超過預測日 N 天"), and its `upcoming` copy splits into a main line
  ("還有 N 天") plus a date sub-line.
- Adding a second line changes the home tile's height contract. All six states
  keep the **same tile height** — `needsOneMore` / `noRecords` reserve the
  second line's space — so the existing equal-height guards do not regress into
  the mis-targeted-tap incident they were written for.
- No backend, `domain/`, `application/` or `infrastructure/` change: every
  value shown is already in `MenstrualStats` / `NextPeriodStatus`. The state
  machine and its priority order are untouched.

## Capabilities

### New Capabilities

- `home-dashboard-ui`: the content contract of the authenticated home
  dashboard's snapshot tiles — currently only their existence is specified (in
  `design-system`, "Home is a dashboard hub") and their loading/error/retry
  behaviour (in `screen-batch-reads-ui`), with nothing owning what a loaded
  tile must actually say. This change needs exactly one requirement there: the
  menstrual-prediction tile must name a date in every state that has one.

### Modified Capabilities

- `menstrual-ui`: gains a requirement that the next-period card leads with a
  status badge sharing the calendar's marker vocabulary, and that the overdue
  state states its overage in words as well as colour.

## Impact

- `lib/shared/widgets/cycle_badge.dart` (new) — the circular badge widget,
  exported alongside the other shared widgets.
- `lib/contexts/menstrual/presentation/next_period_card.dart` — badge column,
  split upcoming copy, overdue explanation line.
- `lib/contexts/home/presentation/home_screen.dart` — `_SnapshotTile` gains an
  optional leading badge, an optional second line, and a warning outline
  variant; the menstrual tile's builder derives the ongoing start date.
- `lib/l10n/app_en.arb`, `lib/l10n/app_zh_Hant.arb` (+ regenerated
  `lib/l10n/generated/`) — badge labels, full-sentence accessibility labels for
  all four badge states, the overdue explanation line, and the split upcoming
  copy.
- `test/contexts/user/presentation/home_screen_responsive_test.dart` — the R3 equal-height
  guards, updated to the new tile height contract and extended to cover all six
  menstrual states.
- `test/contexts/menstrual/`, `test/shared/widgets/` — widget tests for the
  badge, the card states and the tile states; `test/shared/theme/
  real_font_metrics_test.dart` for the badge's real-font fit.
- No change to `domain/`, `application/`, `infrastructure/`, or the backend
  API.
