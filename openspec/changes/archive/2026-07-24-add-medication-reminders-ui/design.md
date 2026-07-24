# Design — Medication reminders UI

## Context & scope

Frontend (Slice 2b) for the medication reminders whose backend shipped in Slice 2.
Manage-reminders UI (list/add/edit/delete + enable toggle) + a timezone setter, against
the live endpoints. Rehab/glucose/missed-meal UIs are later slices. This is what makes
the reminders pipeline usable and lets Cron delivery be verified end-to-end on device.

## Architecture

Grows the existing `lib/contexts/notifications/` context (already holds push
subscribe/settings), mirroring the repo's Clean Arch:

```
domain/
  medication_reminder.dart          # value object + MedicationReminderRepository port + typed errors + timezone port
application/
  medication_reminders.dart         # thin list/create/update/delete use cases (+ setTimezone)
infrastructure/
  http_medication_reminder_repository.dart   # mirrors HttpPushRepository (Bearer, snake_case, typed errors)
presentation/
  medication_reminders_controller.dart
  medication_reminders_screen.dart          # list + FAB + empty state
  medication_reminder_form.dart             # add/edit form (a screen or bottom sheet)
```

Route in `app.dart` (nested, DI-built — per lifeos-web-nav-go-router), a `_MoreBody`
entry in `health_scaffold.dart`, DI in `main.dart`. idToken obtained the same way
`HttpPushRepository`/the reminder settings flow already does.

## Key decisions

- **D1 — Repository + typed errors mirror `HttpPushRepository`.** Same auth/snake_case/
  status-mapping shape (401 → `ReminderReauthRequired`, non-2xx → `ReminderRequestFailed`).
  Presentation maps typed errors to localized copy; domain/infra hold no strings.

- **D2 — Controller reloads after every mutation.** create/update/delete/toggle call the
  endpoint then re-`list()`, so the screen always reflects server truth (avoids optimistic
  divergence). A re-entrancy guard prevents overlapping mutations. Reauth is surfaced via
  the shared full-screen reauth affordance (as the push settings screen does).

- **D3 — Enable toggle PATCHes just `enabled`.** Toggling a row's switch sends a partial
  update `{ enabled }` (the backend PATCH treats omitted fields as no-change), then reloads.

- **D4 — Form validation is client-basic, server-authoritative.** The form blocks submit
  until label non-empty, ≥1 time, ≥1 weekday; deeper validation (HH:mm, ranges, date) is
  the backend's — a 400 surfaces as a localized error, not a crash. Times use
  `showTimePicker` rendered as 24h `HH:mm`; weekdays are 7 toggle chips (Sun..Sat → 0..6);
  week interval a small stepper/dropdown (1=weekly…); anchor via `showDatePicker` (default
  today). Anchor only matters for week_interval>1; the form still stores today by default.

- **D5 — Timezone setter (PUT-only, no GET).** The backend exposes only
  `PUT /api/user/timezone` (no read endpoint), so there is **no `getTimezone`** port. The
  screen displays a locally-remembered value — default `Asia/Taipei`, updated to whatever
  the user last set and persisted via `shared_preferences` — and PUTs on change; validation
  is the backend's (400 → localized error). A short line states reminders use this timezone.
  (The display is the last-set/default value, not a server read — acceptable since the user
  is the one who sets it.)

- **D4b — `anchor_date` is serialized date-only.** `showDatePicker` yields a Dart
  `DateTime`; the repo MUST send `anchor_date` as `YYYY-MM-DD` (no time component — a naive
  `toIso8601String()` would 400). Use the shared day-format helper (`shared/date/…` if
  present, else format the three date fields). A repo test asserts the body carries `YYYY-MM-DD`.

## UI/UX 設計

- **使用者路徑**:更多 → 用藥提醒 → 清單。空清單顯示引導(說明 + 新增鈕)。點 FAB「新增」→
  表單填 label/時間/星期/週間隔/起始日 → 儲存 → 回清單看到新項目。點一筆 → 編輯同表單 → 儲存。
  每筆右側開關可即時啟用/停用。刪除需確認。頂部或設定區可改時區。例外:401 → 全螢幕重新登入
  出口;其他請求失敗 → 可行動的錯誤訊息 + 重試;表單未過基本檢查 → 儲存鈕停用或提示。
- **介面與一致性**:清單用既有卡片/ListTile 樣式;主要動作(儲存)用 `FilledButton`,次要
  (取消/新增時間)用 `OutlinedButton`/`TextButton`;顏色/文字只從 Theme;所有字串走 ARB。
  與 更多 頁既有項目(提醒/通知、匯入)一致。
- **狀態設計**:loading 顯示指示器;loaded 顯示清單或空狀態;mutation 進行中防重入(鈕 loading/
  停用);錯誤/reauth 有明確呈現。開關切換失敗要回復原狀並提示。
- **可及性/理解性**:時間以 24h HH:mm 清楚顯示;星期用本地化短名;「依你的時區」一句說明;
  每個錯誤都說明發生什麼 + 下一步。

## Testing

- **`HttpMedicationReminderRepository` (unit, mock `http.Client`)**: list parses; create/
  update/delete send correct snake_case bodies + verbs; 401 → `ReminderReauthRequired`;
  non-2xx → `ReminderRequestFailed`; timezone PUT.
- **`MedicationRemindersController` (unit, fake repo)**: load → loaded/empty; create/
  update/delete/toggle reload; a mutation failure surfaces the typed error without losing
  the list; 401 → reauth; re-entrancy guarded.
- **Screen + form (widget, `l10nTestApp`, fake controller)**: empty-state guide; a list
  row renders label/times/weekdays + a working enable switch; FAB opens the form; the form
  blocks submit until valid (label/≥1 time/≥1 weekday) and calls create/update on submit;
  delete confirms; reauth shows the full-screen exit.
- **Out of scope for `flutter test`** (on-device): the actual Cron delivery of a created
  reminder — the Slice-2 end-to-end check.
