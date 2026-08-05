import '../domain/split_activity.dart';

/// Where the reader stands in a repayment.
enum RepaymentViewpoint {
  /// The reader handed over the money — "You paid Ben".
  readerPaid,

  /// The reader received it — "Ben paid you".
  readerWasPaid,

  /// Neither party is the reader — "Amy paid Ben". Only reachable for a
  /// **group** repayment: a groupless one is visible to its creator, its
  /// payer and its payee and to nobody else.
  betweenOthers,
}

/// One side of a repayment. [displayName] is passed through untouched — for
/// the actor it can be a raw user id (the backend's own fallback), which the
/// row, not this function, is responsible for hiding.
class RepaymentParty {
  final String? userId;
  final String? displayName;

  const RepaymentParty({required this.userId, required this.displayName});
}

/// Who paid whom, resolved for one reader.
class RepaymentDirection {
  final RepaymentViewpoint viewpoint;
  final RepaymentParty payer;
  final RepaymentParty payee;

  const RepaymentDirection({
    required this.viewpoint,
    required this.payer,
    required this.payee,
  });

  /// The party who is *not* the reader. Only meaningful when the reader is
  /// one of the two — [RepaymentViewpoint.betweenOthers] names both instead.
  RepaymentParty get other =>
      viewpoint == RepaymentViewpoint.readerPaid ? payee : payer;
}

/// Turns the backend's actor-relative [SplitActivity.actorIsPayer] into who
/// paid whom **for this reader**, or `null` when the entry is not a
/// repayment at all.
///
/// This is the one genuinely hard piece of this screen, and the reason it is
/// a pure function instead of a few `?:` in a widget's `build`: the stored
/// boolean is relative to the *actor*, while the reader may be the actor,
/// the counterpart, or a group third party — six combinations, and getting
/// one wrong renders a completely ordinary-looking row that says the exact
/// opposite of what happened ("Ben paid you" for money the reader paid Ben).
/// Such a bug is invisible to every test that only checks that *a* row was
/// drawn.
///
/// The six cases are written out as six separate returns rather than
/// collapsed into `actorIsPayer ? (actor, counterpart) : (counterpart,
/// actor)` plus a comparison — they *are* equivalent, but the collapsed form
/// has only two branches, so no mutation of it can redden a single row of
/// the table test and the per-case coverage cannot be demonstrated. Here
/// each of the six leaves is independently mutable, which is what makes the
/// table test worth having.
RepaymentDirection? resolveRepaymentDirection(
  SplitActivity event,
  String? selfUserId,
) {
  final actorIsPayer = event.actorIsPayer;
  if (actorIsPayer == null) return null;

  final actor = RepaymentParty(
    userId: event.actorUserId,
    displayName: event.actorDisplayName,
  );
  final counterpart = RepaymentParty(
    userId: event.counterpartUserId,
    displayName: event.counterpartDisplayName,
  );

  // A null reader (the profile has not resolved) is nobody, and so falls
  // through to the third-party branch — never to "you".
  if (selfUserId != null && selfUserId == event.actorUserId) {
    return actorIsPayer
        ? RepaymentDirection(
            viewpoint: RepaymentViewpoint.readerPaid,
            payer: actor,
            payee: counterpart,
          )
        : RepaymentDirection(
            viewpoint: RepaymentViewpoint.readerWasPaid,
            payer: counterpart,
            payee: actor,
          );
  }

  if (selfUserId != null && selfUserId == event.counterpartUserId) {
    return actorIsPayer
        ? RepaymentDirection(
            viewpoint: RepaymentViewpoint.readerWasPaid,
            payer: actor,
            payee: counterpart,
          )
        : RepaymentDirection(
            viewpoint: RepaymentViewpoint.readerPaid,
            payer: counterpart,
            payee: actor,
          );
  }

  return actorIsPayer
      ? RepaymentDirection(
          viewpoint: RepaymentViewpoint.betweenOthers,
          payer: actor,
          payee: counterpart,
        )
      : RepaymentDirection(
          viewpoint: RepaymentViewpoint.betweenOthers,
          payer: counterpart,
          payee: actor,
        );
}
