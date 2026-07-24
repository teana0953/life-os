/// A Web Push subscription's three fields: the endpoint URL plus the two
/// encryption keys, as returned by the browser and sent to the backend.
class PushSubscription {
  final String endpoint;
  final String p256dh;
  final String auth;

  const PushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });
}
