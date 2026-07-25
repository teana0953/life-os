import 'package:flutter/foundation.dart';

/// A generic "something changed" counter, bumped by a write flow (e.g. a
/// chaodays import) and listened to by whatever screen needs to know its
/// data may be stale (e.g. [HealthScaffold]) — see the
/// refresh-health-after-import design for why this indirection exists
/// instead of a direct dependency between the two.
class DataRevision extends ChangeNotifier {
  int _revision = 0;

  int get revision => _revision;

  /// Marks that something changed: increments [revision] and notifies
  /// listeners.
  void bump() {
    _revision++;
    notifyListeners();
  }
}
