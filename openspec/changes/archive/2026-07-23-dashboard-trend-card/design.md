# 设计:总览趋势卡(dashboard-trend-card,功能 C2 / 前端)

## 目标
总览第二张卡:**健康数值趋势折线图**——多指标切换(体重/体脂/收缩压/舒张压/心跳/血糖/血氧)+ 区间(7/30/90 天),用 **fl_chart**。消费 `/api/vitals/range`。以既有 vitals context 扩充,不新建 context。

## 依赖
- `pubspec.yaml` 加 **`fl_chart`**(apply 用 `flutter pub add fl_chart` 取最新相容版;`flutter pub get`)。app 目前无图表库。

## vitals context 扩充(`lib/contexts/vitals/`)

**domain**
- `vitals_series.dart`:
  - `SeriesPoint { DateTime day; double value }`。
  - `VitalsSeries { List<SeriesPoint> weight, bodyFat, systolic, diastolic, pulse, glucose, spo2 }`。
  - `VitalsRange { DateTime from; DateTime to; VitalsSeries series }`;snake_case fromJson(每 series = list of {day, value};day 解析为 date-only DateTime)。
  - `enum VitalsMetric { weight, bodyFat, systolic, diastolic, pulse, glucose, spo2 }` + `List<SeriesPoint> seriesFor(VitalsSeries, VitalsMetric)`(取对应序列)。label/unit 在 presentation 走 i18n,不放 domain。
- `vitals_repository.dart`:加 `getRange(String idToken, DateTime from, DateTime to): Future<VitalsRange>`。
- 复用既有 `vitals_exceptions.dart`(reauth/fetch)。

**application**:`get_vitals_trends.dart` — `GetVitalsTrends`(thin,委派 getRange)。

**infrastructure**:`http_vitals_repository.dart` 加 `getRange` —— GET `/api/vitals/range?from=YYYY-MM-DD&to=YYYY-MM-DD`,bearer;非 200→fetchFailure,401→reauth;解析 series。

**presentation**
- `trend_controller.dart` — `TrendController extends ChangeNotifier`:
  - 状态:`loading | loaded | error | needsReauth`;持有 `VitalsRange? range`、`int spanDays`(7/30/90,默认 30)。**可注入 clock**(默认 DateTime.now)算区间。
  - `load(idToken)`:from = today − (spanDays − 1)、to = today(date-only,格式 YYYY-MM-DD),`getRange`。
  - `setSpan(idToken, days)`:更新 spanDays → reload。错误分类镜射 vitals/exercise。
  - 选中指标(VitalsMetric)——放 controller 或卡片 local state 皆可;设计倾向放**卡片 local state**(切指标不需重打 API,只重画;区间才需重载)。
- `trend_card.dart` — 趋势卡 widget(参数 controller、idToken):
  - `LedgeCard`:标题(趋势)+ **指标 chips**(7 个 VitalsMetric,ChoiceChip,label 走 i18n)+ **区间选择**(7/30/90 天,SegmentedButton 或 ChoiceChip)+ 图表区(固定高度,如 200)。
  - 图表:**fl_chart `LineChart`**——取 `seriesFor(range.series, selectedMetric)`;x = 该点 day 相对 range.from 的天数(double),y = value;一条 `LineChartBarData`(主色、圆点、可选淡区域填充);极简 grid、轴标签(x 少量日期、y 数值);单点也要能画(点即可)。**颜色全走 `Theme.of(context)`**,不硬编。
  - **空**:选中指标序列为空 → 图表区显示「尚无资料」讯息(key `trend-empty`),不画空图。
  - loading→骨架/spinner;error→精简错误+重试;needsReauth→交给 DashboardScreen(与 goal 卡一致,dashboard 层拦 needsReauth)。

## Dashboard 接线
- `dashboard_screen.dart`:新增 `required TrendController trendController` 栏位;`initState`/`_load` 里 `trendController.load(token)`;**record 回来的 reload 也要重载 trend**(与 goal 一致:`onOpenLog` 回来后 `_load` 同时 reload goal + trend)。在 GoalCard 之后、record entry 之前插入 `TrendCard(controller: trendController, idToken: idToken)`。dashboard 的 needsReauth 判断也纳入 trend 的 needsReauth(任一 needsReauth → 显示重登出口)。
- DI:`main.dart` 建 `TrendController`(用既有 vitals repo 的 getRange,或注入 GetVitalsTrends),经 `App` → `_AuthenticatedHome` → `HomeScreen` → `DashboardScreen` 传下(镜射 weightGoalController 每一处,含测试建构点:app_test / home_screen_test / home_screen_responsive_test / dashboard_screen_test)。

## i18n
新增 ARB(en + zh_Hant + zh):趋势卡标题、7 个指标 label(体重/体脂/收缩压/舒张压/心跳/血糖/血氧)+ 单位(kg/%/mmHg/bpm/mg dL 等,可选)、区间 label(7天/30天/90天)、空「尚无资料」、错误(载入失败/重试/reauth)。跑 `flutter gen-l10n` 提交 generated。

## 测试(flutter test,TDD;widget 用 `l10nTestApp` 注入 fake)
- domain:VitalsSeries/VitalsRange fromJson(snake_case、各 series 点、空序列);seriesFor 映射各 metric。
- application:GetVitalsTrends 委派。
- infrastructure:`getRange` mock http.Client —— 请求 path/query(from/to YYYY-MM-DD)/bearer、response 映射;非 200→fetchFailure;401→reauth。
- controller:fake repo 验 load(区间由 clock+span 算,断言 from/to)、setSpan 重载、错误分类;可注入 clock。
- trend card(widget):有资料→有 LineChart(`find.byType(LineChart)`);切指标→重画(可断言选中指标的点数/或 chart 存在);切区间→controller 重载(fake 收到新 from/to);空指标→`trend-empty` 讯息、无 LineChart;载入失败→错误态+重试。
- dashboard(widget):总览有 TrendCard(在 GoalCard 之后);record 回来 trend 重载(getRange 再被呼叫);trend needsReauth → 重登出口。更新既有 dashboard/home/app 测试建构点(加 trendController)。
- `flutter analyze` 干净 + `bash scripts/lint-actions.sh` 过。

## 明确延後(不在本 change)
- 多指标叠图(同图多线)、与生理期叠图、min/max band、互动 tooltip/缩放、自订区间。
- 底部导览三模式重构(等更多卡)。

## 范围
只加 vitals context 的 series/getRange/趋势卡/controller + fl_chart 依赖 + dashboard 插第二张卡 + DI + i18n + 测试。不改 goal 卡/tracker/分页壳行为。
