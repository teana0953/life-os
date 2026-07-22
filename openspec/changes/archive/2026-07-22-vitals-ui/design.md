# 设计:健康数值前端 UI(vitals-ui,change 2 / 前端)

消费后端 `/api/vitals`(life-os-backend PR #18),给使用者记录每天的健康数值。比照 bowel-ui 的「填表 + 明确储存 + 草稿」,但更大:两个 scalar 栏 + **三个清单编辑器**(血压/血糖/血氧,可加减多笔)。日誌 shell 的第 5 个底部 tab。

## Context(新 `contexts/vitals/`)
- **domain**:`BpReading { systolic, diastolic, pulse? }`、`GlucoseReading { label, value }`、`Spo2Reading { spo2, pulse? }`、`VitalsDay { day, weightKg?, bodyFatPct?, bpReadings[], glucoseReadings[], spo2Readings[] }`;`VitalsRepository`(getDay、save)。
- **application**:`GetVitalsDay`、`SaveVitalsDay`(thin)。
- **infrastructure**:`HttpVitalsRepository`(`GET /api/vitals?day=`、`PUT /api/vitals`;JSON snake_case:`weight_kg/body_fat_pct/bp_readings[{systolic,diastolic,pulse}]/glucose_readings[{label,value}]/spo2_readings[{spo2,pulse}]`;bearer idToken;401→typed reauth)。
- **presentation**:`VitalsController` + `VitalsScreen`。

## 入口:饮食 shell 的第 5 个底部 tab「数值」
现有 `[今日][目标][饮水][排便]` → 加**第 5 个 tab「数值」**(icon 如 `Icons.monitor_heart`,`loc.dietTabVitals`)。共用 `_day` + `idToken`;shell 在 `_load()`/`_reloadCurrentDay()` 调 `vitalsController.load(token, _day)`(shell 拥有 load)。注意:Material NavigationBar 到 5 个 destination(上限),之后若再多要改结构。

## UI(复用共用元件 + 比照 bowel 的草稿/储存)
- 页首:`TrackerDayHeader`(今日数值 / 数值纪录 + 日期)。
- **体重 / 体脂**:各一个数值栏(`NumericAmountField` 或简单 TextField,可空=未记录;体脂 %)。
- **血压清单**:每笔一列(收缩/舒张/脉搏三个小数值栏)+ 移除;底部「加一笔」。脉搏可空。
- **血糖清单**:每笔一列(label 输入,附餐前/餐后快捷 + 数值 mg/dL)+ 移除;「加一笔」。
- **血氧清单**:每笔一列(SpO2 % + 脉搏可空)+ 移除;「加一笔」。
- **储存**:明确「储存」钮 → `save()` upsert 整天(scalars + 三清单);比照 bowel 的**未存提示 + 储存中禁用 + 失败 SnackBar**(hasUnsavedChanges 才启用)。
- 载入/错误/reauth:`AsyncStateScaffold`;section 用 `LedgeCard`。
- **草稿状态**:controller 载入后填草稿(两 scalar + 三个 mutable list);改草稿(setWeight/setBodyFat、add/update/remove 各清单笔)不立即存;save 才送;切日重载重置草稿;error 不重置(保留输入)。
- i18n:en + zh-Hant 全覆盖。

## DI(main.dart → App → _AuthenticatedHome → HomeScreen → DietShellScreen)
新增 `HttpVitalsRepository(baseUrl: apiBaseUrl)` + `GetVitalsDay/SaveVitalsDay` + `VitalsController`,比照 `bowelController` 穿线(App/_AuthenticatedHome/HomeScreen 各加 field,更新既有 HomeScreen 测试呼叫点)。

## 复用 / 顺手
- 复用 `LedgeCard`/`AsyncStateScaffold`/`TrackerDayHeader`/`NumericAmountField`。
- 若「未存提示 + 失败 SnackBar」的样式与 bowel 一致到可抽小 helper 再说;否则先各自(不过度抽象)。三个清单编辑器结构相近,可抽一个泛型 `_ReadingListSection`(仅本 screen 内),避免三份重复。

## 测试
- `VitalsController`(fake repo):载入填草稿、改 scalar / 增删改三清单笔、save upsert、切日重置、hasUnsavedChanges、error/401→reauth。
- `VitalsScreen`(widget,`l10nTestApp`):显示三清单、加一笔/移除、改值、体重体脂、储存呼叫 save、未存提示、失败 SnackBar、载入/错误/reauth 不崩、日期+条件标题。
- `HttpVitalsRepository`(mock `http.Client`):GET/PUT 三清单 round-trip、401。
- 扩 `diet_shell_screen_test.dart`:第 5 个「数值」tab 存在、选它显示 VitalsScreen、既有 tab/日期导航仍正常。
- `flutter analyze` 乾净 + `flutter test` 绿;重生 `lib/l10n/generated`。

## 范围
vitals context + VitalsScreen/Controller + 第 5 tab + DI 接线 + i18n + 测试。不动其他 tab 行为(除 shell 加一个 tab)。
