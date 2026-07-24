# Design — Today care checklist UI

## Context & scope

Slice C2: the CareFlow Today checklist, consuming Slice-C1 `GET /api/care/today` and marking
slots done/skipped via the existing `POST /api/care/log`. Completes the loop — the first
in-app way to stop a nag. Notification-actions/snooze (B), low-stock (E), and deep home
integration are later.

## Backend contract (confirmed)

- `GET /api/care/today` → `{ date: 'YYYY-MM-DD', items: [ slot ] }`. slot = `{ care_item_id,
  care_schedule_id, category, title, note, dose, time_of_day, local_date, status, done_time,
  dose_quantity }` (snake_case). `POST /api/care/log { care_schedule_id, local_date,
  time_of_day, status: done|skipped }` → bare log. 401 → reauth, non-2xx → failed.

## Architecture

`lib/contexts/notifications/`: domain/care_today.dart (value + port + typed errors),
application/care_today.dart (getToday/markDone/markSkipped), infrastructure/
http_care_today_repository.dart, presentation/care_today_controller.dart + care_today_screen.dart.
go_router route + `_MoreBody` "今日照護" entry + main.dart DI.

## Key decisions

- **D1 — Envelope parse; typed errors.** `getToday` parses `{date, items:[...]}` (not a bare
  array — the Slice-2b trap class). 401 → `CareReauthRequired`, non-2xx → `CareRequestFailed`.

- **D2 — Mark then QUIET reload (server truth, no flicker).** `markDone`/`markSkipped` POST the log
  then re-`getToday` so the slot's status reflects the server (and a nag stops). The mark-triggered
  reload MUST NOT drop the screen to the top-level `loading` state — it keeps the current list
  rendered and shows only a per-action/row spinner via the re-entrancy `marking` flag, so the row
  smoothly moves to Done without the whole focus-card+groups flashing/jumping. Only the INITIAL
  `load()` uses the full-screen loading. A re-entrancy guard blocks overlapping marks; a mark failure
  keeps the current list + surfaces the typed error (SnackBar). The widget test for "row moves to
  Done" asserts the list stays visible throughout the reload.

- **D2b — Reuse the existing care domain types.** `CareTodaySlot.category` reuses the **existing
  Slice-D `CareCategory`** type (do not redefine an enum/parser); typed errors reuse the existing
  `CareReauthRequired`/`CareRequestFailed`.

- **D3 — Focus + groups derived in the controller/screen from the slot list.** Focus slot =
  earliest-`overdue` by `time_of_day`, else earliest-`pending`; if none pending/overdue → the
  celebration card. Groups: Overdue (status=overdue), Later (pending), Done (done/skipped/missed,
  collapsible, shown with count). Ordering within a group by `time_of_day`. All pure functions of
  the slot list (testable).

- **D4 — Inline actions only on actionable slots.** Done/Skip appear on `pending`/`overdue` rows
  and on the focus card; `done` shows its done time; `skipped`/`missed` are struck-through with no
  actions. Skip needs no confirm (it's reversible-by-re-marking is out of scope; a skip is a
  deliberate tap).

- **D5 — Distinct entry from management.** "今日照護 / Today" (this screen) is a separate 更多
  entry from Slice-D's "提醒 / 照護" (manage). Both under go_router nested DI-built routes.

## UI/UX 設計

- **使用者路徑**:更多 → 今日照護 → 焦點卡(最緊急)+ 逾期/稍後/已完成 分組。點焦點卡或列的
  「完成」→ 該項變已完成、從逾期/稍後移到已完成、nag 停;「略過」類似。全部處理完 → 慶祝卡。
  例外:今天無排程 → 空狀態引導(可去「提醒/照護」新增);401 → 全螢幕重新登入;標記失敗 → 可行動
  錯誤 + 保留清單。
- **介面與一致性**:焦點卡用既有 LedgeCard/mascot 慶祝樣式;「完成」FilledButton、「略過」
  OutlinedButton/TextButton;狀態用顏色/圖示(逾期=強調色、pending=一般、done=打勾、skipped/missed=
  弱化刪除線);顏色/文字只從 Theme;字串全走 ARB;分組標題與計數清楚。
- **狀態設計**:loading 指示;loaded 顯示焦點+分組或(無 pending/overdue)慶祝或(無排程)空狀態;
  mark 進行防重入(按鈕 loading/停用);錯誤/reauth 明確;mark 失敗要能看得到(SnackBar + 保留清單)。
- **可及性/理解性**:每列一眼看懂(title·time·狀態);「逾期/接下來」標籤清楚;完成後有即時回饋;
  空/慶祝狀態有正向引導文案。

## Testing

- **`HttpCareTodayRepository` (unit, mock http.Client)**: `getToday` parses the `{date, items}`
  envelope incl. all slot fields + status enum; `logSlot` posts `{care_schedule_id, local_date,
  time_of_day, status}`; 401 → `CareReauthRequired`; non-2xx → `CareRequestFailed`.
- **`CareTodayController` (unit, fake repo)**: load → loaded/empty; markDone/markSkipped reload;
  a mark failure keeps the list + typed error; 401 → reauth; re-entrancy guarded.
- **Focus/group derivation (unit)**: earliest-overdue-else-earliest-pending focus; group membership
  + ordering; all-done when none pending/overdue.
- **Screen (widget, l10nTestApp, fake controller)**: focus card shows the most-urgent slot with
  Done/Skip; groups render; an inline Done triggers the controller + (after reload) the row moves to
  Done; celebration when nothing pending/overdue; empty (no schedules) guide; loading/error/reauth.
- **Out of scope for flutter test** (on-device): the real push → open Today → Done → nag stops.
