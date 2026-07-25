## Why

After running a chaodays import, the 總覽 (overview) still shows pre-import data — the
user has to restart the app to see what was imported. `HealthScaffold._load()` (which
loads all twelve health controllers) runs only once in `initState`, and
`/import/chaodays` is a sibling top-level route pushed on top of `/health`, so coming
back never rebuilds the shell or invalidates the already-loaded controllers. The app has
no pull-to-refresh or any other reload path today.

## What Changes

- **New shared signal** `lib/shared/data_revision.dart`: `DataRevision extends
  ChangeNotifier` with a `revision` counter and `bump()`.
- **`ChaodaysImportController`** takes a `DataRevision` and bumps it once when an import
  run ends having imported at least one type — including a run that fails partway, since
  lifeos data has still changed. A run that writes nothing does not bump.
- **`HealthScaffold`** listens to the `DataRevision` and re-runs its existing `_load()`
  when the revision changes, so the overview, today, trackers, trends, and calendar all
  pick up the imported data.
- **`main.dart`** constructs the single `DataRevision` and passes it to both, so neither
  context depends on the other's controller (both depend only on `shared/`).

The refresh reuses each controller's existing `load()`, which briefly shows its loading
state — accepted here as honest "updating" feedback rather than adding a silent-refresh
path to twelve controllers (see design). Frontend only; no backend, copy, or l10n change.
Gate = lint + `flutter analyze` + `flutter test`.

## Capabilities

### Modified Capabilities

- `chaodays-import-ui`: after a chaodays import writes data, the health screens SHALL
  refresh without an app restart.
