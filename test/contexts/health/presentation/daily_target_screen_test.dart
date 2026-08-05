import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;
  DailyTargetWithRemaining? afterSetTarget;
  double? receivedBaseStaple;

  /// Every staple target [setTarget] was called with, in order — saving the
  /// same draft twice leaves the same state, so only the call list can tell
  /// one save from two.
  final List<double> setTargetCalls = [];

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return afterSetTarget ?? targetToReturn!;
  }

  @override
  Future<DailyTarget> setTarget(
    String idToken, {
    required String day,
    required double baseStaple,
    required double baseMeat,
    required double baseFruit,
    required double baseVeg,
    double? bonusStaple,
    double? bonusMeat,
    double? bonusFruit,
    double? bonusVeg,
  }) async {
    setTargetCalls.add(baseStaple);
    receivedBaseStaple = baseStaple;
    return DailyTarget.fromJson({
      'id': 'target-1',
      'day': day,
      'base_staple': baseStaple,
      'base_meat': baseMeat,
      'base_fruit': baseFruit,
      'base_veg': baseVeg,
      'bonus_staple': bonusStaple ?? 0,
      'bonus_meat': bonusMeat ?? 0,
      'bonus_fruit': bonusFruit ?? 0,
      'bonus_veg': bonusVeg ?? 0,
    });
  }
}

DailyTargetWithRemaining _target({double baseStaple = 0, double loggedStaple = 9}) =>
    DailyTargetWithRemaining.fromJson({
      'day': '2026-07-18',
      'base': {'staple': baseStaple, 'meat': 8, 'fruit': 5, 'veg': 2},
      'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'effective': {'staple': baseStaple, 'meat': 8, 'fruit': 5, 'veg': 2},
      'logged': {'staple': loggedStaple, 'meat': 3, 'fruit': 1, 'veg': 0},
      'remaining': {
        'staple': baseStaple - loggedStaple,
        'meat': 5,
        'fruit': 4,
        'veg': 2,
      },
    });

