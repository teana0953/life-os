import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/domain/auth_repository.dart';
import 'chaodays_import_controller.dart';

/// Full-screen chaodays import form: a chaodays account/password (used only
/// for this import, never stored), a start/end date range, and a checkbox per
/// data type (all selected by default), then a one-tap import of the selected
/// types with per-type progress and results.
class ChaodaysImportScreen extends StatefulWidget {
  final ChaodaysImportController controller;
  final AuthRepository authRepository;

  /// Returns the current time, used as the date pickers' `lastDate` (a
  /// future date can't be imported). Defaults to [DateTime.now]; tests
  /// inject a fixed clock.
  final DateTime Function() clock;

  const ChaodaysImportScreen({
    super.key,
    required this.controller,
    required this.authRepository,
    this.clock = DateTime.now,
  });

  @override
  State<ChaodaysImportScreen> createState() => _ChaodaysImportScreenState();
}

class _ChaodaysImportScreenState extends State<ChaodaysImportScreen> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  /// The types the next import will run. Everything starts selected, so an
  /// untouched form imports exactly what it did before this was selectable.
  final Set<ImportType> _selected = {...ImportType.values};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _accountController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _accountController.removeListener(_onChanged);
    _passwordController.removeListener(_onChanged);
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _isImporting =>
      widget.controller.status == ImportStatus.importing;

  bool get _canSubmit =>
      !_isImporting &&
      _selected.isNotEmpty &&
      _accountController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _start != null &&
      _end != null &&
      !_end!.isBefore(_start!);

  DateTime get _today => widget.clock();

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? _today,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (picked != null) {
      setState(() {
        _start = picked;
        // Keep the range valid: a start after the current end clears the end.
        if (_end != null && _end!.isBefore(picked)) _end = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start ?? _today,
      // Can't pick an end before the start, so the range is always valid.
      firstDate: _start ?? DateTime(2000),
      lastDate: _today,
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit() async {
    final idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await widget.controller.import(
      idToken,
      types: _selected,
      chaodaysUid: _accountController.text,
      chaodaysPassword: _passwordController.text,
      startDate: dayString(_start!),
      endDate: dayString(_end!),
    );
  }

  String? _errorText(AppLocalizations loc) {
    return switch (widget.controller.status) {
      ImportStatus.authFailed => loc.importErrorAuthFailed,
      ImportStatus.unavailable => loc.importErrorUnavailable,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final appBar = AppBar(title: Text(loc.importTitle));

    return AsyncStateScaffold(
      isLoading: false,
      isReauth: widget.controller.status == ImportStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        final theme = Theme.of(context);
        final errorText = _errorText(loc);
        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    LedgeCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            loc.importCredentialsNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('import-account-field'),
                            controller: _accountController,
                            enabled: !_isImporting,
                            // No autofill hints: these are chaodays credentials we
                            // promise not to store, so we don't invite the OS /
                            // browser password manager to save them.
                            decoration: InputDecoration(
                              labelText: loc.importAccountLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('import-password-field'),
                            controller: _passwordController,
                            enabled: !_isImporting,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: loc.importPasswordLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _DateField(
                                  fieldKey: const Key('import-start-date'),
                                  label: loc.importStartDateLabel,
                                  value: _start,
                                  placeholder: loc.importSelectDateLabel,
                                  onTap: _isImporting ? null : _pickStart,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DateField(
                                  fieldKey: const Key('import-end-date'),
                                  label: loc.importEndDateLabel,
                                  value: _end,
                                  placeholder: loc.importSelectDateLabel,
                                  onTap: _isImporting ? null : _pickEnd,
                                ),
                              ),
                            ],
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              errorText,
                              key: const Key('import-error-message'),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    LedgeCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(
                              loc.importTypesTitle,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          if (widget.controller.status == ImportStatus.done)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                key: const Key('import-done-message'),
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    loc.importDoneMessage,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          for (final type in ImportType.values)
                            _TypeResultRow(
                              type: type,
                              state: widget.controller.typeStates[type]!,
                              selected: _selected.contains(type),
                              // Whether the checkbox can be changed is decided
                              // by the run as a whole, not by this type's
                              // status: after a run every row sits at
                              // `success`, so a per-type condition would leave
                              // the checkboxes locked for good and there would
                              // be no way to re-run a different selection here.
                              selectable: !_isImporting,
                              onSelectedChanged: (value) {
                                setState(() {
                                  if (value) {
                                    _selected.add(type);
                                  } else {
                                    _selected.remove(type);
                                  }
                                });
                                // Only this row: its last result was about a
                                // run this type is no longer signed up for the
                                // same way. The other rows were not touched, so
                                // theirs still stand.
                                widget.controller.clearType(type);
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Last, after the selection it acts on: the controls that
                    // decide what runs come before the control that runs it,
                    // so "nothing selected → button disabled" is visible as
                    // cause and effect.
                    FilledButton(
                      key: const Key('import-submit-button'),
                      onPressed: _canSubmit ? _submit : null,
                      child: _isImporting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : Text(loc.importSubmitButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One data type's row in the results card: a leading checkbox saying whether
/// the next import will run this type, the type's label, — once known — its
/// result or failure text, and a trailing slot reflecting its
/// [TypeState.status] — an icon once there is something to report, an
/// equally wide blank before that. The two slots are permanent and never swap
/// roles, so a finished run's outcome stays on screen next to the checkbox
/// that decides the next one.
class _TypeResultRow extends StatelessWidget {
  final ImportType type;
  final TypeState state;
  final bool selected;

  /// Whether the selection can be edited — false only while an import is
  /// running, which locks the checkbox rather than taking it away.
  final bool selectable;
  final ValueChanged<bool> onSelectedChanged;

  const _TypeResultRow({
    required this.type,
    required this.state,
    required this.selected,
    required this.selectable,
    required this.onSelectedChanged,
  });

  String _label(AppLocalizations loc) => switch (type) {
    ImportType.weight => loc.importTypeWeight,
    ImportType.diet => loc.importTypeDiet,
    ImportType.water => loc.importTypeWater,
    ImportType.bowel => loc.importTypeBowel,
    ImportType.dietTarget => loc.importTypeDietTarget,
  };

  String? _resultText(AppLocalizations loc) {
    if (state.status != TypeStatus.success) {
      return state.status == TypeStatus.failed ? loc.importTypeFailed : null;
    }
    final summary = state.summary!;
    var text = loc.importResultSummary(summary.imported, summary.skipped);
    final glucose = summary.glucoseImported;
    if (glucose != null) text += loc.importResultGlucoseSuffix(glucose);
    final waterTarget = summary.waterTargetsImported;
    if (waterTarget != null) {
      text += loc.importResultWaterTargetSuffix(waterTarget);
    }
    return text;
  }

  /// The trailing slot's content, decided by *this type's* status rather than
  /// the run's: after a run the overall status is `done` while an individual
  /// row the user has just re-selected has nothing left to report, and only
  /// the per-type status can tell those apart.
  Widget _statusIcon(ThemeData theme, AppLocalizations loc) {
    final key = Key('import-type-status-${type.name}');
    return switch (state.status) {
      // Never run, or just cleared: an empty box the width of an icon, so the
      // first result to arrive doesn't shove the label sideways. No spoken
      // description either — there is no status to describe.
      TypeStatus.pristine => SizedBox(key: key, height: 24, width: 24),
      // The rest carry a description: the row merges into one semantics node,
      // so without it the icon's meaning never reaches a screen reader.
      TypeStatus.notAttempted => Icon(
        Icons.circle_outlined,
        key: key,
        color: theme.colorScheme.onSurfaceVariant,
        semanticLabel: loc.importStatusNotAttempted,
      ),
      TypeStatus.importing => SizedBox(
        key: key,
        height: 20,
        width: 20,
        // A progress indicator has no `semanticLabel` — it takes
        // `semanticsLabel` instead.
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: importRunningIconColor(theme.colorScheme),
          semanticsLabel: loc.importStatusImporting,
        ),
      ),
      TypeStatus.success => Icon(
        Icons.check_circle,
        key: key,
        color: importSuccessIconColor(theme.colorScheme),
        semanticLabel: loc.importStatusSuccess,
      ),
      TypeStatus.failed => Icon(
        Icons.error,
        key: key,
        color: theme.colorScheme.error,
        semanticLabel: loc.importStatusFailed,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final resultText = _resultText(loc);
    // CheckboxListTile rather than a ListTile holding a Checkbox: it merges the
    // row into one semantics node — a checkbox named after the type — instead
    // of a button node and a same-named checkbox node read out back to back.
    // It also gives the whole row as the hit area, which is what the user aims
    // at (the label, not the box).
    //
    // The result text sits in the subtitle (not the trailing slot) so it wraps
    // instead of overflowing on a narrow phone — the diet row's imported/skipped/
    // glucose line is long, especially in English.
    return CheckboxListTile(
      key: Key('import-type-row-${type.name}'),
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: selectable
          ? (value) => onSelectedChanged(value ?? false)
          : null,
      // `enabled` follows `onChanged`, so while the import runs the tile is
      // disabled — which is what a screen reader needs to hear. The greying
      // that comes with it only reaches the title (it rides the tile's
      // DefaultTextStyle), so the title spells its color out the way the
      // subtitle below already does, and keeps full contrast while the user
      // reads the running rows.
      title: Text(
        _label(loc),
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      subtitle: resultText == null
          ? null
          : Text(
              resultText,
              style: TextStyle(
                color: state.status == TypeStatus.failed
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
      secondary: _statusIcon(theme, loc),
    );
  }
}

/// A labelled, tappable date display (mirrors the menstrual screen's private
/// `_DateField`): shows the formatted [value] or a [placeholder] when unset.
class _DateField extends StatelessWidget {
  final Key fieldKey;
  final String label;
  final DateTime? value;
  final String placeholder;
  final VoidCallback? onTap;

  const _DateField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          key: fieldKey,
          onPressed: onTap,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value == null ? placeholder : mediumDateLabel(context, value!),
            ),
          ),
        ),
      ],
    );
  }
}
