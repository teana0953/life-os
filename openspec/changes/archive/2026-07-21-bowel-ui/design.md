# 设计:排便记录前端 UI(bowel-ui,change 2 / 前端)

消费后端 `/api/bowel`(life-os-backend PR #17),给使用者记录每天的排便:次数、是否正常、备注。比照 water-ui,但更简单(没有 target/进度,改成「填表 + 储存」)。

## Context(新 `contexts/bowel/`)
- **domain**:`BowelDay { day, count, isNormal, note }`(`isNormal` 为 `bool?`,null=未记录);`BowelRepository` port:`getDay(day)`、`save(day, count, isNormal, note)`。
- **application**:`GetBowelDay`、`SaveBowelDay`(thin,注入 port)。
- **infrastructure**:`HttpBowelRepository`(`GET /api/bowel?day=`、`PUT /api/bowel`;JSON snake_case `day/count/is_normal/note`,对齐后端契约;bearer idToken;401→typed reauth)。
- **presentation**:`BowelController`(ChangeNotifier)+ `BowelScreen`。

## 入口:饮食 shell 的第 4 个底部 tab「排便」
`DietShellScreen` 底部现有 `[今日][目标][饮水]`,加**第 4 个 tab「排便」**(合适的 icon,如 `Icons.wc`)。共用 shell 的检视日期 `_day` + `idToken`;shell 在 `_load()`/`_reloadCurrentDay()` 调 `bowelController.load(token, _day)`(与 dailyTarget/water 一致,shell 拥有 load)。日期切换器仍只在「今日」tab;排便 tab 显示检视日期 + 条件标题(今日排便/排便纪录),比照 water。

## UI(比照现有设计系统,复用共用元件)
- 页首:日期 + 条件标题(复用 `day_format`)。
- **次数**:简单 stepper(−/＋ 围绕数字,min 0)。
- **是否正常**:`SegmentedButton` 正常/异常,**可空**(未选前不预设,对应 isNormal=null)。
- **备注**:多行 `TextField`(free text)。
- **储存**:明确的「储存」钮 → `save()` 一次 upsert 整笔(不像饮水即存)。储存中禁用、失败给 SnackBar(比照 water 的 mutation 回馈)。
- 载入/错误/reauth:复用 `AsyncStateScaffold`;section 用 `LedgeCard`。
- **草稿状态**:controller 载入后把 count/isNormal/note 填进可编辑草稿;使用者改草稿,按储存才送后端;切日重载会重置草稿为该日资料。
- i18n:en + zh-Hant 全覆盖。

## DI(main.dart → App → _AuthenticatedHome → HomeScreen → DietShellScreen)
新增 `HttpBowelRepository(baseUrl: apiBaseUrl)` + `GetBowelDay/SaveBowelDay` + `BowelController`,比照 `waterController` 穿线(App/_AuthenticatedHome/HomeScreen 各加 field,更新既有 HomeScreen 测试呼叫点)。

## 测试
- `BowelController`(fake repo):载入填草稿、改草稿、save upsert、切日重置、错误/401→reauth。
- `BowelScreen`(widget,`l10nTestApp`):次数 stepper 加减、正常/异常 toggle、备注输入、储存呼叫 save、储存失败 SnackBar、载入/错误/reauth 不崩、日期+条件标题。
- `HttpBowelRepository`(mock `http.Client`):GET/PUT 映射、错误、401。
- 扩 `diet_shell_screen_test.dart`:第 4 个「排便」tab 存在、选它显示 BowelScreen、既有 tab 与日期导航仍正常。
- `flutter analyze` 乾净 + `flutter test` 绿;重生 `lib/l10n/generated`。

## 复用 & 顺手重构(使用者指示:能共用就共用,发现可抽的一起抽)
- **复用现有共用件**:`shared/widgets/{ledge_card, async_state_scaffold, numeric_amount_field}`、`shared/date/day_format`。
- **抽一个新共用件(真重复,非臆测)**:「日期 + 条件今日/历史标题」的页首现在 `water_screen` 有、`bowel_screen` 也要有 → 抽成 `lib/shared/widgets/tracker_day_header.dart`(接 `day` + `clock` + 今日/历史两个标题字串),并把 `water_screen` 一起改用它(行为/像素不变、测试不改)。
- 其余只在**确有重复**时抽(如 water 的「储存中禁用 + 失败 SnackBar」若与 bowel 一致可抽小 helper);**不过度抽象**(守 CLAUDE.md 简洁)——正常/异常 toggle、次数 stepper 属 bowel 专有,先不抽。

## 范围
bowel context + BowelScreen/Controller + 第 4 tab + DI 接线 + i18n + 测试;加一个 `tracker_day_header` 共用件并迁移 water。不动 diet 行为(除 shell 加一个 tab)。
