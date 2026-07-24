## Why

Frontend for the generic care reminders (Slice A backend is live). Replaces the flat
Slice-2b medication UI — whose endpoints (`/api/reminders/medication`) were removed — with
a CareFlow-style **care management** page covering medication / rehab / radiotherapy_care /
custom, where only medication shows dose + stock. This **restores** the (now-404) ability to
create reminders and generalizes it.

## What Changes

- **Remove** the Slice-2b medication UI (`medication_reminders_screen`/`_controller`/`_form`,
  `http_medication_reminder_repository`, its domain/use-cases/tests) — it calls the removed
  endpoints.
- **New generic care UI** in `lib/contexts/notifications/`:
  - `CareItem` ({ id, category, title, note?, medication-only dose?/stock?/stockAlert?,
    schedules: List<CareSchedule> }) + `CareSchedule` ({ id?, timeOfDay, repeatDays
    (empty=every day), weekInterval, startDate, endDate?, doseQuantity, nagIntervalMinutes,
    enabled }) values; `CareItemRepository` (list/create/update/delete); typed
    errors `CareReauthRequired`, `CareRequestFailed`.
  - **`HttpCareRepository`**: `GET /api/care/items` parses the **`{ items: [...] }` envelope**
    (each item carries `schedules`); create `POST /api/care/items` and update `PATCH
    /api/care/items/:id` return a **bare item**; `DELETE`. snake_case; dates sent as
    **`YYYY-MM-DD`**; `dose_quantity`+`start_date` always sent on every schedule (backend-required);
    the category **enum** (not label) is sent; existing schedule ids round-trip. 401 →
    `CareReauthRequired`, non-2xx → `CareRequestFailed`. (The `/api/care/log` answer endpoint is
    wired in Slice C, not here.)
  - `CareItemsController` (loading/loaded/error/reauth; reload after mutation; typed errors).
  - **`CareItemsScreen`**: list grouped by category (用藥 / 復健 / 放療保養 / 自訂), each row
    showing title, a note snippet, a schedules summary (time · weekdays[empty=每天] · every-N-weeks
    · date range) and — medication — stock; FAB to add; tap to edit; delete (confirm); empty-state
    guide; full-screen reauth exit.
  - **`CareItemForm`** (add/edit): a **category selector** at top; title `TextField`; a
    multi-line note; **add/remove schedules**, each with a time (`showTimePicker` 24h), 7 weekday
    chips (empty shown as 每天), a week-interval stepper, an anchor date shown only when
    interval>1, an optional end date, and a nag-interval dropdown (0=once / 5 / 10 / 15 / 30 min);
    and — **only when category=medication** — dose (text), stock, stock_alert, plus per-schedule
    dose_quantity. Submit gated on non-empty title + ≥1 schedule each with a time.
- **Entry**: the health 更多 tab's medication entry becomes "提醒 / 照護" → a go_router
  nested, DI-built route to `CareItemsScreen`; DI wired in `main.dart`.
- New i18n (en + zh-Hant + zh); regenerated localizations.

Frontend only — management UI (create/list/edit/delete). **No** Today
checklist (Slice C), **no** notification actions/snooze (Slice B), **no** low-stock UI (E).
Real push/Cron are on-device. Gate = `bash scripts/lint-actions.sh` + `flutter analyze` +
`flutter test`.

## Capabilities

### Added Capabilities

- `care-reminders-ui`: from the health 更多 tab, a user can create, list (grouped by
  category), edit, and delete care reminders across medication / rehab / radiotherapy_care /
  custom — with title, instructions, schedules (times, weekdays, every-N-weeks, date range,
  nag interval), and, for medication, dose + stock.

### Removed Capabilities

- `medication-reminders-ui`: the Slice-2b medication management screen is replaced by the
  generic `care-reminders-ui` (medication becomes the `medication` category).
