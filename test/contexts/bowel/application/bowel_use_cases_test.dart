import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';

class FakeBowelRepository implements BowelRepository {
  BowelDay dayToReturn = const BowelDay(
    day: '2026-07-18',
    count: 1,
    isNormal: true,
    note: 'ok',
  );

  String? receivedGetDay;
  String? receivedSaveDay;
  int? receivedCount;
  bool? receivedIsNormal;
  String? receivedNote;

  @override
  Future<BowelDay> getDay(String idToken, String day) async {
    receivedGetDay = day;
    return dayToReturn;
  }

  @override
  Future<BowelDay> save(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  }) async {
    receivedSaveDay = day;
    receivedCount = count;
    receivedIsNormal = isNormal;
    receivedNote = note;
    return BowelDay(day: day, count: count, isNormal: isNormal, note: note);
  }
}

void main() {
  test('BowelDay.fromJson maps snake_case with a nullable is_normal', () {
    final day = BowelDay.fromJson({
      'day': '2026-07-18',
      'count': 3,
      'is_normal': null,
      'note': 'loose',
    });

    expect(day.day, '2026-07-18');
    expect(day.count, 3);
    expect(day.isNormal, isNull);
    expect(day.note, 'loose');
  });

  test('GetBowelDay delegates to the repository', () async {
    final repository = FakeBowelRepository();
    final result = await GetBowelDay(repository).call('token', '2026-07-18');

    expect(repository.receivedGetDay, '2026-07-18');
    expect(result.count, 1);
  });

  test('SaveBowelDay delegates the whole record to the repository', () async {
    final repository = FakeBowelRepository();
    final saved = await SaveBowelDay(repository).call(
      'token',
      day: '2026-07-18',
      count: 2,
      isNormal: false,
      note: 'note',
    );

    expect(repository.receivedSaveDay, '2026-07-18');
    expect(repository.receivedCount, 2);
    expect(repository.receivedIsNormal, false);
    expect(repository.receivedNote, 'note');
    expect(saved.count, 2);
  });
}
