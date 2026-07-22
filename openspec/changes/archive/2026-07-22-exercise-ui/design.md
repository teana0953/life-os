# 设计:运动记录前端 + 导览「更多」溢出(exercise-ui)

## 目标
把已上线的后端 `/api/exercise`(life-os-backend #20)接成可用的前端运动 tracker,并把 daily-log shell 底部导览从「5 格已满」重构为「4 格 + 更多溢出」。纯记录、即时新增/删除;不做趋势图 / 运动→加食量联动 / 自订运动库(延后)。

## 导览重构(方案 A,已与使用者定案)
底部 `NavigationBar` 由 5 格改为 **4 格**:今日 / 目标 / 饮水 / **更多**。
- **更多**是第 4 个 IndexedStack body = 一个 **More 选单屏**(`_MoreMenuScreen`,列出 排便 / 数值 / 运动 三个 tile;之后生理期 / dashboard 也加这)。
- 点 tile → `Navigator.push` 该 tracker 的既有 screen(BowelScreen / VitalsScreen / ExerciseScreen),传入 shell 当前 `_day` + `idToken` + 对应 controller + `clock`。tracker screen 本身不变(排便 / 数值 只是入口从底部 tab 移到更多)。
- shell 仍拥有载入:`_load()` / `_reloadCurrentDay()` 照旧对所有 controller(含新 `exerciseController`)呼叫 `load(token, _day)`;push 出去的 screen 读的是已载入的 controller 状态。
- 换日仍只在「今日」tab 的 `_DayNavBar`(既有行为不变);从更多 push 出的 tracker 显示 push 当下的 `_day`。

**取舍**:排便 / 数值 从底部 tab 变成「更多 → push route」,少一层可见性但频率低、可接受;换成 push route 而非留在 IndexedStack,是为了让「更多」这层可无限扩展且各 tracker screen 零改动。

## 运动 context(`lib/contexts/exercise/`,以 vitals context 为模板)

**domain**
- `exercise_day.dart`:
  - `ExerciseActivity { id, name, category, intensity }`(category 为 `'aerobic' | 'anaerobic'` 字串;来自 `GET /activities`)。
  - `ExerciseEntry { id, activityId, activityName?, category?, durationMinutes, note, createdAt }`(来自 `GET ?day=`,已 enrich;snake_case fromJson:activity_id / activity_name / duration_minutes / created_at)。
  - `ExerciseDay { day, entries: List<ExerciseEntry>, totalMinutes }`(total_minutes)。
- `exercise_repository.dart` — `ExerciseRepository` port:`listActivities(idToken)`、`getDay(idToken, day)`、`addEntry(idToken, {day, activityId, durationMinutes, note})`、`deleteEntry(idToken, entryId)`。
- `exercise_exceptions.dart` — `ExerciseReauthenticationRequired`、`ExerciseFetchFailure`(镜射 water/vitals 的 typed error;不放 message 字串)。

**application**(thin,委派 port)
- `ListExerciseActivities`、`GetExerciseDay`、`AddExerciseEntry`、`DeleteExerciseEntry`。

**infrastructure**
- `http_exercise_repository.dart` — `HttpExerciseRepository`,注入 `http.Client` + `apiBaseUrl`。四个 endpoint:
  - `GET /api/exercise/activities` → `List<ExerciseActivity>`(后端回 `{activities:[...]}` 信封,取 `activities`)。
  - `GET /api/exercise?day=` → `ExerciseDay`。
  - `POST /api/exercise` body `{day, activity_id, duration_minutes, note}` → 回建立的 entry(可忽略回传,呼叫端 reload)。
  - `DELETE /api/exercise/:id` → `{deleted}`。
  - 送 bearer `idToken`;非 200 抛 `ExerciseFetchFailure`,401 抛 `ExerciseReauthenticationRequired`。

**presentation**
- `exercise_controller.dart` — `ExerciseController extends ChangeNotifier`,**即时新增/删除**(镜射 `WaterController._apply`,非 draft-then-save):
  - status:`loading | loaded | saving | error | needsReauth`;持有 `ExerciseDay? day` + `List<ExerciseActivity> activities`。
  - `load(idToken, day)`:载入当天 entries;activities 首次载入后可快取(库是静态的,不必每天重抓——但简单起见每次 load 一并取也可,择一并说明)。
  - `addEntry(idToken, day, {activityId, durationMinutes, note})`:POST 后 `load` 重读。
  - `deleteEntry(idToken, day, entryId)`:DELETE 后 `load` 重读。
  - 错误分类同 water(fetchFailed / unknown / needsReauth)。
- `exercise_screen.dart` — `ExerciseScreen`(参数 `controller, idToken, day, clock`):
  - `AsyncStateScaffold` 包裹;`TrackerDayHeader`(date + today/history 标题);
  - 顶部显示当天**总时长**;当天 entries 清单(每笔:活动名 + 时长 + note,尾端删除钮);
  - 新增:FAB 或按钮开一个 dialog/sheet — 活动选择(库项目,按 有氧/无氧 分组)+ 时长(正整数分钟,**空零惯例**:`value==0?'':...` + `hintText:'0'`,用 `NumericAmountField`)+ 选填 note → `addEntry`;时长非正整数时禁止送出。
  - 颜色只从 `Theme.of(context)`;字串全走 ARB。

## Shell 接线 + DI
- `DietShellScreen` 新增 `required ExerciseController exerciseController`;`_load`/`_reloadCurrentDay` 加 `exerciseController.load(token, _day)`;`build` 的 `screens` 由 5 项改为 4 项(今日 / 目标 / 饮水 / More 选单屏);`NavigationBar` 改 4 destinations(今日 / 目标 / 饮水 / 更多,更多用如 `Icons.more_horiz`)。
- `_MoreMenuScreen`(shell 内私有 widget 或独立 presentation 档):列出 排便 / 数值 / 运动 tile,onTap push 对应 screen(传 `idToken`/`_day`/controller/`clock`)。
- DI:`main.dart` 建 `HttpExerciseRepository` + 四个 use case + `ExerciseController`,经 `App` → `_AuthenticatedHome` → `HomeScreen` → `DietShellScreen` 传下(镜射 `vitalsController` 的每一处新增)。

## i18n
新增 ARB keys(`app_en.arb` 含 description + `app_zh_Hant.arb` + `app_zh.arb`),至少:更多 tab 标签、More 选单标题与三个 tile 标签(排便/数值/运动——沿用既有 tab 标签 key 或新增)、运动画面标题、总时长标签、新增按钮、活动选择/时长/note 栏位、有氧/无氧分类标签、删除、错误讯息。**活动名称是后端资料(中文库,同 food dictionary),不本地化**;分类(有氧/无氧)由 `category` enum 映射本地化标签。跑 `flutter gen-l10n`,提交 `lib/l10n/generated/*.dart`。

## 测试(flutter test,TDD;widget 测试用 `l10nTestApp` 注入 fake)
- domain:`ExerciseDay`/`ExerciseEntry`/`ExerciseActivity` fromJson(snake_case,含 note 空、activityName/category enrich)。
- application:四个 use case 以 fake repo 验委派。
- infrastructure:`HttpExerciseRepository` 用 mock `http.Client` 验四 endpoint 的 request(method/path/body/bearer)与 response 映射;非 200 → fetchFailure;401 → reauth;`{activities}` 信封解包。
- controller:fake repo 验 load / addEntry(POST 后 reload,total 增)/ deleteEntry(reload,total 减)/ 错误分类。
- screen(widget):空日显示零总长无 entries;新增流程(选活动+时长→出现在清单、total 增);非正整数不能送出;删除→消失且 total 减;载入失败→错误态。
- shell(widget,`diet_shell_screen_test.dart`):底部只有 4 destinations;点「更多」出选单列三 tracker;选运动→显示运动画面(当前日);排便/数值仍可从更多到达;今日/目标/饮水仍在底部。
- `flutter analyze` 干净 + `bash scripts/lint-actions.sh` 过。

## 范围
只加 exercise context + More 选单 + shell 导览重构 + DI + i18n + 测试。排便/数值/饮水/今日/目标的**画面本身不改**,只有 排便/数值 的入口从底部移到更多。不做趋势图 / 运动→加食量联动 / 自订运动库。
