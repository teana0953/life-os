## Why

The care item add/edit form renders the start-date picker only when a schedule's
`weekInterval > 1`, on the stated reasoning that "a plain weekly schedule doesn't need an
irrelevant start date". That reasoning is wrong. The backend's
`isActiveOn` (`src/contexts/notifications/domain/care-schedule.ts`) gates every schedule with
`if (localDate < schedule.startDate) return false` — unconditionally, before the week-interval
arithmetic. The start date is therefore a live activation gate for daily and plain-weekly
schedules too.

The user-visible consequence: a schedule with `weekInterval == 1` always gets today's date
silently (`startDate: widget.clock()` at add time), and the picker that would change it is not
on screen. "Start this medication next Monday" cannot be expressed — the item begins firing
immediately.

## What Changes

- The schedule row's start-date picker is shown for **every** schedule, regardless of
  `weekInterval`, positioned directly above the end-date control.
- The comment asserting that a plain weekly schedule doesn't need a start date is corrected to
  record why the start date always matters (the backend gate), so the removed condition is not
  reintroduced.
- Guards are added for `weekInterval == 1`: the start date is visible and editable, and the
  submitted `start_date` is the picked day rather than today. Both are mutation-verified.
- The existing guard that asserts the picker is *hidden* at `weekInterval == 1` is inverted —
  it encodes the behaviour being overturned.
- No change to the picker's `firstDate`/`lastDate` (past and future are already permitted), to
  the backend schema/validation/routes, or to the `careStartDateLabel` l10n string.

## Capabilities

### New Capabilities

<!-- None. This corrects the visibility rule of an existing form control. -->

### Modified Capabilities

- `care-reminders-ui`: the create/edit requirement gains an explicit rule that the schedule
  start date is always shown and editable (previously the spec named a start date among the
  schedule fields without stating when it is reachable, which let the conditional rendering
  pass unchallenged); the list requirement gains the matching rule for the schedule summary,
  which mirrored the form's old visibility condition and would otherwise hide a date the user
  had just set.

## Impact

- `lib/contexts/notifications/presentation/care_item_form.dart` — remove the
  `schedule.weekInterval > 1` guard around the start-date block, move it above the end-date
  block, rewrite the stale comment.
- `test/contexts/notifications/presentation/care_item_form_test.dart` — invert the
  hidden-at-interval-1 guard; add visibility + editability + submitted-value guards, and a
  value guard for edit mode (mutation showed the stored start date could be silently reset to
  today on save with the whole suite green).
- `lib/contexts/notifications/presentation/care_items_screen.dart` — `_scheduleSummary` wrote
  the start date only inside `if (weekInterval > 1)`, mirroring the form's removed rule. Move
  it out of that condition (the every-N-weeks suffix stays inside) and replace its comment.
- `test/contexts/notifications/presentation/care_items_screen_test.dart` — add an interval-1
  summary guard.
- No backend change. `../life-os-backend` is read-only for this change; `start_date` is already
  sent on every schedule, so the wire payload's shape is unchanged — only its value can now
  differ from today.
