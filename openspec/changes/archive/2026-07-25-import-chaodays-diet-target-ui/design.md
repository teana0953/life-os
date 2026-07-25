# Design — add "diet target" to the chaodays import screen (frontend)

## Context
The backend now exposes `POST /api/import/chaodays/diet-target` (imports chaodays
daily menus → daily portion targets + water target). The chaodays import screen
(`ChaodaysImportScreen` + `ChaodaysImportController`) already imports 4 types in
order by iterating `ImportType.values` and rendering one status row per type. Add a
5th type, `dietTarget`, following the identical pattern.

## Decision
- `ImportType` enum gains `dietTarget` (appended last, so it imports after bowel and
  renders as the last row — least disruptive order).
- Port `ImportRepository.importDietTarget(...)` (same signature as the others);
  `HttpImportRepository.importDietTarget` POSTs `/api/import/chaodays/diet-target`
  and parses the backend summary `{ portionTargetsImported, portionTargetsSkipped,
  waterTargetsImported, waterTargetsSkipped }`.
- `ChaodaysImportSummary` gains ONE optional field `waterTargetsImported` (int?,
  non-null only for diet-target) — mirroring `glucoseImported` EXACTLY (one count, no
  skipped, to avoid parsed-but-unshown dead state). For diet-target, `imported` /
  `skipped` carry the **portion** target counts; the backend's water *skipped* count is
  not surfaced (consistent with glucose).
- New thin use case `ImportDietTarget` (mirrors `ImportDiet`); wired in `main.dart`
  and injected into the controller; the controller's `_runImport` switch gains the
  `dietTarget` case.
- l10n: add `importTypeDietTarget` ("飲食目標" / "Diet target") for the row label, and a
  single-placeholder water suffix string mirroring `importResultGlucoseSuffix` (e.g.
  `importResultWaterTargetSuffix` = " · 水目標 {count}") — it MUST carry @-metadata
  declaring its int placeholder in BOTH app_en.arb and app_zh_Hant.arb or gen-l10n
  mis-generates it.

## UI/UX design
- The import screen gains **one more status row** labelled 「飲食目標」, in the same
  card/list as the existing four, using the same not-attempted / importing / success
  / failed visual states and the same per-type result text.
- Success text shows the portion-target imported/skipped counts (same format as the
  other types) plus, when present, the water-target imported count as a suffix on the same row
  (mirroring how diet appends its glucose count via importResultGlucoseSuffix). No new screens, dialogs, or layout — purely an
  additional row driven by the existing `for (type in ImportType.values)` loop, so it
  inherits spacing, theme, and a11y automatically.
- The single "import all" button now runs 5 imports in sequence; the row order is
  weight → diet → water → bowel → diet target.

## Scope
Frontend only (port + http adapter + use case + summary model + controller + screen
label/result + l10n + main wiring + tests). No backend change. Gate =
`bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`.

## Testing
- Use case forwards to the repo; http adapter POSTs the right path and parses the 4
  counts into the summary (portion → imported/skipped, water → optional fields).
- Controller includes `dietTarget` in the sequence and records its state.
- Widget: the screen shows a 「飲食目標」row; on success it shows the portion +
  water counts. l10n asserted via the test-locale helper (no hard-coded literals).
