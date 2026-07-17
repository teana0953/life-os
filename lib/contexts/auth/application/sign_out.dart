import '../domain/auth_repository.dart';

/// Use case: sign out the current user.
class SignOut {
  final AuthRepository _repository;

  SignOut(this._repository);

  Future<void> call() {
    return _repository.signOut();
  }
}
