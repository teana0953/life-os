import '../domain/auth_repository.dart';

/// Use case: create an account with email and password.
class SignUp {
  final AuthRepository _repository;

  SignUp(this._repository);

  Future<void> call(String email, String password) {
    return _repository.signUp(email, password);
  }
}
