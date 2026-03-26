// filepath: lib/src/domain/entities/user_profile.dart

/// A lightweight, public-facing snapshot of a user — the shape that other
/// users see when browsing friends or receiving meeting proposals.
///
/// Sensitive data (e.g. full schedule, device tokens) is deliberately absent.
class UserProfile {
  /// Firebase Auth UID — used as the Firestore document ID in `users/{uid}`.
  final String uid;

  /// Display name chosen by the user (e.g. "Teodor").
  final String displayName;

  /// Optional avatar URL (Firebase Storage or external CDN).
  final String? photoUrl;

  /// Optional email, only stored when the user opts in to discovery.
  final String? email;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.email,
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? photoUrl,
    String? email,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.uid == uid &&
          other.displayName == displayName &&
          other.photoUrl == photoUrl &&
          other.email == email;

  @override
  int get hashCode => Object.hash(uid, displayName, photoUrl, email);

  @override
  String toString() =>
      'UserProfile(uid: $uid, displayName: $displayName)';
}
