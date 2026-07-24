# Tasks

## 1. Domain
- [ ] `domain/care_today.dart`: `CareTodayStatus` enum (pending/overdue/done/skipped/missed);
      `CareTodaySlot` value (careItemId, careScheduleId, category **[reuse the existing Slice-D CareCategory type]**, title, note?, dose?, timeOfDay,
      localDate, status, doneTime?, doseQuantity; value equality); `CareToday` ({ date,
      slots }); `CareTodayRepository` port (`getToday()`, `logSlot({careScheduleId, localDate,
      timeOfDay, status})`); typed errors `CareReauthRequired`, `CareRequestFailed` (reuse the
      existing care ones if present).

## 2. Infrastructure (TDD, mock http.Client)
- [ ] `infrastructure/http_care_today_repository.dart` (authed, snake_case). Tests: `getToday`
      parses the **`{date, items:[...]}` envelope** and each slot field incl. status enum + nullable
      note/dose/done_time; `logSlot` POSTs `{care_schedule_id, local_date, time_of_day, status}`;
      401 → `CareReauthRequired`; non-2xx → `CareRequestFailed`.

## 3. Application + derivation (TDD)
- [ ] `application/care_today.dart`: thin `getToday` / `markDone` / `markSkipped`.
- [ ] Pure focus/group derivation (in the controller or a helper): focus = earliest-overdue else
      earliest-pending (by time_of_day); groups Overdue/Later(pending)/Done(done|skipped|missed);
      all-done when none pending/overdue. Unit-tested.

## 4. Presentation: controller (TDD, fake repo)
- [ ] `presentation/care_today_controller.dart` (ChangeNotifier): loading/loaded({date,slots})/
      error/reauth; `load`, `markDone`, `markSkipped` reload after the log call **as a QUIET reload (keeps the list rendered, a `marking` flag / per-row spinner — never the top-level loading state, D2)**; a mark failure keeps
      the list + typed error; re-entrancy guard; 401 → reauth. Unit-tested.

## 5. Presentation: screen (widget tests, l10nTestApp, fake controller)
- [ ] `presentation/care_today_screen.dart`: focus card (most-urgent slot, Done/Skip), Overdue /
      Later / collapsible Done groups (inline Done/Skip on pending/overdue; done-time on done; struck
      skipped/missed), all-done celebration (existing mascot), empty (no schedules) guide, loading /
      error / reauth (full-screen), date header. Theme colors; ARB strings. Widget tests: focus picks
      most-urgent; groups render; inline Done triggers controller + row moves to Done after reload **with the list staying visible (no full-screen loading flash)**;
      celebration when none pending/overdue; empty guide; reauth exit; a failed mark shows a SnackBar
      and keeps the list.

## 6. Wiring + entry + i18n
- [ ] go_router: nested DI-built route to `CareTodayScreen`; `_MoreBody` "今日照護 / Today" entry
      (distinct from the Slice-D "提醒 / 照護" manage entry).
- [ ] `main.dart`: construct `HttpCareTodayRepository(baseUrl: apiBaseUrl, client)` + controller;
      idToken the same way the existing authed flows do.
- [ ] i18n: en + zh-Hant (+ zh) for all new copy (status labels, overdue/later/done, all-done,
      done/skip, empty); run `flutter gen-l10n` and commit `lib/l10n/generated/*`.

## 7. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.
