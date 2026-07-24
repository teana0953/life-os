import '../domain/push_repository.dart';

/// Requests a backend test push for the current subscription(s), returning
/// how many sends succeeded/failed.
class SendTestPush {
  final PushRepository _repository;

  SendTestPush(this._repository);

  Future<TestPushResult> call(String idToken) => _repository.sendTest(idToken);
}
