# Design — Care reminders management UI

## Context & scope

Slice D of the CareFlow-aligned remodel: the frontend that manages the generic care
reminders whose backend (Slice A) is live. Replaces the removed Slice-2b medication UI and
restores + generalizes create/list/edit/delete. Today checklist (C), notification
actions/snooze (B), and low-stock UI (E) are later slices.

## Backend contract (confirmed from src/adapters/http/routes/care.ts — match exactly)

- `GET /api/care/items` → **`{ items: [ item ] }`** (envelope). `POST /api/care/items` and
  `PATCH /api/care/items/:id` → a **bare `item`** (or 404 `{error:"not_found"}` on PATCH).
  `DELETE /api/care/items/:id` → `{ deleted: bool }`. `POST /api/care/log`
  `{ care_schedule_id, local_date, time_of_day, status }` → a bare log.
- `item` = `{ id, category, title, note, dose, stock, stock_alert, schedules: [schedule] }`.
- `schedule` = `{ id, time_of_day 'HH:mm', repeat_days int[], week_interval, start_date
  'YYYY-MM-DD', end_date, dose_quantity, nag_interval_minutes, enabled }`.
- Create/update body mirror these snake_case fields; a schedule with an `id` is upserted by
  id (preserves logs), one without is inserted. Dates are `YYYY-MM-DD` (no time component).

## Architecture

`lib/contexts/notifications/` — remove the medication_* files, add:
```
domain/care_item.dart        # CareItem + CareSchedule values + CareItemRepository port + typed errors
application/care_items.dart  # thin list/create/update/delete use cases
infrastructure/http_care_repository.dart
presentation/care_items_controller.dart
presentation/care_items_screen.dart      # grouped list + FAB + empty state
presentation/care_item_form.dart         # add/edit
```
go_router route in app.dart (nested, DI-built), a `_MoreBody` "提醒 / 照護" entry, DI in main.dart.

## Key decisions

- **D1 — Repository parses the `{items:[...]}` envelope; create/update parse a bare item.**
  (The Slice-2b blocking bug was parsing a bare array — avoided here by matching the confirmed
  shapes above.) 401 → `CareReauthRequired`, non-2xx → `CareRequestFailed`; presentation maps
  typed errors to localized copy.

- **D2 — Category drives only the ITEM-level medication fields.** The **item-level**
  `dose`/`stock`/`stock_alert` render and are sent **only when category = medication** (they are
  optional on the backend). Every OTHER schedule/item field is category-independent. **Critical
  (Slice-2b trap): `dose_quantity` is REQUIRED on every schedule by the backend regardless of
  category** — always send it (default `1`); for non-medication its editor is hidden but the value
  `1` is still serialized. Only omit the item-level dose/stock/stock_alert for non-medication.
  The category **selector maps a localized label → the wire enum string** (`medication`/`rehab`/
  `radiotherapy_care`/`custom`) — send the enum, never the label (a localized label would 400).

- **D3 — Empty weekdays = every day; every schedule always sends a date-only `start_date`.**
  Weekday chips empty → send `[]` (backend treats empty as every day) and render "每天". **`start_date`
  is REQUIRED on every schedule by the backend** — always send it as `YYYY-MM-DD` (default today when
  the anchor field is hidden at interval==1); `end_date` is optional. Dates go through the shared day
  formatter as `YYYY-MM-DD` (never `toIso8601String`). Since PATCH replaces the whole schedules array,
  this holds on edit too.

- **D4 — Controller reloads after each mutation** (create/update/delete → re-`list`); a mutation
  failure keeps the existing list + surfaces the typed error; re-entrancy guard; 401 → reauth.

- **D5 — Existing schedule ids round-trip.** On edit, each schedule keeps its `id` in the PATCH
  body so the backend upserts by id (preserving adherence history); new schedules omit the id.

## UI/UX 設計

- **使用者路徑**:更多 → 提醒/照護 → 依分類分組的清單。空清單顯示引導。FAB 新增 → 選分類 →
  填標題/說明/排程 → 儲存 → 回清單。點一筆編輯;可刪除(確認)。例外:401 → 全螢幕重新登入;
  其他失敗 → 可行動錯誤 + 保留清單;表單未過檢查 → 儲存停用 + 提示缺什麼。
- **介面與一致性**:清單卡片/分組標題、`FilledButton`(儲存)、`OutlinedButton`/`TextButton`
  (取消/新增排程)、文字輸入對話用 **bottom sheet 非 AlertDialog**(手機鍵盤 gotcha);顏色/文字只
  從 Theme;字串全走 ARB。分類/星期/nag 間隔用人性化文案(「每天」「每 2 週」「只提醒一次」)。
- **狀態設計**:loading 指示;loaded 顯示分組清單或空狀態;mutation 進行防重入;錯誤/reauth 明確;
  分類切換即時顯示/隱藏用藥欄位;排程可增減、interval==1 隱藏起始日。
- **可及性/理解性**:排程摘要一眼看懂(時間·每天/週幾·每N週·期間);note 顯示在編輯與清單摘要;
  每個錯誤說明發生什麼 + 下一步。

## Testing

- **`HttpCareRepository` (unit, mock http.Client)**: list parses the `{items:[...]}` envelope
  incl. nested schedules; create/update send snake_case + **`start_date`/`end_date` as
  `YYYY-MM-DD`** (asserted by regex even from a DateTime-with-time), **always serialize
  `dose_quantity` and `start_date` on EVERY schedule including a non-medication one** (the two
  backend-required-field traps), round-trip existing schedule ids, send the **category enum**
  (not a label), and parse the bare returned item; delete; 401 → `CareReauthRequired`; non-2xx →
  `CareRequestFailed`. (logSlot deferred to Slice C — no caller here.)
- **`CareItemsController` (unit, fake repo)**: load → grouped/empty; create/update/delete reload;
  a failure keeps the list + typed error; 401 → reauth; re-entrancy guarded.
- **Screen + form (widget, l10nTestApp, fake controller)**: grouped list + empty state; a row's
  schedule summary; FAB opens the form; **category=medication shows dose/stock, non-medication
  hides them**; add/remove a schedule; empty weekdays render 每天; submit gated on title + ≥1
  schedule-with-a-time; delete confirm; reauth full-screen exit.
- **Out of scope for flutter test** (on-device): real push delivery of a created reminder.
