# Design: refine-diet-logging

## Context

Front-end refinement of the merged `health-diet` module to match the reviewed
mockup on two functional points. Same conventions: Clean Arch/DDD in
`lib/contexts/health`, `ChangeNotifier` controllers, `Http*Repository` typed
errors, `DietCategoryColors` ThemeExtension, gen_l10n (en + zh-Hant). Backend
unchanged — its manual `POST /api/diet-entries` path (`portions`/`nutrients`,
no `food_item_id`) and the four portion fields on each entry already exist.

## Goals / Non-Goals

**Goals**
- Log a food not in the dictionary: name + per-group portions + meal + eaten-at.
- Show each logged food's portions across all its groups on Today, as pills.

**Non-Goals**
- Visual polish deferred by the user: progress bars, meal cards with emoji/time,
  target steppers.
- Nutrient (calorie) manual entry — portions only, matching the mockup.

## Decisions

### D1 — Manual entry mirrors the dictionary-logging seam

Add `logManualEntry(idToken, {name?, portions{staple,meat,fruit,veg}, meal,
eatenAt})` to `DietLogRepository`; `HttpDietLogRepository` POSTs the backend's
manual shape (`{ day, meal, name?, portions:{…}, eaten_at }`, no `food_item_id`).
A `LogManualEntry` use case wraps it. A `ManualEntryController` (or an extension
of the existing log-entry controller) holds the draft (name, four portion values,
meal, eaten-at) and a typed error, like the other controllers. The form is a
screen/sheet reached from a "找不到? 手動輸入" affordance at the bottom of
`DictionaryScreen`; on successful save it calls an `onSaved` callback the shell
wires to `todayController.load(...)` — the exact pattern the dictionary and
(fixed) target flows use, so Today refreshes immediately.

### D2 — A reusable portion-pills widget on Today

Replace `Text(entry.staple.toString())` in the Today entry row with a
`PortionPills` widget that renders one pill per **non-zero** group among
`{staple, meat, fruit, veg}`, each colored from `DietCategoryColors` and labeled
with its category + value (mirroring the mockup's pills and the pills already
implied by category colors). Zero-portion groups are omitted, so 蛋 (1 meat)
shows a single "肉 1" pill, not "0". The widget is presentation-only and pure
from an entry's portion fields. Because manual entries may be nameless, the Today
row shows a localized fallback label (e.g. "手動記錄") when `entry.name` is empty,
rather than a blank title.

## Risks / Trade-offs

- **Manual portions all zero** → guard/validate before save (nothing to log);
  surface it in the form rather than posting an empty entry.
- **Meal selection for manual entry** → reuse the same meal chips + snack label
  as dictionary logging so manual and dictionary entries share meal semantics and
  eaten-order.
- **Pill overflow on narrow rows** (a food spanning 3–4 groups) → lay pills out
  with a `Wrap` so they never overflow the row.

## Open Questions

- Manual entry as a full screen vs a bottom sheet — start with whatever the
  widget tests drive most cleanly (a pushed screen, consistent with
  `LogEntryScreen`); the form widget stays separable so it can move later.
