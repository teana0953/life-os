/// A net worth account's fixed macro-class. Immutable after creation (the
/// backend rejects a `kind` change).
enum NetWorthKind { asset, liability }

NetWorthKind netWorthKindFromJson(String value) =>
    value == 'liability' ? NetWorthKind.liability : NetWorthKind.asset;

String netWorthKindToJson(NetWorthKind kind) =>
    kind == NetWorthKind.liability ? 'liability' : 'asset';

/// A user's net worth account, as returned by
/// `GET /api/finance/networth/accounts`. The default set is seeded lazily by
/// the backend on first fetch.
class NetWorthAccount {
  final String id;
  final NetWorthKind kind;
  final String name;
  final int sortOrder;
  final bool archived;

  const NetWorthAccount({
    required this.id,
    required this.kind,
    required this.name,
    required this.sortOrder,
    required this.archived,
  });

  factory NetWorthAccount.fromJson(Map<String, dynamic> json) {
    return NetWorthAccount(
      id: json['id'] as String,
      kind: netWorthKindFromJson(json['kind'] as String),
      name: json['name'] as String,
      sortOrder: (json['sort_order'] as num).toInt(),
      archived: json['archived'] as bool,
    );
  }
}
