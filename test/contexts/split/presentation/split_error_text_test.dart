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
  });
}
