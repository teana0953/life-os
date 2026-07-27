import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
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
                          const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    LedgeCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
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
                              // Whether the row offers a checkbox is decided by
                              // the run as a whole, not by this type's status:
                              // after a run every row sits at `success`, and the
                              // checkboxes have to come back so the user can
                              // re-run a different selection here.
                              selectable: !_isImporting,
                              onSelectedChanged: (value) => setState(() {
                                if (value) {
                                  _selected.add(type);
                                } else {
                                  _selected.remove(type);
                                }
                              }),
                            ),
                        ],
                      ),
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

/// One data type's row in the results card: the type's label, — once known —
/// its result or failure text, and a leading slot that carries the selection
/// checkbox while [selectable], and an icon reflecting its [TypeState.status]
/// while the import runs.
class _TypeResultRow extends StatelessWidget {
  final ImportType type;
  final TypeState state;
  final bool selected;

  /// Whether the selection can be edited at all — false only while an import
  /// is running, so the two meanings of the leading slot never overlap.
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

  Widget _leading(BuildContext context) {
    final theme = Theme.of(context);
    if (selectable) {
      return Checkbox(
        value: selected,
        onChanged: (value) => onSelectedChanged(value ?? false),
      );
    }
    return switch (state.status) {
      TypeStatus.notAttempted => Icon(
        Icons.circle_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      TypeStatus.importing => SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      ),
      TypeStatus.success => Icon(
        Icons.check_circle,
        color: theme.colorScheme.tertiary,
      ),
      TypeStatus.failed => Icon(Icons.error, color: theme.colorScheme.error),
    };
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final resultText = _resultText(loc);
    // While the import runs, a left-out type and a selected one that hasn't
    // started both show an empty circle — dimming the whole row is what tells
    // "this won't run" apart from "this is still queued".
    final dimmed = !selectable && !selected;
    // The result text sits in the subtitle (not the trailing slot) so it wraps
    // instead of overflowing on a narrow phone — the diet row's imported/skipped/
    // glucose line is long, especially in English.
    return Opacity(
      key: Key('import-type-row-${type.name}'),
      opacity: dimmed ? 0.5 : 1,
      child: ListTile(
        leading: _leading(context),
        title: Text(_label(loc)),
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
      ),
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
