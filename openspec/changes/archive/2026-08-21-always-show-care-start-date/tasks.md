## 1. Guards first (red before the fix)

- [x] 1.1 In `test/contexts/notifications/presentation/care_item_form_test.dart`, rewrite the
  existing `hides the start-date picker while weekInterval == 1, and shows it once the interval
  is raised above 1` test into a visibility guard for the new rule: add a schedule (interval
  stays 1), assert `care-item-schedule-start-date-0` is found and shows the clock date
  (2026-07-22) as its label, then raise the interval and assert it is still found. Run it and
  confirm it is RED against the unchanged form.
- [x] 1.2 Add an editability guard: with interval 1, tap `care-item-schedule-start-date-0`,
  pick a date in a different month from the injected clock (clock is `DateTime(2026, 7, 22)`;
  pick e.g. 2026-08-03 by driving the `showDatePicker` dialog), and assert the button's label
  now renders the picked date. Confirm RED.
- [x] 1.3 Add a submitted-value guard: same interval-1 schedule, pick the same non-today date,
  fill the title, submit, and assert the `_FakeCareItemRepository.lastDraft`'s single schedule
  has `startDate` equal to the picked day — explicitly NOT the clock's day. Assert against the
  picked date's y/m/d, and include the "not today" comparison so a defaulted value cannot
  satisfy it. Confirm RED.

## 2. Production change

- [x] 2.1 In `lib/contexts/notifications/presentation/care_item_form.dart` `_buildScheduleRow`,
  remove the `if (schedule.weekInterval > 1) ...[ ]` wrapper so the start-date label + picker
  button render unconditionally, keeping their position immediately above the end-date block
  and keeping the key `care-item-schedule-start-date-$index`.
- [x] 2.2 Replace the comment above that block: it currently claims a plain weekly schedule
  doesn't need a start date (design D3). State instead that the backend's `isActiveOn` rejects
  any date before `startDate` regardless of `weekInterval`, so the start date gates every
  schedule and must always be reachable. Do not touch `_pickStartDate`'s `firstDate`/`lastDate`.
- [x] 2.3 Run the three guards from section 1 and confirm they are GREEN.

## 3. Mutation verification

- [x] 3.1 Back up `care_item_form.dart` with `cp` (never `git checkout` — see repo memory), then
  re-introduce `if (schedule.weekInterval > 1)` around the start-date block. Run the care form
  tests and confirm the 1.1 visibility guard is NAMED in the failure list (not merely "some
  test failed"). Restore from the backup.
- [x] 3.2 Same backup/restore cycle: in `_submit`, force the constructed `CareSchedule`'s
  `startDate` to `widget.clock()` instead of `s.startDate`. Confirm the 1.3 submitted-value
  guard is NAMED in the failure list, and that 1.1/1.2 alone would NOT have caught it.
  Restore.
- [x] 3.3 Confirm the file is byte-identical to the pre-mutation state (`git diff` shows only
  the intended 2.1/2.2 edits).

## 4. Full verification

- [x] 4.1 `flutter analyze` clean for the two changed files.
- [x] 4.2 `flutter test test/contexts/notifications/` green, then the full `flutter test` suite
  green — watch for `All tests passed!`, since a hang is not a pass.
- [x] 4.3 Re-run the care form tests under `TZ=UTC flutter test
  test/contexts/notifications/presentation/care_item_form_test.dart` — the guards compare dates,
  and local UTC+8 vs CI UTC has broken date guards in this repo before.
- [x] 4.4 `openspec validate always-show-care-start-date --strict` passes.

## 5. List-row summary (added after review; code-review FINDING 1)

- [x] 5.1 Guard first: in `care_items_screen_test.dart`, add a test asserting the summary for
  `_medicationItem` (weekInterval 1, startDate 2026-07-20) contains
  `careScheduleFrom(Jul 20, 2026)`, and that `careWeekIntervalSuffix(1)` is absent so
  unwrapping the start date cannot drag the suffix out with it. Confirmed RED.
- [x] 5.2 In `_scheduleSummary`, move the start-date write out of `if (weekInterval > 1)`
  (the suffix write stays inside) and replace the comment claiming the start date "only
  matters once weekInterval > 1 ... (mirrors the form's own start-date visibility rule)" —
  that rule no longer exists.
- [x] 5.3 Mutation-verified both ways: re-gating the start-date write on `weekInterval > 1`
  names the new guard; forcing the suffix write to run unconditionally also names it, so the
  `findsNothing` half is not vacuous.
- [x] 5.4 `flutter analyze` clean; `TZ=UTC flutter test` full suite `+3668 ~1: All tests passed!`.
