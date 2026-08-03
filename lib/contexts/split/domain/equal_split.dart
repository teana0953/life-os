/// Splits [amount] equally among [participantUserIds], mirroring the
/// backend's own `equalSplit` exactly (design.md D3/task 6.4b): integer
/// division, then the extra `amount % n` minor units go to the first `n`
/// participants **ordered by lowercase canonical UUID string** — not payer
/// order, not selection order, not name order. Any other order previews
/// different numbers than what the server actually stores, silently.
///
/// Returns a map from `userId` to its share, in [participantUserIds]' own
/// order — the sort above is internal only, used to decide who carries the
/// remainder.
Map<String, int> equalSplitAmounts(int amount, List<String> participantUserIds) {
  final n = participantUserIds.length;
  if (n == 0) return const {};
  final base = amount ~/ n;
  final remainder = amount % n;
  final sorted = [...participantUserIds]..sort(
    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
  );
  final extra = sorted.take(remainder).toSet();
  return {
    for (final id in participantUserIds) id: base + (extra.contains(id) ? 1 : 0),
  };
}
