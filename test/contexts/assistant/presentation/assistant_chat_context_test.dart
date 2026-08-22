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
          'ctx': 'banana',
          'tab': 'transactions',
          'month': '2025-11',
        }),
        isNull,
      );
      // Case-sensitive: the shells write these strings, nothing else does.
      expect(AssistantChatContext.fromQuery({'ctx': 'Health'}), isNull);
      expect(AssistantChatContext.fromQuery({'ctx': ''}), isNull);
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

  group('AssistantChatContext.fromQuery — health', () {
    test('a full health query keeps the space, the tab and the day', () {
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'health',
        'tab': 'overview',
        'day': '2026-08-22',
      })!;
      expect(ctx.space, AssistantContextSpace.health);
      expect(ctx.tab, 'overview');
      expect(ctx.day, '2026-08-22');
      expect(ctx.month, isNull, reason: 'health is day-keyed, not month-keyed');
    });

    test('ctx=finance still parses as the finance space', () {
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'finance',
        'tab': 'transactions',
        'month': '2025-11',
      })!;
      expect(ctx.space, AssistantContextSpace.finance);
      expect(ctx.day, isNull);
    });

    test('a garbage tab is dropped, the module survives', () {
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'health',
        'tab': 'banana',
      })!;
      expect(ctx.space, AssistantContextSpace.health);
      expect(ctx.tab, isNull);
    });

    test('a finance slug on a health entry is not a health tab', () {
      // The two vocabularies are separate on purpose: 'transactions' names no
      // health screen, so it must be dropped rather than echoed as a tab.
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'health',
        'tab': 'transactions',
        'day': '2026-08-22',
      })!;
      expect(ctx.tab, isNull);
    });

    test('a day that is not a real calendar date is dropped, not echoed — '
        'the tab survives', () {
      // 'overview', not any other tab: 記錄/趨勢/更多 all drop the day
      // unconditionally (the cross-field test below), so they could not tell
      // "this is not a real date" apart from "that tab never shows a day".
      // 總覽 is the only tab where a WELL-FORMED day survives, so a bad day
      // failing to survive there is actually the date validation doing its
      // job.
      //
      // '2026-02-31' and '0000-00-00' are the two a bare shape regex would
      // wave through, and DateTime's constructor then rolls them over into a
      // wrong-but-plausible date the context line would state as fact.
      for (final bad in [
        'banana',
        '2026-02-31',
        '0000-00-00',
        '2026-13-01',
        '2026-8-22',
        '2026-08-22T00:00:00',
        '',
      ]) {
        final ctx = AssistantChatContext.fromQuery({
          'ctx': 'health',
          'tab': 'overview',
          'day': bad,
        })!;
        expect(ctx.day, isNull, reason: '"$bad" must not survive as a day');
        expect(ctx.tab, 'overview');
      }
    });

    test('總覽 keeps a well-formed day — it is the only day-keyed tab', () {
      final ctx = AssistantChatContext.fromQuery({
        'ctx': 'health',
        'tab': 'overview',
        'day': '2026-08-22',
      })!;
      expect(ctx.day, '2026-08-22');
    });

    test('記錄/趨勢/更多 with a WELL-FORMED day still drop it — none of them '
        'is day-keyed, no matter how the query got typed', () {
      // 記錄 is in this list, not the one above: the 記錄 tab's body is a hub
      // of buttons that never paints a date, so a context line saying
      // 「健康 記錄 2026年8月22日」 would describe a view no screen has ever
      // shown — the same rule that drops 分帳's month.
      for (final tab in ['record', 'trends', 'more']) {
        final ctx = AssistantChatContext.fromQuery({
          'ctx': 'health',
          'tab': tab,
          'day': '2026-08-22',
        })!;
        expect(ctx.tab, tab);
        expect(
          ctx.day,
          isNull,
          reason:
              'no screen ever shows "健康 $tab 2026-08-22" — a hand-typed URL '
              'must not be able to fabricate that view',
        );
      }
    });

    test('missing tab and day still give a bare health context', () {
      final ctx = AssistantChatContext.fromQuery({'ctx': 'health'})!;
      expect(ctx.space, AssistantContextSpace.health);
      expect(ctx.tab, isNull);
      expect(ctx.day, isNull);
    });
  });

  group('AssistantChatContext.label — health', () {
    testWidgets('names the space, the tab and the day', (tester) async {
      late String actual;
      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            builder: (context) {
              actual = AssistantChatContext.fromQuery({
                'ctx': 'health',
                'tab': 'overview',
                'day': '2026-08-22',
              })!.label(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // Spelled out, not `loc.assistantContextViewing(loc.spaceHealth …)`:
      // an expectation built from the same ARB entries the widget reads is a
      // string compared with itself and can never go red.
      expect(actual, 'Started from: Health Overview Aug 22, 2026');
      // The day is a date, never the raw wire string.
      expect(actual, isNot(contains('2026-08-22')));
    });

    testWidgets('記錄 is named without a day, even when the query carried '
        'a well-formed one', (tester) async {
      late String actual;
      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            builder: (context) {
              actual = AssistantChatContext.fromQuery({
                'ctx': 'health',
                'tab': 'record',
                'day': '2026-08-22',
              })!.label(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(actual, 'Started from: Health Record');
      expect(
        actual,
        isNot(contains('Aug')),
        reason: 'the 記錄 hub shows no date anywhere on screen',
      );
    });

    testWidgets('a dropped day and a dropped tab appear nowhere in the text', (
      tester,
    ) async {
      late String badDay;
      late String badTab;
      late String record;
      late String trends;
      late String more;
      late String bare;
      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            builder: (context) {
              // 'overview': the only tab a well-formed day survives on, so a
              // missing 'banana' here is the date check, not the tab rule.
              badDay = AssistantChatContext.fromQuery({
                'ctx': 'health',
                'tab': 'overview',
                'day': 'banana',
              })!.label(context);
              badTab = AssistantChatContext.fromQuery({
                'ctx': 'health',
                'tab': 'zzz',
                'day': '2026-08-22',
              })!.label(context);
              record = AssistantChatContext.fromQuery({
                'ctx': 'health',
                'tab': 'record',
                'day': '2026-08-22',
              })!.label(context);
              trends = AssistantChatContext.fromQuery({
                'ctx': 'health',
                'tab': 'trends',
                'day': '2026-08-22',
              })!.label(context);
              more = AssistantChatContext.fromQuery({
                'ctx': 'health',
                'tab': 'more',
                'day': '2026-08-22',
              })!.label(context);
              bare = AssistantChatContext.fromQuery({
                'ctx': 'health',
              })!.label(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(badDay, 'Started from: Health Overview');
      expect(badDay, isNot(contains('banana')));
      // Only the tab goes — the module itself was stated, and the day is
      // kept exactly as finance keeps a month when its tab is unreadable
      // (design D4: the cross-field drop names the tabs that show no day,
      // and an unreadable slug is not one of them). The unreadable slug
      // itself must not survive in any form.
      expect(badTab, 'Started from: Health Aug 22, 2026');
      expect(badTab, isNot(contains('zzz')));
      expect(record, 'Started from: Health Record');
      expect(trends, 'Started from: Health Trends');
      expect(more, 'Started from: Health More');
      expect(bare, 'Started from: Health');
    });

    testWidgets('the finance line is unchanged, spelled out', (tester) async {
      late String actual;
      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            builder: (context) {
              actual = AssistantChatContext.fromQuery({
                'ctx': 'finance',
                'tab': 'transactions',
                'month': '2025-11',
              })!.label(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(actual, 'Started from: Finance Transactions Nov 2025');
    });
  });
}
