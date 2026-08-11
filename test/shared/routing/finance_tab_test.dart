import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_chat_context.dart';
import 'package:life_os/shared/routing/finance_tab.dart';

/// [FinanceTab] is two things at once — the `?tab=` wire vocabulary and the
/// finance shell's destination *order* — and both halves fail silently when
/// they drift: a reordered enum sends 總負債 to 明細, a renamed slug turns a
/// home tile into a link that quietly lands on 總覽.
void main() {
  group('FinanceTab.fromSlug', () {
    test('parses every slug back to its own value', () {
      for (final tab in FinanceTab.values) {
        expect(
          FinanceTab.fromSlug(tab.slug),
          tab,
          reason: '${tab.slug} must round-trip',
        );
      }
    });

    test('rejects unknown input rather than defaulting to 總覽', () {
      // Nullable on purpose: the fallback lives at the route builder, so this
      // asserts the *parse*. `overview` here instead of `null` would make
      // "everything is 總覽" indistinguishable from "this slug is known".
      for (final unknown in <String?>[
        null,
        '',
        'bogus',
        'NetWorth', // exact and case-sensitive
        'NETWORTH',
        '2', // the old bare index
        'assets', // a plausible-but-wrong name for 淨值
        ' overview',
        'overview ',
      ]) {
        expect(
          FinanceTab.fromSlug(unknown),
          isNull,
          reason: '"$unknown" is not a tab slug',
        );
      }
    });
  });

  group('FinanceTab order', () {
    test('declaration order is the nav-bar / IndexedStack order', () {
      // The exact list, not a set: reordering two values keeps every
      // membership check green while moving both tabs.
      expect(FinanceTab.values.map((t) => t.slug).toList(), [
        'overview',
        'transactions',
        'networth',
        'split',
      ]);
    });

    test('the two lazily-built destinations keep their indices', () {
      expect(FinanceTab.overview.index, 0);
      expect(FinanceTab.transactions.index, 1);
      expect(FinanceTab.networth.index, 2);
      expect(FinanceTab.split.index, 3);
    });
  });

  group('FinanceTab.location', () {
    test('is /finance?tab=<slug>, built as a Uri', () {
      expect(FinanceTab.networth.location.toString(), '/finance?tab=networth');
      expect(FinanceTab.split.location.toString(), '/finance?tab=split');
      expect(FinanceTab.overview.location.toString(), '/finance?tab=overview');
    });

    test('round-trips through the query parameter the route builder reads', () {
      for (final tab in FinanceTab.values) {
        final uri = Uri.parse(tab.location.toString());
        expect(uri.path, '/finance');
        expect(
          FinanceTab.fromSlug(uri.queryParameters[FinanceTab.queryParameter]),
          tab,
        );
        expect(
          uri.queryParameters.length,
          1,
          reason: 'a tile link carries the tab and nothing else',
        );
      }
    });
  });

  group('vocabulary agreement with AssistantChatContext', () {
    test('every FinanceTab slug is a tab the assistant also recognises', () {
      for (final tab in FinanceTab.values) {
        final context = AssistantChatContext.fromQuery({
          'ctx': 'finance',
          'tab': tab.slug,
        });
        expect(
          context?.tab,
          tab.slug,
          reason:
              '${tab.slug} is on /finance but the assistant drops it — two '
              'naming schemes for one tab',
        );
      }
    });

    test('a slug the enum does not have is dropped by the assistant too', () {
      // The other direction of the same guard: without this, adding a value to
      // `AssistantChatContext._tabs` alone stays green.
      expect(
        AssistantChatContext.fromQuery({
          'ctx': 'finance',
          'tab': 'budget',
        })?.tab,
        isNull,
      );
      expect(FinanceTab.fromSlug('budget'), isNull);
    });
  });
}
