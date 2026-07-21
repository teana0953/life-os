import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_exceptions.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_controller.dart';

class FakeBowelRepository implements BowelRepository {
  BowelDay dayToReturn = const BowelDay(
    day: '2026-07-18',
    count: 0,
    isNormal: null,
    note: '',
  );

  Object? getError;
  Object? saveError;

  int? savedCount;
  bool? savedIsNormal;
  String? savedNote;

  @override
  Future<BowelDay> getDay(String idToken, String day) async {
    if (getError != null) throw getError!;
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
    if (saveError != null) throw saveError!;
    savedCount = count;
    savedIsNormal = isNormal;
    savedNote = note;
    return BowelDay(day: day, count: count, isNormal: isNormal, note: note);
  }
}

BowelController _controller(FakeBowelRepository repository) =>
    BowelController(GetBowelDay(repository), SaveBowelDay(repository));

void main() {
  group('BowelController.load', () {
    test('loads a day and populates the editable draft', () async {
      final repository = FakeBowelRepository()
        ..dayToReturn = const BowelDay(
          day: '2026-07-18',
          count: 2,
          isNormal: true,
          note: 'fine',
        );
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, BowelStatus.loaded);
      expect(controller.count, 2);
      expect(controller.isNormal, true);
      expect(controller.note, 'fine');
    });

    test('a 401 surfaces needsReauth rather than crashing', () async {
      final repository = FakeBowelRepository()
        ..getError = const BowelReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, BowelStatus.needsReauth);
    });

    test('a fetch failure surfaces an error state', () async {
      final repository = FakeBowelRepository()
        ..getError = const BowelFetchFailure('boom');
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, BowelStatus.error);
      expect(controller.error, BowelError.fetchFailed);
    });

    test('loading a different day resets the draft to that day', () async {
      final repository = FakeBowelRepository()
        ..dayToReturn = const BowelDay(
          day: '2026-07-18',
          count: 2,
          isNormal: true,
          note: 'fine',
        );
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      // The user edits the draft...
      controller.setCount(9);
      controller.setNote('edited');

      // ...then a different day loads, resetting the draft.
      repository.dayToReturn = const BowelDay(
        day: '2026-07-17',
        count: 0,
        isNormal: null,
        note: '',
      );
      await controller.load('token', '2026-07-17');

      expect(controller.count, 0);
      expect(controller.isNormal, isNull);
      expect(controller.note, '');
    });
  });

  group('BowelController draft mutations', () {
    test('setCount floors at zero', () async {
      final controller = _controller(FakeBowelRepository());
      await controller.load('token', '2026-07-18');

      controller.setCount(-1);
      expect(controller.count, 0);

      controller.setCount(3);
      expect(controller.count, 3);
    });

    test('setIsNormal and setNote update the draft without saving', () async {
      final repository = FakeBowelRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      controller.setIsNormal(false);
      controller.setNote('note');

      expect(controller.isNormal, false);
      expect(controller.note, 'note');
      // Nothing was persisted.
      expect(repository.savedCount, isNull);
    });
  });

  group('BowelController.save', () {
    test('upserts the draft and reflects the saved state', () async {
      final repository = FakeBowelRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      controller.setCount(2);
      controller.setIsNormal(true);
      controller.setNote('great');
      await controller.save('token', '2026-07-18');

      expect(repository.savedCount, 2);
      expect(repository.savedIsNormal, true);
      expect(repository.savedNote, 'great');
      expect(controller.status, BowelStatus.loaded);
    });

    test('a save failure surfaces error and keeps the entered draft', () async {
      final repository = FakeBowelRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      controller.setCount(4);
      controller.setIsNormal(false);
      controller.setNote('kept');
      repository.saveError = const BowelFetchFailure('boom');
      await controller.save('token', '2026-07-18');

      expect(controller.status, BowelStatus.error);
      // The draft is untouched so the user's values survive.
      expect(controller.count, 4);
      expect(controller.isNormal, false);
      expect(controller.note, 'kept');
    });

    test('a save 401 surfaces needsReauth', () async {
      final repository = FakeBowelRepository()
        ..saveError = const BowelReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      await controller.save('token', '2026-07-18');

      expect(controller.status, BowelStatus.needsReauth);
    });
  });
}
