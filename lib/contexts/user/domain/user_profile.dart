/// The authenticated user's profile, as returned by the backend `/api/me`.
class UserProfile {
  final String id;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String createdAt;

  UserProfile({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}
