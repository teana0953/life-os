import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/send_password_reset.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/password_reset_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  Object? resetErrorToThrow;
  final List<String> resetsRequested = [];

  @override
  Future<void> sendPasswordReset(String email) async {
    resetsRequested.add(email);
    if (resetErrorToThrow != null) throw resetErrorToThrow!;
  }

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

final _loc = lookupAppLocalizations(const Locale('en'));

/// [instance] gives each pump its own widget identity. Without it, pumping a
/// second `PasswordResetScreen` into the same tester reuses the first one's
/// `State` — same type, same position — so `sent` is still true and the form
/// the test is looking for is not there.
Future<Widget> _screen(
  _FakeAuthRepository repository, {
  String initialEmail = '',
  String instance = 'a',
}) async {
  SharedPreferences.setMockInitialValues({});
  return l10nTestApp(
    home: PasswordResetScreen(
      key: ValueKey(instance),
      sendPasswordReset: SendPasswordReset(repository),
      localeController: LocaleController(await SharedPreferences.getInstance()),
      initialEmail: initialEmail,
    ),
  );
}

Future<void> _submit(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const Key('email-field')), email);
  await tester.tap(find.byKey(const Key('submit-button')));
  await tester.pumpAndSettle();
}

void main() {
  group('PasswordResetScreen', () {
    testWidgets('an unknown address and a known one look identical', (tester) async {
      // The reason this screen exists in this shape. If the two differ by so
      // much as a word, anyone with a list of addresses can ask which of them
      // use this app — and this app holds financial and health records, so
      // "has an account here" is itself worth not leaking.
      final known = _FakeAuthRepository();
      await tester.pumpWidget(await _screen(known));
      await _submit(tester, 'known@example.com');
      final afterKnown = tester.widget<Text>(find.byKey(const Key('password-reset-message'))).data;
      final knownHasField = find.byKey(const Key('email-field')).evaluate().isNotEmpty;

      final unknown = _FakeAuthRepository()
        ..resetErrorToThrow = const AuthFailure(AuthFailureCode.invalidCredentials);
      await tester.pumpWidget(await _screen(unknown, instance: 'b'));
      await _submit(tester, 'nobody@example.com');
      final afterUnknown = tester.widget<Text>(find.byKey(const Key('password-reset-message'))).data;

      expect(afterUnknown, afterKnown);
      expect(afterKnown, _loc.passwordResetSentBody);
      // And no error line appears in either case — a visible error is a
      // difference too.
      expect(find.byKey(const Key('error-message')), findsNothing);
      // The same shape, not just the same sentence: a form that stayed on one
      // and went away on the other would be as good a signal as any word.
      expect(find.byKey(const Key('email-field')).evaluate().isNotEmpty, knownHasField);
    });

    testWidgets('the confirmation names the spam folder', (tester) async {
      // The commonest reason a reset "does not work": the mail comes from a
      // Firebase noreply address and gets filtered. Learned by walking a real
      // user through it.
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(await _screen(repository));
      await _submit(tester, 'user@example.com');

      expect(
        tester.widget<Text>(find.byKey(const Key('password-reset-message'))).data,
        contains('spam'),
      );
    });

    testWidgets('a malformed address is reported, not swallowed', (tester) async {
      // Not the same as an unknown one: an address that is not an address
      // cannot be anybody's account, so saying so leaks nothing — and staying
      // silent leaves the user waiting for a mail nobody sent.
      final repository = _FakeAuthRepository()
        ..resetErrorToThrow = const AuthFailure(AuthFailureCode.invalidEmail);
      await tester.pumpWidget(await _screen(repository));
      await _submit(tester, 'not-an-address');

      expect(
        tester.widget<Text>(find.byKey(const Key('error-message'))).data,
        _loc.errorInvalidEmail,
      );
      expect(find.byKey(const Key('submit-button')), findsOneWidget);
    });

    testWidgets('a throttled request says to wait, not that it was sent', (tester) async {
      final repository = _FakeAuthRepository()
        ..resetErrorToThrow = const AuthFailure(AuthFailureCode.tooManyRequests);
      await tester.pumpWidget(await _screen(repository));
      await _submit(tester, 'user@example.com');

      expect(
        tester.widget<Text>(find.byKey(const Key('error-message'))).data,
        _loc.errorTooManyResetRequests,
      );
    });

    testWidgets('the address typed on the sign-in screen carries over', (tester) async {
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(await _screen(repository, initialEmail: 'typed@example.com'));

      await tester.tap(find.byKey(const Key('submit-button')));
      await tester.pumpAndSettle();

      // Submitted without retyping: someone who just failed to sign in should
      // not have to get the address right a second time.
      expect(repository.resetsRequested, ['typed@example.com']);
    });

    testWidgets('sending twice is not offered', (tester) async {
      // The service throttles repeats, and a throttled second attempt reads
      // as the first one having failed.
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(await _screen(repository));
      await _submit(tester, 'user@example.com');

      expect(find.byKey(const Key('submit-button')), findsNothing);
      expect(find.byKey(const Key('email-field')), findsNothing);
      expect(repository.resetsRequested, hasLength(1));
    });
  });
}
