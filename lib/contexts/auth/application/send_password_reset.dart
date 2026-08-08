import '../domain/auth_exceptions.dart';
import '../domain/auth_repository.dart';

/// Use case: email a password-reset link, **without revealing whether the
/// address has an account**.
///
/// Firebase reports an unknown address as an error. Surfacing it would make
/// this endpoint an account-enumeration oracle: anyone with a list of email
/// addresses could ask which of them use this app, and this app holds
/// financial and health records — "has an account here" is itself something
/// worth not leaking.
///
/// So an unknown address is swallowed and the caller is told the same thing
/// either way. A **malformed** address is not: an address that is not an
/// address cannot be anybody's account, so reporting it leaks nothing and
/// saves the user from waiting for a mail that was never going to arrive.
class SendPasswordReset {
  final AuthRepository _repository;

  SendPasswordReset(this._repository);

  Future<void> call(String email) async {
    try {
      await _repository.sendPasswordReset(email);
    } on AuthFailure catch (failure) {
      // `user-not-found` reaches here as `invalidCredentials`, which is also
      // where `wrong-password` lands — a code reset can never produce. The
      // shared code is deliberate: giving "no such user" its own value would
      // put a distinguishable outcome one careless `switch` away from the
      // sign-in screen, which must not distinguish it either.
      if (failure.code == AuthFailureCode.invalidCredentials) return;
      rethrow;
    }
  }
}
