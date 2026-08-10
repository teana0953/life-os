import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_chat_context.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

/// [label] now renders its month through the locale-aware
/// `monthYearLabel` convention (design E), not the raw `YYYY-MM` — this
/// mirrors that formatting for the fixed English test locale, independent
/// of the production helper, so the expectations below aren't just
/// echoing the implementation back at itself.
String _expectedMonthLabel(int year, int month) =>
    DateFormat.yMMM('en').format(DateTime(year, month));

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('AssistantChatContext.fromQuery', () {
    test('a full finance query keeps tab and month', () {
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'finance',
        'tab': 'transactions',
        'month': '2025-11',
      })!;
      expect(ctx.tab, 'transactions');
      expect(ctx.month, '2025-11');
    });

    test('no ctx, or an unknown ctx, is no context at all', () {
      expect(AssistantChatContext.fromQuery(const {}), isNull);
      expect(
        AssistantChatContext.fromQuery({
          'ctx': 'health',
          'tab': 'transactions',
          'month': '2025-11',
        }),
        isNull,
      );
    });

    test('a garbage tab is dropped, not echoed — the month survives', () {
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'finance',
        'tab': 'banana',
        'month': '2025-11',
      })!;
      expect(ctx.tab, isNull);
      expect(ctx.month, '2025-11');
    });

    test('a garbage month is dropped, not echoed — the tab survives', () {
      // 'transactions', not 'split': split drops the month unconditionally
      // (see the cross-field test below), so it can't tell "the regex
      // rejected this month" apart from "split never shows a month" — this
      // fixture must land on a tab where the month survives when it's
      // well-formed, so a bad month failing to survive is actually the
      // regex doing its job.
      for (final bad in [
        '2025-13',
        '2025-00',
        '2025-1',
        'banana',
        '20251-11',
      ]) {
        final ctx = AssistantChatContext.fromQuery({
          'ctx': 'finance',
          'tab': 'transactions',
          'month': bad,
        })!;
        expect(ctx.month, isNull, reason: '"$bad" must not survive as a month');
        expect(ctx.tab, 'transactions');
      }
    });

    test('split with a WELL-FORMED month still drops the month — split has no '
        'month to show, no matter how the query got typed', () {
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'finance',
        'tab': 'split',
        'month': '2025-11',
      })!;
      expect(ctx.tab, 'split');
      expect(
        ctx.month,
        isNull,
        reason:
            'no screen ever shows "分帳 2025-11" — a hand-typed URL '
            'must not be able to fabricate that view',
      );
    });

    test('missing tab and month still give a bare finance context', () {
      final ctx = AssistantChatContext.fromQuery({'ctx': 'finance'})!;
      expect(ctx.tab, isNull);
      expect(ctx.month, isNull);
    });
  });

  group('AssistantChatContext.label', () {
    testWidgets('names the space, the tab and the month', (tester) async {
      late String actual;
      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            builder: (context) {
              const ctx = AssistantChatContext(
                tab: 'transactions',
                month: '2025-11',
              );
              actual = ctx.label(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        actual,
        loc.assistantContextViewing(
          '${loc.spaceFinance} ${loc.financeTabTransactions} '
          '${_expectedMonthLabel(2025, 11)}',
        ),
      );
    });

    testWidgets('omits what it does not have instead of inventing it', (
      tester,
    ) async {
      late String splitOnly;
      late String monthOnly;
      late String bare;
      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            builder: (context) {
              splitOnly = const AssistantChatContext(
                tab: 'split',
              ).label(context);
              monthOnly = const AssistantChatContext(
                month: '2025-11',
              ).label(context);
              bare = const AssistantChatContext().label(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        splitOnly,
        loc.assistantContextViewing(
          '${loc.spaceFinance} ${loc.financeTabSplit}',
        ),
      );
      expect(
        monthOnly,
        loc.assistantContextViewing(
          '${loc.spaceFinance} ${_expectedMonthLabel(2025, 11)}',
        ),
      );
      expect(bare, loc.assistantContextViewing(loc.spaceFinance));
    });
  });
}