void main() {
  group('DailyTargetScreen', () {
    testWidgets('tapping the staple increment control raises the draft and remaining computes', (
      tester,
    ) async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = _target(baseStaple: 11.5, loggedStaple: 9);
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );
      await controller.load('token-123', '2026-07-18');
      repository.afterSetTarget = _target(baseStaple: 12, loggedStaple: 9);

      await tester.pumpWidget(
        l10nTestApp(
          home: DailyTargetScreen(
            controller: controller,
            idToken: () async => 'token-123',
            day: '2026-07-18',
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('daily-target-staple-increment')));
      await tester.pump();

      expect(controller.draftBaseStaple, 12);

      await tester.tap(find.byKey(const Key('save-target-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedBaseStaple, 12);
      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietRemainingOfCategory(3)), findsOneWidget);
    });

    testWidgets(
      'staple target 12 / logged 9 shows the bar ~3/4 filled and "3 remaining"',
      (tester) async {
        final repository = FakeDailyTargetRepository()
          ..targetToReturn = _target(baseStaple: 12, loggedStaple: 9);
        final controller = DailyTargetController(
          GetDailyTargetWithRemaining(repository),
          SetDailyTarget(repository),
        );
        await controller.load('token-123', '2026-07-18');

        await tester.pumpWidget(
          l10nTestApp(
            home: DailyTargetScreen(
              controller: controller,
              idToken: () async => 'token-123',
              day: '2026-07-18',
              onSignInAgain: () {},
            ),
          ),
        );
        await tester.pump();

        const barKey = Key('daily-target-staple-progress');
        final fill = tester.widget<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(barKey),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        expect(fill.widthFactor, closeTo(0.75, 0.0001));

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.dietRemainingOfCategory(3)), findsOneWidget);
      },
    );

    testWidgets('shows the muted bonus note', (tester) async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = _target(baseStaple: 12, loggedStaple: 9);
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );
      await controller.load('token-123', '2026-07-18');

      await tester.pumpWidget(
        l10nTestApp(
          home: DailyTargetScreen(
            controller: controller,
            idToken: () async => 'token-123',
            day: '2026-07-18',
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pump();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.byKey(const Key('daily-target-bonus-note')), findsOneWidget);
      expect(find.text(loc.dietBonusNote), findsOneWidget);
    });

    testWidgets('calls onSaved after a successful save', (tester) async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = _target(baseStaple: 12, loggedStaple: 9);
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );
      await controller.load('token-123', '2026-07-18');
      var savedCalled = false;

      await tester.pumpWidget(
        l10nTestApp(
          home: DailyTargetScreen(
            controller: controller,
            idToken: () async => 'token-123',
            day: '2026-07-18',
            onSaved: () => savedCalled = true,
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('save-target-button')));
      await tester.pumpAndSettle();

      expect(savedCalled, isTrue);
    });

    // The ID token is resolved at request time, so between the tap and the
    // controller's `saving` status there is a whole token round trip during
    // which nothing in the controller has changed yet. That window has to be
    // closed by the screen itself, or a second tap starts a second write.
    group('while the ID token is still resolving', () {
      /// Pumps a loaded screen whose token provider is held open by [gate].
      Future<void> pumpGatedToken(
        WidgetTester tester,
        FakeDailyTargetRepository repository,
        Completer<void> gate,
      ) async {
        final controller = DailyTargetController(
          GetDailyTargetWithRemaining(repository),
          SetDailyTarget(repository),
        );
        await controller.load('token-123', '2026-07-18');
        await tester.pumpWidget(
          l10nTestApp(
            home: DailyTargetScreen(
              controller: controller,
              idToken: () async {
                await gate.future;
                return 'token-123';
              },
              day: '2026-07-18',
              onSignInAgain: () {},
            ),
          ),
        );
        await tester.pump();
      }

      // Two taps inside one frame: the disable only takes effect on the next
      // rebuild, so the second tap still reaches the enabled button and only
      // the re-entrancy check in `_save` can drop it.
      testWidgets('a same-frame second Save tap writes only once', (
        tester,
      ) async {
        final repository = FakeDailyTargetRepository()
          ..targetToReturn = _target(baseStaple: 12, loggedStaple: 9);
        final gate = Completer<void>();
        await pumpGatedToken(tester, repository, gate);

        await tester.tap(find.byKey(const Key('save-target-button')));
        await tester.tap(find.byKey(const Key('save-target-button')));

        gate.complete();
        await tester.pumpAndSettle();

        expect(repository.setTargetCalls, [12]);
      });

      // The visible half: the button disables during token resolution, not
      // only once the controller reaches `saving` — so a later tap can't land
      // either.
      testWidgets(
        'the Save button is disabled and a later tap writes nothing more',
        (tester) async {
          final repository = FakeDailyTargetRepository()
            ..targetToReturn = _target(baseStaple: 12, loggedStaple: 9);
          final gate = Completer<void>();
          await pumpGatedToken(tester, repository, gate);

          await tester.tap(find.byKey(const Key('save-target-button')));
          await tester.pump(const Duration(milliseconds: 400));

          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('save-target-button')),
                )
                .onPressed,
            isNull,
          );

          await tester.tap(
            find.byKey(const Key('save-target-button')),
            warnIfMissed: false,
          );
          await tester.pump();

          gate.complete();
          await tester.pumpAndSettle();

          expect(repository.setTargetCalls, [12]);
        },
      );
    });
  });

  // This screen is the second host of the shared `CategoryProgressBar` (the
  // other is TodayScreen) and had no width guard at all: on main its four
  // bars overflowed by 196/140/168/281px at 360dp/en/2x. Guarding it here
  // keeps the shared widget's narrow-width fix from silently regressing
  // through a host that no other test pumps narrow.
  group('narrow-width layout guard', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'the screen lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, 2400));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final repository = FakeDailyTargetRepository()
                ..targetToReturn = _target(baseStaple: 12, loggedStaple: 9);
              final controller = DailyTargetController(
                GetDailyTargetWithRemaining(repository),
                SetDailyTarget(repository),
              );
              await controller.load('token-123', '2026-07-18');

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(
                  l10nTestApp(
                    locale: locale,
                    home: DailyTargetScreen(
                      controller: controller,
                      idToken: () async => 'token-123',
                      day: '2026-07-18',
                      onSignInAgain: () {},
                    ),
                  ),
                );
                await tester.pumpAndSettle();
              });

              expect(
                find.byKey(const Key('daily-target-staple-progress')).evaluate(),
                isNotEmpty,
              );
            },
          );
        }
      }
    }
  });
}
