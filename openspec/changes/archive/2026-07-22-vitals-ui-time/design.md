# 设计:每笔量测加时间选择器(vitals-ui-time,change 2 / 前端)

后端(life-os-backend PR #19)现在每笔 reading 必填 `time`(HH:mm)。前端在数值 tab 的三个清单编辑器,**每笔 row 加一个时间选择器**。这是对已上线 vitals-ui(#49)的小改。

## 变动
- **Domain**(`lib/contexts/vitals/domain/vitals_day.dart`):`BpReading`/`GlucoseReading`/`Spo2Reading` 各加 `time`(String,HH:mm,**必填**)。加进 fromJson(读 `time`)、toJson(写 `time`)、以及 `==`/`hashCode`(维持 hasUnsavedChanges 用 listEquals 正确 —— time 是新栏位,必须纳入相等比较)。
- **Controller**(`vitals_controller.dart`):
  - 新增一笔时,`time` 预带**现在**(`TimeOfDay.now()` 格式化成 "HH:mm"),让「必填」不卡手、且送后端不会空。
  - per-list 的 update 支援改 `time`(既有 updateField 泛型能改栏位就沿用;否则加 setTime)。
- **Screen**(`vitals_screen.dart`):每笔 row 加一个**紧凑时间控件**(显示 HH:mm 的可点 chip/按钮,点了开 `showTimePicker` → 选到就格式化成 "HH:mm" 写回该笔)。放在 row 里(BP 列已是两行,时间可放脉搏那行或独立;glucose/spo2 row 也各加)。必填 —— 因预带现在,永远有值。
- **序列化**:`HttpVitalsRepository` 结构不变(靠 toJson/fromJson),但确认三种 reading 的 payload 都含 `time`。

## 格式 / i18n
- time 存 "HH:mm"(24h)字串;显示直接用该字串;`showTimePicker` 回 `TimeOfDay` → 格式化 `HH:mm`(用 `MaterialLocalizations.formatTimeOfDay(..., alwaysUse24HourFormat: true)` 或手动补零)。
- 新增 ARB(如需):时间控件的 label/语意标签(e.g. `vitalsTimeLabel` "Time" / "时间");`showTimePicker` 本身走系统在地化。

## 测试
- `VitalsController`:新增一笔的 `time` 预带非空(现在);改 time;hasUnsavedChanges 纳入 time(改 time → 变 dirty)。
- `VitalsScreen`(widget,`l10nTestApp`):每笔 row 显示时间;点时间控件开 `showTimePicker`(可 pump 后选一个时间,断言 controller 收到新 time),或至少断言时间显示存在且新增列预带现在。
- `HttpVitalsRepository`:三种 reading round-trip 含 `time`。
- 更新既有 vitals 测试的 reading fixture / 断言,补上 `time`。
- `flutter analyze` 乾净 + `flutter test` 绿;重生 l10n(若加 key)。

## 范围
只动 vitals 的 domain reading 型别(+time)、controller(add 预带现在 / 改 time)、screen(每笔时间控件)、http 序列化确认、相关测试。不动其他 tab、不动 scalar 栏、不动后端。
