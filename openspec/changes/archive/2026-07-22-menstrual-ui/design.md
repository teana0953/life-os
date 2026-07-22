# 设计:生理期 UI(menstrual-ui,功能 B / 前端)

## 目标
消费後端 /api/menstrual(life-os-backend #21),做成进「更多」选单的生理期 tracker,主视觉是**小月历**(标记经期日 + 预测下次)+ 统计卡。即时新增/编辑/删除。生理期**非 day-keyed**。以 exercise context 为模板。

## menstrual context(`lib/contexts/menstrual/`)

**domain**
- `menstrual_period.dart`:
  - `MenstrualPeriod { id, startDate: DateTime, endDate: DateTime? }`(日期用 `DateTime` 纯日期,或 ISO 字串——择一,倾向存 `DateTime` 的 date-only 便于月历比较;fromJson 解析 `start_date`/`end_date`(`end_date` 可 null))。
  - `MenstrualStats { averageCycleDays: int?, averagePeriodDays: int?, predictedNextStart: DateTime? }`(snake_case)。
  - `MenstrualOverview { periods: List<MenstrualPeriod>, stats: MenstrualStats, lastPeriod: MenstrualPeriod? }`。
- `menstrual_repository.dart` — `MenstrualRepository` port:`getOverview(idToken)`、`addPeriod(idToken, {startDate, endDate})`、`updatePeriod(idToken, id, {Object? startDate, Object? endDate})`(**partial**:未传的欄位不动;endDate 传显式 null 清除——用 sentinel 区分「不动 vs 清除」,见下)、`deletePeriod(idToken, id)`。
- `menstrual_exceptions.dart` — `MenstrualReauthenticationRequired`、`MenstrualFetchFailure`(镜射 exercise 的 typed error)。

**partial-update 的 Dart 表达**:Dart 无 undefined。`updatePeriod` 用「只带想改的具名参数」表达三态:
- `startDate`:`DateTime?` 具名参数 + 一个 `bool` 是否更新的旗标,或更简单——分开两个方法/或用 sentinel。**建议**:`updatePeriod(idToken, id, {DateTime? startDate, DateTime? endDate, bool clearEndDate = false})`;infra 组 body:有 startDate 才放 start_date;`clearEndDate` 为 true 放 `end_date: null`,否则有 endDate 才放 end_date。这样「不动」= 不传、「清除」= clearEndDate:true、「设」= 传 endDate。use case/screen 依此调用。

**application**(thin,委派 port):`GetMenstrualOverview`、`AddPeriod`、`UpdatePeriod`、`DeletePeriod`。

**infrastructure**
- `http_menstrual_repository.dart` — `HttpMenstrualRepository`(注入 `http.Client` + `apiBaseUrl`):
  - `GET /api/menstrual` → `MenstrualOverview`。
  - `POST /api/menstrual` body `{start_date, end_date?}`(end 有才放)→ 回建立的 period(可忽略,呼叫端 reload)。
  - `PATCH /api/menstrual/:id` body **只放要改的欄位**(start_date / end_date;清除时 `end_date: null`)。
  - `DELETE /api/menstrual/:id`。
  - bearer idToken;非 200 → `MenstrualFetchFailure`,401 → reauth。日期送 `YYYY-MM-DD` 字串。

**presentation**
- `menstrual_controller.dart` — `MenstrualController extends ChangeNotifier`,**即时**(镜射 `WaterController._apply`):
  - status:`loading | loaded | saving | error | needsReauth`;持有 `MenstrualOverview? overview`。
  - `load(idToken)`(**无 day 参数** —— 生理期非 day-keyed)。
  - `addPeriod / updatePeriod / deletePeriod`:mutation 後 `load(idToken)` 重读。错误分类同 water。
- `menstrual_screen.dart` — `MenstrualScreen`(参数 `controller, idToken`;无 day/clock 的 day-keyed 参数,但月历「今天」用可注入 `clock` 便于测试):
  - `AsyncStateScaffold`(含 optional appBar,让 loading/reauth 也有返回钮)包裹;appBar 标题 = 生理期。
  - **月历**(见下)+ **统计卡**(LedgeCard:平均周期天数、平均经期天数、预测下次;null → 显示「—」)+ **最近一次周期**摘要。
  - 新增按钮 / 点月历某日 → 开 add/edit dialog。

## 小月历(新 widget,参考既有 `diet_shell_screen.dart` 的 `_DietCalendarDialog`/`_DayCell` 月格逻辑)
- 既有月格逻辑(周日开头、leading blanks、`_weeks()` 分周、`_DayCell` 圆点)是 private 于 diet_shell。**本 change 新建一个 menstrual 专用月历 widget**(`_MonthCalendar` 或独立档),复用同一套月格算法(照抄逻辑,不强行抽共享组件——避免动 diet_shell 的既有行为;若後续要共享再重构)。
- 标记规则(颜色全走 Theme):
  - **经期日**:某日落在任一 period 的 [startDate, endDate] 闭区间内(open period:[startDate, 今天])→ 实心底色/圆点(primary 系)。
  - **预测下次起日**:`stats.predictedNextStart` 那天 → 另一种标记(如 outline 环 / 不同色点),与经期日可辨。
  - 月切换 prev/next(prev 无限制;next 可到未来看预测)。
  - 点某日:若该日属于某 period → 编辑该 period;否则 → 新增一个以该日为 start 的 period(开 dialog 预填)。也提供一个明确「新增周期」按钮(不必先点日期)。

## Add/Edit dialog
- 栏位:起始日(date picker,必填)、结束日(date picker,选填;编辑时可清除 → clearEndDate)。用 `showDatePicker` 或轻量日期选择;date-only。
- 校验:结束日 ≥ 起始日 才能送出(前端挡;後端也会 400)。
- 编辑模式多一个「删除」动作(带确认或 undo SnackBar,择一;至少不要单击即删无回馈——参考 exercise 删除的 undo SnackBar)。
- 送出 → controller.addPeriod / updatePeriod(partial);删除 → deletePeriod。皆即时 reload。

## Shell 接线 + DI
- `DietShellScreen`:新增 `required MenstrualController menstrualController`;**`_load(token)` 里 `menstrualController.load(token)` 载入一次**(day-independent,**不放** `_reloadCurrentDay`)。
- `_MoreMenuScreen`:新增第 4 个 tile「生理期」(icon 如 `Icons.calendar_month` 或合适者),onTap `Navigator.push` `MenstrualScreen(controller: menstrualController, idToken: ...)`。
- DI:`main.dart` 建 `HttpMenstrualRepository` + 四个 use case + `MenstrualController`,经 `App` → `_AuthenticatedHome` → `HomeScreen` → `DietShellScreen` 传下(镜射 `exerciseController` 每一处,含测试建构点:app_test / diet_shell_screen_test / home_screen_test / home_screen_responsive_test)。

## i18n
新增 ARB(en + zh_Hant + zh)：生理期 tile/screen 标题、统计卡三个 label + null 占位「—」、最近一次周期、新增/编辑周期 dialog(起日/结日/清除结日/删除)、月历月份导航 label、进行中(open period)、错误讯息(载入/储存失败、reauth)。跑 `flutter gen-l10n` 提交 generated。

## 测试(flutter test,TDD;widget 用 `l10nTestApp` 注入 fake)
- domain:MenstrualPeriod/Stats/Overview fromJson(snake_case、end_date null、stats null、lastPeriod null)。
- application:四个 use case 委派。
- infrastructure:`HttpMenstrualRepository` mock `http.Client` 验四 endpoint request(method/path/body/bearer)与 response 映射;**PATCH 只放有改的欄位**(只改 end / 只改 start / 清除 end 三种 body 断言);非 200→fetchFailure;401→reauth。
- controller:fake repo 验 load / addPeriod / updatePeriod(partial 传参)/ deletePeriod 後 reload;错误分类。
- 月历逻辑:纯函式/widget 验——某 period range 的日子被标记(含 open period 到今天)、predicted next 那天标记、月切换。
- screen(widget):统计卡显示值 / null→「—」;点日期开 dialog;新增→reload;载入失败→错误态;有 appBar 返回钮。
- shell(widget,diet_shell_screen_test):更多选单出现「生理期」tile;选它→显示 MenstrualScreen(有返回钮);其他 tile 仍在。
- `flutter analyze` 干净 + `bash scripts/lint-actions.sh` 过。

## 明确延後(不在本 change)
- 与体重趋势叠图(功能 C)、症状/经量记录、排卵/受孕期预测、月历的跨月连续 range 视觉优化。

## 范围
只加 menstrual context + menstrual 月历/screen + 更多 tile + DI + i18n + 测试。不改其他 tab/tracker 行为(仅 _MoreMenuScreen 多一个 tile、shell `_load` 多载一个 controller)。
