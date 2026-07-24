# Tasks

## 1. Remove the Slice-2b medication UI
- [ ] Delete `lib/contexts/notifications/`'s medication_reminders_screen.dart / _controller.dart /
      medication_reminder_form.dart, http_medication_reminder_repository.dart, the medication
      reminder domain value/use-cases, and their tests. Remove the old 更多-tab entry + route +
      DI. Ensure nothing else imports them (app_test etc.).

## 2. Domain
- [ ] `domain/care_item.dart`: `CareItem` (id, category, title, note?, dose?, stock?, stockAlert?,
      schedules: List<CareSchedule>; value equality) + `CareSchedule` (id?, timeOfDay, repeatDays,
      weekInterval, startDate, endDate?, doseQuantity, nagIntervalMinutes, enabled) + `CareItemDraft`/
      `CareItemUpdate`; `CareItemRepository` port (list/create/update/delete — **no logSlot this
      slice**, deferred to Slice C); typed errors `CareReauthRequired`, `CareRequestFailed`.

## 3. Infrastructure (TDD, mock http.Client)
- [ ] `infrastructure/http_care_repository.dart` (authed, snake_case). Tests: `list` parses the
      **`{items:[...]}` envelope** with nested schedules; `create`/`update` send snake_case bodies,
      **`start_date`/`end_date` as `YYYY-MM-DD`** (assert regex even from a DateTime-with-time);
      **assert `dose_quantity` AND `start_date` are serialized on EVERY schedule, including a
      non-medication one** (backend requires both regardless of category — the Slice-2b trap);
      assert the **category wire value is the enum string** (not a localized label); round-trip
      existing schedule ids; parse the bare returned item; `delete`; 401 → `CareReauthRequired`;
      non-2xx → `CareRequestFailed`.

## 4. Application + controller (TDD, fake repo)
- [ ] `application/care_items.dart`: thin list/create/update/delete.
- [ ] `presentation/care_items_controller.dart` (ChangeNotifier): loading/loaded(list)/error/reauth;
      reload after each mutation; a failure keeps the list + typed error; re-entrancy guard; 401 →
      reauth. Unit-tested with a fake repo.

## 5. Presentation: screen + form (widget tests)
- [ ] `presentation/care_items_screen.dart`: list grouped by category (localized headers/icons),
      each row (title, note snippet, schedule summary time·weekdays[每天]·every-N-weeks·range,
      medication stock), FAB → form, tap → edit, delete (confirm), empty-state guide, reauth exit.
- [ ] `presentation/care_item_form.dart`: category selector; title TextField; multi-line note;
      add/remove schedules (each: showTimePicker 24h, 7 weekday chips empty=每天, week-interval
      stepper, anchor date shown when interval>1, optional end date, nag-interval dropdown
      0/5/10/15/30); **medication-only** dose/stock/stock_alert + per-schedule dose_quantity;
      submit gated on title non-empty + ≥1 schedule each with a time; dates emitted YYYY-MM-DD.
      Widget tests: grouped/empty; category toggles medication fields; add/remove schedule; empty
      weekdays→每天; submit gating; delete confirm; reauth.

## 6. Wiring + entry + i18n
- [ ] go_router: nested DI-built route to `CareItemsScreen`; `_MoreBody` "提醒 / 照護" entry.
- [ ] `main.dart`: construct `HttpCareRepository(baseUrl: apiBaseUrl, client)` + controller; idToken
      the same way the existing authed flows do.
- [ ] i18n: en + zh-Hant (+ zh) for all new copy (categories, weekdays, nag intervals, hints); run
      `flutter gen-l10n` and commit `lib/l10n/generated/*`.

## 7. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.
