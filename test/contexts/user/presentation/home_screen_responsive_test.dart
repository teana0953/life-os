import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getProfile(String idToken) async => UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<HomeController> _pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = HomeController(
    GetProfile(_FakeProfileRepository()),
    SignOut(_FakeAuthRepository()),
  );
  await controller.load('token-123');
  final localeController = await testLocaleController();
  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: HomeScreen(controller: controller, localeController: localeController),
    ),
  );
  await tester.pump();
  return controller;
}

SliverGridDelegateWithFixedCrossAxisCount _gridDelegate(WidgetTester tester) {
  final gridView = tester.widget<GridView>(find.byKey(const Key('spaces-grid')));
  return gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  group('HomeScreen responsive layout', () {
    testWidgets('narrow phone width: spaces grid uses fewer columns, no overflow', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(360, 800));

      expect(tester.takeException(), isNull);
      expect(_gridDelegate(tester).crossAxisCount, 2);
    });

    testWidgets('wide desktop width: spaces grid uses more columns', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(1200, 800));

      expect(tester.takeException(), isNull);
      expect(_gridDelegate(tester).crossAxisCount, 4);
    });
  });
}
