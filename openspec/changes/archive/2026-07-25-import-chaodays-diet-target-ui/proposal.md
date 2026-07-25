## Why
The backend can now import chaodays diet targets (`POST /api/import/chaodays/diet-target`),
but the chaodays import screen only offers weight/diet/water/bowel. Add "diet target"
so the user can import their daily portion + water targets from the app like the other
types.

## What Changes
- `ImportType` enum gains `dietTarget`; the import screen renders it as a 5th status
  row automatically (it iterates `ImportType.values`), and the "import all" button
  runs it in sequence (weight → diet → water → bowel → diet target).
- `ImportRepository.importDietTarget` + `HttpImportRepository.importDietTarget`
  (POST `/api/import/chaodays/diet-target`), parsing the backend summary
  (portion + water target imported/skipped).
- `ChaodaysImportSummary` gains optional `waterTargetsImported`/`waterTargetsSkipped`
  (non-null only for diet-target), mirroring diet's optional `glucoseImported`;
  `imported`/`skipped` carry the portion-target counts.
- New `ImportDietTarget` use case, wired in `main.dart` + the controller switch.
- l10n: `importTypeDietTarget` row label + a water-target result string.

Frontend only. Gate = lint + `flutter analyze` + `flutter test`.

## Capabilities

### Modified Capabilities
- `chaodays-import-ui`: the chaodays import screen SHALL offer a "diet target" import
  type alongside weight/diet/water/bowel, importing the user's chaodays daily portion
  and water targets and showing its per-type result, reusing the existing import flow.
