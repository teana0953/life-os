# Tasks

## 1. Date-range batching (TDD, pure function)
- [ ] Test first (red): `test/contexts/import/domain/date_range_batches_test.dart` —
  - `start == end` → one batch covering that single day
  - a range exactly the batch size → one batch
  - one day longer than the batch size → two batches, contiguous (second starts the day after the first ends), non-overlapping, together covering exactly the requested range
  - a multi-year range → every batch is at most the batch size, and concatenating them reproduces the original range with no gaps or overlaps
  - a range spanning a leap day / year boundary → still contiguous
- [ ] `lib/contexts/import/domain/date_range_batches.dart`: a named constant for the batch size (**183 days** — see design D1 for why a fixed day count and not six calendar months) and a pure function taking the range and returning the ordered list of `(start, end)` sub-ranges. Work in `DateTime`; the caller formats with the existing `dayString`.

## 2. Summary merging (TDD, pure)
- [ ] Test first (red): `imported`/`skipped` are summed; `glucoseImported` all-null stays null; some-null sums only the non-null batches (**this is the case that silently loses data if written naively**); same for `waterTargetsImported`; merging a single summary returns it unchanged.
- [ ] `ChaodaysImportSummary`: add the merge. Keep it a pure function/factory on the domain class — no controller state involved.

## 3. Controller: selected types + batch loop (TDD)
- [ ] Test first (red), against the existing fake use cases:
  - only the selected types are invoked; unselected ones stay `notAttempted` and their use case is never called
  - a range longer than the batch size invokes the *same* type's use case once per batch, with contiguous non-overlapping sub-ranges in order
  - the type's `TypeState` ends with one merged summary, not the last batch's
  - a failure in a middle batch stops everything: no further batches for that type, no later types, status maps as today (`authFailed` / `needsReauth` / `unavailable`)
  - `DataRevision` still bumps exactly once when at least one batch succeeded, including a run that aborts partway
  - batch progress is observable on `TypeState` while a type is running
- [ ] `ChaodaysImportController.import`: take the selected types (a `Set<ImportType>`); iterate `ImportType.values` filtered by it (keeps the fixed display order); for each, loop its batches calling the existing use case per batch; merge summaries; keep the existing failure handling and the `anySucceeded` → bump rule.
- [ ] `TypeState`: carry batch progress (current / total) while importing. Keep it absent/1-of-1 for single-batch runs so the UI can tell them apart.

## 4. Screen: selection + batch progress (TDD)
- [ ] Test first (red):
  - every type is selected on first build
  - clearing all types disables the submit button
  - submitting with one type selected passes only that type to the controller
  - the selection controls are disabled while importing
  - a type importing with several batches shows the batch counter; a single-batch one does not
- [ ] `ChaodaysImportScreen`: hold the selected set in state (default all); pass it to `controller.import`; extend `_canSubmit` to require at least one type.
- [ ] `_TypeResultRow`: show a `Checkbox` in the leading slot before the import starts (replacing the not-attempted circle), and the existing status icon once it is running/finished — one slot, two non-overlapping meanings. Disable the checkbox while importing.
- [ ] Batch counter next to the type name while importing with more than one batch.
- [ ] l10n: add the batch-progress string to `app_en.arb` (with a `description`), `app_zh_Hant.arb`, `app_zh.arb`, then regenerate `lib/l10n/generated` and commit the diff (see CLAUDE.md i18n rules — no hard-coded strings in presentation).

## 5. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green, with the existing import controller/screen tests still passing under the all-selected default.

## 6. On-device verification (manual — needs the user, after deploy)
- [ ] Import a range longer than 183 days and confirm it completes instead of being blocked, with the batch counter advancing.
- [ ] Import with only one type selected and confirm the others are left untouched.
