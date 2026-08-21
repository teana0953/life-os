import 'package:life_os/shared/screen_batch/section_outcome.dart';
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
  group('BowelController.applyBatchSection', () {
    const record = BowelDay(
      day: '2026-07-18',
      count: 2,
      isNormal: true,
      note: 'fine',
    );

    test(
      'ok lands the identical state load() lands for the same payload',
      () async {
        final at = DateTime(2026, 7, 18, 9, 30);
        final repository = FakeBowelRepository()..dayToReturn = record;
        final viaLoad = BowelController(
          GetBowelDay(repository),
          SaveBowelDay(repository),
          clock: () => at,
        );
        await viaLoad.load('token', '2026-07-18');

        final viaBatch = BowelController(
          GetBowelDay(FakeBowelRepository()),
          SaveBowelDay(FakeBowelRepository()),
          clock: () => at,
        );
        viaBatch.claimBatchRound();
        viaBatch.applyBatchSection(const SectionOk(record));

        expect(viaBatch.status, viaLoad.status);
        expect(viaBatch.error, viaLoad.error);
        expect(viaBatch.lastLoadedAt, viaLoad.lastLoadedAt);
        expect(viaBatch.day!.count, viaLoad.day!.count);
        // The editable draft, not just the record: load() resets it too, and a
        // batch apply that skipped it would leave the screen's fields showing
        // the previous day.
        expect(viaBatch.count, viaLoad.count);
        expect(viaBatch.isNormal, viaLoad.isNormal);
        expect(viaBatch.note, viaLoad.note);
        expect(viaBatch.hasUnsavedChanges, viaLoad.hasUnsavedChanges);
      },
    );

    test('unavailable reaches the fetch-failed state', () {
      final controller = _controller(FakeBowelRepository());

      controller.claimBatchRound();
      controller.applyBatchSection(const SectionUnavailable<BowelDay>());

      expect(controller.status, BowelStatus.error);
      expect(controller.error, BowelError.fetchFailed);
      expect(controller.day, isNull);
    });

    test('reauth reaches needsReauth', () {
      final controller = _controller(FakeBowelRepository());

      controller.claimBatchRound();
      controller.applyBatchSection(const SectionReauth<BowelDay>());

      expect(controller.status, BowelStatus.needsReauth);
    });

    // A section with no claim at all (nobody called `claimBatchRound`) must
    // never apply by accident.
    test('a section nobody claimed a round for is dropped', () {
      final controller = _controller(FakeBowelRepository());

      controller.applyBatchSection(const SectionOk(record));

      expect(controller.day, isNull);
    });

    test(
      'a section is dropped when a load starts after the round was claimed',
      () async {
        final controller = _controller(FakeBowelRepository());
        controller.claimBatchRound();
        final other = controller.load('token', '2026-07-19');

        controller.applyBatchSection(const SectionOk(record));
        expect(controller.day, isNull);

        await other;
      },
    );

    // Same shape, but the day-nav load has already COMPLETED by the time the
    // stale batch section for the round's original day arrives.
    test(
      'a section is dropped when a load already landed after the round was claimed',
      () async {
        final repository = FakeBowelRepository()
          ..dayToReturn = const BowelDay(
            day: '2026-07-19',
            count: 1,
            isNormal: true,
            note: '',
          );
        final controller = _controller(repository);
        controller.claimBatchRound();
        await controller.load('token', '2026-07-19');
        expect(controller.day!.day, '2026-07-19');

        controller.applyBatchSection(const SectionOk(record));

        expect(controller.day!.day, '2026-07-19');
      },
    );

    // The over-correction a day comparison would cause: a round whose day
    // simply differs from whatever day the controller already holds must
    // still apply, as long as nothing navigated since the round was claimed
    // (e.g. the round catching a stale controller up to a fresher day).
    test(
      'a section applies even when its day differs from the day already held, '
      'as long as nothing navigated since the round was claimed',
      () async {
        final repository = FakeBowelRepository()
          ..dayToReturn = const BowelDay(
            day: '2026-07-17',
            count: 0,
            isNormal: null,
            note: '',
          );
        final controller = _controller(repository);
        await controller.load('token', '2026-07-17');
        expect(controller.day!.day, '2026-07-17');

        controller.claimBatchRound();
        controller.applyBatchSection(const SectionOk(record));

        expect(controller.day!.day, record.day);
        expect(controller.count, record.count);
      },
    );
  });

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

  group('BowelController.hasUnsavedChanges', () {
    test('is false right after a load and true after a draft edit', () async {
      final repository = FakeBowelRepository()
        ..dayToReturn = const BowelDay(
          day: '2026-07-18',
          count: 1,
          isNormal: true,
          note: 'ok',
        );
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      expect(controller.hasUnsavedChanges, isFalse);

      controller.setCount(2);
      expect(controller.hasUnsavedChanges, isTrue);
    });

    test('returns to false after a successful save', () async {
      final repository = FakeBowelRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      controller.setNote('changed');
      expect(controller.hasUnsavedChanges, isTrue);

      await controller.save('token', '2026-07-18');
      expect(controller.hasUnsavedChanges, isFalse);
    });
  });

  group('BowelController.lastLoadedAt', () {
    final at = DateTime(2026, 7, 18, 9, 41);

    BowelController controllerWithClock(FakeBowelRepository repository) =>
        BowelController(
          GetBowelDay(repository),
          SaveBowelDay(repository),
          clock: () => at,
        );

    test('is null before the first successful load', () {
      final controller = controllerWithClock(FakeBowelRepository());
      expect(controller.lastLoadedAt, isNull);
    });

    test('is set to the clock value on a successful load', () async {
      final controller = controllerWithClock(FakeBowelRepository());

      await controller.load('token', '2026-07-18');

      expect(controller.lastLoadedAt, at);
    });

    test('is left unchanged when a load fails (needsReauth)', () async {
      final repository = FakeBowelRepository();
      final controller = controllerWithClock(repository);
      await controller.load('token', '2026-07-18');
      final firstLoad = controller.lastLoadedAt;

      repository.getError = const BowelReauthenticationRequired();
      await controller.load('token', '2026-07-18');

      expect(controller.status, BowelStatus.needsReauth);
      expect(controller.lastLoadedAt, firstLoad);
    });

    test('stays null after a failed load with no prior success', () async {
      final repository = FakeBowelRepository()
        ..getError = const BowelFetchFailure('boom');
      final controller = controllerWithClock(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, BowelStatus.error);
      expect(controller.lastLoadedAt, isNull);
    });
  });
}
