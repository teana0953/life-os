import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/balance.dart';
import '../domain/group_member.dart';
import '../domain/split_exceptions.dart';
import '../domain/split_expense.dart';
import '../domain/split_group.dart';
import '../domain/split_input.dart';
import '../domain/split_repository.dart';

/// [SplitRepository] driven adapter backed by the `/api/split/*` HTTP
/// endpoints (contract frozen in design.md, backend PR #65/#66).
///
/// Mirrors `HttpSocialRepository`: error mapping cannot go by status code
/// alone — the ten `400` outcomes are told apart by the response body's
/// `error` field, so every non-2xx path reads the body. A body that is
/// empty or not JSON must not surface as a decode error — it falls back to
/// [SplitFetchFailure].
class HttpSplitRepository implements SplitRepository {
  final String baseUrl;
  final http.Client client;

  HttpSplitRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const SplitFetchFailure();
    }
    if (response.statusCode == 401) {
      throw const SplitReauthenticationRequired();
    }
    return response;
  }

  /// The response body's `error` field, or `null` when the body is empty,
  /// not JSON, or not a JSON object — never throws.
  String? _errorCode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded['error'] as String?;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// The response body's `message` field, or `null` when unavailable.
  String? _errorMessage(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded['message'] as String?;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Maps a non-2xx response to a typed error. `404` -> [SplitNotFound];
  /// `400` dispatches on the body's `error` field across all ten codes,
  /// including `bad_request` (the route's own input validation); anything
  /// else, or an unrecognised `400` code, -> [SplitFetchFailure]. The
  /// three codes that carry `message` (`shares_do_not_sum_to_amount`,
  /// `invalid_split_input`, `bad_request`) carry it into the typed error.
  Never _throwForSplitError(http.Response response) {
    if (response.statusCode == 404) throw const SplitNotFound();
    if (response.statusCode == 400) {
      switch (_errorCode(response)) {
        case 'not_friends':
          throw const NotFriends();
        case 'not_a_group_member':
          throw const NotAGroupMember();
        case 'group_archived':
          throw const GroupArchived();
        case 'shares_do_not_sum_to_amount':
          throw SharesDoNotSumToAmount(_errorMessage(response) ?? '');
        case 'split_too_small':
          throw const SplitTooSmall();
        case 'duplicate_participant':
          throw const DuplicateParticipant();
        case 'already_a_group_member':
          throw const AlreadyAGroupMember();
        case 'not_a_participant':
          throw const NotAParticipant();
        case 'invalid_split_input':
          throw InvalidSplitInput(_errorMessage(response) ?? '');
        case 'bad_request':
          throw SplitBadRequest(_errorMessage(response) ?? '');
      }
    }
    throw const SplitFetchFailure();
  }

  /// Decodes a 2xx body with [parse], turning any malformed payload into
  /// [SplitFetchFailure] rather than letting a decode error escape.
  T _decode<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }

  @override
  Future<List<SplitGroup>> listGroups(String idToken) async {
    final response = await _send(
      () => client.get(Uri.parse('$baseUrl/api/split/groups'), headers: _headers(idToken)),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
    return _decode(
      response,
      (json) => (json['groups'] as List)
          .map((e) => SplitGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<SplitGroup> createGroup(String idToken, String name) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/split/groups'),
        headers: _headers(idToken),
        body: jsonEncode({'name': name}),
      ),
    );
    if (response.statusCode != 201) _throwForSplitError(response);
    return _decode(response, SplitGroup.fromJson);
  }

  @override
  Future<({SplitGroup group, List<GroupMember> members})> getGroup(
    String idToken,
    String groupId,
  ) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/split/groups/$groupId'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
    return _decode(
      response,
      (json) => (
        group: SplitGroup.fromJson(json['group'] as Map<String, dynamic>),
        members: (json['members'] as List)
            .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<GroupMember> addGroupMember(String idToken, String groupId, String userId) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/split/groups/$groupId/members'),
        headers: _headers(idToken),
        body: jsonEncode({'user_id': userId}),
      ),
    );
    if (response.statusCode != 201) _throwForSplitError(response);
    return _decode(response, GroupMember.fromJson);
  }

  @override
  Future<void> archiveGroup(String idToken, String groupId) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/split/groups/$groupId'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
  }

  @override
  Future<List<Balance>> getGroupBalances(String idToken, String groupId) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/split/groups/$groupId/balances'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
    return _decode(
      response,
      (json) =>
          (json['balances'] as List).map((e) => Balance.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<List<SplitExpense>> listExpenses(
    String idToken, {
    String? groupId,
    String? withUserId,
  }) async {
    final queryParameters = {
      if (groupId != null) 'group_id': groupId,
      if (withUserId != null) 'with': withUserId,
    };
    final uri = queryParameters.isEmpty
        ? Uri.parse('$baseUrl/api/split/expenses')
        : Uri.parse('$baseUrl/api/split/expenses').replace(queryParameters: queryParameters);
    final response = await _send(() => client.get(uri, headers: _headers(idToken)));
    if (response.statusCode != 200) _throwForSplitError(response);
    return _decode(
      response,
      (json) => (json['expenses'] as List)
          .map((e) => SplitExpense.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _expenseBody({
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  }) => {
    if (groupId != null) 'group_id': groupId,
    'payer_user_id': payerUserId,
    'amount': amount,
    'currency': currency,
    'description': description,
    'day': day,
    'split': split.toJson(),
  };

  @override
  Future<SplitExpense> createExpense(
    String idToken, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  }) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/split/expenses'),
        headers: _headers(idToken),
        body: jsonEncode(
          _expenseBody(
            groupId: groupId,
            payerUserId: payerUserId,
            amount: amount,
            currency: currency,
            description: description,
            day: day,
            split: split,
          ),
        ),
      ),
    );
    if (response.statusCode != 201) _throwForSplitError(response);
    return _decode(response, SplitExpense.fromJson);
  }

  @override
  Future<SplitExpense> getExpense(String idToken, String expenseId) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/split/expenses/$expenseId'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
    return _decode(response, SplitExpense.fromJson);
  }

  @override
  Future<SplitExpense> updateExpense(
    String idToken,
    String expenseId, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  }) async {
    final response = await _send(
      () => client.patch(
        Uri.parse('$baseUrl/api/split/expenses/$expenseId'),
        headers: _headers(idToken),
        body: jsonEncode(
          _expenseBody(
            groupId: groupId,
            payerUserId: payerUserId,
            amount: amount,
            currency: currency,
            description: description,
            day: day,
            split: split,
          ),
        ),
      ),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
    return _decode(response, SplitExpense.fromJson);
  }

  @override
  Future<void> deleteExpense(String idToken, String expenseId) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/split/expenses/$expenseId'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
  }

  @override
  Future<List<Balance>> getBalances(String idToken) async {
    final response = await _send(
      () => client.get(Uri.parse('$baseUrl/api/split/balances'), headers: _headers(idToken)),
    );
    if (response.statusCode != 200) _throwForSplitError(response);
    return _decode(
      response,
      (json) =>
          (json['balances'] as List).map((e) => Balance.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
