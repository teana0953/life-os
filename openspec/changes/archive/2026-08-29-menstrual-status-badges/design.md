## Context

See `proposal.md` — Why. The settled UI/UX design (uiux id `life-os-ux236`,
issue #236 extended scope) is the input to this change; this document records
the technical decisions that follow from it. The constraints that shape them:

- `computeNextPeriodStatus` returns six states (`ongoing`, `upcoming`, `today`,
  `overdue`, `needsOneMore`, `noRecords`) plus a `days` count and a nullable
  `predictedNextStart`. It is a `domain/` function and is out of scope to
  change — every value this change renders is already in it or in
  `MenstrualStats`.
- The sibling change `menstrual-cycle-day-marker` fixes the calendar's marker
  vocabulary: 32dp circle, **filled = a period day**, **outlined 2dp = a
  prediction**, `color.outline` thin ring = today. This change must reuse that
  vocabulary rather than invent a parallel one.
- The design system has no named spacing tokens; the values below are the ones
  reverse-engineered in the design-system document from actual usage, and map
  to literal `EdgeInsets` / `SizedBox` values in code.
- **Pastel colours may never be foreground text** (hard constraint): in the
  light theme `hachiwareBlue` on `surfaceLight` is 1.9–2.4:1. Any badge text in
  a pastel colour family must instead use `color.ink` or a `*-text` deep
  variant.
- `_SnapshotTile` is one of eight tiles in `_DashboardSection`'s `Wrap`. Its
  height is load-bearing: `home_screen_responsive_test.dart`'s R3 guards exist
  because tiles once changed height between states and taps landed on the wrong
  target.
- Widget tests cannot see the real font (root `CLAUDE.md` — Design system):
  every glyph paints as a `fontSize` square, so no ordinary widget test can
  prove text fits inside a 32dp circle. Only
  `test/shared/theme/real_font_metrics_test.dart` loads the real `.ttf`.

## Goals / Non-Goals

**Goals:**

- One visual vocabulary across calendar, home tile and overview card, so the
  same state never appears in three unrelated shapes.
- Every state that has a date shows that date, on both surfaces.
- The home tile's height contract survives the added second line, across all
  six states.

**Non-Goals:**

- Any change to `domain/`, `application/`, `infrastructure/`, or the backend.
- Any change to `computeNextPeriodStatus`'s state machine or priority order.
- Any redesign of the calendar itself (owned by `menstrual-cycle-day-marker`).
- Any change to the tap/navigation behaviour of the tile or the card.
- New colour tokens. Every colour below already exists in
  `app_colors.dart` / the `ColorScheme`.

## Decisions

### 1. `CycleBadge`: one shared widget, two forms, four state mappings

A new stateless widget under `lib/shared/widgets/` — not a private widget in
either screen — because both the home tile and the overview card render it and
the spec pins them to depict the same state identically. Its API is the two
marker forms, not the six domain states: it takes a `filled` flag, a colour, a
text-colour and a label; the mapping from `NextPeriodState` to those lives at
the two call sites' shared helper, so `shared/widgets/` stays free of
menstrual-domain knowledge (the same layering rule the other 21 shared widgets
follow).

| Property | Token | Value / source |
| --- | --- | --- |
| Diameter | `size.marker` | 32dp — the *same* as the calendar day marker, deliberately not a new `marker-lg` |
| Shape | — | `BoxShape.circle` |
| Border width (outlined form) | `border.width` | 2dp |
| Label text style | `text.label-small` | `textTheme.labelSmall` (M3 default, ~11px/w500) |
| Text scaling | — | `TextScaler.clamp(maxScaleFactor: 1.3)`, inside the badge only |

State-to-appearance mapping:

| State | Fill | Border | Text colour |
| --- | --- | --- | --- |
| `ongoing` | `color.primary` | — | `color.on-primary` |
| `today` | `color.outline` | — | `color.ink` |
| `upcoming` | — | `color.primary` | `color.ink` |
| `overdue` | — | `color.warning` | `color.finance-budget-warning-text` (via `financeBudgetWarningColor(scheme)`) |
| `needsOneMore`, `noRecords` | *no badge rendered at all* | | |

*Why 32dp and not a larger badge for two lines of text:* reusing the calendar's
diameter is what makes the vocabulary shared rather than merely similar, and
`menstrual-cycle-day-marker`'s decision 2 already establishes that two short
lines fit a 32dp circle under a 1.3× clamp. Minimising the token footprint
beats tailoring a size per use.

*Why the outlined `upcoming` badge's text is `color.ink` and not
`color.primary`:* the pastel-never-as-foreground constraint. The "this is the
period colour" meaning is carried by the ring; the text does not need to repeat
it in a colour that fails AA.

*Why `overdue` keeps the outlined form:* the form encodes *prediction vs.
happened*, and an overdue date is still an unconfirmed prediction. Only the
colour changes. Turning it filled would claim the period had started.

*Why `ExcludeSemantics` on the badge:* a screen reader announcing "4" or
"today" as a standalone node is worse than no badge. The home tile already has
the `Semantics(label:) + ExcludeSemantics` pattern in `_SnapshotTile._figure`;
the card follows it.

### 2. The ongoing start date is derived in presentation, not added to the domain

`NextPeriodStatus` carries `days` (the 1-based day of the ongoing period) but
not the period's start date. The tile's new "{start} 開始" line derives it as
`today - Duration(days: days - 1)`.

Done in presentation rather than by adding a field to `NextPeriodStatus`
because that is a `domain/` type shared with the overview card and the tracker,
and the derivation is exact and total: `days` is defined as
`daysBetween(startDate, today) + 1` by the same function, so inverting it
cannot disagree with the source. Adding a field would widen a domain type for
one screen's formatting need and pull `MenstrualPeriod` lookup into a call site
that currently only holds the status.

The derivation lives in one helper next to the badge-state mapping, used by
both surfaces, not copy-pasted per screen — the value must not be able to
differ between the tile and the card.

*Edge case pinned by test:* `days == 1` yields today itself, not yesterday.

### 3. `_SnapshotTile` gains an optional second line and a warning outline; height is fixed for all states

The tile grows from one value line to a value line plus an optional
`text.body-small` / `color.ink-muted` date line, at `space.stack-2xs` (4dp)
below it. The badge sits left of the value at `space.stack-xs` (8dp).

The height contract is kept by raising the tile's `minHeight` rather than by
letting content decide it: states with no date line reserve the space instead
of collapsing. Estimated new value is ~132dp (current 110 + ~22 for one
`bodyMedium` line and its gap) — **an estimate, not a measurement**. The real
value is settled during implementation against
`real_font_metrics_test.dart`, which is the only test that loads the real font;
the ordinary widget tests would pass vacuously at any value.

The overdue outline switches from `color.outline` to `color.warning` at the
existing `border.width-thin` (1dp). The 1dp width is left as it is: widening it
to the site-wide 2dp would be an unrelated visual change to all eight tiles.

*Why not a taller tile only in the states that have a date:* that is exactly
the mis-targeted-tap incident the R3 guards were written for.

### 4. Copy is split rather than reworded, and every badged state gets a full-sentence a11y label

The card's current single `nextPeriodUpcoming` string becomes a main line
("還有 N 天") plus the existing date sub-line, so the badge does not repeat the
day count inline next to it. `overdue` gains a new explanation key
("已超過預測日 N 天").

Four new accessibility keys, one per badged state, each a whole sentence
including the state, the count and the date — for example
"生理週期預測:已逾期,已超過預測日 3 天,預計 7月25日". `needsOneMore` and
`noRecords` reuse their existing copy unchanged, since they gain nothing to
announce.

All keys go into `app_en.arb` with a `description` first, then
`app_zh_Hant.arb`, per the repo's i18n rule; `lib/l10n/generated/` is
regenerated and committed.

## Risks / Trade-offs

- **The estimated 132dp tile height may be wrong, and no ordinary widget test
  can tell.** → Settle it against `real_font_metrics_test.dart` during
  implementation and update the R3 guards to whatever it actually is; do not
  ship the estimate unverified.
- **`real_font_metrics_test.dart` cannot measure the zh-Hant labels.** The
  bundled `NotoSans-Subset-VariableFont.ttf` contains no CJK glyphs at all
  (see `CLAUDE.md` → Design system → Font); CJK has always come from the
  platform fallback font, which a `FontLoader` in a widget test does not
  supply. So the real-font measurement can only be taken on the **English**
  labels ("4d", "3d late", "Today"), and the zh-Hant width remains
  unverified by any automated test. → Take the height from the English
  real-font case, keep the 320dp overflow guard for the CJK `overdue` state
  as the ordinary widget test it is, and treat the CJK fit as confirmed only
  by a manual browser/device check before ship.
- **CJK at 320dp:** "預測日已過 3 天" as the tile's main value plus a 32dp badge
  and 12dp padding is the tightest case. → The value already goes through the
  tile's `FittedBox` single-line shrink; add a 320dp overflow test for the
  overdue state specifically.
- **Clamping the badge's text scale reduces its size for users who enlarged
  system text.** → Accepted, consistent with `menstrual-cycle-day-marker`
  decision 2; the unclamped information is in the a11y sentence and in the
  unclamped date line beneath.
- **Two surfaces now depend on the same state→appearance mapping.** → It is one
  shared helper plus a spec scenario requiring they not disagree, rather than
  two switch statements.
- **The new `home-dashboard-ui` capability overlaps three existing specs**
  (`design-system` owns the tile's existence, `screen-batch-reads-ui` owns its
  loading/retry behaviour, `menstrual-ui` owns the underlying state). → Scoped
  to exactly one requirement — what a loaded menstrual tile must say — and its
  loading/failure scenarios restate the batch-read contract rather than
  redefining it.

## Migration Plan

Not applicable — presentation-only, no persisted data, no API surface. Rollback
is reverting the change. The change is independent of
`menstrual-cycle-day-marker` at the code level (different files) but depends on
it conceptually for the marker vocabulary; if that change is reverted, the
badges remain correct on their own terms but stop matching the calendar.
