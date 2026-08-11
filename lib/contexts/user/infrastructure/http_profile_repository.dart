import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/profile_exceptions.dart';
import '../domain/display_name_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// [ProfileRepository] driven adapter backed by the `GET /api/me` HTTP
/// endpoint.
class HttpProfileRepository
    implements ProfileRepository, DisplayNameRepository {
  final String baseUrl;
  final http.Client client;

  HttpProfileRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your profile. Please try again.';

  @override
  Future<UserProfile> getProfile(String idToken) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } catch (_) {
      throw const ProfileFetchFailure(_genericFailureMessage);
    }

    if (response.statusCode == 401) {
      throw const ReauthenticationRequired();
    }

    if (response.statusCode != 200) {
      throw ProfileFetchFailure(
        'Failed to load profile (status ${response.statusCode}).',
      );
    }

    try {
      return UserProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const ProfileFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<UserProfile> updateDisplayName(
    String idToken,
    String displayName,
  ) async {
    final http.Response response;
    try {
      response = await client.patch(
        Uri.parse('$baseUrl/api/me'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'display_name': displayName}),
      );
    } catch (_) {
      throw const ProfileFetchFailure(_genericFailureMessage);
    }

    if (response.statusCode == 401) throw const ReauthenticationRequired();
    if (response.statusCode != 200) {
      throw const ProfileFetchFailure(_genericFailureMessage);
    }
    try {
      return UserProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const ProfileFetchFailure(_genericFailureMessage);
    }
  }
}
