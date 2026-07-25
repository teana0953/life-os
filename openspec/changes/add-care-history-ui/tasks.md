## 1. domain

- [ ] 1.1 (red) 單元測試:`careDayState(day)` 四態(noSchedule slots 空、full done==slots、
      partial 0<done<slots、missed done==0 且非空;**done 只算 CareTodayStatus.done**,
      skipped/missed/pending/overdue 皆非 done);`careHistorySummary(days)`
      (adherenceRate=Σdone/Σslots、空→null、daysWithDose、missedCount、totalScheduled)。
- [ ] 1.2 (green) `lib/contexts/notifications/domain/care_history.dart`:`CareHistoryDay`、
      兩個純衍生函式、`CareHistoryRepository` port(`getRange` + `editSlot`)。**重用**既有
      `CareTodaySlot`/`CareTodayStatus`/`careTodayStatusFromWire` 與 care typed errors,不重定義。

## 2. infrastructure + application

- [ ] 2.1 (red) `HttpCareHistoryRepository` 測試(mock client):GET
      `/api/care/range?from=&to=` URL/bearer/解析 `{from,to,days:[{date,items:[...]}]}`;
      PUT `/api/care/log` snake body(care_schedule_id/local_date/time_of_day/status);
      401→CareReauthRequired、非2xx→CareRequestFailed。
- [ ] 2.2 (green) `HttpCareHistoryRepository`(mirror `http_care_today_repository.dart`)+
      `get_care_history.dart` / `edit_care_slot.dart` 薄 use case。

## 3. controller

- [ ] 3.1 (red) `CareHistoryController` 測試:load→loaded/error/reauth;`edit` 成功→**安靜重載**
      (status 全程 loaded、`editing` flag)、失敗→保留 days + `editError`、401→reauth;
      re-entrancy guard。
- [ ] 3.2 (green) `CareHistoryController`(比照 `CareTodayController` 的 marking 機制)。

## 4. screen

- [ ] 4.1 (red) `CareHistoryScreen` widget test:清單/圖表 toggle;清單逐日分組 + slot tile
      顯示時間/標題/狀態;圖表 headline + heatmap 格數/狀態色 + legend;7/30/90 切換觸發 reload;
      點 tile → bottom sheet → 選完成/略過觸發 edit;空/loading/reauth。
- [ ] 4.2 (green) `CareHistoryScreen`(AppBar SegmentedButton 清單/圖表 + 期間 SegmentedButton;
      逐日卡 + tile;`GridView.builder` heatmap + legend;bottom sheet 編輯;theme/LedgeCard/pastel,
      無硬編碼顏色/字串)。

## 5. 入口 + DI + i18n + Gate

- [ ] 5.1 (green) `app.dart` 加 `/care-history` route;`care_items_screen` 與 `care_today_screen`
      AppBar 各加「紀錄」icon → push;`main.dart` 組 DI(repo/use case/controller)。
- [ ] 5.2 (green) i18n(en/zh-Hant/zh,各附 description)+ `flutter gen-l10n`:頁標題、清單/圖表、
      達成率/有服藥天數/漏服、legend(完成/部分/未完成)、狀態字、編輯 sheet、空狀態、入口 tooltip。
- [ ] 5.3 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠。
