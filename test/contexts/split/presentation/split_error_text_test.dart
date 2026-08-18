import 'dart:async' show TimeoutException;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/presentation/split_error_text.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('splitErrorText', () {
    test('maps each typed error to its own actionable copy, never a status code', () {
      expect(splitErrorText(loc, const NotFriends()), loc.splitErrorNotFriends);
      expect(splitErrorText(loc, const NotAGroupMember()), loc.splitErrorNotAGroupMember);
      expect(splitErrorText(loc, const GroupArchived()), loc.splitErrorGroupArchived);
      expect(
        splitErrorText(loc, const SharesDoNotSumToAmount('off by 5')),
        loc.splitErrorSharesMismatch('off by 5'),
      );
      expect(splitErrorText(loc, const SplitTooSmall()), loc.splitErrorTooSmall);
      expect(splitErrorText(loc, const DuplicateParticipant()), loc.splitErrorDuplicateParticipant);
      expect(splitErrorText(loc, const AlreadyAGroupMember()), loc.splitErrorAlreadyMember);
      expect(splitErrorText(loc, const NotAParticipant()), loc.splitErrorNotAParticipant);
      expect(
        splitErrorText(loc, const InvalidSplitInput('bad shape')),
        loc.splitErrorInvalidInput('bad shape'),
      );
      expect(
        splitErrorText(loc, const SplitBadRequest('missing field')),
        loc.splitErrorBadRequest('missing field'),
      );
      expect(splitErrorText(loc, const SplitNotFound()), loc.splitErrorNotFound);
      // Not reachable from either settle entry point today (both derive the
      // counterpart from a balance with someone else), so it is pinned here
      // — at the mapping — rather than by a UI test that could never fail.
      expect(
        splitErrorText(loc, const CannotSettleWithSelf()),
        loc.splitErrorCannotSettleWithSelf,
      );
      expect(
        splitErrorText(loc, const CannotSettleWithSelf()),
        isNot(loc.splitErrorGeneric),
      );
    });

    test('the two pass-through failures are framed in the reader\'s own language', () {
      final zh = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
      const message = 'day must be a YYYY-MM-DD calendar date';
      final invalid = splitErrorText(zh, const InvalidSplitInput(message));
      final bad = splitErrorText(zh, const SplitBadRequest(message));

      // The backend's own (English) explanation is still carried…
      expect(invalid, contains(message));
      expect(bad, contains(message));
      // …but never alone: a Chinese reader always gets a sentence of their
      // own around it, and the two failures never collapse into each other.
      expect(invalid, isNot(message));
      expect(bad, isNot(message));
      expect(invalid, isNot(bad));
    });

    test('an unmapped error falls back to the generic message', () {
      expect(splitErrorText(loc, Exception('anything')), loc.splitErrorGeneric);
    });

    // A client-side timeout means the request may or may not have reached
    // the server — the generic/backend-typed copy above all imply the
    // server responded and rejected it, which would wrongly invite a
    // duplicate submission.
    test('a client-side timeout gets its own copy, not the generic message', () {
      final text = splitErrorText(
        loc,
        TimeoutException('HTTP request timed out', const Duration(seconds: 15)),
      );
      expect(text, loc.splitErrorTimeout);
      expect(text, isNot(loc.splitErrorGeneric));
    });
  });
}
