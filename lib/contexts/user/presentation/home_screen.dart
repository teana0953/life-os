import 'package:flutter/material.dart';

import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  final HomeController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(child: _buildBody(controller)),
    );
  }

  Widget _buildBody(HomeController controller) {
    switch (controller.status) {
      case HomeStatus.loading:
        return const CircularProgressIndicator();
      case HomeStatus.loaded:
        final profile = controller.profile!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(profile.email ?? ''),
            Text(profile.id),
            ElevatedButton(
              key: const Key('sign-out-button'),
              onPressed: controller.signOut,
              child: const Text('Sign out'),
            ),
          ],
        );
      case HomeStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.errorMessage ?? 'Something went wrong.',
              key: const Key('error-message'),
            ),
            ElevatedButton(
              key: const Key('sign-out-button'),
              onPressed: controller.signOut,
              child: const Text('Sign out'),
            ),
          ],
        );
      case HomeStatus.needsReauth:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(controller.errorMessage ?? 'Please sign in again.'),
            ElevatedButton(
              key: const Key('sign-in-again-button'),
              onPressed: controller.signOut,
              child: const Text('Sign in again'),
            ),
          ],
        );
    }
  }
}
