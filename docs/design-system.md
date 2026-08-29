## 反推依據

- `life-os/lib/shared/theme/app_colors.dart` — 原始色彩 token 常數
- `life-os/lib/shared/theme/app_theme.dart` — `lightTheme`/`darkTheme`、TextTheme、圓角/邊框常數、`ledgeShadow`
- `life-os/lib/shared/widgets/` — 21 個共用元件檔(含 `ledge_card.dart` 的 radius 預設值)
- `life-os/CLAUDE.md` 的 Design system 章節(breakpoints、設計語彙、字型)
- 全 `lib/` 的 `EdgeInsets` / `SizedBox` / `BorderRadius` 使用頻率統計(間距 token 是從實際用量反推,非既有定義)

註:專案**沒有**間距與 breakpoint 的具名 token 檔案。色彩/字級/圓角有實體來源,間距與 breakpoint 為反推。

## 色彩

以 `ColorScheme` 為分發層,螢幕一律走 `Theme.of(context)`,不得直接引用原始常數。

| Token | Light | Dark | 出處(app_colors.dart 變數) |
| --- | --- | --- | --- |
| color.primary | #8FD3E6 | #8FD3E6 | `hachiwareBlue`(明暗同色) |
| color.on-primary | #284A54 | #173038 | `onPrimaryLight` / `onPrimaryDark` |
| color.primary-deep | #5EB5D3 | 同左 | `primaryDeep`,只用於 focus 邊框 |
| color.secondary | #F6B0C1 | #EE9DB0 | `blushPinkLight` / `blushPinkDark` |
| color.tertiary | #FBE08A | #EFCE78 | `usagiYellowLight` / `usagiYellowDark` |
| color.ground(scaffold 底) | #FBF1E1 | #231D19 | `groundLight` / `groundDark`(也是 `surfaceContainerHighest`) |
| color.surface(卡片) | #FFFDF8 | #2E2721 | `surfaceLight` / `surfaceDark` |
| color.ink(主文字) | #5A4A3E | #F3E9DC | `inkLight` / `inkDark`,永不用純黑/純白 |
| color.ink-muted(次要文字) | #7C6952 | #B6A695 | `mutedInkLight` / `mutedInkDark`,light 已為 AA 調深 |
| color.outline | #D8C3A6 | #463A31 | `outlineLight` / `outlineDark` |
| color.success | #8FC79A | 同左 | `sageSuccess`(僅供邊框/填色) |
| color.warning | #E0A94E | 同左 | `honeyWarning`(僅供邊框/填色) |
| color.error(pastel) | #E98A94 | #E98A94 | `softError`;dark 的 `ColorScheme.error` |
| color.error-text | #B4453D | (用 softError) | `errorTextLight`;light 的 `ColorScheme.error` |
| color.finance-income-text | #2E6B41 | #8FC79A | `financeIncomeTextLight`,經 `financeIncomeColor()` |
| color.finance-budget-warning-text | #8A6A1E | #E0A94E | `financeBudgetWarningTextLight`,經 `financeBudgetWarningColor()` |
| color.import-success-icon | #A88428 | tertiary | `importSuccessIconLight`,經 `importSuccessIconColor()` |
| color.import-running-icon | #3F8FA6 | primary | `importRunningIconLight`,經 `importRunningIconColor()` |
| color.diet-staple | #FBE08A | #EFCE78 | `dietStapleLight/Dark`,經 `DietCategoryColors` ThemeExtension |
| color.diet-meat | #F6B0C1 | #EE9DB0 | `dietMeatLight/Dark`,同上 |
| color.diet-fruit | #F7B98C | #E0A374 | `dietFruitLight/Dark`,同上 |
| color.diet-veg | #A8D5B0 | #7FAF8C | `dietVegLight/Dark`,同上 |

