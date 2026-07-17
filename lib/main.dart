import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'contexts/auth/application/sign_in.dart';
import 'contexts/auth/application/sign_out.dart';
import 'contexts/auth/infrastructure/firebase_auth_repository.dart';
import 'contexts/auth/presentation/login_controller.dart';
import 'contexts/user/application/get_profile.dart';
import 'contexts/user/infrastructure/http_profile_repository.dart';
import 'contexts/user/presentation/home_controller.dart';
import 'firebase_options.dart';
import 'shared/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authRepository = FirebaseAuthRepository(firebase_auth.FirebaseAuth.instance);
  final profileRepository = HttpProfileRepository(
    baseUrl: apiBaseUrl,
    client: http.Client(),
  );

  final loginController = LoginController(SignIn(authRepository));
  final homeController = HomeController(
    GetProfile(profileRepository),
    SignOut(authRepository),
  );

  runApp(
    App(
      authRepository: authRepository,
      loginController: loginController,
      homeController: homeController,
    ),
  );
}
