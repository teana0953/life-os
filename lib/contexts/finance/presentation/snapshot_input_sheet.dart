import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/networth_account.dart';
import 'finance_controller.dart';
import 'networth_controller.dart';

/// Parses a typed market value: a whole number of 0 or more. Returns `null`
/// for anything else — including a decimal, which is never silently rounded
/// (TWD has no minor units, and a silent round is exactly the data-corruption
/// class this repo keeps re-growing).
int? parseSnapshotValue(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value < 0) return null;
  return value;
}

/// The bottom sheet that records one account's market value for the selected
/// month (design.md 4.3).
///
/// **0 vs empty**: `0` is a legal value (an emptied account), so — unlike the
/// budget sheet's "≤ 0 is invalid" rule — only content that doesn't parse to
/// a non-negative whole number is rejected, with an `errorText` and a
/// disabled save (never a silent clear). An **empty** field means "this month
/// is unrecorded": nothing is sent, so save stays disabled rather than
/// pretending to write.
class SnapshotInputSheet extends StatefulWidget {
  final NetWorthController controller;
  final String idToken;
  final NetWorthAccount account;

  /// The account's value for the selected month, or `null` when unrecorded.
  final int? currentValue;

  const SnapshotInputSheet({
    super.key,
    required this.controller,
    required this.idToken,
    required this.account,
    required this.currentValue,
  });

  @override
  State<SnapshotInputSheet> createState() => _SnapshotInputSheetState();
}

class _SnapshotInputSheetState extends State<SnapshotInputSheet> {
  final _valueController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.currentValue;
    if (current != null) _valueController.text = current.toString();
    _valueController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _valueController.removeListener(_onChanged);
    _valueController.dispose();
    super.dispose();
  }

  bool get _isEmpty => _valueController.text.trim().isEmpty;

  /// Non-empty content that doesn't parse to a non-negative whole number.
  bool get _isInvalid => !_isEmpty && parseSnapshotValue(_valueController.text) == null;

  Future<void> _save() async {
    final value = parseSnapshotValue(_valueController.text);
    if (value == null) return;

    setState(() => _saving = true);
    await widget.controller.saveSnapshot(
      widget.idToken,
      accountId: widget.account.id,
      value: value,
    );
    if (!mounted) return;
    if (widget.controller.status == FinanceStatus.loaded) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.status == FinanceStatus.needsReauth
              ? loc.pleaseSignInAgain
              : loc.financeSaveFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      // Lift the sheet above the on-screen keyboard, mirroring the other
      // finance sheets.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.networthSnapshotSheetTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.account.name, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                key: const Key('snapshot-field'),
                controller: _valueController,
                enabled: !_saving,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                decoration: InputDecoration(
                  labelText: loc.networthValueLabel,
                  errorText: _isInvalid ? loc.networthInvalidValue : null,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('snapshot-save'),
                  onPressed: _saving || _isEmpty || _isInvalid ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.financeSaveButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
