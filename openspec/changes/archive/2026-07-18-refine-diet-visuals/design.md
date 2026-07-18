# Design: refine-diet-visuals

## Context

Presentation-only refinement of the merged `health-diet` UI to match the reviewed
mockup. Same conventions: Chiikawa Material 3 theme, `DietCategoryColors`
ThemeExtension, `ledgeShadow`, gen_l10n. No use case, repository, controller
state, or backend change — the data the screens already have is enough.

## Goals / Non-Goals

**Goals**: Today progress as category bars; meal groups as cards with emoji +
time; target via steppers; debounced search. Pixel-intent parity with the mockup.

**Non-Goals**: any behavior/data change (progress math, eaten-order, target
values, search results stay identical); new screens or data.

## Decisions

### D1 — A pure progress-bar widget replaces the chips

A small stateless `CategoryProgressBar` (label + rounded track + category-color
fill + "used / target") laid out one per category. Fill fraction =
`clamp(logged / effective, 0, 1)` (effective 0 → empty, never divide-by-zero;
over-target caps full). Colors from `DietCategoryColors`, track/outline from the
theme. Replaces `_CategoryProgress`/`_CategoryProgressRow` in `today_screen.dart`.

### D2 — Meal cards carry an emoji and the group's time

Each meal group renders as a themed card (rounded + 2px outline + `ledgeShadow`).
A helper maps the standard meals to emoji (breakfast 🌅, lunch 🍱, dinner 🌙) and
falls back to 🍎 for snack labels. The card title shows the localized meal label
plus the group's **earliest** eaten-at time — computed as the `min` of the
group's entries' `eatenAt` (not just `entries.first`, since per-entry order
within a group isn't guaranteed by the domain). `eatenAt` is a UTC `DateTime`, so
it MUST be converted with `.toLocal()` before formatting as `HH:mm` via `intl`
(otherwise production shows UTC and the widget test would falsely pass). No
hard-coded format string beyond the pattern.

### D3 — Stepper widget replaces the target text fields

A `PortionStepper` (− value +) per category updates the same
`controller.setDraftBase*` the text field did — the controller/draft/save path is
untouched. Step by 0.5 (half-portion targets stay reachable), clamped at 0,
decimals preserved — this deliberately replaces free-form decimal text entry with
+/- adjustment, and half-steps cover the mockup's targets. Colors via
`DietCategoryColors`. Replaces `_TargetField`.

### D4 — Debounce lives in the controller

`DictionaryController` gains a `Timer`-based debounce (~300 ms): `search(query)`
resets a timer and only issues the request when it fires; a new keystroke cancels
the pending timer. An injectable debounce duration keeps widget tests fast
(tests can pass `Duration.zero` or pump past the delay). The timer is cancelled
in `dispose`. Search behavior/results are otherwise unchanged.

## Risks / Trade-offs

- **Progress bar divide-by-zero / over-target** → `effective <= 0` renders an
  empty bar; ratio clamped to [0,1] so over-logging shows a full bar (numbers
  still show the true "used / target").
- **Debounce leaking a timer** → cancel in `dispose`; tests assert no pending
  timer after dispose.
- **Time formatting locale** → use localized `HH:mm` via `intl`, consistent with
  the app's i18n; no literal format string in the widget layer beyond the pattern.

## Open Questions

- None outstanding. (Stepper granularity resolved to 0.5 to keep half-portion
  targets reachable while dropping free-form decimal text entry.)
