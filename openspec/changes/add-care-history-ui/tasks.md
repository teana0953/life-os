## 1. domain

- [x] 1.1 (red) 單元測試:`careDayState(day)` 四態(noSchedule slots 空、full done==slots、
      partial 0<done<slots、missed done==0 且非空;**done 只算 CareTodayStatus.done**,
      skipped/missed/pending/overdue 皆非 done);`careHistorySummary(days)`
      (adherenceRate=Σdone/Σslots、空→null、daysWithDose、missedCount、totalScheduled;
      **不做 clamp**——done⊆slots 恆 ≤1);`isEmpty` 判定 = 每天 slots 皆空(days 本身恆非空)。
- [x] 1.2 (green) `lib/contexts/notifications/domain/care_history.dart`:`CareHistoryDay`、
      兩個純衍生函式、`CareHistoryRepository` port(`getRange` + `editSlot`)。**重用**既有
      `CareTodaySlot`/`CareTodayStatus`/`careTodayStatusFromWire` 與 care typed errors,不重定義。

## 2. infrastructure + application

- [x] 2.1 (red) `HttpCareHistoryRepository` 測試(mock client):GET
      `/api/care/range?from=&to=` URL/bearer/解析 `{from,to,days:[{date,items:[...]}]}`;
      PUT `/api/care/log` snake body(care_schedule_id/local_date/time_of_day/status);
      401→CareReauthRequired、非2xx→CareRequestFailed。
- [x] 2.2 (green) `HttpCareHistoryRepository`(mirror `http_care_today_repository.dart`)+
      `get_care_history.dart` / `edit_care_slot.dart` 薄 use case。

## 3. controller

- [x] 3.1 (red) `CareHistoryController` 測試:load→loaded/error/reauth;`edit` 成功→**安靜重載**
      (status 全程 loaded、`editing` flag)、失敗→保留 days + `editError`、401→reauth;
      **FIX 2**:PUT 成功但後續重載失敗(非 401)→仍保留清單 + editError,不掉 error 態;
      **換期間不整頁閃白**(已有資料時 reload 保留舊內容);re-entrancy guard。
- [x] 3.2 (green) `CareHistoryController`(比照 `CareTodayController` 的 marking 機制)。

## 4. screen

- [x] 4.1 (red) `CareHistoryScreen` widget test:清單/圖表 toggle;清單逐日分組 + slot tile
      顯示時間(`slot.timeOfDay`)/標題/狀態、**無 slot 的日子不出現在清單**;圖表 headline +
      heatmap **格數 = span 天數(含今天)**、狀態色、legend;7/30/90 切換觸發 reload
      (**from = today-(span-1)、to = today**,經 `dayString`);點 tile → bottom sheet →
      選完成/略過觸發 edit;空(每天皆無 slot)/loading/reauth。
- [x] 4.2 (green) `CareHistoryScreen`(AppBar SegmentedButton 清單/圖表 + 期間 SegmentedButton;
      逐日卡 + tile;`GridView.builder` heatmap + legend;bottom sheet 編輯;theme/LedgeCard/pastel,
      無硬編碼顏色/字串)。

## 5. 入口 + DI + i18n + Gate

- [ ] 5.1 (green) `app.dart` 加 `/care-history` route;`care_items_screen` 與 `care_today_screen`
      AppBar 各加「紀錄」icon → push;`main.dart` 組 DI(repo/use case/controller)。
      **連帶**:`App` 建構子新增必填 controller 會打斷 `test/app_test.dart` 的共用 pump helper
      (每個 controller 都有預設)——補一個 optional 參數 + `_FakeCareHistoryRepository` 預設,
      維持既有測試綠。
- [x] 5.2 (green) i18n(en/zh-Hant/zh,各附 description)+ `flutter gen-l10n`:頁標題、清單/圖表、
      達成率/有服藥天數/漏服、legend(完成/部分/未完成)、狀態字、編輯 sheet、空狀態、入口 tooltip。
      **heatmap 日狀態的 legend 用獨立新 key**(勿共用 slot 狀態的 `careTodayStatusMissed`——
      日層「未完成」含全部略過的日子,與 slot 層語意/數字不同)。
- [ ] 5.3 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠。
