# Tasks

## 1. Summary model + port + http adapter (TDD)
- [ ] `chaodays_import_summary.dart`: add ONE optional `waterTargetsImported` (int?), non-null only for diet-target (mirror `glucoseImported`; do NOT add a skipped field — avoid dead state).
- [ ] `import_repository.dart`: add `importDietTarget(idToken, {chaodaysUid, chaodaysPassword, startDate, endDate})`.
- [ ] `http_import_repository.dart`: implement `importDietTarget` → POST `/api/import/chaodays/diet-target`; parse the response → summary(imported=portionTargetsImported, skipped=portionTargetsSkipped, waterTargetsImported=waterTargetsImported); ignore the backend's waterTargetsSkipped. Same error mapping (auth→authFailed, unavailable) as siblings.

## 2. Use case + controller + wiring (TDD)
- [ ] `application/import_diet_target.dart`: thin use case mirroring `import_diet.dart`.
- [ ] `chaodays_import_controller.dart`: add `dietTarget` to `ImportType`; inject `ImportDietTarget`; add its case to `_runImport`.
- [ ] `main.dart`: construct `ImportDietTarget` and pass to the controller.

## 3. Screen + l10n (UI)
- [ ] l10n: add `importTypeDietTarget` ("飲食目標" / "Diet target") + a single-int-placeholder water suffix `importResultWaterTargetSuffix` (" · 水目標 {count}", mirror `importResultGlucoseSuffix`) to app_en.arb + app_zh_Hant.arb WITH @-metadata for the int placeholder; regenerate generated l10n.
- [ ] `chaodays_import_screen.dart`: extend the per-type label mapping so `dietTarget` shows `importTypeDietTarget`; on success show the portion imported/skipped counts plus the water-target count (mirror diet's glucose extra). Row is auto-rendered by the existing `for (type in ImportType.values)` loop.

## 4. Tests + wiring blast radius (enumerated — update ALL)
- [ ] Fakes gaining `importDietTarget`: `test/app_test.dart` (_FakeImportRepository) and `test/contexts/import/presentation/chaodays_import_controller_test.dart` (FakeImportRepository).
- [ ] `ChaodaysImportController` gains a 5th use-case arg — update every construction site: `lib/main.dart`, `test/app_test.dart`, `test/contexts/import/presentation/chaodays_import_screen_test.dart` (2 sites), `test/contexts/import/presentation/chaodays_import_controller_test.dart`.
- [ ] The two exhaustive switches (controller `_runImport`, screen `_TypeResultRow._label`/result) must gain the `dietTarget` case (analyze fails until they do — expected).
- [ ] Tests: use case forwards to repo; http adapter POSTs the right path + parses portion counts + waterTargetsImported; controller runs dietTarget in sequence; widget shows the 「飲食目標」row + its success counts incl. the water suffix (assert via test-locale l10n, no literals).

## 5. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.
