/// The `split` field of a create/update-expense request: either an equal
/// split among participants, or an exact list of per-user shares. Mirrors
/// the backend's frozen `split` contract (design.md):
/// `{ mode: "equal", participant_user_ids: [...] }` or
/// `{ mode: "exact", shares: [{ user_id, amount }] }`.
sealed class SplitInput {
  const SplitInput();

  Map<String, dynamic> toJson();
}

class EqualSplitInput extends SplitInput {
  final List<String> participantUserIds;

  const EqualSplitInput(this.participantUserIds);

  @override
  Map<String, dynamic> toJson() => {
    'mode': 'equal',
    'participant_user_ids': participantUserIds,
  };
}

class ExactSplitInput extends SplitInput {
  final List<ExactShareInput> shares;

  const ExactSplitInput(this.shares);

  @override
  Map<String, dynamic> toJson() => {
    'mode': 'exact',
    'shares': shares.map((s) => s.toJson()).toList(),
  };
}

class ExactShareInput {
  final String userId;
  final int amount;

  const ExactShareInput({required this.userId, required this.amount});

  Map<String, dynamic> toJson() => {'user_id': userId, 'amount': amount};
}
