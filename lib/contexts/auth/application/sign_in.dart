import '../domain/auth_repository.dart';

class SignIn {
  final AuthRepository _repository;

  SignIn(this._repository);

  Future<void> call(String email, String password) {
    return _repository.signIn(email, password);
  }
}
