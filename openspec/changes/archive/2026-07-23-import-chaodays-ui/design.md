# Design — chaodays 匯入 Slice 4:前端 UI

## Why

「從 chaodays 匯入」最後一片:前端 UI。後端四個端點已就緒
(`POST /api/import/chaodays/{weight,diet,water,bowel}`)。使用者輸入 chaodays 帳密 + 選日期範圍,
一次匯入全部四類,顯示各類結果。

## 使用者決定(鎖定)

- **一次全匯**:點一下依序匯入四類(體重體脂 / 飲食血糖 / 飲水 / 排便),顯示各類「匯入 X / 跳過 Y」。
- **入口**:健康模組「更多」分頁。
- **安全**:chaodays 帳密不儲存(只該次匯入用);密碼欄遮蔽。

## 架構(照 life-os house style,新 context `lib/contexts/import/`)

- **domain**:
  - `ImportRepository` port:四個方法 `importWeight/importDiet/importWater/importBowel`
    (各:`idToken, chaodaysUid, chaodaysPassword, startDate, endDate`)→ `ChaodaysImportSummary`。
  - `ChaodaysImportSummary { imported, skipped, glucoseImported? }`(飲食多帶 glucoseImported;
    其餘 imported/skipped)。
  - typed exceptions(仿 `bowel_exceptions.dart`,infrastructure 只丟型別不丟文字):
    `ImportFetchFailure`(網路/非預期)、`ImportReauthenticationRequired`(lifeos 401)、
    `ImportChaodaysAuthFailed`(後端 400 `chaodays_auth_failed`=chaodays 帳密錯)、
    `ImportChaodaysUnavailable`(後端 502 `chaodays_unavailable`)。
- **infrastructure** `HttpImportRepository`(仿 `http_bowel_repository.dart`):`baseUrl`+`http.Client`
  注入;`_headers(idToken)` 帶 `Authorization: Bearer`;四個 POST 各打對應端點,body
  `{chaodays_uid, chaodays_password, start_date, end_date}`;依 statusCode map typed exception
  (401→Reauth、400 且 body error==chaodays_auth_failed→AuthFailed、502→Unavailable、其餘→FetchFailure);
  解析 summary。
- **presentation**:
  - `ChaodaysImportController extends ChangeNotifier`(仿 `bowel_controller`):
    整體狀態 `enum ImportStatus { idle, importing, done, authFailed, unavailable, needsReauth }`
    + 每類狀態 `Map<ImportType, TypeState>`,`TypeState ∈ { notAttempted, importing, success(summary),
    failed }`。方法 `import(idToken, uid, password, startDate, endDate)`:四類依序跑,逐類 `notifyListeners`:
    - 某類成功 → 該類 success(summary),續下一類。
    - **chaodays 帳密錯**(所有類共用同帳密,必全錯)→ status=authFailed,**中止**,剩餘類維持
      `notAttempted`(不標紅 failed,避免誤導),UI 顯示一次「帳密錯」總訊息。
    - **lifeos 401** → status=needsReauth,中止,提示重新登入。
    - **上游 chaodays 連不上** → status=unavailable,該類 failed;中止剩餘為 notAttempted(同一 chaodays 多半皆連不上)。
    - 全部跑完 → status=done。
    - **憑證不落地**:controller/screen **不注入任何儲存依賴**(無 SharedPreferences),帳密只存在
      表單 `TextEditingController` 記憶體、傳給 use case 後即不再保留——「密碼不儲存」以此結構性保證(可驗)。
  - `ChaodaysImportScreen`(全螢幕,AppBar 有返回):
    - 表單:chaodays 帳號 `TextField`(username)、密碼 `TextField(obscureText, autofillHints:password)`
      (仿 login_screen);起訖日期各一個 `showDatePicker`(仿 `menstrual_screen` 雙 picker,
      `lastDate=today`、endDate 不早於 start);`dayString` 轉 `YYYY-MM-DD`。
    - 匯入 `FilledButton`:帳號/密碼/起訖齊全且非 importing 才 enabled;importing 時 child 放小 spinner。
    - 結果區:四類各一列,顯示 pending / 匯入中(spinner)/ 成功「體重 匯入 X 跳過 Y」/ 失敗(型別化訊息)。
    - 錯誤文字本地化(帳密錯、chaodays 無法連線、需重新登入)——**錯誤文案在 presentation** 由 controller 的
      typed error map(house rule)。
  - **入口**:`health_scaffold.dart` 的 `_MoreBody` 加一張 `LedgeCard>ListTile`(icon `Icons.cloud_download`
    + 新 l10n),`onTap: onOpenImport`;`onOpenImport` 由 `app.dart` 注入 `() => context.push('/import/chaodays')`
    (比照既有 `onOpenSettings`)。
- **route/DI**:`app.dart` `_buildRouter` 加 top-level `GoRoute('/import/chaodays', builder: DI 建
  `ChaodaysImportScreen(controller, authRepository)`)(不放 extra,web 重整可重建);`main.dart` 建
  `HttpImportRepository`+use cases+`ChaodaysImportController` 傳進 `App`;`App` 加對應建構參數。

## UI/UX 設計

- **入口可見且一步可達**:健康「更多」分頁一張明確的匯入卡片(icon + 標題),tap 導到匯入頁。
- **流程清楚**:一頁完成——填帳密、選起訖、按「開始匯入」;匯入中按鈕轉 loading、四類結果即時更新。
- **狀態回饋**:每類三態視覺(等待 / 進行中 spinner / 完成打勾+數字 / 失敗+訊息);整體完成有明確收尾。
- **錯誤可懂可復原**:chaodays 帳密錯 → 明確「chaodays 帳號或密碼錯誤」(非通用錯誤),使用者可改後重試;
  chaodays 連不上 → 「暫時無法連線,請稍後再試」;lifeos 401 → 提示重新登入。
- **安全感**:密碼遮蔽;頁面說明「帳密僅用於這次匯入,不會儲存」。
- **無障礙/設計系統**:顏色/形狀走 `Theme`;元件用 `LedgeCard`/`FilledButton`/`TextField`;RWD 沿用既有
  `ConstrainedBox(maxWidth)` 置中。

## 測試

- **controller unit**(fake `ImportRepository`:可設四類各自成功/丟型別錯/丟 reauth):依序匯入、逐類狀態、
  帳密錯中止並標 failed、lifeos 401 → needsReauth、summary 顯示數字。
- **screen widget**(`l10nTestApp` + fake controller/repo):表單欄位在、按鈕在齊全前 disabled、
  填齊+tap → 呼叫 import、匯入中 loading、成功顯示各類數字、帳密錯顯示對應本地化訊息。
- **入口導航**(`l10nRouterTestApp`):更多分頁的匯入 tile tap → 導到 `/import/chaodays`。
- gate = `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`。

## 範圍

前端 UI,一次全匯四類。不改後端。i18n 新字串走 en + zh_Hant + zh + `flutter gen-l10n`(產出檔 commit)。
