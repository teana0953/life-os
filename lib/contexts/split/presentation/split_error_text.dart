import '../../../l10n/generated/app_localizations.dart';
import '../domain/split_exceptions.dart';

/// Maps a typed split error to actionable, localized copy (design.md,
/// task 8.3) — every failure the backend distinguishes gets its own
/// sentence, never a bare status code. Used wherever a split mutation
/// (create/update/delete expense, create group, add member, archive) can
/// fail: the expense sheet, the split tab, and the group detail screen.
String splitErrorText(AppLocalizations loc, Object error) {
  if (error is NotFriends) return loc.splitErrorNotFriends;
  if (error is NotAGroupMember) return loc.splitErrorNotAGroupMember;
  if (error is GroupArchived) return loc.splitErrorGroupArchived;
  if (error is SharesDoNotSumToAmount) {
    return loc.splitErrorSharesMismatch(error.message);
  }
  if (error is SplitTooSmall) return loc.splitErrorTooSmall;
  if (error is DuplicateParticipant) return loc.splitErrorDuplicateParticipant;
  if (error is AlreadyAGroupMember) return loc.splitErrorAlreadyMember;
  if (error is NotAParticipant) return loc.splitErrorNotAParticipant;
  if (error is InvalidSplitInput) return loc.splitErrorInvalidInput(error.message);
  if (error is SplitBadRequest) return loc.splitErrorBadRequest(error.message);
  if (error is SplitNotFound) return loc.splitErrorNotFound;
  return loc.splitErrorGeneric;
}
