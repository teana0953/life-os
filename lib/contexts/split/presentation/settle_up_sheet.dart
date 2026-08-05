import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../finance/domain/finance_money.dart';
import 'settlement_writer.dart';
import 'split_error_text.dart';
import 'split_expense_sheet.dart' show NumericAmountFieldWide;
import '../../../shared/auth/id_token_provider.dart';

/// The largest amount the backend accepts (a signed 32-bit int) — blocked
/// client-side rather than sent and rejected (mirrors `split_expense_sheet.dart`).
const _maxAmount = 2147483647;

/// Why the amount can't be submitted right now — one value per condition so
/// each gets its own sentence (mirrors `SplitExpenseSheet`'s `_SaveBlock`).
enum _AmountError { required, notWhole, tooLarge }

/// Settles a person-to-person balance in one currency (design.md D0–D5,
/// task 4). Pre-fills the currency's full outstanding amount; the direction
/// (who pays whom) is derived from the sign of [balanceAmount] and is never
/// a choice the user makes — see [fromUserId]/[toUserId].
///
/// Only reachable from a two-person balance row (design D0): `group_id` is
/// always sent as `null` (there is no from/to pair for a group's per-member
/// net figure).
class SettleUpSheet extends StatefulWidget {
  final SettlementWriter writer;
  final IdTokenProvider idToken;

  /// The caller's own user id (design D5c).
  final String selfUserId;

  /// The other person in this two-person balance.
  final String otherUserId;
  final String? otherDisplayName;

  /// This currency's signed balance with [otherUserId] (design D2): positive
  /// means [otherUserId] owes the caller, negative means the caller owes
  /// [otherUserId]. Never zero — a settled currency has no balance row to
  /// open this sheet from.
  final int balanceAmount;
  final String currency;

  /// Today's `YYYY-MM-DD`, the default day for a new settlement.
  final String today;

  const SettleUpSheet({
    super.key,
    required this.writer,
    required this.idToken,
    required this.selfUserId,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.balanceAmount,
    required this.currency,
    required this.today,
  }) : assert(balanceAmount != 0, 'a settled currency has nothing to settle');

  /// Whether [otherUserId] owes the caller (a positive balance, design D2) —
  /// determines both the from/to pair and which heading/warning copy shows.
  bool get otherOwesMe => balanceAmount > 0;

  /// The full outstanding amount for this currency, always positive.
  int get fullAmount => balanceAmount.abs();

  /// Who pays: the debtor, derived from the sign of [balanceAmount] — never
  /// a choice offered to the user (design D1).
  String get fromUserId => otherOwesMe ? otherUserId : selfUserId;

  /// Who receives: the creditor.
  String get toUserId => otherOwesMe ? selfUserId : otherUserId;

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  late String _day;
  bool _saving = false;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = widget.today;
    _amountController.text = formatMinorUnits(widget.fullAmount, widget.currency);
    _amountController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _amountController.removeListener(_onChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The single reason the typed amount can't be submitted, or `null` when
  /// it's valid. A zero-decimal currency (TWD/JPY/KRW) silently rounds a
  /// fractional input via [parseAmountToMinorUnits] — that's the wrong
  /// behaviour here, so a fractional value is refused explicitly rather than
  /// rounded away (design.md task 4.5).
  _AmountError? get _amountError {
    final trimmed = _amountController.text.trim();
    if (trimmed.isEmpty) return _AmountError.required;
    final raw = double.tryParse(trimmed);
    if (raw == null || raw <= 0) return _AmountError.required;
    if (decimalDigitsFor(widget.currency) == 0 && raw != raw.roundToDouble()) {
      return _AmountError.notWhole;
    }
    final minorUnits = parseAmountToMinorUnits(trimmed, widget.currency);
    if (minorUnits == null) return _AmountError.required;
    if (minorUnits > _maxAmount) return _AmountError.tooLarge;
    return null;
  }

  /// The validated amount in minor units, or `null` while [_amountError] is
  /// non-null.
  int? get _amount {
    if (_amountError != null) return null;
    return parseAmountToMinorUnits(_amountController.text, widget.currency);
  }

  /// The amount by which the typed value exceeds the full outstanding
  /// amount, or `null` when it doesn't (a partial or exact payment).
  int? get _overpayExcess {
    final amount = _amount;
    if (amount == null || amount <= widget.fullAmount) return null;
    return amount - widget.fullAmount;
  }

  bool get _canSubmit => !_saving && _amount != null;

  String _amountErrorText(AppLocalizations loc, _AmountError error) => switch (error) {
    _AmountError.required => loc.settleUpAmountRequired,
    _AmountError.notWhole => loc.settleUpAmountMustBeWhole,
    _AmountError.tooLarge => loc.settleUpAmountTooLarge,
  };

  Future<void> _pickDay() async {
    final initial = DateTime.tryParse(_day) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (!_canSubmit || amount == null) return;

    setState(() => _saving = true);
    final seqBefore = widget.writer.mutationErrorSeq;
    final note = _noteController.text.trim();
    await widget.writer.createSettlement(
      await widget.idToken(),
      groupId: null,
      fromUserId: widget.fromUserId,
      toUserId: widget.toUserId,
      amount: amount,
      currency: widget.currency,
      day: _day,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    if (widget.writer.mutationErrorSeq != seqBefore) {
      setState(() => _saving = false);
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(splitErrorText(loc, widget.writer.mutationError!))),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final otherName = widget.otherDisplayName ?? loc.splitUnknownMember;
    final amountError = _amountError;
    final overpayExcess = _overpayExcess;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherOwesMe
                    ? loc.settleUpTitleReceiving(otherName)
                    : loc.settleUpTitlePaying(otherName),
                key: const Key('settle-up-title'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // No `errorText`: the field is a hard `SizedBox(width: 120)`
                  // and `InputDecoration.errorText` defaults to
                  // `errorMaxLines: 1`, so a sentence handed to it is clipped
                  // — silently, raising no layout error — at every width,
                  // locale and text scale, leaving a disabled Confirm with
                  // no readable reason. The reason goes on its own
                  // full-width line below instead (`SplitExpenseSheet`'s
                  // `_SaveBlock` shape).
                  NumericAmountFieldWide(
                    fieldKey: const Key('settle-up-amount-field'),
                    controller: _amountController,
                    label: loc.financeAmountLabel,
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      widget.currency,
                      key: const Key('settle-up-currency'),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              if (amountError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _amountErrorText(loc, amountError),
                  key: const Key('settle-up-amount-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('settle-up-day-field'),
                onPressed: _pickDay,
                child: Text('${loc.splitDayLabel}: $_day'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('settle-up-note-field'),
                controller: _noteController,
                decoration: InputDecoration(labelText: loc.financeNoteLabel),
              ),
              if (overpayExcess != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.otherOwesMe
                      ? loc.settleUpOverpayWarningYouWillOwe(
                          otherName,
                          formatMinorUnitsForDisplay(overpayExcess, widget.currency),
                        )
                      : loc.settleUpOverpayWarningTheyWillOwe(
                          otherName,
                          formatMinorUnitsForDisplay(overpayExcess, widget.currency),
                        ),
                  key: const Key('settle-up-overpay-warning'),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('settle-up-confirm-button'),
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(loc.settleUpConfirmButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
