import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('parses all fields from backend shape', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'firebase_uid': 'firebase-abc',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(profile.id, 'user-1');
      expect(profile.firebaseUid, 'firebase-abc');
      expect(profile.email, 'test@example.com');
      expect(profile.displayName, 'Test User');
      expect(profile.createdAt, '2026-01-01T00:00:00.000Z');
    });

    test('treats missing nullable fields as null', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'firebase_uid': 'firebase-abc',
        'email': null,
        'display_name': null,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(profile.email, isNull);
      expect(profile.displayName, isNull);
    });

    test('maps is_admin: true to isAdmin true', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'firebase_uid': 'firebase-abc',
        'email': null,
        'display_name': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'is_admin': true,
      });

      expect(profile.isAdmin, isTrue);
    });

    test('maps is_admin: false to isAdmin false', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'firebase_uid': 'firebase-abc',
        'email': null,
        'display_name': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'is_admin': false,
      });

      expect(profile.isAdmin, isFalse);
    });

    test('treats a missing is_admin key as isAdmin false, not a throw', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'firebase_uid': 'firebase-abc',
        'email': null,
        'display_name': null,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(profile.isAdmin, isFalse);
    });
  });
}
