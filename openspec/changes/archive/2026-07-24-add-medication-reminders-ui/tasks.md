# Tasks

## 1. Domain
- [ ] `domain/medication_reminder.dart`: `MedicationReminder` value ({ id, label,
      times, daysOfWeek, weekInterval, anchorDate, enabled }, value equality);
      `MedicationReminderRepository` port (`list`, `create`, `update`, `delete`, and
      `setTimezone` — **PUT only, no `getTimezone`**: the backend has no read endpoint,
      so the UI shows a locally-remembered/default value, D5); typed errors
      `ReminderReauthRequired`, `ReminderRequestFailed` (no localized text).

## 2. Infrastructure (TDD, mock http.Client)
- [ ] `infrastructure/http_medication_reminder_repository.dart` (mirror
      `http_push_repository.dart`: injected `baseUrl` + `http.Client`, `Authorization:
      Bearer <idToken>`, snake_case). `anchor_date` is sent **date-only `YYYY-MM-DD`**
      (never `toIso8601String()` — D4b). Test: `list` parses the array; `create`/`update`
      (partial, incl. `enabled`)/`delete` send the right verb + snake_case body **and a
      test asserts `anchor_date` is `YYYY-MM-DD`**; `setTimezone` PUTs `/api/user/timezone`;
      401 → `ReminderReauthRequired`; other non-2xx → `ReminderRequestFailed`.

## 3. Application (TDD, fake repo)
- [ ] `application/medication_reminders.dart`: thin `list/create/update/delete` (+
      `setTimezone`) use cases. Basic front validation (non-empty label, ≥1 time, ≥1
      weekday) may live here or in the controller — test whichever holds it.

## 4. Presentation: controller (TDD, fake repo)
- [ ] `presentation/medication_reminders_controller.dart` (ChangeNotifier): states
      loading / loaded (list, possibly empty) / error / reauth; `load`, `create`,
      `update`, `delete`, `toggleEnabled` each reload after the call; holds typed error
      (not text); re-entrancy guard. Unit-tested with a fake repo (load, create→reload,
      toggle, delete, failure keeps list, 401→reauth).

## 5. Presentation: screen + form (widget tests, l10nTestApp, fake controller)
- [ ] `presentation/medication_reminders_screen.dart`: list (each row: label, times,
      weekdays, enable `Switch` that toggles via the controller), FAB → form, tap row →
      edit, delete with a confirm, empty-state guide, reauth full-screen exit. Colors/text
      via Theme; strings via ARB.
- [ ] `presentation/medication_reminder_form.dart`: label `TextField`; add/remove `HH:mm`
      times via `showTimePicker` (24h display); 7 weekday toggle chips (Sun..Sat→0..6);
      week-interval stepper/dropdown; `showDatePicker` anchor (default today); enabled
      switch; submit disabled until label non-empty + ≥1 time + ≥1 weekday; submit calls
      create or update. Widget tests: empty-state, a rendered row + working switch, FAB
      opens form, form gates submit on validity, delete confirm, reauth exit.
- [ ] Timezone setter UI (on the screen or a small section): shows the current tz
      (default Asia/Taipei), lets the user change it (`setTimezone`), 400 → localized
      error; a one-line "reminders use your timezone" note.

## 6. Wiring + entry + i18n
- [ ] go_router: nested, DI-built route to `MedicationRemindersScreen` (per
      lifeos-web-nav-go-router); `_MoreBody` entry "用藥提醒" in `health_scaffold.dart`.
- [ ] `main.dart`: construct `HttpMedicationReminderRepository(baseUrl: apiBaseUrl,
      client)`, the use cases, and the controller; idToken the same way the existing
      push/import flows do.
- [ ] i18n: add en + zh-Hant (+ zh) strings for all new copy; run `flutter gen-l10n`
      and commit `lib/l10n/generated/*`.

## 7. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.
