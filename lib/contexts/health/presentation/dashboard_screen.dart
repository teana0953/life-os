import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../../body_profile/presentation/goal_card.dart';
import '../../body_profile/presentation/weight_goal_controller.dart';
import '../../vitals/presentation/trend_card.dart';
import '../../vitals/presentation/trend_controller.dart';

/// The health module's landing screen: a 總覽 (Overview) dashboard — a
/// scrollable stack of cards. For this change it holds the goal card plus a
/// "today's log" entry that opens the existing daily-log tab shell (via
/// [onOpenLog]). Owns the auth-token load (mirroring `DietShellScreen`) and
/// loads the weight goal on first build.
class DashboardScreen extends StatefulWidget {
  final WeightGoalController weightGoalController;
  final TrendController trendController;
  final AuthRepository authRepository;

  /// Signs the user out; wired to the needsReauth "sign in again" exit,
  /// mirroring the other health screens.
  final SignOut signOut;

  /// Opens the daily-log tab shell (the home wires this to push
  /// `DietShellScreen`). Returns when the shell is popped, so the dashboard can
  /// reload the goal (e.g. after a weight was recorded).
  final Future<void> Function() onOpenLog;

  const DashboardScreen({
    super.key,
    required this.weightGoalController,
    required this.trendController,
    required this.authRepository,
    required this.signOut,
    required this.onOpenLog,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _idToken;

  @override
  void initState() {
    super.initState();
    widget.weightGoalController.addListener(_onControllerChanged);
    widget.trendController.addListener(_onControllerChanged);
    _load();
  }

  @override
  void dispose() {
    widget.weightGoalController.removeListener(_onControllerChanged);
    widget.trendController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// Signs out, then pops this pushed dashboard (if it can) so the app-level
  /// auth routing — which by then has flipped `MaterialApp.home` to
  /// `LoginScreen` — becomes visible. Without the pop the dashboard would stay
  /// on top of the now-stale route, hiding the login screen (mirrors
  /// `SettingsScreen`'s sign-out-and-close).
  Future<void> _signOutAndClose() async {
    await widget.signOut();
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _load() async {
    final token = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    setState(() => _idToken = token);
    await widget.weightGoalController.load(token);
    await widget.trendController.load(token);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final idToken = _idToken;
    final appBar = AppBar(title: Text(loc.dashboardTitle));

    // The token is still resolving (first build) — show a spinner, mirroring
    // DietShell's null-token guard.
    if (idToken == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // A 401 on either the goal or the trend surfaces a re-authentication exit,
    // consistent with the other screens. The pushed dashboard keeps its app-bar
    // back button.
    if (widget.weightGoalController.status == WeightGoalStatus.needsReauth ||
        widget.trendController.status == TrendStatus.needsReauth) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('dashboard-sign-in-again-button'),
                onPressed: _signOutAndClose,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GoalCard(
                  controller: widget.weightGoalController,
                  idToken: idToken,
                ),
                const SizedBox(height: 16),
                TrendCard(
                  controller: widget.trendController,
                  idToken: idToken,
                  heightCm: widget.weightGoalController.goal?.heightCm,
                ),
                const SizedBox(height: 16),
                LedgeCard(
                  child: ListTile(
                    key: const Key('dashboard-record-entry'),
                    leading: const Icon(Icons.edit_note),
                    title: Text(loc.dashboardRecordEntryTitle),
                    subtitle: Text(loc.dashboardRecordEntrySubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    // Reload the goal after returning from the log shell so a
                    // weight just recorded is reflected without a manual refresh.
                    onTap: () async {
                      await widget.onOpenLog();
                      if (mounted) await _load();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
