# 设计:饮水记录前端 UI(water-ui,change 2 / 前端)

消费后端 `/api/water`(已在 life-os-backend PR #16),给使用者一个记录每日饮水、对每日目标看进度的画面。目标逻辑与后端一致(carry-forward)。

## Context(新 `contexts/hydration/`)
自成一个 context(不塞进 diet-heavy 的 health context,保持乾净;之后排便可加姊妹 context 或共用):
- **domain**:`WaterDay { day, totalMl, targetMl, remainingMl }`;`WaterRepository` port:`getDay(day)`、`addWater(day, addMl)`、`setTarget(day, targetMl)`。
- **application**:`GetWaterDay`、`AddWater`、`SetWaterTarget`(thin use cases,注入 port)。
- **infrastructure**:`HttpWaterRepository`(`baseUrl` + `idToken`,打 GET/POST `/api/water`、PUT `/api/water/target`;JSON snake_case:`day/total_ml/target_ml/remaining_ml/add_ml`,对齐后端契约)。
- **presentation**:`WaterScreen` + `WaterController`(ChangeNotifier)。

## UI(比照现有设计系统 / diet 画面)
- 页首:吉祥物 + 「今日饮水」+ 日期,含**日期切换**(prev/next,沿用 diet_shell 的 `_DayNavBar` 样式;今天不能往未来)。
- **进度条**「1200 / 2000 ml」(重用份量进度条样式;remaining 可为负→显示超标)。
- **快键**:＋250ml、＋500ml、自订(数字对话框,empty-zero 惯例);另一个 **−250ml / 修正**(送负 add_ml,后端 clamp≥0)。
- **可设每日目标**(小控件,镜射 diet 的每日目标设定 UI)。
- 载入 / 错误 / reauth(401)状态处理比照 diet(错误不崩、401 提示重新登入)。
- i18n:en + zh-Hant 全覆盖(所有字串走 ARB)。

## 入口:饮食 shell 的第 3 个底部 tab(方案 C)
`DietShellScreen` 现在底部有 `[今日] [目标]` 两个 tab(共用 scaffold、`idToken`、页首的检视日期 `_day`)。加**第 3 个 tab「饮水」**(`IndexedStack` 加一个 `WaterScreen`、`NavigationBar` 加一个 `NavigationDestination`,水滴 icon)。
- 饮水 tab **共用 shell 的检视日期 `_day`**(页首日期切换飲水也適用),接 `idToken`。
- 语意上 shell 从「饮食」扩成「健康日志」(名字暂不改,之后正名);排便之后会是第 4 个 tab(次数 + 正常/异常 + free text),同一套。

## DI(main.dart → HomeScreen → DietShellScreen)
新增 `HttpWaterRepository(baseUrl: apiBaseUrl)` + `GetWaterDay/AddWater/SetWaterTarget` + `WaterController`,比照 `dailyTargetController` 穿线:main.dart 建好 → HomeScreen → DietShellScreen 当必填参数,shell 把它 + `idToken` + `_day` 交给 `WaterScreen`。

## 测试
- `WaterController` 单元(fake `WaterRepository`):加水更新总量/剩余、设目标、切日重载、错误状态、401→reauth。
- `WaterScreen` widget(注入 fake use cases / controller,`l10nTestApp`):进度条读数、＋250/＋500/自订加水、−250 修正、设目标、日期切换、错误不崩。
- `HttpWaterRepository`(注入 mock `http.Client`):GET/POST/PUT 的 request/response 映射、错误。
- `flutter analyze` 乾净 + `flutter test` 绿。

## 范围
只加 hydration context + WaterScreen/Controller + 饮食 shell 第 3 个底部 tab + DI 接线(main.dart → App → _AuthenticatedHome → HomeScreen → DietShellScreen)+ i18n 字串 + 测试。不动 diet 行为(除 shell 加一个 tab)。

## 已定案
- **位置**:方案 C——饮食 shell 第 3 个底部 tab「饮水」,共用 shell 的检视日期 `_day`。排便之后是第 4 个 tab(次数 + 正常/异常 + free text)。
- **Context**:前端新 `contexts/hydration`。
- **载入归属**:shell 拥有 load(如同 dailyTargetController),在 `_load()`/`_reloadCurrentDay()` 调 `waterController.load(token, _day)`;WaterScreen 本身不自 load。
- **契约细节**:`POST /api/water` 只回 `{day, total_ml}`(后端已 clamp≥0),显示的 total 取自回应或重 GET,不本地算;进度条 fill clamp 100%。
