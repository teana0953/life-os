# Tasks

## 1. 共用 month component + 重構(先做)

- [x] 1.1 `lib/shared/widgets/month_nav_header.dart`:`MonthNavHeader` **啞展示元件**(`monthLabel`、`onPrevious()`、`onNext()`、`keyPrefix`;不依賴 finance domain,前後月運算由 caller 做;key `<prefix>-previous/label/next`)。測試:點箭頭呼對應 callback、keyPrefix 隔離。
- [x] 1.2 重構 `finance_overview_tab.dart` 的 private `_MonthNav` → `MonthNavHeader(keyPrefix: 'finance-month')`;caller 用 finance_month 的 previousMonth/nextMonth 算好傳進 onChanged。保留既有 `finance-month-*` key + label 文字。跑既有記帳測試確認不破。

## 2. Domain + application + infrastructure

- [x] 2.1 `domain/`:`NetWorthAccount`/`NetWorthSnapshot`/`MonthlyNetWorth`(accounts+totals+net+prev+growth,growth/prev 可 null)/`NetWorthTrendPoint`;`FinanceRepository` port 加 listAccounts/createAccount/updateAccount/upsertSnapshot/getMonthlyNetWorth/getNetWorthTrend。
- [x] 2.2 `application/` networth use cases(thin,照既有 finance use case 慣例):ListNetWorthAccounts/CreateNetWorthAccount/UpdateNetWorthAccount/UpsertSnapshot/GetMonthlyNetWorth/GetNetWorthTrend——controller 呼 use case 不直呼 port。
- [x] 2.3 `HttpFinanceRepository` networth 方法(契約照 design.md;status→typed exception)。測試:mock client、body 形狀(含 growth null)、401/404/400。

## 3. Controller(重要邏輯,測試必須覆蓋)

- [ ] 3.1 `NetWorthController`:selectedMonth、`load(month)`(accounts+monthly+trend 同批 Future.wait;trend 視窗=selectedMonth 往前 11 個月到 selectedMonth 近 12 月;月份 gate 同月才落地;切月同步清除;**淨值 selectedMonth 獨立於記帳,不連動**;401→needsReauth;首個 await 前不 notify)、`saveSnapshot` 後 reload、科目 create/update 後 reload。測試:load 落地、競態(舊月不覆蓋)、切月清除、saveSnapshot reload、科目 CRUD reload、401、非法輸入不送。

## 4. Presentation

- [ ] 4.1 `FinanceScaffold` 底部 nav 加第三格「淨值」(總覽/明細/淨值);`Key('networth-tab')`。
- [ ] 4.2 `NetWorthTab`:MonthNavHeader(keyPrefix `networth-month`)、淨值大數字卡(`networth-net-value`)+ 月成長率(`networth-growth`,箭頭方向+百分比,null→只顯淨值)、資產/負債分組科目列(`account-row-<id>`)、趨勢 fl_chart LineChart(<2 點顯示不足提示,照 vitals trend 慣例)、科目管理鈕(`account-manage-button`)、空月引導、loading/error+retry/reauth。
- [ ] 4.3 `SnapshotInputSheet`:點科目列開(viewInsets padding),金額數字鍵盤、**0 合法(≥0)、空=未記錄不送、只有負數/非數字才 errorText+存檔 disabled**(不沿用 budget 的 ≤0 非法),不靜默,存=upsert;`Key('snapshot-field')`。
- [ ] 4.4 科目管理(sheet 或區塊):新增(kind asset/liability + name)、改名/排序/封存;archived 不在市值列表、管理區可見可復原。
- [ ] 4.5 widget tests:淨值卡數字+成長率三態(漲/跌/null)、資產負債分組、科目列開 sheet、快照 upsert、非法輸入 gate、科目管理、趨勢 <2 點提示、空月引導、競態、l10nTestApp。

## 5. 入口 + i18n + 收尾

- [ ] 5.1 `app.dart`/`main.dart` DI 組線(NetWorthController + networth use cases)。
- [ ] 5.2 ARB 三檔(en 含 description、zh_Hant、zh)+ `flutter gen-l10n`,generated commit。
- [ ] 5.3 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠(`All tests passed!`);`TZ=UTC flutter test` 複驗。
