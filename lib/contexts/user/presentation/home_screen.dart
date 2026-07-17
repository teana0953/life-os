import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/mascot.dart';
import 'home_controller.dart';

/// Illustrative-only preview names for the "Your spaces" grid — future
/// modules (Health, Finance, ...) are out of scope for this design-system
/// change; these are placeholders, not real navigation targets.
const _spacePreviewNames = ['Health', 'Finance', 'Tasks', 'Journal'];

const _contentMaxWidth = 960.0;

int _spacesCrossAxisCount(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth < _contentMaxWidth
                ? constraints.maxWidth
                : _contentMaxWidth;
            return Center(
              child: SizedBox(
                width: contentWidth,
                child: _buildBody(context, controller, contentWidth),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeController controller,
    double contentWidth,
  ) {
    final theme = Theme.of(context);
    switch (controller.status) {
      case HomeStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case HomeStatus.loaded:
        final profile = controller.profile!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Mascot(size: 64)),
              const SizedBox(height: 12),
              Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outline, width: 2),
                  boxShadow: ledgeShadow(theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(profile.email ?? '', style: theme.textTheme.bodyLarge),
                          Text(
                            profile.id,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Signed in',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Your spaces', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              GridView.builder(
                key: const Key('spaces-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _spacesCrossAxisCount(contentWidth),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: _spacePreviewNames.length,
                itemBuilder: (context, index) => Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outline, width: 2),
                  ),
                  child: Text(_spacePreviewNames[index]),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('sign-out-button'),
                onPressed: controller.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
      case HomeStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.errorMessage ?? 'Something went wrong.',
                key: const Key('error-message'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('sign-out-button'),
                onPressed: controller.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
      case HomeStatus.needsReauth:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.errorMessage ?? 'Please sign in again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('sign-in-again-button'),
                onPressed: controller.signOut,
                child: const Text('Sign in again'),
              ),
            ],
          ),
        );
    }
  }
}
