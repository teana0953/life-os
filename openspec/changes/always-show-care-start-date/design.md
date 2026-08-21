## Context

`care_item_form.dart` renders each schedule as a row of controls. The start-date block sits
between the week-interval stepper and the end-date block, wrapped in
`if (schedule.weekInterval > 1) ...[ ... ]`, with a comment recording the original decision
(referenced as design D3 in the archived care-reminders-ui work): a plain weekly schedule
supposedly doesn't need an irrelevant start date, so it is hidden but "still always sent,
defaulting to today".

That premise does not hold against the backend. `isActiveOn` in
`../life-os-backend/src/contexts/notifications/domain/care-schedule.ts` runs

```ts
if (localDate < schedule.startDate) return false;
```

before it computes `weeksSince(...) % schedule.weekInterval`. The start date is an
unconditional lower bound on activity; the week interval only decides which of the days on or
after it count. So the hidden field is not irrelevant on an interval-1 schedule — it is a gate
the user cannot see or move, permanently pinned to the day the schedule was added
(`startDate: widget.clock()` in `_addSchedule`).

The data model already carries the field on every schedule (`_ScheduleDraft.startDate`,
`CareSchedule.startDate`), `_pickStartDate` already exists and is interval-agnostic, and
`careStartDateLabel` is already localized. The whole defect is one render condition and the
comment defending it.

## Goals / Non-Goals

**Goals:**

- The start date is reachable and changeable for every schedule, so "start next Monday" is
  expressible on a daily or plain-weekly item.
- The overturned reasoning is replaced in-place by the fact that overturned it, so a future
  reader does not re-derive the old condition.
- Guards that would go red if the condition came back, proven red by mutation.

**Non-Goals:**

- No change to `firstDate`/`lastDate` on the picker. Past dates stay allowed (backfilling an
  item that started earlier is legitimate; the backend only compares, it does not reject) and
  the +3650-day ceiling stays as-is.
- No backend change: schema, validation, routes, and `isActiveOn` are read-only here. The
  payload already contains `start_date` for every schedule.
- No new l10n. `careStartDateLabel` is reused verbatim.
- No relationship between start date and end date is introduced (no ordering validation). The
  form has never enforced one and this change is not the place to add it.
- No default-value change. A new schedule still starts at today; only the ability to change it
  is added.

## Decisions

**D1 — Unconditional render rather than a widened condition.** The block is unwrapped
entirely, not re-gated on something narrower (e.g. "show when the value differs from today").
A conditional control is exactly what made the field unreachable, and any predicate other than
`true` reintroduces a state where the gate is invisible. The layout cost is one extra label +
button per schedule row.

**D2 — Position: above the end-date block, keeping its current source position.** The block
already sits immediately before the end-date block; removing the `if` leaves it there. Start
then end reads in chronological order and matches the requirement's wording. No reordering of
the surrounding controls (week interval above, dose/nag below) is done, so the diff stays
confined to the removed condition and the comment.

**D3 — Keep the widget key `care-item-schedule-start-date-$index`.** Existing tests and the new
guards address the control by this key; the always-present button is the same control, so a
rename would only churn call sites. Note that, unlike the end date, there is no separate
"add start date" key — the start date always has a value, so it is always the single-button
form.

**D4 — Comment states the backend gate, not the UI rule.** The replacement records *why* the
field is always shown (`isActiveOn` rejects any date before `startDate` regardless of
`weekInterval`), which is the durable fact; "we show it always" is already visible in the code.
This is the incident-avoidance case from the repo comment policy: the old comment was a wrong
claim that survived review, so the correction has to carry its refutation.

**D5 — The old guard is inverted, not deleted.** The existing test
`hides the start-date picker while weekInterval == 1, and shows it once the interval is raised
above 1` asserts the behaviour being removed and will go red. It is rewritten to assert
visibility at interval 1 and continued visibility after the interval is raised — the second
half still has value (it pins that raising the interval does not disturb the control).

**D6 — Two guards, not one, because visibility does not imply the value is used.** A
visible-and-editable guard can pass while `_submit` still writes today (e.g. if a future
refactor recomputed `startDate` at submit time). The second guard drives the picker, submits,
and asserts the captured `CareItemDraft`'s schedule carries the picked date. The fixture date
must be a day that is **not** today under the injected clock, otherwise the assertion is
satisfied by the defaulted value and the guard cannot fail — the "guard that cannot fail"
shape this repo keeps hitting.

**D7 — Mutation verification is per-assertion.** Both guards are verified by mutating the
production code and confirming *the specific new assertion* appears in the failure list:
(a) restore `if (schedule.weekInterval > 1)` around the block → the visibility guard must go
red; (b) force `startDate: widget.clock()` in `_submit`'s `CareSchedule` construction → the
submitted-value guard must go red. Seeing "some test failed" is not sufficient; the named
guard has to be in the output.

## Risks / Trade-offs

- **[The interval-1 row grows by a label and a button, making the schedule card taller on
  narrow screens]** → The row is inside a scrolling `ListView` with a 600px max width and no
  fixed-height ancestor, and the added block is the same shape as the end-date block already
  below it. No overflow surface is introduced. No narrow-screen layout guard is added, since
  none of the widths change.
- **[Users who never cared about the start date now see one more control on every schedule]** →
  Accepted. The alternative (hiding a live gate) is the defect being fixed; a field showing
  today's date is self-explanatory and costs a glance.
- **[A user backdates a start date on an existing item and changes when it fires]** → This is
  the intended capability, and it was already reachable at `weekInterval > 1`. The backend
  recomputes activity from the stored value on every day-run, so no stale state persists.
- **[The mutation in D7(b) is silently a no-op if the fixture clock happens to equal the picked
  date]** → The fixture pins a fixed clock and picks a date in a different month, so the two
  can never coincide.

## Open Questions

None.
