import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/friend.dart';
import '../domain/friend_invite.dart';
import '../domain/invite_preview.dart';
import '../domain/social_exceptions.dart';
import '../domain/social_repository.dart';

/// [SocialRepository] driven adapter backed by the `/api/friends/*` HTTP
/// endpoints (contract frozen in design.md, backend PR #64).
///
/// Unlike `HttpFinanceRepository`'s `_throwForStatus`, error mapping here
/// cannot go by status code alone: the four `400` outcomes are told apart
/// by the response body's `error` field, so every non-2xx path reads the
/// body. A body that is empty or not JSON must not surface as a decode
/// error — it falls back to [SocialFetchFailure] (design.md).
class HttpSocialRepository implements SocialRepository {
  final String baseUrl;
  final http.Client client;

  HttpSocialRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const SocialFetchFailure();
    }
    if (response.statusCode == 401) {
      throw const SocialReauthenticationRequired();
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

  /// Maps a non-2xx response from `removeFriend`/`listInvites`/
  /// `createInvite`/`revokeInvite`/`listFriends` — the "generic" call
  /// sites. `404` here means the friendship/invite the caller targeted is
  /// gone, never that a link is invalid (design.md).
  Never _throwForSocialError(http.Response response) {
    if (response.statusCode == 404) throw const SocialNotFound();
    throw const SocialFetchFailure();
  }

  /// Maps a non-2xx response from `previewInvite`/`acceptInvite` — the
  /// invite-token call sites. `404` and `400 bad_request` both mean "this
  /// link is invalid" to the user, so both become [InviteNotFound].
  Never _throwForInviteError(http.Response response) {
    if (response.statusCode == 404) throw const InviteNotFound();
    if (response.statusCode == 400) {
      switch (_errorCode(response)) {
        case 'invite_expired':
          throw const InviteExpired();
        case 'invite_already_used':
          throw const InviteAlreadyUsed();
        case 'invite_revoked':
          throw const InviteRevoked();
        case 'cannot_friend_self':
          throw const CannotFriendSelf();
        case 'bad_request':
          throw const InviteNotFound();
      }
    }
    throw const SocialFetchFailure();
  }

  /// Decodes a 200 body with [parse], turning any malformed payload into
  /// [SocialFetchFailure] rather than letting a decode error escape.
  T _decode<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const SocialFetchFailure();
    }
  }

  @override
  Future<List<Friend>> listFriends(String idToken) async {
    final response = await _send(
      () => client.get(Uri.parse('$baseUrl/api/friends'), headers: _headers(idToken)),
    );
    if (response.statusCode != 200) _throwForSocialError(response);
    return _decode(
      response,
      (json) => (json['friends'] as List)
          .map((e) => Friend.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> removeFriend(String idToken, String friendUserId) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/friends/$friendUserId'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSocialError(response);
  }

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/friends/invites'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSocialError(response);
    return _decode(
      response,
      (json) => (
        token: json['token'] as String,
        expiresAt: json['expires_at'] as String,
      ),
    );
  }

  @override
  Future<List<FriendInvite>> listInvites(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/friends/invites'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSocialError(response);
    return _decode(
      response,
      (json) => (json['invites'] as List)
          .map((e) => FriendInvite.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> revokeInvite(String idToken, String id) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/friends/invites/$id'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForSocialError(response);
  }

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/friends/invites/preview'),
        headers: _headers(idToken),
        body: jsonEncode({'token': token}),
      ),
    );
    if (response.statusCode != 200) _throwForInviteError(response);
    return _decode(response, InvitePreview.fromJson);
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/friends/invites/accept'),
        headers: _headers(idToken),
        body: jsonEncode({'token': token}),
      ),
    );
    if (response.statusCode != 200) _throwForInviteError(response);
    return _decode(response, AcceptInviteResult.fromJson);
  }
}
