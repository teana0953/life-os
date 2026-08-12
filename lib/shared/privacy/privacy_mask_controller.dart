import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A figure a user can choose to hide on the home hub.
///
/// **The identifiers below are the on-disk format.** They are persisted via
/// `.name` and read back via [PrivacyMaskItem.values], so renaming any of
/// them silently discards every existing user's choices on their next launch
/// — a rename here is a data migration, not a refactor. Pinned by
/// `privacy_mask_controller_test.dart` (U6).
enum PrivacyMaskItem { latestWeight, budget, netWorth, totalLiabilities }

/// The per-account key holding [PrivacyMaskItem.name]s the user hid.
///
/// Keyed by firebase uid, not a single shared key: this device is shared
/// between accounts (the same reason sign-out clears the Gemini key), and a
/// shared key would show B the figures A chose to hide — and overwrite A's
/// choices the first time B toggles anything.
String _prefsKeyFor(String uid) => 'privacy_hidden_items_$uid';

/// Holds which home-hub figures the signed-in user chose to hide, persisted
/// per account via [SharedPreferences].
///
/// Loading is deliberately **synchronous** ([loadForUser]): `SharedPreferences`
/// is already in memory by the time anyone signs in, so home cannot paint an
/// unmasked figure for a frame and then cover it up.
class PrivacyMaskController extends ChangeNotifier {
  final SharedPreferences _prefs;

  PrivacyMaskController(this._prefs);

  /// The account the in-memory set belongs to. `null` means signed out — see
  /// [setHidden], which then refuses to write, because there is no key it
  /// could safely write to.
  String? _uid;

  final Set<PrivacyMaskItem> _hidden = <PrivacyMaskItem>{};

  /// Replaces the in-memory set with [uid]'s stored choices. `null` behaves
  /// exactly like [clearUser]. Always notifies: the caller is an auth-state
  /// transition, and "the new user has nothing hidden" is still a change from
  /// whatever the previous one had.
  void loadForUser(String? uid) {
    _uid = uid;
    _hidden.clear();
    if (uid != null) {
      final stored = _prefs.getStringList(_prefsKeyFor(uid)) ?? const [];
      for (final name in stored) {
        // Unknown names are skipped rather than thrown on: an entry written
        // by a newer build (or a removed item) must not make sign-in fail.
        for (final item in PrivacyMaskItem.values) {
          if (item.name == name) _hidden.add(item);
        }
      }
    }
    notifyListeners();
  }

  /// Forgets the current user's choices **in memory only** — sign-out is a
  /// change of occupant, not a deletion, so signing back in as the same
  /// account restores their settings.
  void clearUser() {
    _uid = null;
    _hidden.clear();
    notifyListeners();
  }

  bool isHidden(PrivacyMaskItem item) => _hidden.contains(item);

  /// Sets [item]'s masked state and persists it.
  ///
  /// Memory first, then the write — the opposite of [GeminiKeyController]'s
  /// order, deliberately. That one guards a secret, where claiming success
  /// before the write lands is expensive; this is a display preference, and
  /// the eye has to respond to the tap in the same frame.
  Future<void> setHidden(PrivacyMaskItem item, bool hidden) async {
    final uid = _uid;
    // No uid, no key: writing under a placeholder would leak one account's
    // choice into whoever signs in next.
    if (uid == null) return;
    if (hidden) {
      _hidden.add(item);
    } else {
      _hidden.remove(item);
    }
    notifyListeners();
    // Written back even when empty (rather than `remove`): "I unhid
    // everything" is a real state, and one branch fewer to get wrong.
    await _prefs.setStringList(
      _prefsKeyFor(uid),
      _hidden.map((e) => e.name).toList(),
    );
  }

  Future<void> toggle(PrivacyMaskItem item) =>
      setHidden(item, !isHidden(item));
}
