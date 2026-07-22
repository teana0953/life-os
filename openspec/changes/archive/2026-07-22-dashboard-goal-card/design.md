# 设计:总览 dashboard + 目标卡(dashboard-goal-card,功能 C1 / 前端)

## 目标
把健康模组的落地页从「分页壳」改成「**总览 dashboard**」(卡片堆),并加第一张卡——**目标卡**(目标/今日/剩余体重 + 达成率环 + BMI + 设定入口)。分页壳(今日/目标/饮水/更多)不动,从总览进入。**不改底部导览**(三模式导览等 C2/C3 内容够了再重构)。以 exercise/menstrual context 为模板。

## body_profile context(`lib/contexts/body_profile/`)

**domain**
- `weight_goal.dart`:
  - `BodyProfile { heightCm: double?, targetWeightKg: double? }`(GET/PUT body-profile)。
  - `WeightGoal { heightCm: double?, targetWeightKg: double?, currentWeightKg: double?, remainingKg: double?, achievementRate: int?, bmi: double? }`(GET weight-goal;snake_case fromJson,全可 null)。
- `body_profile_repository.dart` — `BodyProfileRepository` port:`getWeightGoal(idToken)`、`getBodyProfile(idToken)`、`setBodyProfile(idToken, {double? heightCm, double? targetWeightKg})`(**partial**:只送有给的栏位)。
- `body_profile_exceptions.dart` — `BodyProfileReauthenticationRequired`、`BodyProfileFetchFailure`(typed,镜射 exercise)。

**application**(thin):`GetWeightGoal`、`GetBodyProfile`、`SetBodyProfile`。

**infrastructure**
- `http_body_profile_repository.dart`:GET `/api/weight-goal` → `WeightGoal`;GET `/api/body-profile` → `BodyProfile`;PUT `/api/body-profile`(**只放有给的栏位**)→ 回 profile。bearer idToken;非 200 → fetchFailure,401 → reauth。

**presentation**
- `weight_goal_controller.dart` — `WeightGoalController extends ChangeNotifier`(**即时**,镜射 WaterController._apply):
  - status:`loading | loaded | saving | error | needsReauth`;持有 `WeightGoal? goal`、`BodyProfile? profile`(edit sheet 预填用)。
  - `load(idToken)`:载 weight-goal(+ body-profile 供 edit 预填,可一并载)。
  - `saveProfile(idToken, {heightCm?, targetWeightKg?})`:PUT 後 `load` 重读。错误分类同 exercise。
- `goal_card.dart` — 目标卡 widget(参数 controller、idToken):
  - `AsyncStateScaffold` 不适用(卡片非整屏);卡片自己处理 loading/error/reauth 的精简呈现,或由 DashboardScreen 包状态。**建议**:卡片内依 controller.status 呈现(loading→骨架、error→精简错误+重试、needsReauth→交给 dashboard/screen 层),loaded→内容。
  - **loaded 且 profile 有设**:LedgeCard 内——达成率**环**(achievementRate%;null→空环/不确定)+ 目标/今日/剩余(kg,null→「—」)+ **BMI**(null→「—」)。
  - **profile 未设(height、target 皆 null)**:显示「设定你的目标」引导 + 一个设定按钮(而非一排「—」)。
  - 点卡片(或设定按钮)→ 开 **edit bottom sheet**。
- `goal_edit_sheet.dart`(或放 goal_card.dart 内)—— **`showModalBottomSheet(isScrollControlled: true)` + `EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom)` 包 SingleChildScrollView**(**务必用 bottom sheet,不用 AlertDialog**——避免手机键盘盖住输入,见 exercise #54 教训):身高(cm)、目标体重(kg)两个数字栏(TextField,数字键盘;空零惯例);正数才能存;送出 → controller.saveProfile。

## DashboardScreen(`lib/contexts/health/presentation/dashboard_screen.dart` 或新 dashboard presentation)
- 健康模组落地页。`Scaffold` + AppBar(标题=健康/总览)+ 可卷 `ListView` 卡片堆。
- 本 change 的卡片:**目标卡**(GoalCard(weightGoalController))+ 一张「今日记录 / 进入记录」卡或明显按钮 → `onOpenLog()`(push 现有 DietShellScreen)。
- shell 载入时机:dashboard 在 initState/首次 build `weightGoalController.load(token)`;DietShell 的各 controller 仍由既有壳自己在 _load 载(push 进 shell 时照旧)。
- 参数:`weightGoalController`、`idToken`(或 authRepository 取 token)、`onOpenLog`(VoidCallback → push DietShell)、必要的 signOut/settings 沿用。

## 接线(landing 改到 dashboard)
- `home_screen.dart` 的 `_openHealth`:改成 push **DashboardScreen**,不是 DietShellScreen。DashboardScreen 传入:
  - `weightGoalController`(新,从 HomeScreen 栏位,从 main.dart DI 下来)。
  - `onOpenLog: () => Navigator.push(MaterialPageRoute(builder: (_) => DietShellScreen(...原本那串 controllers...)))` —— **DietShell 的建構整段移进这个 callback**(controllers 仍从 widget 栏位取,不变)。
  - idToken 取得:比照既有(authRepository.idToken)。
- DI:`main.dart` 建 `HttpBodyProfileRepository` + 三个 use case + `WeightGoalController`,经 `App` → `_AuthenticatedHome` → `HomeScreen` 传下(镜射既有 controller 的 threading;HomeScreen 新增一个 `weightGoalController` 栏位)。

## i18n
新增 ARB(en + zh_Hant + zh):总览标题、目标卡(目标/今日/剩余 label + kg 单位、达成率、BMI、null 占位「—」)、未设引导「设定你的目标」+ 设定按钮、edit sheet(身高 cm / 目标体重 kg / 储存)、「今日记录」入口、错误(载入/储存失败、reauth)。跑 `flutter gen-l10n` 提交 generated。

## 测试(flutter test,TDD;widget 用 `l10nTestApp` 注入 fake)
- domain:WeightGoal/BodyProfile fromJson(snake_case、全 null 容错)。
- application:三个 use case 委派。
- infrastructure:`HttpBodyProfileRepository` mock http.Client —— GET weight-goal/body-profile 映射;**PUT 只放有给栏位**(只送 height / 只送 target / 两者)三种 body 断言;非 200→fetchFailure;401→reauth。
- controller:fake repo 验 load / saveProfile 後 reload / 错误分类。
- goal card(widget):profile 有设→显示 target/current/remaining/环/BMI(数字精确:target51/current52/remaining1/ring75/bmi19.1);null achievement/bmi→空环/「—」;profile 未设→引导+设定钮;载入失败→错误态。
- edit sheet(widget):开 sheet、输入身高+目标体重→saveProfile 收到对应值;非正数不能存;**用 bottom sheet(断言 showModalBottomSheet / 有 viewInsets padding 结构)**。
- dashboard + 接线(widget):健康 space → DashboardScreen(有目标卡);「记录」入口 → DietShellScreen 出现。更新既有 home/app 测试(landing 从 DietShell 改 Dashboard 的建構点)。
- `flutter analyze` 干净 + `bash scripts/lint-actions.sh` 过。

## 明确延後(不在本 change)
- 底部导览三模式重构(总览/记录/趋势/更多)—— 等 C2/C3 内容。
- 其他卡片(趋势 C2、习惯/月历 C3、生理期/数值 快照)。
- 份量目标自动计算、生理性别。

## 范围
只加 body_profile context + DashboardScreen + 目标卡/edit sheet + landing 改到 dashboard + DI + i18n + 测试。不改 diet/water/… tracker 与分页壳本身的行为。
