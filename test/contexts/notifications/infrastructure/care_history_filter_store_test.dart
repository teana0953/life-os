import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/care_history_period.dart';
import 'package:life_os/contexts/notifications/infrastructure/care_history_filter_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<CareHistoryFilterStore> _store(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return CareHistoryFilterStore(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nothing stored reads as no period, leaving the caller its default',
      () async {
    final store = await _store({});
    expect(store.readPeriod(), isNull);
  });

  test('a span round-trips', () async {
    final store = await _store({});
    await store.writePeriod(const CareHistoryPeriod.span(90));
    expect(store.readPeriod(), const CareHistoryPeriod.span(90));
  });

  test('a custom range round-trips', () async {
    final store = await _store({});
    await store.writePeriod(
      const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
    );
    expect(
      store.readPeriod(),
      const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
    );
  });

  // Writing one kind has to clear the other's keys: a span left behind by an
  // earlier session is read first, so it would win over the custom range the
  // user just picked.
  test('switching from a span to a custom range and back clears the other',
      () async {
    final store = await _store({});
    await store.writePeriod(const CareHistoryPeriod.span(30));
    await store.writePeriod(
      const CareHistoryPeriod.custom('2026-03-01', '2026-03-10'),
    );
    expect(
      store.readPeriod(),
      const CareHistoryPeriod.custom('2026-03-01', '2026-03-10'),
    );
    await store.writePeriod(const CareHistoryPeriod.span(7));
    expect(store.readPeriod(), const CareHistoryPeriod.span(7));
  });

  test('a span the selector does not offer is ignored', () async {
    final store = await _store({'care_history_period_span': 9});
    expect(store.readPeriod(), isNull);
  });

  test('an unparseable stored date is ignored', () async {
    final store = await _store({
      'care_history_period_from': 'not-a-date',
      'care_history_period_to': '2026-05-20',
    });
    expect(store.readPeriod(), isNull);
  });

  test('a half-written custom range is ignored', () async {
    final store = await _store({'care_history_period_from': '2026-03-01'});
    expect(store.readPeriod(), isNull);
  });

  // The backend rejects a range wider than 366 days with a 400, so restoring
  // one would put the screen straight into its error state with no way back
  // except changing the period.
  test('a stored range wider than the backend cap is ignored', () async {
    final store = await _store({
      'care_history_period_from': '2025-01-01',
      'care_history_period_to': '2026-05-20',
    });
    expect(store.readPeriod(), isNull);
  });

  test('a range exactly at the backend cap is kept', () async {
    final store = await _store({
      'care_history_period_from': '2025-05-21',
      'care_history_period_to': '2026-05-21',
    });
    expect(
      store.readPeriod(),
      const CareHistoryPeriod.custom('2025-05-21', '2026-05-21'),
    );
  });

  test('a backwards stored range is ignored', () async {
    final store = await _store({
      'care_history_period_from': '2026-05-20',
      'care_history_period_to': '2026-03-01',
    });
    expect(store.readPeriod(), isNull);
  });
}
