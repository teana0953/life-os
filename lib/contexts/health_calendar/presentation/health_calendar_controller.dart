import 'package:flutter/foundation.dart';

import '../../../shared/screen_batch/section_outcome.dart';
import '../application/get_health_calendar.dart';
import '../domain/health_calendar.dart';
import '../domain/health_calendar_exceptions.dart';

enum HealthCalendarStatus { loading, loaded, error, needsReauth }

/// Drives the dashboard's health-calendar card: loads a month's logged days +
/// rates. The month it opens on and "today" come from an injectable [clock]
/// (only the local date is used) so tests can pin them.
///
/// Month switching carries the same two guards as [FinanceController] (this
/// repo's most repeated bug class — a shared controller showing month A on
/// screen while month B's data lands in it):
///
/// - the outgoing month's [calendar] is dropped synchronously, so a slow or
///   failed switch never leaves the old month drawn under the new month's
///   label;
/// - a response for a month the user has since left is discarded instead of
///   overwriting the month they are now looking at.
class HealthCalendarController extends ChangeNotifier {
  final GetHealthCalendar _getHealthCalendar;
  final DateTime Function() _clock;

  HealthCalendarController(
    this._getHealthCalendar, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  HealthCalendarStatus status = HealthCalendarStatus.loading;
  HealthCalendar? calendar;

  /// `null` until a month is explicitly opened — and again after [reset].
  /// This is the sentinel that makes [reset] immune to in-flight responses
  /// (see [reset]); [selectedMonth] hides it from callers.
  DateTime? _selectedMonth;

  /// The month being viewed, as its first day. Falls back to the clock's local
  /// month — the card opens on the current month, as it always has.
  DateTime get selectedMonth => _selectedMonth ?? _currentMonth;

  DateTime get _currentMonth {
    final now = _clock();
    return DateTime(now.year, now.month);
  }

  /// Clears the signed-out user's month and data, so the next user opens the
  /// card on their own current month (design.md D2) rather than inheriting the
  /// previous user's browsed month and figures.
  ///
  /// Clearing to the `null` sentinel rather than re-assigning the current
  /// month is what makes this safe, mirroring `NetWorthController.reset`'s
  /// `''`: the staleness check compares against [_selectedMonth], and the
  /// current month is precisely the month most likely to be in flight at
  /// sign-out — so setting it here would let the previous user's response
  /// land in the next user's card. [selectedMonth] still reads as the current
  /// month, so the card and [load] open on it as before.
  void reset() {
    _selectedMonth = null;
    _batchMonthClaim = null;
    calendar = null;
    status = HealthCalendarStatus.loading;
  }

  /// Reloads the month currently being viewed. (Retries go through here, so a
  /// retry refreshes what the user is looking at, not whatever month it was
  /// when the app started.)
  Future<void> load(String idToken) =>
      loadMonth(idToken, selectedMonth.year, selectedMonth.month);

  /// Records the month a whole-screen batch round is about to request.
  /// Mirrors what [loadMonth] does with its own month — set synchronously,
  /// before the request goes out — so [applyBatchSection] can compare the
  /// response against a snapshot rather than against a value that moves
  /// under it. A *separate* field from [_selectedMonth], which belongs to
  /// the user: a round must never move the month they paged to.
  ///
  /// Without it the apply could only compare against [selectedMonth], which
  /// falls back to the clock's current month — so after [reset] cleared the
  /// signed-out user's month, that user's in-flight response would match the
  /// fallback and land in the next user's card.
  void claimBatchMonth(int year, int month) {
    _batchMonthClaim = DateTime(year, month);
  }

  DateTime? _batchMonthClaim;

  /// Applies the batched `health_calendar` section, but only when it is the
  /// month this card is showing — returns whether it did.
  ///
  /// The section is always computed for the round's `day`, so a card the user
  /// has paged to another month must not be overwritten by it; the caller
  /// leaves that one card alone.
  ///
  /// The claim is checked against the same nullable-sentinel rule
  /// [loadMonth]'s own staleness check uses: [reset] clears it, so *every*
  /// response in flight across a sign-out is stale — including one for what
  /// [selectedMonth] would still call the current month.
  bool applyBatchSection(
    SectionOutcome<HealthCalendar> section, {
    required int requestedYear,
    required int requestedMonth,
  }) {
    final claim = _batchMonthClaim;
    if (claim == null ||
        requestedYear != claim.year ||
        requestedMonth != claim.month) {
      return false;
    }
    if (requestedYear != selectedMonth.year ||
        requestedMonth != selectedMonth.month) {
      return false;
    }
    switch (section) {
      case SectionOk<HealthCalendar>(:final value):
        calendar = value;
        status = HealthCalendarStatus.loaded;
      case SectionUnavailable<HealthCalendar>():
        status = HealthCalendarStatus.error;
      case SectionReauth<HealthCalendar>():
        status = HealthCalendarStatus.needsReauth;
    }
    notifyListeners();
    return true;
  }

  /// Switches to [year]/[month] and loads its summary, passing the local
  /// `today` — which stays the real today whichever month is being viewed, so
  /// days-elapsed is judged against the user's calendar day, not server UTC.
  Future<void> loadMonth(String idToken, int year, int month) async {
    final isMonthChange =
        year != selectedMonth.year || month != selectedMonth.month;
    // Set synchronously, so a switch started after this one can tell this one
    // is stale by the time its response arrives.
    _selectedMonth = DateTime(year, month);
    if (isMonthChange) calendar = null;
    status = HealthCalendarStatus.loading;
    notifyListeners();

    final now = _clock();
    final today =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}';

    // Deliberately reads the nullable field, not the getter: after [reset]
    // there is no selected month, so *every* in-flight response is stale.
    bool stale() =>
        _selectedMonth?.year != year || _selectedMonth?.month != month;

    try {
      final loaded = await _getHealthCalendar(
        idToken,
        year: year,
        month: month,
        today: today,
      );
      if (stale()) return;
      calendar = loaded;
      status = HealthCalendarStatus.loaded;
    } on HealthCalendarReauthenticationRequired {
      if (stale()) return;
      status = HealthCalendarStatus.needsReauth;
    } on HealthCalendarFetchFailure {
      if (stale()) return;
      status = HealthCalendarStatus.error;
    } catch (_) {
      if (stale()) return;
      status = HealthCalendarStatus.error;
    }
    notifyListeners();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
