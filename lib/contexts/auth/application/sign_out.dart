import '../domain/auth_repository.dart';

class SignOut {
  final AuthRepository _repository;

  SignOut(this._repository);

  Future<void> call() {
    return _repository.signOut();
  }
}
