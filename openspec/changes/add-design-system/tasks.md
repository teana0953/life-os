# Tasks: add-design-system

## 1. Theme 基礎

- [x] 1.1 `assets/fonts/`:bundle 一個圓潤 OFL 字體(Baloo 2 或 Quicksand),`pubspec.yaml` 註冊 font family + assets;授權/來源註明。若無法取得字體檔,fallback 用系統字並在 design 註記(但優先 bundle)
- [x] 1.2 `lib/shared/theme/app_colors.dart`:定義亮/暗 token 常數(primary Hachiware 藍、pink、yellow、cream ground、soft-brown ink/outline、sage/honey/error 語意色),對齊 design.md 的 hex
- [x] 1.3 `lib/shared/theme/app_theme.dart`:`lightTheme`/`darkTheme`(Material 3、`useMaterial3: true`),明確 `ColorScheme` + 元件主題(`FilledButtonTheme`/`OutlinedButtonTheme` pill+描邊+ledge 陰影、`InputDecorationTheme` 圓角描邊、`CardTheme` 圓角描邊、`TextTheme` 圓體字級);先寫測試(theme 存在、primary 色、useMaterial3)

## 2. Mascot

- [ ] 2.1 `lib/shared/widgets/mascot.dart`:原創圓萌小臉 widget(腮紅、圓眼),尺寸可調;非 Chiikawa 角色本尊。widget 測試能 render

## 3. App 接線

- [ ] 3.1 `lib/app.dart`:`MaterialApp` 加 `theme`/`darkTheme`/`themeMode: ThemeMode.system`;既有 auth-state 路由與錯誤畫面改用主題色;既有測試維持綠(必要時更新 widget 定位但保留行為斷言)

## 4. 畫面重構(behavior 不變)

- [ ] 4.1 `LoginScreen`:套主題化元件(brand + mascot、卡片、圓角輸入、pill 主按鈕、錯誤態、loading);**responsive**——卡片置中 `maxWidth`≈420,寬螢幕不拉滿;不硬編碼顏色;既有 widget 測試維持綠(更新定位不改行為)
- [ ] 4.2 `HomeScreen`:套主題化(問候 header、profile 卡、Signed-in pill、Your spaces grid 示意);**responsive** grid 欄數隨寬度(手機 1–2、桌機多欄),內容置中限寬;既有測試維持綠

## 5. Responsive 測試 + 收尾

- [ ] 5.1 responsive 測試:用 `tester.binding.setSurfaceSize` 在窄(如 360×800)與寬(如 1200×800)兩尺寸下,驗登入卡限寬 / home grid 欄數不同,且無 overflow(pump 後無 exception)
- [ ] 5.2 repo `CLAUDE.md` 補「設計系統」節(token 位置、元件慣例、responsive 斷點、新畫面如何沿用 theme);`flutter analyze` 無 issue、`flutter test` 全綠
