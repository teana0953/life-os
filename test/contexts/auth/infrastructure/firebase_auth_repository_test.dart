import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/infrastructure/firebase_auth_repository.dart';

/// Compile-time pin: [FirebaseAuthRepository] is the only production
/// adapter for [AuthRepository], and [currentUidOf] reads a signed-in uid
/// through [CurrentUidProvider] only when the concrete type implements it.
/// If a future edit drops `CurrentUidProvider` from the `implements`
/// clause, [FirebaseAuthRepository] can no longer be assigned here and this
/// file fails to compile — closing the gap where every test still passes
/// (they all drive fakes that implement [CurrentUidProvider] on their own)
/// while the production adapter silently reads as signed-out forever and
/// the "remember the choice" feature dies with no red anywhere.
// ignore: unused_element
CurrentUidProvider _firebaseAuthRepositoryMustImplementCurrentUidProvider(
  FirebaseAuthRepository repo,
) => repo;

void main() {
  test(
    'nothing to run: this file exists for the compile-time pin above',
    () {},
  );
}
