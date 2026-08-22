import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_chat_context.dart';
import 'package:life_os/shared/routing/health_tab.dart';

/// [HealthTab] is two things at once — the `?tab=` wire vocabulary and the
/// health shell's destination *order* — and both halves fail silently when
/// they drift: a reordered enum tells the assistant the user was on 趨勢 when
/// they were on 記錄, a renamed slug drops the tab out of the context line
/// with nothing to go red.
void main() {
  group('HealthTab.fromSlug', () {
    test('parses every slug back to its own value', () {
      for (final tab in HealthTab.values) {
        expect(
          HealthTab.fromSlug(tab.slug),
          tab,
          reason: '${tab.slug} must round-trip',
        );
      }
    });

    test('rejects unknown input rather than defaulting to 總覽', () {
      // Nullable on purpose: `overview` here instead of `null` would make
      // "everything is 總覽" indistinguishable from "this slug is known", and
      // the context line would claim a tab the user never opened.
      for (final unknown in <String?>[
        null,
        '',
        'bogus',
        'Record', // exact and case-sensitive
        'RECORD',
        '2', // the bare index the shell still uses internally
        'dashboard', // a plausible-but-wrong name for 總覽
        'transactions', // a finance slug — the two vocabularies are separate
        ' record',
        'record ',
      ]) {
        expect(
          HealthTab.fromSlug(unknown),
          isNull,
          reason: '"$unknown" is not a health tab slug',
        );
      }
    });
  });

  group('HealthTab order', () {
    test('declaration order is the nav-bar / IndexedStack order', () {
      // The exact list, not a set: reordering two values keeps every
      // membership check green while sending the wrong tab to the assistant.
      expect(HealthTab.values.map((t) => t.slug).toList(), [
        'overview',
        'record',
        'trends',
        'more',
      ]);
    });

    test('each value keeps the index HealthScaffold._index hands it', () {
      // `HealthTab.values[_index]` is the only bridge between the widget's
      // integer selection and the wire vocabulary.
      expect(HealthTab.overview.index, 0);
      expect(HealthTab.record.index, 1);
      expect(HealthTab.trends.index, 2);
      expect(HealthTab.more.index, 3);
    });
  });

  group('vocabulary agreement with AssistantChatContext', () {
    test('every HealthTab slug is a tab the assistant also recognises', () {
      for (final tab in HealthTab.values) {
        final context = AssistantChatContext.fromQuery({
          'ctx': 'health',
          'tab': tab.slug,
        });
        expect(
          context?.tab,
          tab.slug,
          reason:
              '${tab.slug} is what the health shell writes but the assistant '
              'drops it — two naming schemes for one tab',
        );
      }
    });

    test('a slug the enum does not have is dropped by the assistant too', () {
      expect(
        AssistantChatContext.fromQuery({
          'ctx': 'health',
          'tab': 'diet',
        })?.tab,
        isNull,
      );
      expect(HealthTab.fromSlug('diet'), isNull);
    });
  });
}
