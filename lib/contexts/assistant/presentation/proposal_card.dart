import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../finance/domain/finance_money.dart';
import '../../finance/domain/finance_type.dart';
import '../domain/transaction_draft.dart';
import 'assistant_controller.dart';

/// One transaction confirmation card. Everything it shows comes off
/// [ProposalState.draft] — the same object [AssistantController.accept]
/// saves — so what the user reads and what gets written cannot diverge.
///
/// Five live states (pending / saving / saved / failed / categoryNotFound)
/// and one dead end: an unrenderable proposal, which has no draft and so no
/// accept button at all.
///
/// `categoryNotFound` keeps a live button on purpose. Its message sends the
/// user off to create the category, so pressing again on their return has to
/// re-resolve it — refusing to write into a wrong category is the honest
/// part, and making the user retype the request is not.
class ProposalCard extends StatelessWidget {
  final ProposalState state;

  /// Position in the transcript, used only to key the card's widgets so
  /// tests can address one card among several.
  final int entryIndex;
  final int proposalIndex;

  /// Invoked on accept; `ProposalCard` itself never decides whether a tap is
  /// allowed twice — the controller's status guard does.
  final VoidCallback onAccept;

  const ProposalCard({
    super.key,
    required this.state,
    required this.entryIndex,
    required this.proposalIndex,
    required this.onAccept,
  });

  Key _key(String part) =>
      Key('assistant-proposal-$part-$entryIndex-$proposalIndex');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final draft = state.draft;

    final card = Container(
      key: _key('card'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
        boxShadow: ledgeShadow(theme.colorScheme.outline),
      ),
      child: draft == null
          ? Text(
              loc.assistantProposalUnrenderable,
              key: _key('unrenderable'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : _draftBody(context, theme, loc, draft),
    );
    return card;
  }

  Widget _draftBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations loc,
    TransactionDraft draft,
  ) {
    final typeLabel = draft.type == FinanceType.expense
        ? loc.financeTypeExpense
        : loc.financeTypeIncome;
    final amountText =
        '$typeLabel ${formatMinorUnitsForDisplay(draft.amount, draft.currency)} ${draft.currency}';
    final String? categoryName = draft.categoryName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(loc.assistantProposalTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          amountText,
          key: _key('amount'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          categoryName == null
              ? loc.assistantProposalNoCategory
              : loc.assistantProposalCategoryRow(categoryName),
          key: _key('category'),
        ),
        Text(loc.assistantProposalDateRow(draft.day), key: _key('day')),
        if (draft.note != null)
          Text(loc.assistantProposalNoteRow(draft.note!), key: _key('note')),
        const SizedBox(height: 12),
        ..._statusArea(theme, loc),
      ],
    );
  }

  List<Widget> _statusArea(ThemeData theme, AppLocalizations loc) {
    switch (state.status) {
      case ProposalStatus.saved:
        // No button at all once saved: a disabled button would still say
        // "there is an action here"; there isn't.
        return [
          Text(
            loc.assistantProposalSaved,
            key: _key('saved'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ];
      case ProposalStatus.categoryNotFound:
        final String? name = state.draft?.categoryName;
        return [
          Text(
            name == null
                ? loc.assistantProposalNoCategory
                : loc.assistantProposalCategoryNotFound(name),
            key: _key('category-not-found'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          // Live, not disabled: the message above tells the user to go and
          // create the category, so the button they come back to has to try
          // again. A dead button would make that instruction a lie.
          FilledButton(
            key: _key('accept'),
            onPressed: onAccept,
            child: Text(loc.assistantProposalRetryAccept),
          ),
        ];
      case ProposalStatus.failed:
      case ProposalStatus.pending:
      case ProposalStatus.saving:
        final saving = state.status == ProposalStatus.saving;
        return [
          if (state.status == ProposalStatus.failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                loc.assistantProposalSaveFailed,
                key: _key('save-failed'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          FilledButton(
            key: _key('accept'),
            // Disabled while saving — with the controller's own status guard
            // this is the double lock against a double tap recording twice.
            onPressed: saving ? null : onAccept,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(loc.assistantProposalAccept),
          ),
        ];
    }
  }
}
