## Why

Frontend for medication reminders. Slice 2 shipped the backend (schedule + occurrence
+ per-minute Cron dispatch) — but there is no in-app UI, so a user can't actually create
a reminder. This adds the manage-medication-reminders screen (list / add / edit / delete
+ enable toggle) and a timezone setter, against the live endpoints
`POST/GET/PATCH/DELETE /api/reminders/medication` and `PUT /api/user/timezone`. It also
finally lets the whole reminders pipeline be verified end-to-end on device (create a
reminder a few minutes out → Cron delivers the push).

## What Changes

- **`notifications` context (frontend) grows a medication-reminders capability:**
  - `MedicationReminder` value ({ id, label, times, daysOfWeek, weekInterval, anchorDate,
    enabled }) + `MedicationReminderRepository` port (list/create/update/delete) + typed
    errors (`ReminderReauthRequired`, `ReminderRequestFailed`); a timezone get/set port.
  - **`HttpMedicationReminderRepository`** (patterned on `HttpPushRepository`): Bearer
    token, snake_case bodies; 401 → `ReminderReauthRequired`, other non-2xx →
    `ReminderRequestFailed`. Timezone via `PUT /api/user/timezone`.
  - Thin list/create/update/delete use cases.
  - **`MedicationRemindersController`** (ChangeNotifier): loading / loaded / error /
    reauth; create/update (incl. enable toggle)/delete then reload; holds typed errors.
  - **`MedicationRemindersScreen`**: the list (each row shows label, times, weekdays, an
    enable switch that PATCHes on toggle), a FAB to add, tap-to-edit, delete (confirm),
    and an empty-state guide. A **`MedicationReminderForm`** (add/edit): label
    (`TextField`), an add/remove list of `HH:mm` times (`showTimePicker`, 24h), a 7-chip
    weekday selector (Sun..Sat → 0..6), a week-interval control (1=weekly, 2=biweekly…),
    an anchor date (`showDatePicker`, default today), and an enabled switch — with basic
    pre-submit checks (non-empty label, ≥1 time, ≥1 weekday). A simple timezone setter
    (shows the current zone, editable; default `Asia/Taipei`) makes clear reminders fire
    in the user's timezone.
- **Entry point**: a "用藥提醒" entry in the health 更多 tab → a go_router nested,
  DI-built route to `MedicationRemindersScreen`; DI wired in `main.dart`.
- New i18n strings (en + zh-Hant + zh fallback), regenerated localizations.

Frontend only, medication only (rehab/glucose/missed-meal are later slices). The real
Cron delivery is verified on device after deploy; tests cover the repository (mock
client), the controller state machine, and each screen/form state (fake controller).
Gate = `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`.

## Capabilities

### Added Capabilities

- `medication-reminders-ui`: from the health 更多 tab, a user can create, list, edit,
  enable/disable, and delete medication reminders (label, times, weekdays, every-N-weeks)
  and set their timezone, with clear empty/error/reauth states.
