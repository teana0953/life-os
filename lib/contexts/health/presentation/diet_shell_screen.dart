import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/food_item.dart';
import 'daily_target_controller.dart';
import 'daily_target_screen.dart';
import 'dictionary_controller.dart';
import 'dictionary_screen.dart';
import 'log_entry_controller.dart';
import 'log_entry_screen.dart';
import 'manual_entry_controller.dart';
import 'manual_entry_screen.dart';
import 'today_controller.dart';
import 'today_screen.dart';

String _dayString(DateTime time) {
  final y = time.year.toString().padLeft(4, '0');
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Diet shell: bottom navigation across Today, Dictionary, and Target.
/// Owns the auth-token load (mirroring `_AuthenticatedHome`) and passes it
/// down to each section's controller.
class DietShellScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final TodayController todayController;
  final DictionaryController dictionaryController;
  final DailyTargetController dailyTargetController;
  final LogEntryController logEntryController;
  final ManualEntryController manualEntryController;
  final SignOut? signOut;

  /// Returns the current time, used to resolve "today" and to default the
  /// log-entry eaten-at time. Defaults to [DateTime.now]; tests inject a
  /// fixed clock.
  final DateTime Function() clock;

  const DietShellScreen({
    super.key,
    required this.authRepository,
    required this.todayController,
    required this.dictionaryController,
    required this.dailyTargetController,
    required this.logEntryController,
    required this.manualEntryController,
    this.signOut,
    this.clock = DateTime.now,
  });

  @override
  State<DietShellScreen> createState() => _DietShellScreenState();
}

class _DietShellScreenState extends State<DietShellScreen> {
  int _index = 0;
  String? _idToken;
  late final String _day = _dayString(widget.clock());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await widget.authRepository.idToken() ?? '';
    setState(() => _idToken = token);
    await widget.todayController.load(token, _day);
    await widget.dictionaryController.load(token);
    await widget.dailyTargetController.load(token, _day);
  }

  void _openLogEntry(FoodItem item) {
    final idToken = _idToken;
    if (idToken == null) return;
    widget.logEntryController.start(item, clock: widget.clock);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogEntryScreen(
          controller: widget.logEntryController,
          idToken: idToken,
          day: _day,
          onSaved: () => widget.todayController.load(idToken, _day),
        ),
      ),
    );
  }

  void _openManualEntry() {
    final idToken = _idToken;
    if (idToken == null) return;
    widget.manualEntryController.start(clock: widget.clock);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          controller: widget.manualEntryController,
          idToken: idToken,
          day: _day,
          onSaved: () => widget.todayController.load(idToken, _day),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final idToken = _idToken;

    final screens = [
      TodayScreen(
        controller: widget.todayController,
        signOut: widget.signOut ?? SignOut(widget.authRepository),
        onAddEntry: () => setState(() => _index = 1),
      ),
      DictionaryScreen(
        controller: widget.dictionaryController,
        onSelectItem: _openLogEntry,
        onManualEntry: _openManualEntry,
      ),
      idToken == null
          ? const Center(child: CircularProgressIndicator())
          : DailyTargetScreen(
              controller: widget.dailyTargetController,
              idToken: idToken,
              day: _day,
              // Refresh Today's portion progress after the target changes,
              // so switching back to Today reflects the new target.
              onSaved: () => widget.todayController.load(idToken, _day),
            ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today),
            label: loc.dietTabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book),
            label: loc.dietTabDictionary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flag),
            label: loc.dietTabTarget,
          ),
        ],
      ),
    );
  }
}
