# Tasks — Diet UX follow-ups

## 1. Manual entry as a bottom sheet
- [ ] 1.1 `_openManualEntry(meal)`: `Navigator.push(full-screen)` → `showModalBottomSheet(
      isScrollControlled: true, showDragHandle: true, clipBehavior: Clip.antiAlias,
      shape: rounded top _dietSheetCornerRadius, builder: ManualEntryScreen)`, opened
      from the dictionary sheet (second layer). `ManualEntryScreen` drops its
      Scaffold/AppBar for a thin sheet body (SafeArea → Padding(viewInsets) →
      SingleChildScrollView → form), mirroring EditEntryScreen/LogEntryScreen. On
      save it pops itself + onSaved; the "added" snackbar shows on the dictionary
      sheet's messenger. Controller save logic unchanged. Adjust the old
      "manual entry pushes a full-screen route" tests to expect the sheet.

## 2. Add to an existing snack group
- [ ] 2.1 `today_screen.dart` snack-group card gains an "add to this snack"
      control (`Key('add-to-snack-<name>')`) → new `onAddToSnackGroup(String)`
      callback (nullable, mirroring onAddToMeal). Coexists with the snack area's
      `onAddSnack`.
- [ ] 2.2 Shell wires `onAddToSnackGroup(name)` → `_openDictionarySheet(name)`
      (seed that exact snack name, no renumber). Widget test: seeded to that name,
      not the next number.

## 3. Browse-only dictionary from Today's header
- [ ] 3.1 `_openDictionarySheet` / `_DictionarySheet` gain a `browseOnly` flag
      (default false): when true, no `_LoggingMealBar`, no `_currentMeal` (browse has
      no session), and the hosted `DictionaryScreen` gets `browseOnly: true` AND
      **`onManualEntry: null`** (suppress the manual-entry logging path too — it's
      gated by `onManualEntry != null`, not browseOnly). Same shared style + height
      cap. Open via a dedicated `_openDictionaryBrowse()`.
- [ ] 3.2 `DictionaryScreen` gains `browseOnly` (default false): when true, a row
      tap does NOT call `onSelectItem` (row onTap and the trailing favorite
      IconButton are already separate); portions + favorite toggle still shown/work;
      no food-detail view. When false, current behavior unchanged.
- [ ] 3.3 Today's `_DayNavBar` header gains a food-dictionary `IconButton`
      (`Key('open-dictionary-button')`, localized tooltip) → `_openDictionaryBrowse()`
      opening the browse-only sheet. New ARB key; regenerate l10n.

## 4. Tests + verify
- [ ] 4.1 Widget tests: manual entry opens as a sheet (not push) + style + save
      pops + snackbar; snack-group "add to this snack" seeds that name (no
      increment) while "add snack" seeds next; header dictionary button opens a
      browse-only sheet (no logging bar, row tap doesn't log, favorite still works).
- [ ] 4.2 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` green.