**硬性約束**:pastel 色只作邊框/填色,不作前景文字 — 文字用途一律走上表的 `*-text` 深色變體(light 主題下 pastel 對 #FFFDF8 只有 1.9–2.4:1,不過 AA)。

## 字級

字型家族 `text.font-family = NotoSans`(`app_theme.dart` 的 `_fontFamily`,經 `ThemeData.fontFamily` 套用)。TextTheme 只定義 5 個 style,其餘沿用 Material 預設。

| Token | 對應 style | 值(出自 `_textTheme()`) |
| --- | --- | --- |
| text.headline | `textTheme.headlineMedium` | 28px / w800 / line-height 1.3 / ink |
| text.title | `textTheme.titleLarge` | 20px / w700 / 1.3 / ink |
| text.body | `textTheme.bodyLarge` | 16px / w400 / 1.5 / ink |
| text.body-small | `textTheme.bodyMedium` | 14px / w400 / 1.5 / ink |
| text.label | `textTheme.labelLarge` | 16px / w700(無 color,由按鈕 foreground 決定);FilledButton/OutlinedButton 的 `textStyle` |

## 間距

無具名常數;以下由 `lib/` 全域使用頻率反推(數字為出現次數)。

| Token | 值 | 常見用法 |
| --- | --- | --- |
| space.card-padding | 20dp | 卡片內距,最主流(`EdgeInsets.all(20)` ×49) |
| space.section-padding | 24dp | 頁面外層 / 大區塊內距(×21) |
| space.compact-padding | 16dp | 密集列表、次級卡片內距(×24) |
| space.tight-padding | 12dp | 小 chip / 密集容器(×4) |
| space.stack-lg | 20dp | 區塊之間垂直間隔(`SizedBox(height: 20)` ×33) |
| space.stack-md | 16dp | 元素之間預設垂直間隔,最主流(×127) |
| space.stack-sm | 12dp | 段落內間隔(×68) |
| space.stack-xs | 8dp | 相鄰元素(×88) |
| space.stack-2xs | 4dp | 標題與副標題(×38) |
| space.row-padding-v | 4dp | 列表列上下內距(`symmetric(vertical: 4)` ×12) |
| space.button-padding | 24dp / 14dp | 按鈕水平/垂直內距(`app_theme.dart` FilledButton、OutlinedButton) |
| space.tap-target-min | 64×48 | 按鈕 `minimumSize`(同上) |
| space.content-max-width | 960dp | 首頁內容最大寬(`home_screen.dart` `_contentMaxWidth`) |
| space.form-max-width | 600dp | 一般表單/分頁內容最大寬(settings、finance、health、social 共 10+ 處) |
| space.auth-card-max-width | 420dp | 登入/註冊/重設密碼卡片(`_cardMaxWidth`),也用於 assistant 面板 |

## 圓角

| Token | 值 | 出處 |
| --- | --- | --- |
| radius.card | 22dp | `app_theme.dart` `_cardRadius`,`CardThemeData.shape` |
| radius.ledge-card | 20dp | `ledge_card.dart` 的 `borderRadius` 預設(auth 畫面覆寫為 22) |
| radius.input | 14dp | `app_theme.dart` `_inputRadius`,`InputDecorationTheme` 三種 border |
| radius.pill | 999dp | `app_theme.dart` `_pillRadius`,Filled/Outlined 按鈕 |
| radius.chip | 12dp | 小容器 / chip(`BorderRadius.circular(12)` ×8,無具名常數) |
| radius.bar | 8dp | 進度條、細長元素(×3) |
| border.width | 2dp | `_borderWidth`,卡片/輸入框/按鈕統一描邊 |
| shadow.ledge | offset (0,4), blur 0, outline @ 55% alpha | `ledgeShadow(outline)`;**不是** elevation,elevation 一律 0 |

## Breakpoints

僅在 CLAUDE.md 中定義為規範,`lib/` 內**未找到**對應的 `LayoutBuilder` 判斷常數 — 實務上以 `maxWidth` 約束容器取代條件分支。

| Token | 範圍 | 網格欄數(依 CLAUDE.md) |
| --- | --- | --- |
| bp.phone | < 600 logical px | 首頁 spaces grid 2 欄 |
| bp.tablet | 600–899 | 3 欄 |
| bp.desktop | >= 900 | 4 欄 |

## 元件清單

- `LedgeCard` — 圓角 + 2px 描邊 + toy-ledge 陰影的標準卡片容器(diet/water 區塊、settings、auth 表單共用)
- `AsyncStateScaffold` — 全螢幕 loading / reauth / loaded 三態骨架,`onSignInAgain` 為必填出口
- `CardLoading` — 卡片首次載入中的置中 spinner(不畫卡片本體)
- `CardErrorRetry` — 卡片載入失敗時的錯誤訊息 + 重試按鈕(不畫卡片本體)
- `StaleNotice` — 已有內容但重新載入失敗時,附在卡片下方的細列 + 單卡重試
- `EmptyState` — 全app唯二的「這裡沒有東西」樣式,統一標題樣式/間距/圖示尺寸
- `LastLoadedLabel` — 資料畫面頂端的「上次成功載入時間」淡色小字
- `TrackerBusyBar` — 追蹤頁 mutation/reload 進行中的 3px 細條(閒置時仍佔位,避免跳動)
- `TrackerDayNavHeader` — 每日追蹤頁頂端的日期標頭,含 today/yesterday chip
- `TrackerDayNav` — 為 day-keyed 追蹤頁(water/vitals/bowel/exercise)加上可瀏覽的「檢視日」
- `MonthNavHeader` — `‹ 2026-07 ›` 月份切換列(純展示,已格式化文字由外部傳入)
- `MonthPickerDialog` — 月份選擇對話框(`showMonthPicker`)
- `DateField` — 可點擊的標籤化日期顯示欄,`onTap` 為 null 時停用
- `AmountEntryDialog` — 泛型單欄數值輸入對話框,遵循 empty-zero 慣例
- `NumericAmountField` — 固定寬度置中數值欄,`hintText: '0'` 取代字面 "0"
- `LabelValueRow` — 左標籤右數值列,value 為非 flex 子項以避免數字被壓爆
- `FractionalProgressBar` — 圓角描邊軌道 + 填色進度條,fraction 夾在 0..1
- `ShrinkToFitText` — 單行縮放文字,寬度受限時不低於 `minFontSize`
- `AppSheet` — 標準 modal bottom sheet(`isScrollControlled` + `showDragHandle`)
- `Mascot` — 原創 `CustomPaint` 圓臉吉祥物,顏色取自 ColorScheme

## git 狀態自查

```
$ git status --porcelain
?? openspec/changes/menstrual-cycle-day-marker/

$ git rev-parse HEAD
b360d21e9796a66b823a85f998262f8f15e658c1
```

未建立、修改或刪除任何檔案;未執行測試、建置或 git 寫入操作。唯一的 untracked 項目在探查開始前即已存在。

## 尺寸(補充決策 — issue #236 延伸範圍)

| Token | 值 | 用途 |
| --- | --- | --- |
| size.marker | 32dp | 日曆日格標記(既有)與新元件 CycleBadge(首頁磚塊、NextPeriodCard 徽標)共用同一直徑,不新增 marker-lg——兩行內容(數字+單位)已有 `menstrual-cycle-day-marker/design.md` 決策2 的 1.3× 文字縮放上限先例佐證可行,footprint 最小化優先於為每個用途量身訂做尺寸 |
| size.marker-legend | 16dp | 日曆圖例、CycleBadge 圖例的小型色塊(既有值命名) |
| size.tile-min-height | ~132dp(估計值,待覆核) | 首頁磚塊(`_SnapshotTile`)最小高度。現況 110dp 只夠一行主值;本次新增第二行日期(`text.body-small`)+ `space.stack-2xs` 間距,估算 110 + ~22(一行 body-small 含 line-height) = 132。**這是設計階段的估計,非實測值**——需在實作階段以 `test/shared/theme/real_font_metrics_test.dart`(唯一載入真實字型的測試)覆核六態(含 needsOneMore/noRecords 的留白佔位態)在此高度下皆不溢位、且彼此等高,不足則調整此 token,不得憑空假設目前估計值一定夠 |

## 圓角(補充決策)

| Token | 值 | 出處 |
| --- | --- | --- |
| radius.tile | 14dp | 首頁磚塊(`_SnapshotTile`)圓角,現況硬編碼於 `home_screen.dart`。數值恰與 `radius.input` 相同純屬巧合(語意不同:一個是輸入框、一個是儀表板磚塊),故獨立命名,不借用 `radius.input`——未來兩者可能各自演化,共用同一個 token 名稱會讓語意上不相關的元件被綁死在一起改 |

## 邊框寬度(補充決策)

| Token | 值 | 出處 |
| --- | --- | --- |
| border.width-thin | 1dp | 首頁磚塊(`_SnapshotTile`)外框寬度,現況硬編碼。與全站標準的 `border.width`(2dp,卡片/輸入框/按鈕描邊)不同——維持現況 1dp 並獨立命名,不強行改成 2dp:改變既有磚塊外框粗細是本次需求(補徽標與日期)之外的無關視覺變動,不在 issue #236 延伸範圍內 |

## 間距(補充決策)

| Token | 值 | 出處 |
| --- | --- | --- |
| space.tile-gutter | 10dp | `_DashboardSection` 的 `Wrap` spacing/runSpacing(現況硬編碼)。與 `space.stack-xs`(8dp)不同——維持現況 10dp 並獨立命名,不強行對齊 8dp:磚塊格線間距是全站 8 個磚塊共用的既有視覺決定,不在本次變更範圍 |

## Breakpoints(補充決策)

| Token | 值 | 出處 |
| --- | --- | --- |
| bp.section-two-column | 260dp | `_DashboardSection` 的 `twoColumnMinWidth`(現況常數 `_sectionTwoColumnMinWidth`)。命名為獨立 token 而非併入 `bp.*`(phone/tablet/desktop)系列——這是元件層級的容器寬度門檻,與頁面層級的裝置斷點是不同概念,合併命名會誤導成裝置分類 |

## 字級(補充決策)

| Token | 對應 style | 值 | 用途 |
| --- | --- | --- | --- |
| text.label-small | `textTheme.labelSmall` | Material 3 預設(~11px/w500,本專案 `_textTheme()` 未覆寫,沿用 Flutter 內建值) | CycleBadge 徽標內數字、日曆逐格週期天數標記 |
| text.title-medium | `textTheme.titleMedium` | Material 3 預設(~16px/w500,同上未覆寫) | 首頁磚塊主值文字、NextPeriodCard 主文字 |

## 色彩使用規則(補充決策 — 不新增色碼)

- **空心 primary 徽標(upcoming 狀態)內文字**:用 `color.ink`,不新增 `color.primary-text`。理由:pastel 色(`hachiwareBlue`)本來就不得作前景文字(硬性約束),徽標的「這是 primary 語意」已由框色(`color.primary`)承載,內文字改用中性 `color.ink` 即可解決 AA 對比問題,不需要為此新增一個色彩 token——徽標的圖形語意(填色=經期日、空心框=預測)由形狀與框色表達,文字色不必也跟著變色系。
- **實心中性徽標(today 狀態)內文字**:同理用 `color.ink`。`color.outline`(#D8C3A6)作填色,`color.ink` 作文字色的對比關係與全站 `groundLight`(#FBF1E1,同樣是淺色底)配 `color.ink` 的既有用法相近,不需要新增 `on-outline` token。
