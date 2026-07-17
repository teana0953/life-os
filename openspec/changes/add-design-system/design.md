# add-design-system — Chiikawa 可愛風設計系統

## 目標

把 `life-os` 從預設 Material 樣式,升級成一套**Chiikawa 啟發的可愛粉彩設計語言**,落地為 Flutter Material 3 主題,並套用到登入與 home 畫面。亮暗兩版、**responsive**(手機到桌機)。

視覺方向已用 mockup 與使用者對齊(rose-clay 版被否決,改採此可愛風)。

## 設計 Token(正本)

**色彩**(語意角色,亮 → 暗):
- Primary(Hachiware 淡藍):`#8FD3E6`;on-primary 用深墨 `#284A54`(暗版 primary 同色、on 用 `#173038`)。primary-deep `#5EB5D3` 供 focus/border。
- Blush pink `#F6B0C1`(暗 `#EE9DB0`)、Usagi yellow `#FBE08A`(暗 `#EFCE78`)——點綴/次要,不搶主色。
- Ground 奶油 `#FBF1E1` → 暗 `#231D19`;Surface `#FFFDF8` → 暗 `#2E2721`。
- Ink 柔棕 `#5A4A3E`(**文字不用純黑**)→ 暗 `#F3E9DC`;muted `#96836F` → 暗 `#B6A695`。
- Outline 柔棕描邊 `#D8C3A6` → 暗 `#463A31`(卡片/按鈕/輸入框 2px 細邊,呼應手繪線)。
- 語意色(與主色分開):success sage `#8FC79A`、warning honey `#E0A94E`、error `#E98A94`。

**形狀 / 質感**:大圓角(卡片 20–22、輸入框 14、按鈕 pill 999)、2px 柔棕描邊、卡片/主按鈕下方一道柔和「小台階」陰影(玩具感)。

**字體**:圓潤友善 sans。用 OFL 圓體(如 **Baloo 2** 或 **Quicksand**),**bundle 成 pubspec asset**(離線 + 測試可靠,不靠 runtime 抓字),授權註明。層級靠字重(700/800)+ 字級,字級偏大、行高寬鬆(可讀性/無障礙)。

**可讀性**:粉彩按鈕配深墨文字維持 AA 對比;柔棕文字在奶油底對比充足。

## 架構(遵循 repo CLAUDE.md)

- 新增 `lib/shared/theme/`:`app_theme.dart`(`lightTheme`/`darkTheme` 的 `ThemeData`,Material 3,`ColorScheme` 明確覆寫上述角色色 + 元件主題:`FilledButtonTheme`/`OutlinedButtonTheme`、`InputDecorationTheme`、`CardTheme`、`TextTheme`)、`app_colors.dart`(token 常數)。屬 shared 跨 context 技術件。
- `app.dart`:`MaterialApp` 加 `theme: lightTheme`、`darkTheme: darkTheme`、`themeMode: ThemeMode.system`。
- Presentation(login/home)改用主題化元件與 token,**不硬編碼顏色**;behavior 不變(既有測試的 key/文字/流程保留)。
- 原創 mascot(圓萌小臉,非 Chiikawa 角色)以 `CustomPaint`/簡單 widget 實作,放 `lib/shared/widgets/`。

## Responsive

- 用 `LayoutBuilder`/`MediaQuery` 斷點(例如 < 600 手機、≥ 600 平板/桌機)。
- 登入:卡片置中、`maxWidth` 限寬(約 420),不隨寬螢幕拉滿。
- Home:「Your spaces」grid 桌機多欄(如 4 欄)、平板 2–3 欄、手機 1–2 欄;內容置中限寬容器。
- 觸控目標 ≥ 44,字級隨斷點微調。

## 範圍

### 包含
Flutter theme(light/dark token + 元件主題)、字體 bundle、mascot widget、login/home 套新樣式、responsive 版面、repo CLAUDE.md 補「設計系統」節。

### 不包含
新功能/新畫面、未來模組(Health/Finance…)的實作(mockup 的 spaces grid 只是示意,不在本 loop 建)、動畫特效(保持克制,最多按鈕按下的微互動)。

## 測試策略(gate)

- **既有行為測試維持全綠**:restyle 不改流程;若測試以 widget 型別定位(如 `ElevatedButton`→`FilledButton`)需同步更新定位,但保留行為斷言。
- **新增薄測試**:`MaterialApp` 有 light/dark theme 且 `themeMode: system`;`ColorScheme.primary` == Hachiware 藍;theme useMaterial3。
- **responsive 測試**:用 `tester.binding.setSurfaceSize` 在窄/寬兩尺寸下,驗 home grid 欄數不同或登入卡限寬(以可觀察的 widget 屬性斷言)。
- gate:`flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`(沿用)。

## QA / 驗收

- `flutter build web` 成功;實跑 Chrome 截圖 light + dark,對照 mockup 方向(粉彩、柔棕描邊、圓角、mascot、responsive 在窄/寬皆正常)。
- 既有登入端到端不受影響(behavior 不變)。

## 驗收標準
1. `flutter analyze` 無 issue、`flutter test` 全綠、web build 成功。
2. 登入/home 呈現 Chiikawa 可愛風(對照 mockup),亮暗跟隨系統。
3. 窄螢幕(手機)與寬螢幕(桌機)版面皆正常、無溢出。
