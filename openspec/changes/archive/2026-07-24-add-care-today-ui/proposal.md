## Why

The Today daily checklist — CareFlow's primary surface. It consumes the live Slice-C1
`GET /api/care/today` and lets the user mark a slot **done / skipped** inline (via the
existing `POST /api/care/log`). This is **the only way to stop a nag from the app** — until
now an unanswered reminder re-nags until midnight with no in-app way to answer it.

## What Changes

- New in `lib/contexts/notifications/`:
  - `CareTodaySlot` value ({ careItemId, careScheduleId, category, title, note?, dose?,
    timeOfDay, localDate, status (pending/overdue/done/skipped/missed), doneTime?,
    doseQuantity }) + `CareTodayRepository` port (`getToday` → { date, slots }; `logSlot`
    → mark done/skipped) + typed errors `CareReauthRequired`/`CareRequestFailed`.
  - **`HttpCareTodayRepository`**: `getToday` parses the **`{ date, items:[...] }` envelope**;
    `logSlot` `POST /api/care/log { care_schedule_id, local_date, time_of_day, status }`.
    401 → reauth, non-2xx → failed.
  - Thin `getToday` / `markDone` / `markSkipped` use cases.
  - `CareTodayController` (loading/loaded({date,slots})/error/reauth; mark → reload; typed
    errors; re-entrancy guard).
  - **`CareTodayScreen`** (CareFlow layout): a **focus card** = the most-urgent slot
    (earliest overdue, else earliest pending) with big title/time/category/note (+ dose for
    medication) and primary Done / secondary Skip; then groups **Overdue**, **Later
    (pending)**, and a collapsible **Done** (count), with inline Done/Skip on pending/overdue
    rows, the done time on done rows, and struck-through skipped/missed; an **all-done
    celebration** card (existing mascot) when nothing is pending/overdue. loading / empty
    (no schedules today) / error / reauth states; the date shown at top.
  - Entry: a "今日照護 / Today" entry in the health 更多 tab → a go_router nested, DI-built
    route to `CareTodayScreen` (distinct from the Slice-D "提醒 / 照護" management entry —
    today vs. manage); DI in `main.dart`.
- New i18n (en + zh-Hant + zh); regenerated localizations.

Frontend only — Today list + inline done/skip. **No** notification actions/snooze (Slice B),
**no** low-stock (E), **no** deep home integration (later). Real push is on-device. Gate =
`bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`.

## Capabilities

### Added Capabilities

- `care-today-ui`: from the health 更多 tab, a user sees today's care slots as a checklist
  (a focus card for the most-urgent, then overdue / later / done groups, with an all-done
  celebration) and can mark a slot done or skipped inline — which stops its reminder nag.
